#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INTERP_ENV_TIME

C !INTERFACE:
      SUBROUTINE BOM_INTERP_ENV_TIME(
     I                 i, j, bi, bj, iSource, stageTime,
     O                 stageEast, stageNorth,
     O                 dtEast, dtNorth, pointValid,
     O                 failCode, failStage, interpValid,
     I                 myThid )

C !DESCRIPTION:
C     Evaluate one accepted environmental C point at a particle-stage
C     time.  Exact or tolerance-snapped endpoints are copied directly;
C     interior values are linear and time derivatives are the bracket
C     secants.  The accepted endpoint state is never modified.

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
      _RL stageEast, stageNorth, dtEast, dtNorth
      LOGICAL pointValid, interpValid
      INTEGER failCode, failStage
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER iter0, iter1, selectedEnd
      _RL time0, time1, interval, timeScale, timeTol
      _RL effectiveTime, theta, weight0
      _RL east0, east1, north0, north1
      LOGICAL valid0, valid1, freshBracket
      LOGICAL near0, near1, compareValid, diffValid
      LOGICAL eastRateValid, northRateValid
#endif

      stageEast = 0. _d 0
      stageNorth = 0. _d 0
      dtEast = 0. _d 0
      dtNorth = 0. _d 0
      pointValid = .FALSE.
      interpValid = .FALSE.
      failCode = BOM_FAIL_FIELD_SOURCE
      failStage = BOM_STAGE_FIELD_OLD

#ifdef ALLOW_BOM
      IF ( iSource.LT.1 .OR. iSource.GT.BOM_ENV_NSOURCE ) RETURN
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) RETURN
      IF ( bi.LT.myBxLo(myThid) .OR. bi.GT.myBxHi(myThid)
     &     .OR. bj.LT.myByLo(myThid)
     &     .OR. bj.GT.myByHi(myThid) ) RETURN
      IF ( i.LT.1-OLx .OR. i.GT.sNx+OLx .OR.
     &     j.LT.1-OLy .OR. j.GT.sNy+OLy ) RETURN

      failCode = BOM_FAIL_FIELD_TIME
      IF ( .NOT.bomEnvReady ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(stageTime) ) RETURN

      time0 = bomEnvTime(BOM_ENV_OLD)
      time1 = bomEnvTime(BOM_ENV_NEW)
      iter0 = bomEnvIter(BOM_ENV_OLD)
      iter1 = bomEnvIter(BOM_ENV_NEW)
      IF ( .NOT.IEEE_IS_FINITE(time0) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(time1) ) THEN
        failStage = BOM_STAGE_FIELD_NEW
        RETURN
      ENDIF

      freshBracket = time1.EQ.time0
      interval = 0. _d 0
      IF ( freshBracket ) THEN
        IF ( iter1.NE.iter0 ) THEN
          failStage = BOM_STAGE_FIELD_NEW
          RETURN
        ENDIF
      ELSE
        failStage = BOM_STAGE_FIELD_NEW
        IF ( time1.LT.time0 ) RETURN
        IF ( .NOT.IEEE_IS_FINITE(deltaTClock) .OR.
     &       deltaTClock.LE.0. _d 0 ) RETURN
        CALL BOM_NONNEG_TIME_DIFF(
     I       time1, time0,
     O       interval, diffValid )
        IF ( .NOT.diffValid .OR. interval.LE.0. _d 0 ) RETURN
        timeScale = MAX(oneRL,ABS(interval),ABS(deltaTClock))
        timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
        IF ( .NOT.IEEE_IS_FINITE(timeTol) ) RETURN
        CALL BOM_TIME_NEAR(
     I       interval, deltaTClock, timeTol,
     O       near1, compareValid )
        IF ( .NOT.compareValid .OR. .NOT.near1 ) RETURN
        IF ( iter0.GE.HUGE(iter0) ) RETURN
        IF ( iter1.NE.iter0+1 ) RETURN
      ENDIF

C--   Snap before the range test so a scaled tolerance is accepted.
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

      effectiveTime = stageTime
      selectedEnd = BOM_STAGE_NONE
      IF ( stageTime.EQ.time0 ) THEN
        effectiveTime = time0
        selectedEnd = BOM_ENV_OLD
      ELSEIF ( stageTime.EQ.time1 ) THEN
        effectiveTime = time1
        selectedEnd = BOM_ENV_NEW
      ELSEIF ( near0 .AND. near1 ) THEN
        IF ( ABS(stageTime-time0).LE.ABS(time1-stageTime) ) THEN
          effectiveTime = time0
          selectedEnd = BOM_ENV_OLD
        ELSE
          effectiveTime = time1
          selectedEnd = BOM_ENV_NEW
        ENDIF
      ELSEIF ( near0 ) THEN
        effectiveTime = time0
        selectedEnd = BOM_ENV_OLD
      ELSEIF ( near1 ) THEN
        effectiveTime = time1
        selectedEnd = BOM_ENV_NEW
      ENDIF

      IF ( selectedEnd.EQ.BOM_STAGE_NONE ) THEN
        IF ( stageTime.LT.time0 ) THEN
          failStage = BOM_STAGE_FIELD_OLD
          RETURN
        ELSEIF ( stageTime.GT.time1 ) THEN
          failStage = BOM_STAGE_FIELD_NEW
          RETURN
        ENDIF
      ENDIF

      east0 = bomEnvEast(i,j,BOM_ENV_OLD,iSource,bi,bj)
      east1 = bomEnvEast(i,j,BOM_ENV_NEW,iSource,bi,bj)
      north0 = bomEnvNorth(i,j,BOM_ENV_OLD,iSource,bi,bj)
      north1 = bomEnvNorth(i,j,BOM_ENV_NEW,iSource,bi,bj)
      valid0 = bomEnvValid(i,j,BOM_ENV_OLD,iSource,bi,bj)
      valid1 = bomEnvValid(i,j,BOM_ENV_NEW,iSource,bi,bj)
      failCode = BOM_FAIL_FIELD_SOURCE
      failStage = BOM_STAGE_FIELD_OLD
      IF ( .NOT.IEEE_IS_FINITE(east0) .OR.
     &     .NOT.IEEE_IS_FINITE(north0) ) RETURN
      failStage = BOM_STAGE_FIELD_NEW
      IF ( .NOT.IEEE_IS_FINITE(east1) .OR.
     &     .NOT.IEEE_IS_FINITE(north1) ) RETURN

