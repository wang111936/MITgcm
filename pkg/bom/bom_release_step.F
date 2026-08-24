#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C     !ROUTINE: BOM_RELEASE_STEP
C     !INTERFACE:
      SUBROUTINE BOM_RELEASE_STEP(
     I                 status0, releaseTime, age0,
     I                 tSub0, tSub1,
     O                 statusCandidate, dtActive, ageCandidate,
     O                 doAdvance, doRefresh,
     O                 failCode, isValid )

C     !DESCRIPTION:
C     Form the Phase-1.3 release, status, and age candidates for one
C     nominal substep.  This routine is stateless: it never writes a
C     particle slot.  A release at the substep end requests a zero-time
C     FINAL diagnostic refresh before the caller commits ALIVE state.

C     !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE

C     !INCLUDES:
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C     !INPUT PARAMETERS:
      INTEGER status0
      _RL releaseTime
      _RL age0
      _RL tSub0
      _RL tSub1

C     !OUTPUT PARAMETERS:
      INTEGER statusCandidate
      _RL dtActive
      _RL ageCandidate
      LOGICAL doAdvance
      LOGICAL doRefresh
      INTEGER failCode
      LOGICAL isValid

C     !LOCAL VARIABLES:
      _RL timeScale
      _RL timeTol
      _RL releaseEffective
      LOGICAL nearStart
      LOGICAL nearEnd
      LOGICAL compareValid
      LOGICAL diffValid
CEOP

      statusCandidate = status0
      dtActive = 0. _d 0
      ageCandidate = age0
      doAdvance = .FALSE.
      doRefresh = .FALSE.
      failCode = BOM_FAIL_NONE
      isValid = .FALSE.

C--   State errors have precedence over release-time errors.
      IF ( status0.NE.BOM_ALIVE .AND.
     &     status0.NE.BOM_WAITING ) THEN
        failCode = BOM_FAIL_STATE
        RETURN
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(age0) .OR.
     &     age0.LT.0. _d 0 ) THEN
        failCode = BOM_FAIL_STATE
        RETURN
      ENDIF
      IF ( status0.EQ.BOM_WAITING .AND.
     &     age0.NE.0. _d 0 ) THEN
        failCode = BOM_FAIL_STATE
        RETURN
      ENDIF

      IF ( .NOT.IEEE_IS_FINITE(releaseTime) .OR.
     &     releaseTime.LT.0. _d 0 ) THEN
        failCode = BOM_FAIL_RELEASE
        RETURN
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(tSub0) .OR.
     &     .NOT.IEEE_IS_FINITE(tSub1) ) THEN
        failCode = BOM_FAIL_RELEASE
        RETURN
      ENDIF
      IF ( tSub1.LT.tSub0 ) THEN
        failCode = BOM_FAIL_RELEASE
        RETURN
      ENDIF

      timeScale = MAX( oneRL, ABS(tSub0), ABS(tSub1),
     &                 ABS(releaseTime) )
      timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
      IF ( .NOT.IEEE_IS_FINITE(timeTol) .OR.
     &     timeTol.LT.0. _d 0 ) THEN
        failCode = BOM_FAIL_RELEASE
        RETURN
      ENDIF

      CALL BOM_TIME_NEAR(
     I     releaseTime, tSub0, timeTol,
     O     nearStart, compareValid )
      IF ( .NOT.compareValid ) THEN
        failCode = BOM_FAIL_RELEASE
        RETURN
      ENDIF
      CALL BOM_TIME_NEAR(
     I     releaseTime, tSub1, timeTol,
     O     nearEnd, compareValid )
      IF ( .NOT.compareValid ) THEN
        failCode = BOM_FAIL_RELEASE
        RETURN
      ENDIF

