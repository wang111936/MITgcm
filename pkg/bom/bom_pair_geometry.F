#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_PAIR_GEOMETRY
C !INTERFACE:
      SUBROUTINE BOM_PAIR_GEOMETRY(
     I                 idA, xA, yA, idB, xB, yB,
     I                 cartesianGrid, sphericalGrid, periodicX,
     I                 xMin, xMax, yMin, yMax, xPeriod,
     I                 sphereRadius, pairDistanceMin,
     O                 displacementEast, displacementNorth, distance,
     O                 failCode, pairValid )

C !DESCRIPTION:
C     Return one canonical low-ID to high-ID east/north displacement and
C     overflow-safe distance.  Numeric outputs remain unchanged on error.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      INTEGER*8 idA, idB
      _RL xA, yA, xB, yB
      LOGICAL cartesianGrid, sphericalGrid, periodicX
      _RL xMin, xMax, yMin, yMax, xPeriod
      _RL sphereRadius, pairDistanceMin
      _RL displacementEast, displacementNorth, distance
      INTEGER failCode
      LOGICAL pairValid

      _RL xLo, yLo, xHi, yHi
      _RL dxNative, dyNative, xResidLo, xResidHi
      _RL halfPeriod, candidate, midpointLat, cosMid
      _RL midpointLo, midpointHi
      _RL lonRadians, latRadians, metricFactor
      _RL workEast, workNorth, workDistance
      LOGICAL calcValid, termValid