C--   A fresh publication is a legal single-time bracket.  Its two
C     endpoint copies must still agree and its secant is exactly zero.
      IF ( freshBracket ) THEN
        IF ( east1.NE.east0 .OR. north1.NE.north0 .OR.
     &       (valid1.NEQV.valid0) ) RETURN
        stageEast = east0
        stageNorth = north0
        pointValid = valid0
        dtEast = 0. _d 0
        dtNorth = 0. _d 0
        failCode = BOM_FAIL_NONE
        failStage = BOM_STAGE_NONE
        interpValid = .TRUE.
        RETURN
      ENDIF

      CALL BOM_ENV_TIME_SECANT(
     I     east1, east0, interval,
     O     dtEast, eastRateValid )
      CALL BOM_ENV_TIME_SECANT(
     I     north1, north0, interval,
     O     dtNorth, northRateValid )
      IF ( .NOT.eastRateValid .OR. .NOT.northRateValid ) THEN
        dtEast = 0. _d 0
        dtNorth = 0. _d 0
        failStage = BOM_STAGE_DERIVATIVE
        RETURN
      ENDIF

      IF ( selectedEnd.EQ.BOM_ENV_OLD ) THEN
        stageEast = east0
        stageNorth = north0
        pointValid = valid0
      ELSEIF ( selectedEnd.EQ.BOM_ENV_NEW ) THEN
        stageEast = east1
        stageNorth = north1
        pointValid = valid1
      ELSE
        theta = (effectiveTime-time0)/interval
        IF ( .NOT.IEEE_IS_FINITE(theta) .OR.
     &       theta.LT.0. _d 0 .OR. theta.GT.oneRL ) THEN
          stageEast = 0. _d 0
          stageNorth = 0. _d 0
          dtEast = 0. _d 0
          dtNorth = 0. _d 0
          failCode = BOM_FAIL_FIELD_TIME
          failStage = BOM_STAGE_DERIVATIVE
          RETURN
        ENDIF
        weight0 = oneRL-theta
        stageEast = weight0*east0 + theta*east1
        stageNorth = weight0*north0 + theta*north1
        pointValid = valid0 .AND. valid1
        IF ( .NOT.IEEE_IS_FINITE(stageEast) .OR.
     &       .NOT.IEEE_IS_FINITE(stageNorth) ) THEN
          stageEast = 0. _d 0
          stageNorth = 0. _d 0
          dtEast = 0. _d 0
          dtNorth = 0. _d 0
          pointValid = .FALSE.
          failCode = BOM_FAIL_FIELD_SOURCE
          failStage = BOM_STAGE_DERIVATIVE
          RETURN
        ENDIF
      ENDIF

      failCode = BOM_FAIL_NONE
      failStage = BOM_STAGE_NONE
      interpValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----2----3----4----5----6----7-|--+----|
      SUBROUTINE BOM_ENV_TIME_SECANT(
     I                 value1, value0, interval,
     O                 rate, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL value1, value0, interval, rate
      _RL difference, scaled1, scaled0
      LOGICAL isValid, oppositeSigns

      rate = 0. _d 0
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(value1) .OR.
     &     .NOT.IEEE_IS_FINITE(value0) .OR.
     &     .NOT.IEEE_IS_FINITE(interval) ) RETURN
      IF ( interval.LE.0. _d 0 ) RETURN

      oppositeSigns = ( value1.GT.0. _d 0 .AND.
     &                  value0.LT.0. _d 0 ) .OR.
     &                ( value1.LT.0. _d 0 .AND.
     &                  value0.GT.0. _d 0 )
      IF ( oppositeSigns ) THEN
        scaled1 = value1/interval
        scaled0 = value0/interval
        IF ( .NOT.IEEE_IS_FINITE(scaled1) .OR.
     &       .NOT.IEEE_IS_FINITE(scaled0) ) RETURN
        rate = scaled1-scaled0
      ELSE
        difference = value1-value0
        IF ( .NOT.IEEE_IS_FINITE(difference) ) RETURN
        rate = difference/interval
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(rate) ) THEN
        rate = 0. _d 0
        RETURN
      ENDIF
      isValid = .TRUE.

      RETURN
      END
