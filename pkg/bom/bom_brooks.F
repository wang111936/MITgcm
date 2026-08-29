#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BROOKS_RATE
C !INTERFACE:
      SUBROUTINE BOM_BROOKS_RATE(
     I                 temperature, nutrient,
     I                 muMax, mortality, kN, tMin, tMax,
     O                 tempFactor, nutrientFactor, dSdt,
     O                 failCode, rateValid )

C !DESCRIPTION:
C     Stateless finite Brooks temperature/nutrient law in SI units.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL temperature, nutrient
      _RL muMax, mortality, kN, tMin, tMax

C !OUTPUT PARAMETERS:
      _RL tempFactor, nutrientFactor, dSdt
      INTEGER failCode
      LOGICAL rateValid
CEOP

C !LOCAL VARIABLES:
      _RL tOpt, ratio, ratioAbs, exponent
      _RL nSafe, scaledN, growth
      LOGICAL ratioValid, arithmeticValid

      tempFactor = 0. _d 0
      nutrientFactor = 0. _d 0
      dSdt = 0. _d 0
      failCode = BOM_FAIL_BROOKS
      rateValid = .FALSE.

      IF ( .NOT.IEEE_IS_FINITE(temperature) .OR.
     &     .NOT.IEEE_IS_FINITE(nutrient) .OR.
     &     .NOT.IEEE_IS_FINITE(muMax) .OR.
     &     .NOT.IEEE_IS_FINITE(mortality) .OR.
     &     .NOT.IEEE_IS_FINITE(kN) .OR.
     &     .NOT.IEEE_IS_FINITE(tMin) .OR.
     &     .NOT.IEEE_IS_FINITE(tMax) ) RETURN
      IF ( muMax.LT.0. _d 0 .OR. mortality.LT.0. _d 0 .OR.
     &     kN.LE.0. _d 0 .OR. tMin.GE.tMax ) RETURN

C--   Half-scaled sum cannot overflow for ordered finite endpoints.
      tOpt = halfRL*tMin+halfRL*tMax
      IF ( .NOT.IEEE_IS_FINITE(tOpt) ) RETURN

      IF ( temperature.EQ.tMin .OR. temperature.EQ.tMax ) THEN
        tempFactor = 0. _d 0
      ELSEIF ( temperature.GT.tMin .AND.
     &         temperature.LT.tOpt ) THEN
        CALL BOM_BROOKS_DIFF_RATIO(
     I       temperature, tOpt, temperature, tMin,
     O       ratio, ratioValid )
        IF ( .NOT.ratioValid ) RETURN
        ratioAbs = ABS(ratio)
        IF ( ratioAbs.GT.SQRT(HUGE(oneRL)) ) THEN
          tempFactor = 0. _d 0
        ELSE
          exponent = -halfRL*ratio*ratio
          tempFactor = EXP(exponent)
        ENDIF
      ELSEIF ( temperature.EQ.tOpt ) THEN
        tempFactor = oneRL
      ELSEIF ( temperature.GT.tOpt .AND.
     &         temperature.LT.tMax ) THEN
        CALL BOM_BROOKS_DIFF_RATIO(
     I       temperature, tOpt, temperature, tMax,
     O       ratio, ratioValid )
        IF ( .NOT.ratioValid ) RETURN
        ratioAbs = ABS(ratio)
        IF ( ratioAbs.GT.SQRT(HUGE(oneRL)) ) THEN
          tempFactor = 0. _d 0
        ELSE
          exponent = -halfRL*ratio*ratio
          tempFactor = EXP(exponent)
        ENDIF
      ELSE
        tempFactor = 0. _d 0
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(tempFactor) ) RETURN
      IF ( tempFactor.LT.0. _d 0 .OR.
     &     tempFactor.GT.oneRL ) RETURN

C--   Algebraically equivalent bounded form avoids kN+N overflow.
      nSafe = MAX(nutrient,0. _d 0)
      IF ( nSafe.EQ.0. _d 0 ) THEN
        nutrientFactor = 0. _d 0
      ELSEIF ( nSafe.LE.kN ) THEN
        scaledN = nSafe/kN
        nutrientFactor = scaledN/(oneRL+scaledN)
      ELSE
        scaledN = kN/nSafe
        nutrientFactor = oneRL/(oneRL+scaledN)
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(nutrientFactor) ) RETURN
      IF ( nutrientFactor.LT.0. _d 0 .OR.
     &     nutrientFactor.GT.oneRL ) RETURN

      CALL BOM_SAFE_MULT_RL(
     I     tempFactor, nutrientFactor,
     O     scaledN, arithmeticValid )
      IF ( .NOT.arithmeticValid ) RETURN
      CALL BOM_SAFE_MULT_RL(
     I     muMax, scaledN,
     O     growth, arithmeticValid )
      IF ( .NOT.arithmeticValid ) RETURN
      CALL BOM_SAFE_ADD_RL(
     I     growth, -mortality,
     O     dSdt, arithmeticValid )
      IF ( .NOT.arithmeticValid ) RETURN

      failCode = BOM_FAIL_NONE
      rateValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_BROOKS_DIFF_RATIO(
     I                 num1, num0, den1, den0,
     O                 ratio, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      _RL num1, num0, den1, den0, ratio
      _RL numerator, denominator, absNumerator, absDenominator
      LOGICAL isValid, numeratorValid, denominatorValid
      LOGICAL wouldOverflow

      ratio = 0. _d 0
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(num1) .OR.
     &     .NOT.IEEE_IS_FINITE(num0) .OR.
     &     .NOT.IEEE_IS_FINITE(den1) .OR.
     &     .NOT.IEEE_IS_FINITE(den0) ) RETURN
      CALL BOM_SAFE_ADD_RL(
     I     num1, -num0,
     O     numerator, numeratorValid )
      CALL BOM_SAFE_ADD_RL(
     I     den1, -den0,
     O     denominator, denominatorValid )
      IF ( .NOT.numeratorValid .OR.
     &     .NOT.denominatorValid ) RETURN
      IF ( denominator.EQ.0. _d 0 ) RETURN
      absNumerator = ABS(numerator)
      absDenominator = ABS(denominator)
      wouldOverflow = .FALSE.
      IF ( absDenominator.LT.oneRL )
     &     wouldOverflow =
     &       absNumerator.GT.HUGE(oneRL)*absDenominator
      IF ( wouldOverflow ) THEN
        ratio = HUGE(oneRL)
        IF ( (numerator.LT.0. _d 0 .AND.
     &        denominator.GT.0. _d 0) .OR.
     &       (numerator.GT.0. _d 0 .AND.
     &        denominator.LT.0. _d 0) ) ratio = -ratio
      ELSE
        ratio = numerator/denominator
      ENDIF
      isValid = IEEE_IS_FINITE(ratio)
      IF ( .NOT.isValid ) ratio = 0. _d 0

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BIOLOGY_PLAN
C !INTERFACE:
      SUBROUTINE BOM_BIOLOGY_PLAN(
     I                 statusBefore, sBefore,
     I                 temperature, nutrient, dtActive,
     I                 sampleValid,
     O                 tempFactor, nutrientFactor, dSdt,
     O                 sTrial, sCandidate, eventType,
     O                 missingGrowth,
     O                 failCode, p4FailPhase, planValid )