CEOP

      failCode = BOM_FAIL_PAIR_GEOMETRY
      pairValid = .FALSE.

      IF ( idA.LE.0_8 .OR. idB.LE.0_8 .OR. idA.EQ.idB ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(xA) .OR.
     &     .NOT.IEEE_IS_FINITE(yA) .OR.
     &     .NOT.IEEE_IS_FINITE(xB) .OR.
     &     .NOT.IEEE_IS_FINITE(yB) ) RETURN
      IF ( cartesianGrid.EQV.sphericalGrid ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(xMin) .OR.
     &     .NOT.IEEE_IS_FINITE(xMax) .OR.
     &     .NOT.IEEE_IS_FINITE(yMin) .OR.
     &     .NOT.IEEE_IS_FINITE(yMax) ) RETURN
      IF ( xMax.LE.xMin .OR. yMax.LE.yMin ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(pairDistanceMin) ) RETURN
      IF ( pairDistanceMin.LE.0. _d 0 ) RETURN

      IF ( idA.LT.idB ) THEN
        xLo = xA
        yLo = yA
        xHi = xB
        yHi = yB
      ELSE
        xLo = xB
        yLo = yB
        xHi = xA
        yHi = yA
      ENDIF

      IF ( yLo.LT.yMin .OR. yLo.GE.yMax .OR.
     &     yHi.LT.yMin .OR. yHi.GE.yMax ) RETURN
      IF ( .NOT.periodicX ) THEN
        IF ( xLo.LT.xMin .OR. xLo.GE.xMax .OR.
     &       xHi.LT.xMin .OR. xHi.GE.xMax ) RETURN
        CALL BOM_SAFE_ADD_RL(xHi,-xLo,dxNative,calcValid)
        IF ( .NOT.calcValid ) RETURN
      ELSE
        IF ( .NOT.IEEE_IS_FINITE(xPeriod) ) RETURN
        IF ( xPeriod.LE.0. _d 0 ) RETURN
        CALL BOM_SAFE_ADD_RL(xLo,-xMin,xResidLo,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_ADD_RL(xHi,-xMin,xResidHi,calcValid)
        IF ( .NOT.calcValid ) RETURN
        xResidLo = MODULO(xResidLo,xPeriod)
        xResidHi = MODULO(xResidHi,xPeriod)
        IF ( .NOT.IEEE_IS_FINITE(xResidLo) .OR.
     &       .NOT.IEEE_IS_FINITE(xResidHi) ) RETURN
        CALL BOM_SAFE_ADD_RL(
     I       xResidHi,-xResidLo,
     O       dxNative,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_MULT_RL(
     I       halfRL,xPeriod,
     O       halfPeriod,calcValid)
        IF ( .NOT.calcValid ) RETURN
        IF ( halfPeriod.LE.0. _d 0 ) RETURN
C--     A half-period pair has two equally short images and is unsupported.
        IF ( ABS(dxNative).EQ.halfPeriod ) RETURN
        IF ( dxNative.GT.halfPeriod ) THEN
          CALL BOM_SAFE_ADD_RL(
     I         dxNative,-xPeriod,
     O         candidate,calcValid)
          IF ( .NOT.calcValid ) RETURN
          dxNative = candidate
        ELSEIF ( dxNative.LT.-halfPeriod ) THEN
          CALL BOM_SAFE_ADD_RL(
     I         dxNative,xPeriod,
     O         candidate,calcValid)
          IF ( .NOT.calcValid ) RETURN
          dxNative = candidate
        ENDIF
      ENDIF

      CALL BOM_SAFE_ADD_RL(yHi,-yLo,dyNative,calcValid)
      IF ( .NOT.calcValid ) RETURN

      IF ( cartesianGrid ) THEN
        workEast = dxNative
        workNorth = dyNative
      ELSE
        IF ( .NOT.IEEE_IS_FINITE(sphereRadius) ) RETURN
        IF ( sphereRadius.LE.0. _d 0 ) RETURN
        IF ( ABS(yLo).GT.90. _d 0 .OR.
     &       ABS(yHi).GT.90. _d 0 ) RETURN
        CALL BOM_SAFE_MULT_RL(halfRL,yLo,midpointLo,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_MULT_RL(halfRL,yHi,midpointHi,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_ADD_RL(
     I       midpointLo,midpointHi,
     O       midpointLat,calcValid)
        IF ( .NOT.calcValid ) RETURN
        cosMid = COS(deg2rad*midpointLat)
        IF ( .NOT.IEEE_IS_FINITE(cosMid) ) RETURN
        IF ( ABS(cosMid).LT.SQRT(EPSILON(oneRL)) ) RETURN
        CALL BOM_SAFE_MULT_RL(
     I       dxNative,deg2rad,
     O       lonRadians,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_MULT_RL(
     I       dyNative,deg2rad,
     O       latRadians,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_MULT_RL(
     I       sphereRadius,cosMid,
     O       metricFactor,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_MULT_RL(
     I       metricFactor,lonRadians,
     O       workEast,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_MULT_RL(
     I       sphereRadius,latRadians,
     O       workNorth,calcValid)
        IF ( .NOT.calcValid ) RETURN
      ENDIF

      CALL BOM_SAFE_NORM2_RL(
     I     workEast,workNorth,
     O     workDistance,termValid)
      IF ( .NOT.termValid ) RETURN
      IF ( workDistance.LE.pairDistanceMin ) RETURN

      displacementEast = workEast
      displacementNorth = workNorth
      distance = workDistance
      failCode = BOM_FAIL_NONE
      pairValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SAFE_NORM2_RL(
     I                 value1, value2,
     O                 normValue, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL value1, value2, normValue
      _RL scaleValue, scaled1, scaled2, rootValue
      LOGICAL isValid

      normValue = 0. _d 0
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(value1) .OR.
     &     .NOT.IEEE_IS_FINITE(value2) ) RETURN
      scaleValue = MAX(ABS(value1),ABS(value2))
      IF ( scaleValue.EQ.0. _d 0 ) THEN
        isValid = .TRUE.
        RETURN
      ENDIF
      scaled1 = value1/scaleValue
      scaled2 = value2/scaleValue
      rootValue = SQRT(scaled1*scaled1+scaled2*scaled2)
      IF ( .NOT.IEEE_IS_FINITE(rootValue) ) RETURN
      IF ( rootValue.LE.0. _d 0 ) RETURN
      IF ( scaleValue.GT.HUGE(normValue)/rootValue ) RETURN
      normValue = scaleValue*rootValue
      IF ( .NOT.IEEE_IS_FINITE(normValue) ) THEN
        normValue = 0. _d 0
        RETURN
      ENDIF
      isValid = .TRUE.

      RETURN
      END
