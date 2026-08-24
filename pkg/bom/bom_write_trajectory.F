#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_WRITE_TRAJECTORY
C !INTERFACE:
      SUBROUTINE BOM_WRITE_TRAJECTORY(
     I                 sampleTime, scheduledTime, myIter, myThid )

C !DESCRIPTION:
C     Write one P1.5 tiled MDS trajectory frame.  A complete 64-bit ID is
C     never converted to floating point; its unsigned 32-bit words are
C     independently exact in the fixed float64 record.

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
      _RL record(bomOutputFields)
      _RL nextTime
      _RS dummyRS(1)
      INTEGER bi, bj, ip, k, ioUnit, iRecord
      INTEGER iGlobal, jGlobal
      INTEGER*8 idRadix, idHi8, idLo8

      idRadix = 4294967296_8
      nextTime = bomNextOutputTime + bomOutputFreq
      IF ( rwSuffixType.EQ.0 ) THEN
        WRITE(suffix,'(I10.10)') myIter
      ELSE
        CALL RW_GET_SUFFIX( suffix, sampleTime, myIter, myThid )
      ENDIF
      WRITE(fileName,'(A,A10)') 'bom_traj.', suffix

      _BEGIN_MASTER(myThid)
      DO bj=1,nSy
       DO bi=1,nSx
        DO k=1,bomOutputFields
          record(k) = 0. _d 0
        ENDDO
        iGlobal = myXGlobalLo + (bi-1)*sNx
        jGlobal = myYGlobalLo + (bj-1)*sNy
        record(1) = bomOutputSchema
        record(2) = bomOutputFields
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

        ioUnit = -1
        iRecord = -1
        IF ( bomNPartTile(bi,bj).EQ.0 ) iRecord = 1
        CALL MDS_WRITEVEC_LOC(
     I       fileName, precFloat64, ioUnit,
     I       'RL', bomOutputFields, record, dummyRS,
     I       bi, bj, iRecord, myIter, myThid )

        DO ip=1,bomNPartTile(bi,bj)
          DO k=1,bomOutputFields
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
          iRecord = ip + 1
          IF ( ip.NE.bomNPartTile(bi,bj) ) iRecord = -iRecord
          CALL MDS_WRITEVEC_LOC(
     I         fileName, precFloat64, ioUnit,
     I         'RL', bomOutputFields, record, dummyRS,
     I         bi, bj, iRecord, myIter, myThid )
        ENDDO
        CLOSE(ioUnit)
       ENDDO
      ENDDO
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
