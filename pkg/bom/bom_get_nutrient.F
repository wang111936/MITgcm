#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_GET_NUTRIENT
C !INTERFACE:
      SUBROUTINE BOM_GET_NUTRIENT(
     I                 targetTime, targetIter,
     O                 failCode, nutrientValid,
     I                 myThid )

C !DESCRIPTION:
C     Evaluate one BOM-owned scalar nutrient FILES endpoint.  Failed
C     metadata, record or arithmetic checks modify work arrays only.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL targetTime
      INTEGER targetIter, myThid

C !OUTPUT PARAMETERS:
      INTEGER failCode
      LOGICAL nutrientValid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER bi, bj, i, j
      INTEGER previousRec, rec0, rec1
      INTEGER localErrCount, globalErrCount
      _RL weight0, weight1, locTime, locBase, cycleRecords
      _RL value0, value1, maxAbs, mixedValue, scaledValue
      LOGICAL fileValid, wetPoint, arithmeticValid

      failCode = BOM_FAIL_BIOLOGY_FIELD
      nutrientValid = .FALSE.
      localErrCount = 0
      previousRec = 0
      rec0 = 0
      rec1 = 0
      weight0 = 0. _d 0
      weight1 = 0. _d 0

      IF ( bomNSource.NE.'FILES' ) localErrCount = 1
      IF ( .NOT.IEEE_IS_FINITE(targetTime) .OR.
     &     .NOT.IEEE_IS_FINITE(bomNStartTime) .OR.
     &     .NOT.IEEE_IS_FINITE(bomNPeriod) .OR.
     &     .NOT.IEEE_IS_FINITE(bomNRepCycle) .OR.
     &     .NOT.IEEE_IS_FINITE(bomNInScale) ) THEN
        localErrCount = 1
      ELSEIF ( bomNPeriod.LE.0. _d 0 .OR.
     &         bomNRepCycle.LT.0. _d 0 .OR.
     &         bomNInScale.LE.0. _d 0 ) THEN
        localErrCount = 1
      ENDIF
      IF ( bomNFile.EQ.' ' ) localErrCount = 1
      IF ( bomNFilePrec.NE.32 .AND. bomNFilePrec.NE.64 )
     &     localErrCount = 1
      IF ( IEEE_IS_FINITE(bomNRepCycle) .AND.
     &     IEEE_IS_FINITE(bomNPeriod) ) THEN
       IF ( bomNRepCycle.GT.0. _d 0 .AND.
     &      bomNPeriod.GT.0. _d 0 ) THEN
        IF ( bomNPeriod.LT.bomNRepCycle/HUGE(oneRL) ) THEN
          localErrCount = 1
        ELSE
          cycleRecords = ANINT(bomNRepCycle/bomNPeriod)
          IF ( .NOT.IEEE_IS_FINITE(cycleRecords) ) THEN
            localErrCount = 1
          ELSEIF ( cycleRecords.LT.1. _d 0 .OR.
     &             bomNRepCycle.NE.cycleRecords*bomNPeriod ) THEN
            localErrCount = 1
          ENDIF
        ENDIF
       ENDIF
      ENDIF
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      CALL BOM_SAFE_ADD_RL(
     I     targetTime, -bomNStartTime,
     O     locBase, arithmeticValid )
      IF ( arithmeticValid ) CALL BOM_SAFE_ADD_RL(
     I     locBase, bomNPeriod*halfRL,
     O     locTime, arithmeticValid )
      localErrCount = 0
      IF ( .NOT.arithmeticValid ) localErrCount = 1
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      CALL GET_PERIODIC_INTERVAL(
     O     previousRec, rec0, rec1, weight0, weight1,
     I     bomNRepCycle, bomNPeriod,
     I     deltaTClock, locTime, myThid )
      localErrCount = 0
      IF ( rec0.LE.0 .OR. rec1.LE.0 ) THEN
        localErrCount = 1
      ELSEIF ( .NOT.IEEE_IS_FINITE(weight0) .OR.
     &         .NOT.IEEE_IS_FINITE(weight1) ) THEN
        localErrCount = 1
      ELSEIF ( weight0.LT.0. _d 0 .OR.
     &         weight0.GT.oneRL .OR.
     &         weight1.LT.0. _d 0 .OR.
     &         weight1.GT.oneRL ) THEN
        localErrCount = 1
      ENDIF
      IF ( localErrCount.EQ.0 ) THEN
        CALL BOM_SCALAR_FILE_PREFLIGHT(
     I       bomNFile, rec0, rec1, Nx, Ny, bomNFilePrec,
     O       fileValid,
     I       myThid )
        IF ( .NOT.fileValid ) localErrCount = 1
      ENDIF
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomBioNWork(i,j,1,bi,bj) = 0. _d 0
          bomBioN0(i,j,1,bi,bj) = 0. _d 0
          bomBioN1(i,j,1,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      CALL READ_REC_3D_RL(
     I     bomNFile, bomNFilePrec, 1,
     O     bomBioN0,
     I     rec0, targetIter, myThid )
      CALL READ_REC_3D_RL(
     I     bomNFile, bomNFilePrec, 1,
     O     bomBioN1,
     I     rec1, targetIter, myThid )

      localErrCount = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          value0 = bomBioN0(i,j,1,bi,bj)
          value1 = bomBioN1(i,j,1,bi,bj)
          IF ( .NOT.IEEE_IS_FINITE(value0) .OR.
     &         .NOT.IEEE_IS_FINITE(value1) ) THEN
            localErrCount = 1
          ELSEIF ( maskC(i,j,1,bi,bj).GT.0. ) THEN
            maxAbs = MAX(ABS(value0),ABS(value1))
            mixedValue = 0. _d 0
            IF ( maxAbs.GT.0. _d 0 )
     &         mixedValue = maxAbs*(weight0*(value0/maxAbs)
     &                    +weight1*(value1/maxAbs))
            IF ( .NOT.IEEE_IS_FINITE(mixedValue) ) THEN
              localErrCount = 1
            ELSE
              CALL BOM_SAFE_MULT_RL(
     I             bomNInScale, mixedValue,
     O             scaledValue, arithmeticValid )
              IF ( .NOT.arithmeticValid ) THEN
                localErrCount = 1
              ELSE
                bomBioNWork(i,j,1,bi,bj) =
     &               MAX(0. _d 0,scaledValue)
              ENDIF
            ENDIF
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      CALL EXCH_3D_RL( bomBioNWork, 1, myThid )
      localErrCount = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          IF ( .NOT.IEEE_IS_FINITE(
     &         bomBioNWork(i,j,1,bi,bj)) ) THEN
            localErrCount = 1
          ELSEIF ( .NOT.wetPoint .AND.
     &             bomBioNWork(i,j,1,bi,bj).NE.0. _d 0 ) THEN
            localErrCount = 1
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      failCode = BOM_FAIL_NONE
      nutrientValid = .TRUE.
#else
      failCode = BOM_FAIL_BIOLOGY_FIELD
      nutrientValid = .FALSE.
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SCALAR_FILE_PREFLIGHT(
     I                 fileName, rec0, rec1,
     I                 nX, nY, filePrec,
     O                 fileValid,
     I                 myThid )

      IMPLICIT NONE
#include "EEPARAMS.h"
      CHARACTER*(*) fileName
      INTEGER rec0, rec1, nX, nY, filePrec, myThid
      LOGICAL fileValid
      CHARACTER*(MAX_LEN_FNAM) dataName
      INTEGER nameLen, bytesPerValue, maxRec
      INTEGER*8 fileBytes, recordBytes, requiredBytes
      LOGICAL fileExists
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

      fileValid = .FALSE.
      fileBytes = -1_8
      fileExists = .FALSE.
      nameLen = ILNBLNK(fileName)
      IF ( nameLen.LE.0 .OR. nX.LE.0 .OR. nY.LE.0 ) RETURN
      IF ( filePrec.EQ.32 ) THEN
        bytesPerValue = 4
      ELSEIF ( filePrec.EQ.64 ) THEN
        bytesPerValue = 8
      ELSE
        RETURN
      ENDIF
      INQUIRE(FILE=fileName(1:nameLen),EXIST=fileExists,SIZE=fileBytes)
      IF ( .NOT.fileExists ) THEN
        WRITE(dataName,'(A,A)') fileName(1:nameLen), '.data'
        INQUIRE(FILE=dataName,EXIST=fileExists,SIZE=fileBytes)
      ENDIF
      IF ( .NOT.fileExists ) RETURN
      recordBytes = INT(nX,8)*INT(nY,8)*INT(bytesPerValue,8)
      maxRec = MAX(rec0,rec1)
      requiredBytes = recordBytes*INT(maxRec,8)
      IF ( recordBytes.LE.0_8 .OR. requiredBytes.LE.0_8 ) RETURN
      IF ( fileBytes.LT.requiredBytes ) RETURN
      IF ( MOD(fileBytes,recordBytes).NE.0_8 ) RETURN
      fileValid = .TRUE.

      RETURN
      END
