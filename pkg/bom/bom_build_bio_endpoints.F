#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_TRY_BUILD_BIO_ENDPOINTS
C !INTERFACE:
      SUBROUTINE BOM_TRY_BUILD_BIO_ENDPOINTS(
     I                 targetTime, targetIter, initialize,
     O                 failCode, buildValid,
     I                 myThid )

C !DESCRIPTION:
C     Build a complete P4.1 temperature/nutrient bracket in scratch.
C     Accepted state is published only by BOM_TRY_BUILD_ENDPOINTS after the
C     physical and biology transactions have both validated.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "DYNVARS.h"
#include "GRID.h"
#ifdef ALLOW_PTRACERS
# include "PTRACERS_SIZE.h"
# include "PTRACERS_FIELDS.h"
# include "PTRACERS_PARAMS.h"
#endif
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL targetTime
      INTEGER targetIter, myThid
      LOGICAL initialize

C !OUTPUT PARAMETERS:
      INTEGER failCode
      LOGICAL buildValid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER bi, bj, i, j, iEnd
      INTEGER tempCode, nCode
      INTEGER localErrCount, globalErrCount
      _RL oldTime, interval, timeScale, timeTol
      _RL tempValue, nValue
      LOGICAL isNear, compareValid, wetPoint, providerValid

      failCode = BOM_FAIL_BIOLOGY_FIELD
      buildValid = .FALSE.
      localErrCount = 0
      oldTime = targetTime
      tempCode = BOM_BIO_TEMP_NONE
      nCode = BOM_BIO_N_NONE
      IF ( .NOT.bomUseBiology ) localErrCount = 1
      IF ( bomTempSource.EQ.'THETA' ) THEN
        tempCode = BOM_BIO_TEMP_THETA
      ELSE
        localErrCount = 1
      ENDIF
      IF ( bomNSource.EQ.'PTRACER' ) THEN
        nCode = BOM_BIO_N_PTRACER
#ifndef ALLOW_PTRACERS
        localErrCount = 1
#else
        IF ( .NOT.usePTRACERS .OR.
     &       bomNTracerIndex.LT.1 .OR.
     &       bomNTracerIndex.GT.PTRACERS_num .OR.
     &       bomNTracerIndex.GT.PTRACERS_numInUse ) localErrCount = 1
