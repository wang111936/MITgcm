#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BUILD_ENDPOINTS
C !INTERFACE:
      SUBROUTINE BOM_BUILD_ENDPOINTS(
     I                 targetTime, targetIter, initialize,
     I                 myThid )

C !DESCRIPTION:
C     Publish one Phase-2 environmental endpoint transaction or stop.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL targetTime
      INTEGER targetIter, myThid
      LOGICAL initialize
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER failCode, failStage
      LOGICAL buildValid

      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     targetTime, targetIter, initialize,
     O     failCode, failStage, buildValid,
     I     myThid )
      IF ( .NOT.buildValid ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,1PE24.16,A,3I12,A,2A)')
     &         'BOM_BUILD_ENDPOINTS: failed time=', targetTime,
     &         ' iter/stage/code=', targetIter, failStage, failCode,
     &         ' wind/Stokes=', bomWindSource, bomStokesSource
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_BUILD_ENDPOINTS'
      ENDIF
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_TRY_BUILD_ENDPOINTS
C !INTERFACE:
      SUBROUTINE BOM_TRY_BUILD_ENDPOINTS(
     I                 targetTime, targetIter, initialize,
     O                 failCode, failStage, buildValid,
     I                 myThid )

C !DESCRIPTION:
C     Prepare, validate, and atomically publish environmental endpoints.
C     A failed component return leaves accepted state unchanged.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "DYNVARS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL targetTime
      INTEGER targetIter, myThid
      LOGICAL initialize

C !OUTPUT PARAMETERS:
      INTEGER failCode, failStage
      LOGICAL buildValid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER bi, bj, i, j, iEnd, iSource
      INTEGER localErrCount, localOldErr, localNewErr
      INTEGER globalErrCount
      _RL oldTime, interval, timeScale, timeTol
      _RL eastValue, northValue
      LOGICAL isNear, compareValid, wetPoint, fieldInvalid
      LOGICAL windProviderValid, stokesProviderValid

      failCode = BOM_FAIL_NONE
      failStage = BOM_STAGE_NONE
      buildValid = .FALSE.
      localErrCount = 0
      oldTime = targetTime

C--   Validate labels and accepted NEW continuity before scratch writes.
      IF ( .NOT.IEEE_IS_FINITE(targetTime) ) THEN
        localErrCount = localErrCount + 1
      ELSEIF ( initialize ) THEN
        failStage = BOM_STAGE_FIELD_NEW
        IF ( bomEnvReady ) localErrCount = localErrCount + 1
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
        failStage = BOM_STAGE_FIELD_OLD
        IF ( .NOT.bomEnvReady ) localErrCount = localErrCount + 1
        IF ( .NOT.IEEE_IS_FINITE(deltaTClock) .OR.
     &       deltaTClock.LE.0. _d 0 ) THEN
          localErrCount = localErrCount + 1
        ELSEIF ( targetTime.LE.-HUGE(oldTime)+deltaTClock ) THEN
          localErrCount = localErrCount + 1
        ELSE
          oldTime = targetTime-deltaTClock
          IF ( .NOT.IEEE_IS_FINITE(oldTime) .OR.
     &         targetTime.LE.oldTime ) THEN
            localErrCount = localErrCount + 1
          ELSE
            interval = targetTime-oldTime
            timeScale = MAX(oneRL,ABS(interval),ABS(deltaTClock))
            timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
            CALL BOM_TIME_NEAR(
     I           interval, deltaTClock, timeTol,
     O           isNear, compareValid )
            IF ( .NOT.compareValid .OR. .NOT.isNear )
     &           localErrCount = localErrCount + 1
          ENDIF
        ENDIF
        IF ( targetIter.LE.-HUGE(targetIter) ) THEN
          localErrCount = localErrCount + 1
        ELSEIF ( bomEnvIter(BOM_ENV_NEW).NE.targetIter-1 ) THEN
          localErrCount = localErrCount + 1
        ENDIF
        IF ( IEEE_IS_FINITE(oldTime) .AND.
     &       IEEE_IS_FINITE(bomEnvTime(BOM_ENV_NEW)) ) THEN
          timeScale = MAX(oneRL,ABS(oldTime),
     &                         ABS(bomEnvTime(BOM_ENV_NEW)))
          timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
          CALL BOM_TIME_NEAR(
     I         bomEnvTime(BOM_ENV_NEW), oldTime, timeTol,
     O         isNear, compareValid )
          IF ( .NOT.compareValid .OR. .NOT.isNear )
     &         localErrCount = localErrCount + 1
        ELSE
          localErrCount = localErrCount + 1
        ENDIF
      ENDIF

      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        failCode = BOM_FAIL_FIELD_TIME
        IF ( failStage.EQ.BOM_STAGE_NONE ) THEN
          IF ( initialize ) THEN
            failStage = BOM_STAGE_FIELD_NEW
          ELSE
            failStage = BOM_STAGE_FIELD_OLD
          ENDIF
        ENDIF
        RETURN
      ENDIF

