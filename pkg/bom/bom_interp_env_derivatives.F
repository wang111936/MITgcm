#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INTERP_ENV_DERIVATIVES
C !INTERFACE:
      SUBROUTINE BOM_INTERP_ENV_DERIVATIVES(
     I                 i, j, bi, bj, iSource, stageTime,
     O                 dEastEast, dNorthEast,
     O                 dEastNorth, dNorthNorth,
     O                 pointValid,
     O                 failCode, failStage, interpValid,
     I                 myThid )

C !DESCRIPTION:
C     Interpolate accepted endpoint gradients at the same snapped stage
C     time used by BOM_INTERP_ENV_TIME.  Nonlinear covariant products are
C     intentionally outside this linear endpoint operator.

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
      INTEGER i, j, bi, bj, iSource, myThid
      _RL stageTime

C !OUTPUT PARAMETERS:
      _RL dEastEast, dNorthEast, dEastNorth, dNorthNorth
      LOGICAL pointValid, interpValid
      INTEGER failCode, failStage
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER selectedEnd, rawFailCode, rawFailStage
      _RL rawEast, rawNorth, rawDtEast, rawDtNorth
      _RL time0, time1, interval, timeScale, timeTol
      _RL theta, weight0
      _RL dee0, dee1, dne0, dne1, den0, den1, dnn0, dnn1
      LOGICAL rawPointValid, rawInterpValid
      LOGICAL valid0, valid1, freshBracket
      LOGICAL near0, near1, compareValid
#endif

      dEastEast = 0. _d 0
      dNorthEast = 0. _d 0
      dEastNorth = 0. _d 0
      dNorthNorth = 0. _d 0
      pointValid = .FALSE.
      interpValid = .FALSE.
      failCode = BOM_FAIL_GRADIENT
      failStage = BOM_STAGE_DERIVATIVE

#ifdef ALLOW_BOM
C--   Reuse the primary field routine as the authoritative bracket check.
      CALL BOM_INTERP_ENV_TIME(
     I     i, j, bi, bj, iSource, stageTime,
     O     rawEast, rawNorth, rawDtEast, rawDtNorth,
     O     rawPointValid,
     O     rawFailCode, rawFailStage, rawInterpValid,
     I     myThid )
      IF ( .NOT.rawInterpValid ) THEN
        failCode = rawFailCode
        failStage = rawFailStage
        RETURN
      ENDIF
      IF ( .NOT.bomGradReady ) RETURN

      time0 = bomEnvTime(BOM_ENV_OLD)
      time1 = bomEnvTime(BOM_ENV_NEW)
      freshBracket = time1.EQ.time0
      interval = time1-time0

      dee0 = bomGradEastEast(i,j,BOM_ENV_OLD,iSource,bi,bj)
      dee1 = bomGradEastEast(i,j,BOM_ENV_NEW,iSource,bi,bj)
      dne0 = bomGradNorthEast(i,j,BOM_ENV_OLD,iSource,bi,bj)
      dne1 = bomGradNorthEast(i,j,BOM_ENV_NEW,iSource,bi,bj)
      den0 = bomGradEastNorth(i,j,BOM_ENV_OLD,iSource,bi,bj)
      den1 = bomGradEastNorth(i,j,BOM_ENV_NEW,iSource,bi,bj)
      dnn0 = bomGradNorthNorth(i,j,BOM_ENV_OLD,iSource,bi,bj)
      dnn1 = bomGradNorthNorth(i,j,BOM_ENV_NEW,iSource,bi,bj)
      valid0 = bomGradValid(i,j,BOM_ENV_OLD,iSource,bi,bj)
      valid1 = bomGradValid(i,j,BOM_ENV_NEW,iSource,bi,bj)
      IF ( .NOT.IEEE_IS_FINITE(dee0) .OR.
     &     .NOT.IEEE_IS_FINITE(dee1) .OR.
     &     .NOT.IEEE_IS_FINITE(dne0) .OR.
     &     .NOT.IEEE_IS_FINITE(dne1) .OR.
     &     .NOT.IEEE_IS_FINITE(den0) .OR.
     &     .NOT.IEEE_IS_FINITE(den1) .OR.
     &     .NOT.IEEE_IS_FINITE(dnn0) .OR.
     &     .NOT.IEEE_IS_FINITE(dnn1) ) RETURN

      IF ( freshBracket ) THEN
        IF ( dee1.NE.dee0 .OR. dne1.NE.dne0 .OR.
     &       den1.NE.den0 .OR. dnn1.NE.dnn0 .OR.
     &       (valid1.NEQV.valid0) ) RETURN
        dEastEast = dee0
        dNorthEast = dne0
        dEastNorth = den0
        dNorthNorth = dnn0
        pointValid = rawPointValid .AND. valid0
        failCode = BOM_FAIL_NONE
        failStage = BOM_STAGE_NONE
        interpValid = .TRUE.
        RETURN
      ENDIF