#endif
      ELSEIF ( bomNSource.EQ.'FILES' ) THEN
        nCode = BOM_BIO_N_FILES
      ELSE
        localErrCount = 1
      ENDIF

      IF ( .NOT.IEEE_IS_FINITE(targetTime) ) THEN
        localErrCount = localErrCount + 1
      ELSEIF ( initialize ) THEN
        IF ( bomBioReady ) localErrCount = localErrCount + 1
        IF ( targetIter.NE.nIter0 ) localErrCount = localErrCount + 1
        IF ( .NOT.IEEE_IS_FINITE(startTime) ) THEN
          localErrCount = localErrCount + 1
        ELSE
          timeScale = MAX(oneRL,ABS(targetTime),ABS(startTime))
          timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
          CALL BOM_TIME_NEAR(
     I         targetTime, startTime, timeTol,
     O         isNear, compareValid )
          IF ( .NOT.compareValid .OR. .NOT.isNear )
     &         localErrCount = localErrCount + 1
        ENDIF
      ELSE
        IF ( .NOT.bomBioReady ) localErrCount = localErrCount + 1
        IF ( .NOT.IEEE_IS_FINITE(deltaTClock) ) THEN
          localErrCount = localErrCount + 1
        ELSEIF ( deltaTClock.LE.0. _d 0 .OR.
     &           targetTime.LE.-HUGE(oldTime)+deltaTClock ) THEN
          localErrCount = localErrCount + 1
        ELSE
          oldTime = targetTime-deltaTClock
          interval = targetTime-oldTime
          timeScale = MAX(oneRL,ABS(interval),ABS(deltaTClock))
          timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
          CALL BOM_TIME_NEAR(
     I         interval, deltaTClock, timeTol,
     O         isNear, compareValid )
          IF ( .NOT.compareValid .OR. .NOT.isNear )
     &         localErrCount = localErrCount + 1
        ENDIF
        IF ( bomBioIter(BOM_ENV_NEW).NE.targetIter-1 )
     &       localErrCount = localErrCount + 1
        IF ( bomBioTempSource(BOM_ENV_NEW).NE.tempCode .OR.
     &       bomBioNSource(BOM_ENV_NEW).NE.nCode )
     &       localErrCount = localErrCount + 1
        IF ( IEEE_IS_FINITE(oldTime) .AND.
     &       IEEE_IS_FINITE(bomBioTime(BOM_ENV_NEW)) ) THEN
          timeScale = MAX(oneRL,ABS(oldTime),
     &                         ABS(bomBioTime(BOM_ENV_NEW)))
          timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
          CALL BOM_TIME_NEAR(
     I         bomBioTime(BOM_ENV_NEW), oldTime, timeTol,
     O         isNear, compareValid )
          IF ( .NOT.compareValid .OR. .NOT.isNear )
     &         localErrCount = localErrCount + 1
        ELSE
          localErrCount = localErrCount + 1
        ENDIF
      ENDIF
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      _BEGIN_MASTER(myThid)
      IF ( initialize ) THEN
        bomBioTimeScratch(BOM_ENV_OLD) = targetTime
        bomBioIterScratch(BOM_ENV_OLD) = targetIter
        bomBioTempSourceScratch(BOM_ENV_OLD) = tempCode
        bomBioNSourceScratch(BOM_ENV_OLD) = nCode
      ELSE
        bomBioTimeScratch(BOM_ENV_OLD) =
     &       bomBioTime(BOM_ENV_NEW)
        bomBioIterScratch(BOM_ENV_OLD) =
     &       bomBioIter(BOM_ENV_NEW)
        bomBioTempSourceScratch(BOM_ENV_OLD) =
     &       bomBioTempSource(BOM_ENV_NEW)
        bomBioNSourceScratch(BOM_ENV_OLD) =
     &       bomBioNSource(BOM_ENV_NEW)
      ENDIF
      bomBioTimeScratch(BOM_ENV_NEW) = targetTime
      bomBioIterScratch(BOM_ENV_NEW) = targetIter
      bomBioTempSourceScratch(BOM_ENV_NEW) = tempCode
      bomBioNSourceScratch(BOM_ENV_NEW) = nCode
      _END_MASTER(myThid)
      _BARRIER

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomBioTempWork(i,j,1,bi,bj) = 0. _d 0
          bomBioNWork(i,j,1,bi,bj) = 0. _d 0
          DO iEnd=1,BOM_ENV_NEND
            bomBioTempScratch(i,j,iEnd,bi,bj) = 0. _d 0
            bomBioNScratch(i,j,iEnd,bi,bj) = 0. _d 0
            bomBioValidScratch(i,j,iEnd,bi,bj) = .FALSE.
          ENDDO
          IF ( .NOT.initialize ) THEN
            bomBioTempScratch(i,j,BOM_ENV_OLD,bi,bj) =
     &           bomBioTemp(i,j,BOM_ENV_NEW,bi,bj)
            bomBioNScratch(i,j,BOM_ENV_OLD,bi,bj) =
     &           bomBioN(i,j,BOM_ENV_NEW,bi,bj)
            bomBioValidScratch(i,j,BOM_ENV_OLD,bi,bj) =
     &           bomBioValid(i,j,BOM_ENV_NEW,bi,bj)
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Copy only the surface level into BOM-owned scalar work arrays.
      localErrCount = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          IF ( maskC(i,j,1,bi,bj).GT.0. ) THEN
            tempValue = theta(i,j,1,bi,bj)
            IF ( .NOT.IEEE_IS_FINITE(tempValue) ) THEN
              localErrCount = 1
            ELSE
              bomBioTempWork(i,j,1,bi,bj) = tempValue
            ENDIF
