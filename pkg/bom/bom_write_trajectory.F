#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_WRITE_TRAJECTORY
C !INTERFACE:
      SUBROUTINE BOM_WRITE_TRAJECTORY(
     I                 sampleTime, scheduledTime, myIter, myThid )

C !DESCRIPTION:
C     Write one mode-selected tiled MDS trajectory frame.  LEEW retains the
C     exact schema-1 record.  BOM schema 2 appends the accepted 27-component
C     slow-manifold diagnostic plus its equation and current-policy codes.
C     Spring-enabled BOM adds the required schema-3 signature and sidecar
C     without changing the accepted schema-2 core record.
C     A complete 64-bit ID is never converted to floating point; its unsigned
C     32-bit words are independently exact in every float64 record.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL sampleTime, scheduledTime
      INTEGER myIter, myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_FNAM) fileName
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*10 suffix
      _RL record(bomOutputFields2)
      _RL nextTime
      _RS dummyRS(1)
      INTEGER bi, bj, ip, k, ioUnit, iRecord, iDiag
      INTEGER iGlobal, jGlobal
      INTEGER activeSchema, activeFields
      INTEGER localErrCount, globalErrCount
      INTEGER modeCode, equationCode, currentCode
      INTEGER windCode, stokesCode, integratorCode
      INTEGER*8 idRadix, idHi8, idLo8
      LOGICAL codesValid, useSchema3

      idRadix = 4294967296_8
      activeSchema = bomOutputSchema
      activeFields = bomOutputFields
      modeCode = 1
      equationCode = 0
      currentCode = 0
      windCode = 0
      stokesCode = 0
      integratorCode = 0
      codesValid = .TRUE.
      useSchema3 = .FALSE.
      IF ( bomMode.EQ.'BOM' ) THEN
        activeSchema = bomOutputSchema2
        activeFields = bomOutputFields2
        CALL BOM_PICKUP2_CODES(
     O       modeCode, equationCode, currentCode,
     O       windCode, stokesCode, integratorCode,
     O       codesValid )
        useSchema3 = bomSpringLaw.NE.'NONE'
      ENDIF
      IF ( .NOT.codesValid ) THEN
        WRITE(msgBuf,'(A,I12,A,A,A,A)')
     &       'BOM_WRITE_TRAJECTORY: invalid schema-2 codes iter=',
     &       myIter, ' equation=', bomEquationMode,
     &       ' current=', bomCurrentPolicy
        CALL PRINT_ERROR( msgBuf, myThid )
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_WRITE_TRAJECTORY'
      ENDIF
      nextTime = bomNextOutputTime + bomOutputFreq
      IF ( rwSuffixType.EQ.0 ) THEN
        WRITE(suffix,'(I10.10)') myIter
      ELSE
        CALL RW_GET_SUFFIX( suffix, sampleTime, myIter, myThid )
      ENDIF
      WRITE(fileName,'(A,A10)') 'bom_traj.', suffix

