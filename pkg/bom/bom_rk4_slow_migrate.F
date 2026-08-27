#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_RK4_SLOW_MIGRATE
C !INTERFACE:
      SUBROUTINE BOM_RK4_SLOW_MIGRATE(
     I                 x0, y0, stageTime0, deltaT, bi, bj,
     O                 x1, y1, ix, jy, rhsDiag,
     O                 wetWeight, stageCFL,
     O                 failStage, failCode, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Classical RK4 Phase-2 transaction at exact stage times.  K1 must
C     be on the input owner; K2--K4 and FINAL may use its overlap.  No
C     authoritative particle field is changed here.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      _RL x0, y0, stageTime0, deltaT
      INTEGER bi, bj, myThid
      _RL x1, y1, ix, jy, rhsDiag(BOM_RHS_NDIAG)
      _RL wetWeight, stageCFL
      INTEGER failStage, failCode
      LOGICAL isValid
CEOP

C !LOCAL VARIABLES:
      _RL k1X, k1Y, k2X, k2Y, k3X, k3Y, k4X, k4Y
      _RL finalX, finalY, xStage, yStage, xTrial, yTrial
      _RL timeMid, timeFinal
      _RL stageDiag(BOM_RHS_NDIAG)
      INTEGER iDiag, rhsFail, rhsFailStage
      LOGICAL rhsOwner, rhsValid, coordValid

      x1 = x0
      y1 = y0
      ix = -1. _d 0
      jy = -1. _d 0
      wetWeight = 0. _d 0
      stageCFL = 0. _d 0
      failStage = BOM_STAGE_NONE
      failCode = BOM_FAIL_NONE
      isValid = .FALSE.
      DO iDiag=1,BOM_RHS_NDIAG
        rhsDiag(iDiag) = 0. _d 0
      ENDDO
      IF ( .NOT.IEEE_IS_FINITE(x0) .OR.
     &     .NOT.IEEE_IS_FINITE(y0) .OR.
     &     .NOT.IEEE_IS_FINITE(stageTime0) .OR.
     &     .NOT.IEEE_IS_FINITE(deltaT) .OR.
     &     deltaT.LT.0. _d 0 ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK_COORD_UPDATE(
     I     stageTime0, oneRL, deltaT, 0.5 _d 0,
     O     timeMid, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK_COORD_UPDATE(
     I     stageTime0, oneRL, deltaT, oneRL,
     O     timeFinal, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF

      failStage = BOM_STAGE_K1
      CALL BOM_RHS_SLOW_MANIFOLD(
     I     x0, y0, stageTime0, deltaT, bi, bj, BOM_STAGE_K1,
     O     k1X, k1Y, ix, jy, stageDiag,
     O     wetWeight, stageCFL,
     O     rhsOwner, rhsValid, rhsFail, rhsFailStage,
     I     myThid )
      IF ( .NOT.rhsValid ) THEN
        failCode = rhsFail
        RETURN
      ENDIF
      IF ( .NOT.rhsOwner ) THEN
        failCode = BOM_FAIL_OWNER
        RETURN
      ENDIF

      failStage = BOM_STAGE_K2
      CALL BOM_RK_COORD_UPDATE(
     I     x0, k1X, deltaT, 0.5 _d 0, xStage, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK_COORD_UPDATE(
     I     y0, k1Y, deltaT, 0.5 _d 0, yStage, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RHS_SLOW_MANIFOLD(
     I     xStage, yStage, timeMid, deltaT, bi, bj, BOM_STAGE_K2,
     O     k2X, k2Y, ix, jy, stageDiag,
     O     wetWeight, stageCFL,
     O     rhsOwner, rhsValid, rhsFail, rhsFailStage,
     I     myThid )
      IF ( .NOT.rhsValid ) THEN
        failCode = rhsFail
        RETURN
      ENDIF

      failStage = BOM_STAGE_K3
      CALL BOM_RK_COORD_UPDATE(
     I     x0, k2X, deltaT, 0.5 _d 0, xStage, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK_COORD_UPDATE(
     I     y0, k2Y, deltaT, 0.5 _d 0, yStage, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RHS_SLOW_MANIFOLD(
     I     xStage, yStage, timeMid, deltaT, bi, bj, BOM_STAGE_K3,
     O     k3X, k3Y, ix, jy, stageDiag,
     O     wetWeight, stageCFL,
     O     rhsOwner, rhsValid, rhsFail, rhsFailStage,
     I     myThid )
      IF ( .NOT.rhsValid ) THEN
        failCode = rhsFail
        RETURN
      ENDIF

      failStage = BOM_STAGE_K4
      CALL BOM_RK_COORD_UPDATE(
     I     x0, k3X, deltaT, oneRL, xStage, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK_COORD_UPDATE(
     I     y0, k3Y, deltaT, oneRL, yStage, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RHS_SLOW_MANIFOLD(
     I     xStage, yStage, timeFinal, deltaT, bi, bj,
     I     BOM_STAGE_K4,
     O     k4X, k4Y, ix, jy, stageDiag,
     O     wetWeight, stageCFL,
     O     rhsOwner, rhsValid, rhsFail, rhsFailStage,
     I     myThid )
      IF ( .NOT.rhsValid ) THEN
        failCode = rhsFail
        RETURN
      ENDIF

      failStage = BOM_STAGE_FINAL
      CALL BOM_RK4_COORD_UPDATE(
     I     x0, k1X, k2X, k3X, k4X, deltaT,
     O     xTrial, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK4_COORD_UPDATE(
     I     y0, k1Y, k2Y, k3Y, k4Y, deltaT,
     O     yTrial, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RHS_SLOW_MANIFOLD(
     I     xTrial, yTrial, timeFinal, 0. _d 0,
     I     bi, bj, BOM_STAGE_FINAL,
     O     finalX, finalY, ix, jy, stageDiag,
     O     wetWeight, stageCFL,
     O     rhsOwner, rhsValid, rhsFail, rhsFailStage,
     I     myThid )
      IF ( .NOT.rhsValid ) THEN
        failCode = rhsFail
        RETURN
      ENDIF

      x1 = xTrial
      y1 = yTrial
      DO iDiag=1,BOM_RHS_NDIAG
        rhsDiag(iDiag) = stageDiag(iDiag)
      ENDDO
      failStage = BOM_STAGE_NONE
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
      RETURN
      END