#ifdef ALLOW_PTRACERS
            IF ( bomNSource.EQ.'PTRACER' ) THEN
              nValue = pTracer(i,j,1,bi,bj,bomNTracerIndex)
              IF ( .NOT.IEEE_IS_FINITE(nValue) ) THEN
                localErrCount = 1
              ELSE
                bomBioNWork(i,j,1,bi,bj) = MAX(0. _d 0,nValue)
              ENDIF
            ENDIF
#endif
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      CALL EXCH_3D_RL( bomBioTempWork, 1, myThid )
      IF ( bomNSource.EQ.'PTRACER' ) THEN
        CALL EXCH_3D_RL( bomBioNWork, 1, myThid )
      ELSE
        CALL BOM_GET_NUTRIENT(
     I       targetTime, targetIter,
     O       failCode, providerValid,
     I       myThid )
        IF ( .NOT.providerValid ) RETURN
      ENDIF

C--   Validate exchanged halos, then populate NEW and optional fresh OLD.
      localErrCount = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          tempValue = bomBioTempWork(i,j,1,bi,bj)
          nValue = bomBioNWork(i,j,1,bi,bj)
          IF ( .NOT.IEEE_IS_FINITE(tempValue) .OR.
     &         .NOT.IEEE_IS_FINITE(nValue) ) THEN
            localErrCount = 1
          ELSEIF ( wetPoint ) THEN
            IF ( nValue.LT.0. _d 0 ) localErrCount = 1
            bomBioTempScratch(i,j,BOM_ENV_NEW,bi,bj) = tempValue
            bomBioNScratch(i,j,BOM_ENV_NEW,bi,bj) = nValue
            bomBioValidScratch(i,j,BOM_ENV_NEW,bi,bj) = .TRUE.
          ELSEIF ( tempValue.NE.0. _d 0 .OR.
     &             nValue.NE.0. _d 0 ) THEN
            localErrCount = 1
          ENDIF
          IF ( initialize ) THEN
            bomBioTempScratch(i,j,BOM_ENV_OLD,bi,bj) =
     &           bomBioTempScratch(i,j,BOM_ENV_NEW,bi,bj)
            bomBioNScratch(i,j,BOM_ENV_OLD,bi,bj) =
     &           bomBioNScratch(i,j,BOM_ENV_NEW,bi,bj)
            bomBioValidScratch(i,j,BOM_ENV_OLD,bi,bj) =
     &           bomBioValidScratch(i,j,BOM_ENV_NEW,bi,bj)
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

C--   Revalidate both complete endpoints, including the preserved OLD copy.
      localErrCount = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          DO iEnd=1,BOM_ENV_NEND
            tempValue = bomBioTempScratch(i,j,iEnd,bi,bj)
            nValue = bomBioNScratch(i,j,iEnd,bi,bj)
            IF ( wetPoint ) THEN
              IF ( .NOT.bomBioValidScratch(i,j,iEnd,bi,bj)
     &             .OR. .NOT.IEEE_IS_FINITE(tempValue)
     &             .OR. .NOT.IEEE_IS_FINITE(nValue) ) THEN
                localErrCount = 1
              ELSEIF ( nValue.LT.0. _d 0 ) THEN
                localErrCount = 1
              ENDIF
            ELSE
              IF ( bomBioValidScratch(i,j,iEnd,bi,bj)
     &             .OR. tempValue.NE.0. _d 0
     &             .OR. nValue.NE.0. _d 0 ) localErrCount = 1
            ENDIF
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      failCode = BOM_FAIL_NONE
      buildValid = .TRUE.
#else
      failCode = BOM_FAIL_BIOLOGY_FIELD
      buildValid = .FALSE.
#endif

      RETURN
      END