C--   Reproduce the frozen endpoint snap used by the primary field routine.
      timeScale = MAX(oneRL,ABS(time0),ABS(time1),
     &                ABS(stageTime),ABS(interval))
      timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
      IF ( .NOT.IEEE_IS_FINITE(timeTol) ) RETURN
      CALL BOM_TIME_NEAR(
     I     stageTime, time0, timeTol,
     O     near0, compareValid )
      IF ( .NOT.compareValid ) RETURN
      CALL BOM_TIME_NEAR(
     I     stageTime, time1, timeTol,
     O     near1, compareValid )
      IF ( .NOT.compareValid ) RETURN

      selectedEnd = BOM_STAGE_NONE
      IF ( stageTime.EQ.time0 ) THEN
        selectedEnd = BOM_ENV_OLD
      ELSEIF ( stageTime.EQ.time1 ) THEN
        selectedEnd = BOM_ENV_NEW
      ELSEIF ( near0 .AND. near1 ) THEN
        IF ( ABS(stageTime-time0).LE.ABS(time1-stageTime) ) THEN
          selectedEnd = BOM_ENV_OLD
        ELSE
          selectedEnd = BOM_ENV_NEW
        ENDIF
      ELSEIF ( near0 ) THEN
        selectedEnd = BOM_ENV_OLD
      ELSEIF ( near1 ) THEN
        selectedEnd = BOM_ENV_NEW
      ENDIF

      IF ( selectedEnd.EQ.BOM_ENV_OLD ) THEN
        dEastEast = dee0
        dNorthEast = dne0
        dEastNorth = den0
        dNorthNorth = dnn0
        pointValid = rawPointValid .AND. valid0
      ELSEIF ( selectedEnd.EQ.BOM_ENV_NEW ) THEN
        dEastEast = dee1
        dNorthEast = dne1
        dEastNorth = den1
        dNorthNorth = dnn1
        pointValid = rawPointValid .AND. valid1
      ELSE
        theta = (stageTime-time0)/interval
        IF ( .NOT.IEEE_IS_FINITE(theta) .OR.
     &       theta.LT.0. _d 0 .OR. theta.GT.oneRL ) RETURN
        weight0 = oneRL-theta
        dEastEast = weight0*dee0 + theta*dee1
        dNorthEast = weight0*dne0 + theta*dne1
        dEastNorth = weight0*den0 + theta*den1
        dNorthNorth = weight0*dnn0 + theta*dnn1
        IF ( .NOT.IEEE_IS_FINITE(dEastEast) .OR.
     &       .NOT.IEEE_IS_FINITE(dNorthEast) .OR.
     &       .NOT.IEEE_IS_FINITE(dEastNorth) .OR.
     &       .NOT.IEEE_IS_FINITE(dNorthNorth) ) THEN
          dEastEast = 0. _d 0
          dNorthEast = 0. _d 0
          dEastNorth = 0. _d 0
          dNorthNorth = 0. _d 0
          RETURN
        ENDIF
        pointValid = rawPointValid .AND. valid0 .AND. valid1
      ENDIF

      failCode = BOM_FAIL_NONE
      failStage = BOM_STAGE_NONE
      interpValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END
