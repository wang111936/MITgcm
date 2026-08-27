#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_RK2_SLOW_MIGRATE
C !INTERFACE:
      SUBROUTINE BOM_RK2_SLOW_MIGRATE(
     I                 x0, y0, stageTime0, deltaT, bi, bj,
     O                 x1, y1, ix, jy, rhsDiag,
     O                 wetWeight, stageCFL,
     O                 failStage, failCode, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Explicit-midpoint Phase-2 transaction at exact stage times.  K1
C     must be on the input owner; later stages may use its overlap.  The
C     final position and complete FINAL diagnostic vector are published
C     to output candidates only after every stage succeeds.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL x0, y0, stageTime0, deltaT
      INTEGER bi, bj, myThid
C !OUTPUT PARAMETERS:
      _RL x1, y1, ix, jy, rhsDiag(BOM_RHS_NDIAG)
      _RL wetWeight, stageCFL
      INTEGER failStage, failCode
      LOGICAL isValid
CEOP

C !LOCAL VARIABLES:
      _RL k1X, k1Y, k2X, k2Y, finalX, finalY
      _RL xMid, yMid, xTrial, yTrial, timeMid, timeFinal
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
     I     x0, k1X, deltaT, 0.5 _d 0, xMid, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK_COORD_UPDATE(
     I     y0, k1Y, deltaT, 0.5 _d 0, yMid, coordValid )
      IF ( .NOT.coordValid ) THEN
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
      CALL BOM_RHS_SLOW_MANIFOLD(
     I     xMid, yMid, timeMid, deltaT, bi, bj, BOM_STAGE_K2,
     O     k2X, k2Y, ix, jy, stageDiag,
     O     wetWeight, stageCFL,
     O     rhsOwner, rhsValid, rhsFail, rhsFailStage,
     I     myThid )
      IF ( .NOT.rhsValid ) THEN
        failCode = rhsFail
        RETURN
      ENDIF

      failStage = BOM_STAGE_FINAL
      CALL BOM_RK_COORD_UPDATE(
     I     x0, k2X, deltaT, oneRL, xTrial, coordValid )
      IF ( .NOT.coordValid ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      CALL BOM_RK_COORD_UPDATE(
     I     y0, k2Y, deltaT, oneRL, yTrial, coordValid )
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