C--   Select only providers implemented by this production increment.
      localErrCount = 0
      IF ( bomWindSource.NE.'NONE' .AND.
     &     bomWindSource.NE.'EXF' )
     &     localErrCount = localErrCount + 1
      IF ( bomStokesSource.NE.'NONE' .AND.
     &     bomStokesSource.NE.'FILES' )
     &     localErrCount = localErrCount + 1
#ifndef ALLOW_EXF
      IF ( bomWindSource.EQ.'EXF' )
     &     localErrCount = localErrCount + 1
#endif
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        failCode = BOM_FAIL_FIELD_SOURCE
        failStage = BOM_STAGE_FIELD_NEW
        RETURN
      ENDIF

C--   Initialise a complete scratch transaction on thread-owned tiles.
      _BEGIN_MASTER(myThid)
      IF ( initialize ) THEN
        bomEnvTimeScratch(BOM_ENV_OLD) = targetTime
        bomEnvIterScratch(BOM_ENV_OLD) = targetIter
      ELSE
        bomEnvTimeScratch(BOM_ENV_OLD) =
     &       bomEnvTime(BOM_ENV_NEW)
        bomEnvIterScratch(BOM_ENV_OLD) =
     &       bomEnvIter(BOM_ENV_NEW)
      ENDIF
      bomEnvTimeScratch(BOM_ENV_NEW) = targetTime
      bomEnvIterScratch(BOM_ENV_NEW) = targetIter
      _END_MASTER(myThid)
      _BARRIER

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomEnvUWork(i,j,1,bi,bj) = uVel(i,j,1,bi,bj)
          bomEnvVWork(i,j,1,bi,bj) = vVel(i,j,1,bi,bj)
          bomEnvEastWork(i,j,1,bi,bj) = 0. _d 0
          bomEnvNorthWork(i,j,1,bi,bj) = 0. _d 0
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            bomEnvEastScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomEnvNorthScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomEnvValidScratch(i,j,iEnd,iSource,bi,bj) =
     &           .FALSE.
           ENDDO
          ENDDO
          IF ( .NOT.initialize ) THEN
           DO iSource=1,BOM_ENV_NSOURCE
            bomEnvEastScratch(i,j,BOM_ENV_OLD,iSource,bi,bj) =
     &           bomEnvEast(i,j,BOM_ENV_NEW,iSource,bi,bj)
            bomEnvNorthScratch(i,j,BOM_ENV_OLD,iSource,bi,bj) =
     &           bomEnvNorth(i,j,BOM_ENV_NEW,iSource,bi,bj)
            bomEnvValidScratch(i,j,BOM_ENV_OLD,iSource,bi,bj) =
     &           bomEnvValid(i,j,BOM_ENV_NEW,iSource,bi,bj)
           ENDDO
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Ocean source: surface C-grid copy, C-point colocation and rotation.
      CALL ROTATE_UV2EN_RL(
     U     bomEnvUWork, bomEnvVWork,
     U     bomEnvEastWork, bomEnvNorthWork,
     I     .TRUE., .TRUE., .TRUE., 1, myThid )
      CALL EXCH_3D_RL( bomEnvEastWork, 1, myThid )
      CALL EXCH_3D_RL( bomEnvNorthWork, 1, myThid )

C--   EXF is evaluated independently at the exact requested endpoint.
      windProviderValid = .TRUE.
      IF ( bomWindSource.EQ.'EXF' ) THEN
        CALL BOM_GET_EXF_WIND(
     I       targetTime, targetIter,
     O       failCode, windProviderValid,
     I       myThid )
        IF ( .NOT.windProviderValid ) THEN
          failCode = BOM_FAIL_FIELD_SOURCE
          failStage = BOM_STAGE_FIELD_NEW
          RETURN
        ENDIF
      ENDIF

C--   FILES Stokes is independently read at the exact requested endpoint.
      stokesProviderValid = .TRUE.
      IF ( bomStokesSource.EQ.'FILES' ) THEN
        CALL BOM_GET_STOKES(
     I       targetTime, targetIter,
     O       failCode, stokesProviderValid,
     I       myThid )
        IF ( .NOT.stokesProviderValid ) THEN
          failCode = BOM_FAIL_FIELD_SOURCE
          failStage = BOM_STAGE_FIELD_NEW
          RETURN
        ENDIF
      ENDIF

