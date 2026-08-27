#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_EVAL_COVARIANT
C !INTERFACE:
      SUBROUTINE BOM_EVAL_COVARIANT(
     I                 wEast, wNorth, dtEast, dtNorth,
     I                 dEastEast, dNorthEast,
     I                 dEastNorth, dNorthNorth,
     I                 tauSphere,
     O                 dSelfEast, dSelfNorth, vorticity,
     O                 failCode, evalValid )

C !DESCRIPTION:
C     Stateless frozen covariant material derivative and vorticity kernel.
C     Inputs have already been interpolated to the same stage time and
C     position.  This routine has no particle or COMMON-state side effects.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL wEast, wNorth, dtEast, dtNorth
      _RL dEastEast, dNorthEast, dEastNorth, dNorthNorth
      _RL tauSphere, dSelfEast, dSelfNorth, vorticity
      _RL term1, term2, term3, term4, sum1, sum2, candidate
      INTEGER failCode
      LOGICAL evalValid, valid1, valid2, valid3
CEOP

      dSelfEast = 0. _d 0
      dSelfNorth = 0. _d 0
      vorticity = 0. _d 0
      failCode = BOM_FAIL_EQUATION
      evalValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(wEast) .OR.
     &     .NOT.IEEE_IS_FINITE(wNorth) .OR.
     &     .NOT.IEEE_IS_FINITE(dtEast) .OR.
     &     .NOT.IEEE_IS_FINITE(dtNorth) .OR.
     &     .NOT.IEEE_IS_FINITE(dEastEast) .OR.
     &     .NOT.IEEE_IS_FINITE(dNorthEast) .OR.
     &     .NOT.IEEE_IS_FINITE(dEastNorth) .OR.
     &     .NOT.IEEE_IS_FINITE(dNorthNorth) .OR.
     &     .NOT.IEEE_IS_FINITE(tauSphere) ) RETURN

C--   East material derivative.
      CALL BOM_SAFE_MULT_RL(wEast,dEastEast,term1,valid1)
      CALL BOM_SAFE_MULT_RL(wNorth,dNorthEast,term2,valid2)
      CALL BOM_SAFE_MULT_RL(tauSphere,wEast,term3,valid3)
      IF ( valid3 )
     &     CALL BOM_SAFE_MULT_RL(term3,wNorth,term4,valid3)
      IF ( .NOT.valid1 .OR. .NOT.valid2 .OR.
     &     .NOT.valid3 ) RETURN
      CALL BOM_SAFE_ADD_RL(dtEast,term1,sum1,valid1)
      IF ( valid1 )
     &     CALL BOM_SAFE_ADD_RL(sum1,term2,sum2,valid1)
      IF ( valid1 )
     &     CALL BOM_SAFE_ADD_RL(sum2,-term4,candidate,valid1)
      IF ( .NOT.valid1 ) RETURN
      dSelfEast = candidate

C--   North material derivative.
      CALL BOM_SAFE_MULT_RL(wEast,dEastNorth,term1,valid1)
      CALL BOM_SAFE_MULT_RL(wNorth,dNorthNorth,term2,valid2)
      CALL BOM_SAFE_MULT_RL(tauSphere,wEast,term3,valid3)
      IF ( valid3 )
     &     CALL BOM_SAFE_MULT_RL(term3,wEast,term4,valid3)
      IF ( .NOT.valid1 .OR. .NOT.valid2 .OR.
     &     .NOT.valid3 ) THEN
        dSelfEast = 0. _d 0
        RETURN
      ENDIF
      CALL BOM_SAFE_ADD_RL(dtNorth,term1,sum1,valid1)
      IF ( valid1 )
     &     CALL BOM_SAFE_ADD_RL(sum1,term2,sum2,valid1)
      IF ( valid1 )
     &     CALL BOM_SAFE_ADD_RL(sum2,term4,candidate,valid1)
      IF ( .NOT.valid1 ) THEN
        dSelfEast = 0. _d 0
        RETURN
      ENDIF
      dSelfNorth = candidate

C--   Relative vorticity.
      CALL BOM_SAFE_ADD_RL(dEastNorth,-dNorthEast,
     &                     sum1,valid1)
      CALL BOM_SAFE_MULT_RL(tauSphere,wEast,term1,valid2)
      IF ( valid1 .AND. valid2 )
     &     CALL BOM_SAFE_ADD_RL(sum1,term1,candidate,valid1)
      IF ( .NOT.valid1 .OR. .NOT.valid2 ) THEN
        dSelfEast = 0. _d 0
        dSelfNorth = 0. _d 0
        RETURN
      ENDIF
      vorticity = candidate
      failCode = BOM_FAIL_NONE
      evalValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SAFE_MULT_RL(
     I                 value1, value2,
     O                 product, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL value1, value2, product
      _RL absValue1, absValue2
      LOGICAL isValid

      product = 0. _d 0
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(value1) .OR.
     &     .NOT.IEEE_IS_FINITE(value2) ) RETURN
      IF ( value1.EQ.0. _d 0 .OR. value2.EQ.0. _d 0 ) THEN
        isValid = .TRUE.
        RETURN
      ENDIF
      absValue1 = ABS(value1)
      absValue2 = ABS(value2)
C--   Divide HUGE only by a factor >= 1; the guard must not overflow.
      IF ( absValue2.GT.1. _d 0 ) THEN
        IF ( absValue1.GT.HUGE(product)/absValue2 ) RETURN
      ELSEIF ( absValue1.GT.1. _d 0 ) THEN
        IF ( absValue2.GT.HUGE(product)/absValue1 ) RETURN
      ENDIF
      product = value1*value2
      isValid = IEEE_IS_FINITE(product)
      IF ( .NOT.isValid ) product = 0. _d 0

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SAFE_ADD_RL(
     I                 value1, value2,
     O                 sumValue, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL value1, value2, sumValue
      LOGICAL isValid

      sumValue = 0. _d 0
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(value1) .OR.
     &     .NOT.IEEE_IS_FINITE(value2) ) RETURN
      IF ( value2.GT.0. _d 0 ) THEN
        IF ( value1.GT.HUGE(sumValue)-value2 ) RETURN
      ELSEIF ( value2.LT.0. _d 0 ) THEN
        IF ( value1.LT.-HUGE(sumValue)-value2 ) RETURN
      ENDIF
      sumValue = value1+value2
      isValid = IEEE_IS_FINITE(sumValue)
      IF ( .NOT.isValid ) sumValue = 0. _d 0

      RETURN
      END
