#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_SPRING_PAIR
C !INTERFACE:
      SUBROUTINE BOM_SPRING_PAIR(
     I                 springLaw, tauValue, springL,
     I                 hookeK, springA, springDelta,
     I                 displacementEast, displacementNorth, distance,
     O                 velocityEastLo, velocityNorthLo, stiffness,
     O                 failCode, pairValid )

C !DESCRIPTION:
C     Evaluate one stateless P3.1 spring contribution for the low-ID
C     endpoint.  The canonical displacement points from low ID to high ID.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      CHARACTER*(*) springLaw
      _RL tauValue, springL, hookeK, springA, springDelta
      _RL displacementEast, displacementNorth, distance
      _RL velocityEastLo, velocityNorthLo, stiffness
      INTEGER failCode
      LOGICAL pairValid

      _RL normValue, normDifference, normTolerance
      _RL twoL, numerator, zValue, exponential, denominator
      _RL logTinyValue
      _RL stiffnessWork, ratio, extensionFactor
      _RL tauStiffness, scalarFactor, eastWork, northWork
      LOGICAL calcValid, termValid
CEOP

      failCode = BOM_FAIL_SPRING_LAW
      pairValid = .FALSE.

      IF ( springLaw.NE.'HOOKE' .AND.
     &     springLaw.NE.'EBOMB' ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(tauValue) .OR.
     &     .NOT.IEEE_IS_FINITE(springL) .OR.
     &     .NOT.IEEE_IS_FINITE(displacementEast) .OR.
     &     .NOT.IEEE_IS_FINITE(displacementNorth) .OR.
     &     .NOT.IEEE_IS_FINITE(distance) ) RETURN
      IF ( tauValue.LT.0. _d 0 .OR.
     &     springL.LE.0. _d 0 .OR. distance.LE.0. _d 0 ) RETURN