C--   Preserve exact endpoint identity.  A non-endpoint value that falls
C     within both endpoint tolerances is ambiguous and is rejected.
      releaseEffective = releaseTime
      IF ( releaseTime.EQ.tSub0 ) THEN
        releaseEffective = tSub0
        nearEnd = .FALSE.
      ELSEIF ( releaseTime.EQ.tSub1 ) THEN
        releaseEffective = tSub1
        nearStart = .FALSE.
      ELSEIF ( nearStart .AND. nearEnd ) THEN
        failCode = BOM_FAIL_RELEASE
        RETURN
      ELSEIF ( nearStart ) THEN
        releaseEffective = tSub0
      ELSEIF ( nearEnd ) THEN
        releaseEffective = tSub1
      ENDIF

      IF ( status0.EQ.BOM_WAITING ) THEN
        IF ( releaseEffective.GT.tSub1 ) THEN
C--       Still unreleased: every authoritative value remains unchanged.
          isValid = .TRUE.
          RETURN
        ENDIF
        statusCandidate = BOM_ALIVE
        doRefresh = .TRUE.
        IF ( releaseEffective.LE.tSub0 ) THEN
          CALL BOM_NONNEG_TIME_DIFF(
     I         tSub1, tSub0,
     O         dtActive, diffValid )
        ELSE
          CALL BOM_NONNEG_TIME_DIFF(
     I         tSub1, releaseEffective,
     O         dtActive, diffValid )
        ENDIF
      ELSE
C--     An ALIVE record cannot carry a truly future release time.
        IF ( releaseEffective.GT.tSub0 ) THEN
          failCode = BOM_FAIL_RELEASE
          RETURN
        ENDIF
        doRefresh = .TRUE.
        CALL BOM_NONNEG_TIME_DIFF(
     I       tSub1, tSub0,
     O       dtActive, diffValid )
      ENDIF

      IF ( .NOT.diffValid .OR.
     &     .NOT.IEEE_IS_FINITE(dtActive) ) THEN
        failCode = BOM_FAIL_RELEASE
        RETURN
      ENDIF
      IF ( age0.GT.HUGE(ageCandidate)-dtActive ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      ageCandidate = age0 + dtActive
      IF ( .NOT.IEEE_IS_FINITE(ageCandidate) ) THEN
        ageCandidate = age0
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      doAdvance = dtActive.GT.0. _d 0
      isValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_TIME_NEAR(
     I                 value, endpoint, tolerance,
     O                 isNear, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL value
      _RL endpoint
      _RL tolerance
      LOGICAL isNear
      LOGICAL isValid
      _RL absValue
      _RL absEndpoint
      _RL difference
      LOGICAL oppositeSigns

      isNear = .FALSE.
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(value) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(endpoint) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(tolerance) ) RETURN
      IF ( tolerance.LT.0. _d 0 ) RETURN

      absValue = ABS(value)
      absEndpoint = ABS(endpoint)
      oppositeSigns = ( value.GT.0. _d 0 .AND.
     &                  endpoint.LT.0. _d 0 ) .OR.
     &                ( value.LT.0. _d 0 .AND.
     &                  endpoint.GT.0. _d 0 )
      IF ( oppositeSigns ) THEN
        IF ( absValue.GT.HUGE(difference)-absEndpoint ) THEN
          isValid = .TRUE.
          RETURN
        ENDIF
      ENDIF
      difference = ABS(value-endpoint)
      IF ( .NOT.IEEE_IS_FINITE(difference) ) RETURN
      isNear = difference.LE.tolerance
      isValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_NONNEG_TIME_DIFF(
     I                 laterTime, earlierTime,
     O                 difference, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL laterTime
      _RL earlierTime
      _RL difference
      LOGICAL isValid

      difference = 0. _d 0
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(laterTime) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(earlierTime) ) RETURN
      IF ( laterTime.LT.earlierTime ) RETURN
      IF ( laterTime.GT.0. _d 0 .AND.
     &     earlierTime.LT.0. _d 0 ) THEN
        IF ( laterTime.GT.HUGE(difference)+earlierTime ) RETURN
      ENDIF
      difference = laterTime-earlierTime
      IF ( .NOT.IEEE_IS_FINITE(difference) ) THEN
        difference = 0. _d 0
        RETURN
      ENDIF
      IF ( difference.LT.0. _d 0 ) THEN
        difference = 0. _d 0
        RETURN
      ENDIF
      isValid = .TRUE.

      RETURN
      END
