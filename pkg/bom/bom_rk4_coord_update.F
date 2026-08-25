#include "BOM_OPTIONS.h"

C $Header: $
C $Name:  $

C--   File bom_rk4_coord_update.F
C--   Contents
C--   o BOM_RK4_COORD_UPDATE

CBOP
C     !ROUTINE: BOM_RK4_COORD_UPDATE
C     !INTERFACE:
      SUBROUTINE BOM_RK4_COORD_UPDATE(
     I                 baseCoord, rate1, rate2, rate3, rate4,
     I                 deltaT,
     O                 trialCoord, isValid )

C     !DESCRIPTION:
C     Form the classical RK4 weighted coordinate update without first
C     constructing k1+2*k2+2*k3+k4.  Rates are normalized by their
C     maximum magnitude, so finite cancellation and extreme same-sign
C     values cannot overflow an intermediate weighted sum.

C     !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE

C     !INPUT PARAMETERS:
      _RL baseCoord
      _RL rate1
      _RL rate2
      _RL rate3
      _RL rate4
      _RL deltaT

C     !OUTPUT PARAMETERS:
      _RL trialCoord
      LOGICAL isValid

C     !LOCAL VARIABLES:
      _RL rateScale
      _RL weightedNorm
      _RL normMagnitude
      _RL signedScale
      _RL roundBound
CEOP

      trialCoord = baseCoord
      isValid = .FALSE.

      IF ( .NOT. IEEE_IS_FINITE(baseCoord) ) RETURN
      IF ( .NOT. IEEE_IS_FINITE(rate1) ) RETURN
      IF ( .NOT. IEEE_IS_FINITE(rate2) ) RETURN
      IF ( .NOT. IEEE_IS_FINITE(rate3) ) RETURN
      IF ( .NOT. IEEE_IS_FINITE(rate4) ) RETURN
      IF ( .NOT. IEEE_IS_FINITE(deltaT) ) RETURN
      IF ( deltaT .LT. 0. _d 0 ) RETURN

      rateScale = MAX( ABS(rate1), ABS(rate2),
     &                 ABS(rate3), ABS(rate4) )
      IF ( rateScale .EQ. 0. _d 0 .OR.
     &     deltaT .EQ. 0. _d 0 ) THEN
        isValid = .TRUE.
        RETURN
      ENDIF

C--   Absolute weights sum to one, so the exact normalized mean is
C--   bounded by one.  Clamp only a representational overshoot.
      weightedNorm = (rate1/rateScale)/6. _d 0
     &             + (rate2/rateScale)/3. _d 0
     &             + (rate3/rateScale)/3. _d 0
     &             + (rate4/rateScale)/6. _d 0
      IF ( .NOT. IEEE_IS_FINITE(weightedNorm) ) RETURN
      normMagnitude = ABS(weightedNorm)
      roundBound = 1. _d 0 + 16. _d 0*EPSILON(rateScale)
      IF ( normMagnitude .GT. 1. _d 0 ) THEN
        IF ( normMagnitude .GT. roundBound ) RETURN
        weightedNorm = SIGN(1. _d 0,weightedNorm)
        normMagnitude = 1. _d 0
      ENDIF
      IF ( normMagnitude .EQ. 0. _d 0 ) THEN
        isValid = .TRUE.
        RETURN
      ENDIF

C--   The generic helper forms deltaT*normMagnitude*signedScale with
C--   exponent-scaled arithmetic and performs the guarded base addition.
      signedScale = SIGN(rateScale,weightedNorm)
      CALL BOM_RK_COORD_UPDATE(
     I     baseCoord, signedScale, deltaT, normMagnitude,
     O     trialCoord, isValid )

      RETURN
      END