C--   Reject mismatched displacement/distance inputs before using L/d.
      CALL BOM_SAFE_NORM2_RL(
     I     displacementEast,displacementNorth,
     O     normValue,calcValid)
      IF ( .NOT.calcValid ) RETURN
      IF ( normValue.LE.0. _d 0 ) RETURN
      normDifference = ABS(normValue-distance)
      CALL BOM_SAFE_MULT_RL(
     I     128. _d 0*EPSILON(oneRL),
     I     MAX(oneRL,normValue,distance),
     O     normTolerance,calcValid)
      IF ( .NOT.calcValid ) RETURN
      IF ( normDifference.GT.normTolerance ) RETURN

      IF ( springLaw.EQ.'HOOKE' ) THEN
        IF ( .NOT.IEEE_IS_FINITE(hookeK) ) RETURN
        IF ( hookeK.LE.0. _d 0 ) RETURN
        stiffnessWork = hookeK
      ELSE
        IF ( .NOT.IEEE_IS_FINITE(springA) .OR.
     &       .NOT.IEEE_IS_FINITE(springDelta) ) RETURN
        IF ( springA.LE.0. _d 0 .OR.
     &       springDelta.LE.0. _d 0 ) RETURN
        CALL BOM_SAFE_MULT_RL(
     I       2. _d 0,springL,
     O       twoL,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_ADD_RL(
     I       distance,-twoL,
     O       numerator,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_DIV_RL(
     I       numerator,springDelta,
     O       zValue,calcValid)
        IF ( .NOT.calcValid ) RETURN
        logTinyValue = LOG(TINY(oneRL))
        IF ( zValue.GE.0. _d 0 ) THEN
          IF ( zValue.GT.-logTinyValue ) THEN
            exponential = 0. _d 0
          ELSE
            exponential = EXP(-zValue)
          ENDIF
          IF ( .NOT.IEEE_IS_FINITE(exponential) ) RETURN
          CALL BOM_SAFE_ADD_RL(
     I         oneRL,exponential,
     O         denominator,calcValid)
          IF ( .NOT.calcValid ) RETURN
          CALL BOM_SAFE_MULT_RL(
     I         springA,exponential,
     O         numerator,calcValid)
          IF ( .NOT.calcValid ) RETURN
          CALL BOM_SAFE_DIV_RL(
     I         numerator,denominator,
     O         stiffnessWork,calcValid)
        ELSE
          IF ( zValue.LT.logTinyValue ) THEN
            exponential = 0. _d 0
          ELSE
            exponential = EXP(zValue)
          ENDIF
          IF ( .NOT.IEEE_IS_FINITE(exponential) ) RETURN
          CALL BOM_SAFE_ADD_RL(
     I         oneRL,exponential,
     O         denominator,calcValid)
          IF ( .NOT.calcValid ) RETURN
          CALL BOM_SAFE_DIV_RL(
     I         springA,denominator,
     O         stiffnessWork,calcValid)
        ENDIF
        IF ( .NOT.calcValid ) RETURN
        IF ( .NOT.IEEE_IS_FINITE(stiffnessWork) ) RETURN
      ENDIF

      CALL BOM_SAFE_DIV_RL(
     I     springL,distance,
     O     ratio,calcValid)
      IF ( .NOT.calcValid ) RETURN
      CALL BOM_SAFE_ADD_RL(
     I     ratio,-oneRL,
     O     extensionFactor,calcValid)
      IF ( .NOT.calcValid ) RETURN
      CALL BOM_SAFE_MULT_RL(
     I     tauValue,stiffnessWork,
     O     tauStiffness,calcValid)
      IF ( .NOT.calcValid ) RETURN
      CALL BOM_SAFE_MULT_RL(
     I     tauStiffness,extensionFactor,
     O     scalarFactor,calcValid)
      IF ( .NOT.calcValid ) RETURN
      CALL BOM_SAFE_MULT_RL(
     I     -scalarFactor,displacementEast,
     O     eastWork,calcValid)
      IF ( .NOT.calcValid ) RETURN
      CALL BOM_SAFE_MULT_RL(
     I     -scalarFactor,displacementNorth,
     O     northWork,termValid)
      IF ( .NOT.termValid ) RETURN

      velocityEastLo = eastWork
      velocityNorthLo = northWork
      stiffness = stiffnessWork
      failCode = BOM_FAIL_NONE
      pairValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SPRING_ACCUMULATE(
     I                 accumulatedEast, accumulatedNorth,
     I                 pairEast, pairNorth,
     O                 resultEast, resultNorth,
     O                 failCode, accumulationValid )

C     Stateless finite-checked accumulation helper for future ID-sorted
C     owner neighbor loops.  It cannot partially publish one component.
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL accumulatedEast, accumulatedNorth, pairEast, pairNorth
      _RL resultEast, resultNorth, eastWork, northWork
      INTEGER failCode
      LOGICAL accumulationValid, eastValid, northValid

      resultEast = accumulatedEast
      resultNorth = accumulatedNorth
      failCode = BOM_FAIL_SPRING_LAW
      accumulationValid = .FALSE.
      CALL BOM_SAFE_ADD_RL(
     I     accumulatedEast,pairEast,
     O     eastWork,eastValid)
      CALL BOM_SAFE_ADD_RL(
     I     accumulatedNorth,pairNorth,
     O     northWork,northValid)
      IF ( .NOT.eastValid .OR. .NOT.northValid ) RETURN
      resultEast = eastWork
      resultNorth = northWork
      failCode = BOM_FAIL_NONE
      accumulationValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SAFE_DIV_RL(
     I                 numerator, denominator,
     O                 quotient, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL numerator, denominator, quotient
      _RL absNumerator, absDenominator
      LOGICAL isValid

      quotient = 0. _d 0
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(numerator) .OR.
     &     .NOT.IEEE_IS_FINITE(denominator) ) RETURN
      IF ( denominator.EQ.0. _d 0 ) RETURN
      IF ( numerator.EQ.0. _d 0 ) THEN
        isValid = .TRUE.
        RETURN
      ENDIF
      absNumerator = ABS(numerator)
      absDenominator = ABS(denominator)
      IF ( absDenominator.LT.1. _d 0 ) THEN
        IF ( absNumerator.GT.HUGE(quotient)*absDenominator ) RETURN
      ENDIF
      quotient = numerator/denominator
      IF ( .NOT.IEEE_IS_FINITE(quotient) ) THEN
        quotient = 0. _d 0
        RETURN
      ENDIF
      isValid = .TRUE.

      RETURN
      END
