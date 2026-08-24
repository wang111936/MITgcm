#include "BOM_OPTIONS.h"

C $Header: $
C $Name:  $

C--   File bom_rk_coord_update.F
C--   Contents
C--   o BOM_RK_COORD_UPDATE

CBOP
C     !ROUTINE: BOM_RK_COORD_UPDATE
C     !INTERFACE:
      SUBROUTINE BOM_RK_COORD_UPDATE(
     I                 baseCoord, rateCoord, deltaT, stageFactor,
     O                 trialCoord, isValid )

C     !DESCRIPTION:
C     Form one Runge--Kutta trial coordinate without allowing finite
C     multiplication or addition to overflow.  A zero time step, zero
C     stage factor, or zero rate preserves the input coordinate bit for
C     bit, including the sign of zero.

C     !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE

C     !INPUT PARAMETERS:
      _RL baseCoord
      _RL rateCoord
      _RL deltaT
      _RL stageFactor

C     !OUTPUT PARAMETERS:
      _RL trialCoord
      LOGICAL isValid

C     !LOCAL VARIABLES:
      _RL scaledRate
      _RL increment
      _RL hugeRL
CEOP

      trialCoord = baseCoord
      isValid = .FALSE.

      IF ( .NOT. IEEE_IS_FINITE(baseCoord) ) RETURN
      IF ( .NOT. IEEE_IS_FINITE(rateCoord) ) RETURN
      IF ( .NOT. IEEE_IS_FINITE(deltaT) ) RETURN
      IF ( .NOT. IEEE_IS_FINITE(stageFactor) ) RETURN

      IF ( deltaT .LT. 0. _d 0 ) RETURN
      IF ( stageFactor .LT. 0. _d 0 ) RETURN
      IF ( stageFactor .GT. 1. _d 0 ) RETURN

      IF ( deltaT .EQ. 0. _d 0 .OR.
     &     stageFactor .EQ. 0. _d 0 .OR.
     &     rateCoord .EQ. 0. _d 0 ) THEN
        isValid = .TRUE.
        RETURN
      ENDIF

      hugeRL = HUGE(increment)
      IF ( deltaT .GT. 1. _d 0 ) THEN
        IF ( ABS(rateCoord) .GT. hugeRL/deltaT ) RETURN
      ENDIF

      scaledRate = deltaT*rateCoord
      IF ( .NOT. IEEE_IS_FINITE(scaledRate) ) RETURN

C--   Multiplying the guarded full-step increment by a factor in [0,1]
C--   cannot overflow and avoids premature underflow of the input rate.
      increment = stageFactor*scaledRate
      IF ( .NOT. IEEE_IS_FINITE(increment) ) RETURN

      IF ( increment .GT. 0. _d 0 ) THEN
        IF ( baseCoord .GT. hugeRL-increment ) RETURN
      ELSEIF ( increment .LT. 0. _d 0 ) THEN
        IF ( baseCoord .LT. -hugeRL-increment ) RETURN
      ENDIF

      trialCoord = baseCoord + increment
      IF ( .NOT. IEEE_IS_FINITE(trialCoord) ) THEN
        trialCoord = baseCoord
        RETURN
      ENDIF

      isValid = .TRUE.

      RETURN
      END
