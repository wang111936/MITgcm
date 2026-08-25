#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_WRITE_PICKUP
C !INTERFACE:
      SUBROUTINE BOM_WRITE_PICKUP(
     I                 suffix, myTime, myIter, myThid )

C !DESCRIPTION:
C     Write the mode-selected pickup transaction.  LEEW retains the exact
C     schema-1 layout; BOM adds schema-2 fingerprint and endpoint sidecars.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      CHARACTER*(*) suffix
      _RL myTime
      INTEGER myIter, myThid
CEOP

C !FUNCTIONS:
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_FNAM) fileName, sigName
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      _RL signature(
     &     bomPickup2SigBase+2*MAX_LEN_FNAM+256)
      _RL record(bomPickupFields)
      _RL timeScale, timeTol
      _RS dummyRS(1)
      INTEGER bi, bj, ip, k, ioUnit, iRecord, suffixLen
      INTEGER iGlobal, jGlobal
      INTEGER localErrCount, globalErrCount
      INTEGER envLocalErr, activeSchema, sigFields, envFields
      INTEGER sigRecordFields, sigRecords, sigIndex, writeRecord
      INTEGER localOwnerCount, globalOwnerCount
      INTEGER*8 idRadix, idHi8, idLo8
      LOGICAL schemaValid

      idRadix = 4294967296_8
      localErrCount = 0
      localOwnerCount = 0
      activeSchema = bomPickupSchema
      sigFields = bomPickupSigFields
      sigRecordFields = sigFields
      envFields = 0
      schemaValid = .TRUE.
      IF ( bomMode.EQ.'BOM' ) THEN
        activeSchema = bomPickupSchema2
        CALL BOM_GET_PICKUP2_SIZES(
     O       sigFields, envFields )
        sigRecordFields = bomPickupChunkFields
        CALL BOM_VALIDATE_ENV_PICKUP_STATE(
     I       myTime, myIter,
     O       envLocalErr,
     I       myThid )
        localErrCount = localErrCount + envLocalErr
        CALL BOM_BUILD_PICKUP2_SIGNATURE(
     I       myTime, myIter, bomNPartExpected, bomNextOutputTime,
     I       bomEnvTime(BOM_ENV_OLD), bomEnvTime(BOM_ENV_NEW),
     I       bomEnvIter(BOM_ENV_OLD), bomEnvIter(BOM_ENV_NEW),
     I       bomEnvReady,
     O       signature, sigFields, envFields, schemaValid,
     I       myThid )
        IF ( .NOT.schemaValid ) localErrCount = localErrCount + 1
      ENDIF
      sigRecords = (sigFields+sigRecordFields-1)/sigRecordFields
      suffixLen = ILNBLNK(suffix)
      timeScale = MAX(oneRL,ABS(myTime),ABS(bomOutputFreq),
     &                ABS(bomNextOutputTime))
      timeTol = 16. _d 0*EPSILON(oneRL)*timeScale

      IF ( suffixLen.LE.0 ) localErrCount = localErrCount + 1
      IF ( .NOT.IEEE_IS_FINITE(myTime) .OR.
     &     .NOT.IEEE_IS_FINITE(bomOutputFreq) .OR.
     &     .NOT.IEEE_IS_FINITE(bomNextOutputTime) .OR.
     &     .NOT.bomOutputScheduleReady ) THEN
        localErrCount = localErrCount + 1
      ELSEIF ( bomOutputFreq.EQ.0. _d 0 ) THEN
        IF ( bomNextOutputTime.NE.0. _d 0 )
     &       localErrCount = localErrCount + 1
      ELSEIF ( bomOutputFreq.LT.0. _d 0 .OR.
     &         bomNextOutputTime.LE.myTime+timeTol ) THEN
        localErrCount = localErrCount + 1
      ENDIF
      IF ( bomNPartExpected.LT.0 .OR.
     &     bomNPartExpected.GT.bomMaxParticles .OR.
     &     bomNPartExpected.GT.bomInitGlobalLimit .OR.
     &     bomNPartExpected.GT.bomMaxInitRecords ) THEN
        localErrCount = localErrCount + 1
      ENDIF

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        IF ( bomNPartTile(bi,bj).LT.0 .OR.
     &       bomNPartTile(bi,bj).GT.bomMaxPartTile ) THEN
          localErrCount = localErrCount + 1
        ELSE
          localOwnerCount = localOwnerCount + bomNPartTile(bi,bj)
        ENDIF
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      globalOwnerCount = localOwnerCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      CALL GLOBAL_SUM_INT( globalOwnerCount, myThid )
      IF ( globalOwnerCount.NE.bomNPartExpected )
     &     globalErrCount = globalErrCount + 1
      IF ( globalErrCount.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,A,A,3I12,A,L3,A,3(1X,1PE24.16))')
     &         'BOM_WRITE_PICKUP: invalid state suffix=', suffix,
     &         ' iter/count/expected=', myIter,
     &         globalOwnerCount, bomNPartExpected,
     &         ' ready=', bomOutputScheduleReady,
     &         ' time/freq/next=', myTime, bomOutputFreq,
     &         bomNextOutputTime
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_WRITE_PICKUP'
      ENDIF