C--   Publish the candidate NEW source values only into scratch storage.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          IF ( wetPoint ) THEN
            bomEnvEastScratch(i,j,BOM_ENV_NEW,
     &           BOM_ENV_EULERIAN,bi,bj) =
     &           bomEnvEastWork(i,j,1,bi,bj)
            bomEnvNorthScratch(i,j,BOM_ENV_NEW,
     &           BOM_ENV_EULERIAN,bi,bj) =
     &           bomEnvNorthWork(i,j,1,bi,bj)
            IF ( bomWindSource.EQ.'EXF' ) THEN
              bomEnvEastScratch(i,j,BOM_ENV_NEW,
     &             BOM_ENV_WIND,bi,bj) =
     &             bomExfWindEastWork(i,j,1,bi,bj)
              bomEnvNorthScratch(i,j,BOM_ENV_NEW,
     &             BOM_ENV_WIND,bi,bj) =
     &             bomExfWindNorthWork(i,j,1,bi,bj)
            ENDIF
            IF ( bomStokesSource.EQ.'FILES' ) THEN
              bomEnvEastScratch(i,j,BOM_ENV_NEW,
     &             BOM_ENV_STOKES,bi,bj) =
     &             bomStokesEastWork(i,j,1,bi,bj)
              bomEnvNorthScratch(i,j,BOM_ENV_NEW,
     &             BOM_ENV_STOKES,bi,bj) =
     &             bomStokesNorthWork(i,j,1,bi,bj)
            ENDIF
            DO iSource=1,BOM_ENV_NSOURCE
              bomEnvValidScratch(i,j,BOM_ENV_NEW,
     &             iSource,bi,bj) = .TRUE.
            ENDDO
          ENDIF
          IF ( initialize ) THEN
           DO iSource=1,BOM_ENV_NSOURCE
            bomEnvEastScratch(i,j,BOM_ENV_OLD,iSource,bi,bj) =
     &           bomEnvEastScratch(i,j,BOM_ENV_NEW,
     &                             iSource,bi,bj)
            bomEnvNorthScratch(i,j,BOM_ENV_OLD,iSource,bi,bj) =
     &           bomEnvNorthScratch(i,j,BOM_ENV_NEW,
     &                              iSource,bi,bj)
            bomEnvValidScratch(i,j,BOM_ENV_OLD,iSource,bi,bj) =
     &           bomEnvValidScratch(i,j,BOM_ENV_NEW,
     &                              iSource,bi,bj)
           ENDDO
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Validate every source and endpoint before accepted-state writes.
      localOldErr = 0
      localNewErr = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            eastValue =
     &           bomEnvEastScratch(i,j,iEnd,iSource,bi,bj)
            northValue =
     &           bomEnvNorthScratch(i,j,iEnd,iSource,bi,bj)
            IF ( wetPoint ) THEN
              fieldInvalid = .NOT.bomEnvValidScratch(
     &             i,j,iEnd,iSource,bi,bj) .OR.
     &             .NOT.IEEE_IS_FINITE(eastValue) .OR.
     &             .NOT.IEEE_IS_FINITE(northValue)
            ELSE
              fieldInvalid = bomEnvValidScratch(
     &             i,j,iEnd,iSource,bi,bj) .OR.
     &             eastValue.NE.0. _d 0 .OR.
     &             northValue.NE.0. _d 0
            ENDIF
            IF ( fieldInvalid ) THEN
              IF ( iEnd.EQ.BOM_ENV_OLD .AND.
     &             .NOT.initialize ) THEN
                localOldErr = 1
              ELSE
                localNewErr = 1
              ENDIF
            ENDIF
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localOldErr
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        failCode = BOM_FAIL_FIELD_SOURCE
        failStage = BOM_STAGE_FIELD_OLD
        RETURN
      ENDIF
      globalErrCount = localNewErr
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        failCode = BOM_FAIL_FIELD_SOURCE
        failStage = BOM_STAGE_FIELD_NEW
        RETURN
      ENDIF

C--   No failure remains: withdraw readiness, copy, then publish metadata.
      _BEGIN_MASTER(myThid)
      bomEnvReady = .FALSE.
      _END_MASTER(myThid)
      _BARRIER
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            bomEnvEast(i,j,iEnd,iSource,bi,bj) =
     &           bomEnvEastScratch(i,j,iEnd,iSource,bi,bj)
            bomEnvNorth(i,j,iEnd,iSource,bi,bj) =
     &           bomEnvNorthScratch(i,j,iEnd,iSource,bi,bj)
            bomEnvValid(i,j,iEnd,iSource,bi,bj) =
     &           bomEnvValidScratch(i,j,iEnd,iSource,bi,bj)
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BARRIER
      _BEGIN_MASTER(myThid)
      DO iEnd=1,BOM_ENV_NEND
        bomEnvTime(iEnd) = bomEnvTimeScratch(iEnd)
        bomEnvIter(iEnd) = bomEnvIterScratch(iEnd)
      ENDDO
      bomEnvReady = .TRUE.
      _END_MASTER(myThid)
      _BARRIER
      failCode = BOM_FAIL_NONE
      failStage = BOM_STAGE_NONE
      buildValid = .TRUE.
#else
      failCode = BOM_FAIL_FIELD_SOURCE
      failStage = BOM_STAGE_FIELD_NEW
      buildValid = .FALSE.
#endif /* ALLOW_BOM */

      RETURN
      END
