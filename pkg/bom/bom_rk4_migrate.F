#include "BOM_OPTIONS.h"

C $Header: $
C $Name:  $

C--   File bom_rk4_migrate.F
C--   Contents
C--   o BOM_RK4_MIGRATE

CBOP
C     !ROUTINE: BOM_RK4_MIGRATE
C     !INTERFACE:
      SUBROUTINE BOM_RK4_MIGRATE(
     I                 x0, y0, deltaT, bi, bj,
     O                 x1, y1, ix, jy,
     O                 oceanEast, oceanNorth,
     O                 windEast, windNorth,
     O                 driftEast, driftNorth,
     O                 wetWeight, stageCFL,
     O                 failStage, failCode, isValid,
     I                 myThid )

C     !DESCRIPTION:
C     Evaluate one P1.4 classical RK4 step using exchanged overlap
C     fields.  K1 must be on the input owner; later stages may leave it
C     and are committed only after post-substep migration.
C
C       k1 = f(q0)
C       k2 = f(q0 + 0.5*deltaT*k1)
C       k3 = f(q0 + 0.5*deltaT*k2)
C       k4 = f(q0 + deltaT*k3)
C       q1 = q0 + deltaT*(k1 + 2*k2 + 2*k3 + k4)/6
C
C     A final zero-guard RHS evaluation refreshes field diagnostics at
C     q1.  No particle slot, count, release state, or owner state is
C     modified here.  On any failure x1/y1 remain equal to x0/y0.

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
      _RL x0
      _RL y0
      _RL deltaT
      INTEGER bi
      INTEGER bj
      INTEGER myThid

C     !OUTPUT PARAMETERS:
      _RL x1
      _RL y1
      _RL ix
      _RL jy
      _RL oceanEast
      _RL oceanNorth
      _RL windEast
      _RL windNorth
      _RL driftEast
      _RL driftNorth
      _RL wetWeight
      _RL stageCFL
      INTEGER failStage
      INTEGER failCode
      LOGICAL isValid

C     !LOCAL VARIABLES:
      _RL k1X
      _RL k1Y
      _RL k2X
      _RL k2Y
      _RL k3X
      _RL k3Y
      _RL k4X
      _RL k4Y
      _RL finalRhsX
      _RL finalRhsY
      _RL xStage
      _RL yStage
      _RL xTrial
      _RL yTrial
      INTEGER rhsFailCode
      LOGICAL rhsOwner
      LOGICAL rhsValid
      LOGICAL coordValid
CEOP

C--   Deterministic rollback values and diagnostics.
      x1 = x0
      y1 = y0
      ix = -1. _d 0
      jy = -1. _d 0
      oceanEast = 0. _d 0
      oceanNorth = 0. _d 0
      windEast = 0. _d 0
      windNorth = 0. _d 0
      driftEast = 0. _d 0
      driftNorth = 0. _d 0
      wetWeight = 0. _d 0
      stageCFL = 0. _d 0
      failStage = BOM_STAGE_NONE
      failCode = BOM_FAIL_NONE
      isValid = .FALSE.