C--   The full state budget is meaningful only for a nonempty owner set.
      IF ( bomNPartExpected.GT.0 ) THEN
        CALL BOM_CHECK_STATE(
     I       myTime, myIter, 'PICKUP_WRITE', myThid )
      ENDIF

      WRITE(fileName,'(A,A)') 'pickup_bom.', suffix(1:suffixLen)
      WRITE(sigName,'(A,A)') fileName(1:ILNBLNK(fileName)), '.sig'

      _BEGIN_MASTER(myThid)
      IF ( activeSchema.EQ.bomPickupSchema ) THEN
        DO k=1,sigFields
          signature(k) = 0. _d 0
        ENDDO
        signature(1) = bomPickupSchema
        signature(2) = bomPickupSigFields
        signature(3) = nPx
        signature(4) = nPy
        signature(5) = sNx
        signature(6) = sNy
        signature(7) = nSx
        signature(8) = nSy
        signature(9) = Nx
        signature(10) = Ny
        signature(11) = bomMaxPartTile
        signature(12) = bomNPartExpected
        signature(13) = myIter
        signature(14) = myTime
        signature(15) = bomOutputFreq
        signature(16) = bomNextOutputTime
      ENDIF
      ioUnit = -1
      DO iRecord=1,sigRecords
        DO k=1,sigRecordFields
          record(k) = 0. _d 0
          sigIndex = (iRecord-1)*sigRecordFields+k
          IF ( sigIndex.LE.sigFields )
     &         record(k) = signature(sigIndex)
        ENDDO
        writeRecord = iRecord
        IF ( iRecord.LT.sigRecords ) writeRecord = -iRecord
        CALL MDS_WRITEVEC_LOC(
     I       sigName, precFloat64, ioUnit,
     I       'RL', sigRecordFields, record, dummyRS,
     I       0, 0, writeRecord, myIter, myThid )
      ENDDO
      IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
      IF ( activeSchema.EQ.bomPickupSchema2 ) THEN
        CALL BOM_WRITE_PICKUP_ENV(
     I       fileName, myTime, myIter, envFields, myThid )
      ENDIF

      DO bj=1,nSy
       DO bi=1,nSx
        DO k=1,bomPickupFields
          record(k) = 0. _d 0
        ENDDO
        iGlobal = myXGlobalLo + (bi-1)*sNx
        jGlobal = myYGlobalLo + (bj-1)*sNy
        record(1) = activeSchema
        record(2) = bomPickupFields
        record(3) = bomNPartTile(bi,bj)
        record(4) = bomNPartExpected
        record(5) = 1. _d 0
        record(6) = 1. _d 0
        record(7) = 64. _d 0
        record(8) = myIter
        record(9) = myTime
        record(10) = bomNextOutputTime
        record(11) = bomOutputFreq
        record(12) = nPx
        record(13) = nPy
        record(14) = sNx
        record(15) = sNy
        record(16) = nSx
        record(17) = nSy
        record(18) = iGlobal
        record(19) = jGlobal
        record(20) = myProcId
        record(21) = bi
        record(22) = bj
        record(23) = bomMaxPartTile

        ioUnit = -1
        iRecord = -1
        IF ( bomNPartTile(bi,bj).EQ.0 ) iRecord = 1
        CALL MDS_WRITEVEC_LOC(
     I       fileName, precFloat64, ioUnit,
     I       'RL', bomPickupFields, record, dummyRS,
     I       bi, bj, iRecord, myIter, myThid )

        DO ip=1,bomNPartTile(bi,bj)
          DO k=1,bomPickupFields
            record(k) = 0. _d 0
          ENDDO
          idHi8 = bomId(ip,bi,bj)/idRadix
          idLo8 = MOD(bomId(ip,bi,bj),idRadix)
          record(1) = idHi8
          record(2) = idLo8
          record(3) = bomStatus(ip,bi,bj)
          record(4) = bomX(ip,bi,bj)
          record(5) = bomY(ip,bi,bj)
          record(6) = bomReleaseTime(ip,bi,bj)
          record(7) = bomAge(ip,bi,bj)
          record(8) = bomI(ip,bi,bj)
          record(9) = bomJ(ip,bi,bj)
          record(10) = bomVEast(ip,bi,bj)
          record(11) = bomVNorth(ip,bi,bj)
          record(12) = bomWindEast(ip,bi,bj)
          record(13) = bomWindNorth(ip,bi,bj)
          record(14) = bomDriftEast(ip,bi,bj)
          record(15) = bomDriftNorth(ip,bi,bj)
          record(16) = myProcId
          record(17) = bi
          record(18) = bj
          iRecord = ip + 1
          IF ( ip.NE.bomNPartTile(bi,bj) ) iRecord = -iRecord
          CALL MDS_WRITEVEC_LOC(
     I         fileName, precFloat64, ioUnit,
     I         'RL', bomPickupFields, record, dummyRS,
     I         bi, bj, iRecord, myIter, myThid )
        ENDDO
        CLOSE(ioUnit)
       ENDDO
      ENDDO
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A,A,A,I12,A,3(1X,1PE24.16))')
     &       'BOM_WRITE_PICKUP: suffix=', suffix(1:suffixLen),
     &       ' count=', bomNPartExpected,
     &       ' time/freq/next=', myTime, bomOutputFreq,
     &       bomNextOutputTime
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
      _BARRIER
#endif

      RETURN
      END
