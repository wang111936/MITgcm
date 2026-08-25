#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C     !ROUTINE: BOM_SUBSTEP_SETUP
C     !INTERFACE:
      SUBROUTINE BOM_SUBSTEP_SETUP(
     I                 myTime,
     O                 stepStart, nSub, dtSub,
     O                 failCode, isValid )

C     !DESCRIPTION:
C     Derive the deterministic equal-length Phase-1.3 particle substeps
C     after finite/range checks and before any integer conversion.

C     !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE

C     !INCLUDES:
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C     !INPUT PARAMETERS:
      _RL myTime

C     !OUTPUT PARAMETERS:
      _RL stepStart
      INTEGER nSub
      _RL dtSub
      INTEGER failCode
      LOGICAL isValid

C     !LOCAL VARIABLES:
      _RL subRatio
CEOP

      stepStart = 0. _d 0
      nSub = 0
      dtSub = 0. _d 0
      failCode = BOM_FAIL_NONE
      isValid = .FALSE.

      IF ( .NOT.IEEE_IS_FINITE(myTime) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(deltaTClock) .OR.
     &     deltaTClock.LE.0. _d 0 ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(bomDeltaTTarget) .OR.
     &     bomDeltaTTarget.LE.0. _d 0 ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( myTime.LE.-HUGE(stepStart)+deltaTClock ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      stepStart = myTime-deltaTClock
      IF ( .NOT.IEEE_IS_FINITE(stepStart) ) THEN
        stepStart = 0. _d 0
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF

C--   Guard division and CEILING separately.
      IF ( bomDeltaTTarget.LT.
     &     deltaTClock/DFLOAT(HUGE(nSub)) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      subRatio = deltaTClock/bomDeltaTTarget
      IF ( .NOT.IEEE_IS_FINITE(subRatio) .OR.
     &     subRatio.LE.0. _d 0 ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( subRatio.GT.DFLOAT(HUGE(nSub)) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      nSub = MAX(1,CEILING(subRatio))
      IF ( nSub.LT.1 ) THEN
        nSub = 0
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      dtSub = deltaTClock/DFLOAT(nSub)
      IF ( .NOT.IEEE_IS_FINITE(dtSub) .OR.
     &     dtSub.LE.0. _d 0 ) THEN
        nSub = 0
        dtSub = 0. _d 0
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      isValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C     !ROUTINE: BOM_SUBSTEP_BOUNDS
C     !INTERFACE:
      SUBROUTINE BOM_SUBSTEP_BOUNDS(
     I                 stepStart, stepEnd, dtSub, iSub, nSub,
     O                 tSub0, tSub1, isValid )

C     !DESCRIPTION:
C     Form one nominal interval.  The last endpoint is forced to the
C     authoritative ocean-step end so rounding cannot create a gap.

C     !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE

C     !INPUT PARAMETERS:
      _RL stepStart
      _RL stepEnd
      _RL dtSub
      INTEGER iSub
      INTEGER nSub

C     !OUTPUT PARAMETERS:
      _RL tSub0
      _RL tSub1
      LOGICAL isValid

C     !LOCAL VARIABLES:
      _RL offset
      LOGICAL addValid
CEOP

      tSub0 = stepStart
      tSub1 = stepStart
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(stepStart) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(stepEnd) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(dtSub) ) RETURN
      IF ( dtSub.LE.0. _d 0 ) RETURN
      IF ( nSub.LT.1 ) RETURN
      IF ( iSub.LT.0 .OR. iSub.GE.nSub ) RETURN

      offset = 0. _d 0
      IF ( iSub.GT.0 ) THEN
        IF ( dtSub.GT.HUGE(offset)/DFLOAT(iSub) ) RETURN
        offset = DFLOAT(iSub)*dtSub
        IF ( .NOT.IEEE_IS_FINITE(offset) ) RETURN
        CALL BOM_ADD_NONNEG_TIME(
     I       stepStart, offset,
     O       tSub0, addValid )
        IF ( .NOT.addValid ) RETURN
      ENDIF
      IF ( iSub.EQ.nSub-1 ) THEN
        tSub1 = stepEnd
      ELSE
        CALL BOM_ADD_NONNEG_TIME(
     I       tSub0, dtSub,
     O       tSub1, addValid )
        IF ( .NOT.addValid ) RETURN
      ENDIF
      IF ( tSub1.LT.tSub0 .OR. tSub1.GT.stepEnd ) RETURN
      isValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_ADD_NONNEG_TIME(
     I                 baseTime, increment,
     O                 resultTime, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL baseTime
      _RL increment
      _RL resultTime
      LOGICAL isValid

      resultTime = baseTime
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(baseTime) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(increment) ) RETURN
      IF ( increment.LT.0. _d 0 ) RETURN
      IF ( increment.EQ.0. _d 0 ) THEN
        isValid = .TRUE.
        RETURN
      ENDIF
      IF ( baseTime.GT.HUGE(resultTime)-increment ) RETURN
      resultTime = baseTime+increment
      IF ( .NOT.IEEE_IS_FINITE(resultTime) ) THEN
        resultTime = baseTime
        RETURN
      ENDIF
      isValid = .TRUE.

      RETURN
      END