C--   Reject invalid schema-3 state before creating any frame member.
      IF ( useSchema3 ) THEN
        CALL BOM_VALIDATE_P3_IO_STATE(
     I       sampleTime, myIter, nextTime,
     O       localErrCount,
     I       myThid )
        globalErrCount = localErrCount
        CALL GLOBAL_SUM_INT( globalErrCount, myThid )
        IF ( globalErrCount.GT.0 ) THEN
          _BEGIN_MASTER(myThid)
          IF ( myProcId.EQ.0 ) THEN
            WRITE(msgBuf,'(A,I4,A,I12)')
     &           'BOM_WRITE_TRAJECTORY: schema-3 state code=',
     &           BOM_FAIL_PICKUP_SCHEMA3, ' errors=', globalErrCount
            CALL PRINT_ERROR( msgBuf, myThid )
          ENDIF
          _END_MASTER(myThid)
          CALL ALL_PROC_DIE( 0 )
          STOP 'ABNORMAL END: S/R BOM_WRITE_TRAJECTORY'
        ENDIF
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( useSchema3 ) THEN
        CALL BOM_WRITE_P3_SIGNATURE(
     I       fileName, sampleTime, myIter,
     I       bomNPartExpected, nextTime,
     O       localErrCount,
     I       myThid )
        IF ( localErrCount.NE.0 ) THEN
          CALL ALL_PROC_DIE( 0 )
          STOP 'ABNORMAL END: S/R BOM_WRITE_TRAJECTORY'
        ENDIF
      ENDIF
      DO bj=1,nSy
       DO bi=1,nSx
        DO k=1,activeFields
          record(k) = 0. _d 0
        ENDDO
        iGlobal = myXGlobalLo + (bi-1)*sNx
        jGlobal = myYGlobalLo + (bj-1)*sNy
        record(1) = activeSchema
        record(2) = activeFields
        record(3) = bomNPartTile(bi,bj)
        record(4) = bomNPartExpected
        record(5) = 1. _d 0
        record(6) = 1. _d 0
        record(7) = 64. _d 0
        record(8) = myIter
        record(9) = sampleTime
        record(10) = scheduledTime
        record(11) = nextTime
        record(12) = nPx
        record(13) = nPy
        record(14) = iGlobal
        record(15) = jGlobal
        record(16) = myProcId
        record(17) = bi
        record(18) = bj
        IF ( activeSchema.EQ.bomOutputSchema2 ) THEN
          record(19) = modeCode
          record(20) = equationCode
          record(21) = currentCode
          record(22) = windCode
          record(23) = stokesCode
          record(24) = integratorCode
          record(25) = BOM_RHS_NDIAG
          record(26) = 22
          record(27) = bomOutputFields2
        ENDIF

        ioUnit = -1
        iRecord = -1
        IF ( bomNPartTile(bi,bj).EQ.0 ) iRecord = 1
        CALL MDS_WRITEVEC_LOC(
     I       fileName, precFloat64, ioUnit,
     I       'RL', activeFields, record, dummyRS,
     I       bi, bj, iRecord, myIter, myThid )

        DO ip=1,bomNPartTile(bi,bj)
          DO k=1,activeFields
            record(k) = 0. _d 0
          ENDDO
          idHi8 = bomId(ip,bi,bj)/idRadix
          idLo8 = MOD(bomId(ip,bi,bj),idRadix)
          record(1) = idHi8
          record(2) = idLo8
          record(3) = bomStatus(ip,bi,bj)
          record(4) = sampleTime
          record(5) = myIter
          record(6) = bomX(ip,bi,bj)
          record(7) = bomY(ip,bi,bj)
          record(8) = bomReleaseTime(ip,bi,bj)
          record(9) = bomAge(ip,bi,bj)
          record(10) = bomI(ip,bi,bj)
          record(11) = bomJ(ip,bi,bj)
          record(12) = bomVEast(ip,bi,bj)
          record(13) = bomVNorth(ip,bi,bj)
          record(14) = bomWindEast(ip,bi,bj)
          record(15) = bomWindNorth(ip,bi,bj)
          record(16) = bomDriftEast(ip,bi,bj)
          record(17) = bomDriftNorth(ip,bi,bj)
          record(18) = myProcId
          record(19) = bi
          record(20) = bj
          record(21) = 1. _d 0
          IF ( activeSchema.EQ.bomOutputSchema2 ) THEN
            DO iDiag=1,BOM_RHS_NDIAG
              record(21+iDiag) =
     &             bomRhsDiag(iDiag,ip,bi,bj)
            ENDDO
          ENDIF
          iRecord = ip + 1
          IF ( ip.NE.bomNPartTile(bi,bj) ) iRecord = -iRecord
          CALL MDS_WRITEVEC_LOC(
     I         fileName, precFloat64, ioUnit,
     I         'RL', activeFields, record, dummyRS,
     I         bi, bj, iRecord, myIter, myThid )
        ENDDO
        CLOSE(ioUnit)
       ENDDO
      ENDDO
      IF ( useSchema3 ) THEN
        CALL BOM_WRITE_P3_SIDECAR(
     I       fileName, sampleTime, scheduledTime,
     I       nextTime, myIter, myThid )
      ENDIF
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A,A10,A,I12,A,3(1X,1PE24.16))')
     &       'BOM_WRITE_TRAJECTORY: suffix=', suffix,
     &       ' count=', bomNPartExpected,
     &       ' sample/scheduled/next=',
     &       sampleTime, scheduledTime, nextTime
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
      _BARRIER
#endif

      RETURN
      END