C--   No RK stage has begun when the input state or step is invalid.
      IF ( .NOT. IEEE_IS_FINITE(x0) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( .NOT. IEEE_IS_FINITE(y0) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( .NOT. IEEE_IS_FINITE(deltaT) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( deltaT .LT. 0. _d 0 ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF

C--   K1: full Leeway RHS at the input position.
      failStage = BOM_STAGE_K1
      CALL BOM_RHS_LEEWAY_HALO(
     I     x0, y0, deltaT, bi, bj,
     O     k1X, k1Y, ix, jy,
     O     oceanEast, oceanNorth,
     O     windEast, windNorth,
     O     driftEast, driftNorth,
     O     wetWeight, stageCFL,
     O     rhsOwner, rhsValid, rhsFailCode,
     I     myThid )
      IF ( .NOT. rhsValid ) THEN
        failCode = rhsFailCode
        RETURN
      ENDIF
      IF ( .NOT. rhsOwner ) THEN
        failCode = BOM_FAIL_OWNER
        RETURN
      ENDIF

C--   K2 trial and full RHS.
      failStage = BOM_STAGE_K2
      CALL BOM_RK_COORD_UPDATE(
     I     x0, k1X, deltaT, 0.5 _d 0,
     O     xStage, coordValid )
      IF ( .NOT. coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK_COORD_UPDATE(
     I     y0, k1Y, deltaT, 0.5 _d 0,
     O     yStage, coordValid )
      IF ( .NOT. coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RHS_LEEWAY_HALO(
     I     xStage, yStage, deltaT, bi, bj,
     O     k2X, k2Y, ix, jy,
     O     oceanEast, oceanNorth,
     O     windEast, windNorth,
     O     driftEast, driftNorth,
     O     wetWeight, stageCFL,
     O     rhsOwner, rhsValid, rhsFailCode,
     I     myThid )
      IF ( .NOT. rhsValid ) THEN
        failCode = rhsFailCode
        RETURN
      ENDIF
C--   K3 trial and full RHS.
      failStage = BOM_STAGE_K3
      CALL BOM_RK_COORD_UPDATE(
     I     x0, k2X, deltaT, 0.5 _d 0,
     O     xStage, coordValid )
      IF ( .NOT. coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK_COORD_UPDATE(
     I     y0, k2Y, deltaT, 0.5 _d 0,
     O     yStage, coordValid )
      IF ( .NOT. coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RHS_LEEWAY_HALO(
     I     xStage, yStage, deltaT, bi, bj,
     O     k3X, k3Y, ix, jy,
     O     oceanEast, oceanNorth,
     O     windEast, windNorth,
     O     driftEast, driftNorth,
     O     wetWeight, stageCFL,
     O     rhsOwner, rhsValid, rhsFailCode,
     I     myThid )
      IF ( .NOT. rhsValid ) THEN
        failCode = rhsFailCode
        RETURN
      ENDIF
C--   K4 trial and full RHS.
      failStage = BOM_STAGE_K4
      CALL BOM_RK_COORD_UPDATE(
     I     x0, k3X, deltaT, 1. _d 0,
     O     xStage, coordValid )
      IF ( .NOT. coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK_COORD_UPDATE(
     I     y0, k3Y, deltaT, 1. _d 0,
     O     yStage, coordValid )
      IF ( .NOT. coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RHS_LEEWAY_HALO(
     I     xStage, yStage, deltaT, bi, bj,
     O     k4X, k4Y, ix, jy,
     O     oceanEast, oceanNorth,
     O     windEast, windNorth,
     O     driftEast, driftNorth,
     O     wetWeight, stageCFL,
     O     rhsOwner, rhsValid, rhsFailCode,
     I     myThid )
      IF ( .NOT. rhsValid ) THEN
        failCode = rhsFailCode
        RETURN
      ENDIF
C--   Form the final weighted trial position in local scratch state.
      failStage = BOM_STAGE_FINAL
      CALL BOM_RK4_COORD_UPDATE(
     I     x0, k1X, k2X, k3X, k4X, deltaT,
     O     xTrial, coordValid )
      IF ( .NOT. coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK4_COORD_UPDATE(
     I     y0, k1Y, k2Y, k3Y, k4Y, deltaT,
     O     yTrial, coordValid )
      IF ( .NOT. coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF

C--   FINAL is a validation/diagnostic refresh, not an RK stage.
      CALL BOM_RHS_LEEWAY_HALO(
     I     xTrial, yTrial, 0. _d 0, bi, bj,
     O     finalRhsX, finalRhsY, ix, jy,
     O     oceanEast, oceanNorth,
     O     windEast, windNorth,
     O     driftEast, driftNorth,
     O     wetWeight, stageCFL,
     O     rhsOwner, rhsValid, rhsFailCode,
     I     myThid )
      IF ( .NOT. rhsValid ) THEN
        failCode = rhsFailCode
        RETURN
      ENDIF
C--   Publish the accepted local result only after FINAL succeeds.
      x1 = xTrial
      y1 = yTrial
      failStage = BOM_STAGE_NONE
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.

      RETURN
      END