C !DESCRIPTION:
C     Produce one immutable P4.1 biology candidate.  No owner field, slot,
C     count, ID, event buffer or accepted endpoint is modified.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER statusBefore
      _RL sBefore, temperature, nutrient, dtActive
      LOGICAL sampleValid

C !OUTPUT PARAMETERS:
      _RL tempFactor, nutrientFactor, dSdt
      _RL sTrial, sCandidate
      INTEGER eventType, failCode, p4FailPhase
      LOGICAL missingGrowth, planValid
CEOP

C !LOCAL VARIABLES:
      _RL increment
      LOGICAL rateValid, arithmeticValid

      tempFactor = 0. _d 0
      nutrientFactor = 0. _d 0
      dSdt = 0. _d 0
      sTrial = 0. _d 0
      sCandidate = 0. _d 0
      eventType = BOM_EVENT_NONE
      missingGrowth = .FALSE.
      failCode = BOM_FAIL_BROOKS
      p4FailPhase = BOM_P4_PHASE_BIOLOGY
      planValid = .FALSE.

      IF ( .NOT.IEEE_IS_FINITE(sBefore) .OR.
     &     .NOT.IEEE_IS_FINITE(dtActive) ) RETURN
      IF ( dtActive.LT.0. _d 0 ) RETURN
      sTrial = sBefore
      sCandidate = sBefore
      IF ( statusBefore.EQ.BOM_WAITING ) THEN
        failCode = BOM_FAIL_NONE
        p4FailPhase = BOM_P4_PHASE_NONE
        planValid = .TRUE.
        RETURN
      ENDIF
      IF ( statusBefore.NE.BOM_ALIVE ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(bomS0) .OR.
     &     .NOT.IEEE_IS_FINITE(bomSMin) .OR.
     &     .NOT.IEEE_IS_FINITE(bomSMax) ) RETURN
      IF ( bomSMin.GE.bomS0 .OR. bomS0.GE.bomSMax ) RETURN

      IF ( .NOT.sampleValid ) THEN
        IF ( bomBiologyMissingPolicy.EQ.'STOP' ) THEN
          failCode = BOM_FAIL_BIOLOGY_FIELD
          p4FailPhase = BOM_P4_PHASE_ENDPOINT
          RETURN
        ELSEIF ( bomBiologyMissingPolicy.EQ.'NO_GROWTH' ) THEN
          IF ( .NOT.IEEE_IS_FINITE(bomMort) ) RETURN
          IF ( bomMort.LT.0. _d 0 ) RETURN
          dSdt = -bomMort
          missingGrowth = .TRUE.
        ELSE
          failCode = BOM_FAIL_BIOLOGY_CONFIG
          RETURN
        ENDIF
      ELSE
        CALL BOM_BROOKS_RATE(
     I       temperature, nutrient,
     I       bomMuMax, bomMort, bomKN, bomTMin, bomTMax,
     O       tempFactor, nutrientFactor, dSdt,
     O       failCode, rateValid )
        IF ( .NOT.rateValid ) RETURN
      ENDIF

      CALL BOM_SAFE_MULT_RL(
     I     dSdt, dtActive,
     O     increment, arithmeticValid )
      IF ( .NOT.arithmeticValid ) THEN
        failCode = BOM_FAIL_BROOKS
        RETURN
      ENDIF
      CALL BOM_SAFE_ADD_RL(
     I     sBefore, increment,
     O     sTrial, arithmeticValid )
      IF ( .NOT.arithmeticValid ) THEN
        failCode = BOM_FAIL_BROOKS
        sTrial = sBefore
        RETURN
      ENDIF

      sCandidate = sTrial
      IF ( sTrial.LT.bomSMin ) THEN
        eventType = BOM_EVENT_DEAD_BIO
      ELSEIF ( sTrial.GT.bomSMax ) THEN
        eventType = BOM_EVENT_BIRTH
        sCandidate = bomS0
      ENDIF

      failCode = BOM_FAIL_NONE
      p4FailPhase = BOM_P4_PHASE_NONE
      planValid = .TRUE.
      RETURN
      END
