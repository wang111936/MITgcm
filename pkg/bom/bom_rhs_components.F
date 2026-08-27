#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_RHS_COMPONENTS
C !INTERFACE:
      SUBROUTINE BOM_RHS_COMPONENTS(
     I                 equationMode, currentPolicy,
     I                 hasExplicitStokes, rhsStage,
     I                 trialDt, recipDx, recipDy, advCFL,
     I                 alpha, tauValue, rValue, sigma,
     I                 fCori, tauSphere,
     I                 sourceEast, sourceNorth,
     I                 sourceDtEast, sourceDtNorth,
     I                 gradEastEast, gradNorthEast,
     I                 gradEastNorth, gradNorthNorth,
     O                 rhsDiag, stageCFL, stokesApplied,
     O                 failCode, failStage, rhsValid )

C !DESCRIPTION:
C     Stateless P2.3 equation-mode dispatcher.  Inputs are values and
C     derivatives already interpolated to one particle stage.  The routine
C     validates the explicit/precombined Stokes contract before selecting a
C     named algebra path, checks the final physical-drift CFL, and publishes
C     one complete diagnostic candidate.  It writes no particle COMMON state.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) equationMode, currentPolicy
      LOGICAL hasExplicitStokes
      INTEGER rhsStage
      _RL trialDt, recipDx, recipDy, advCFL
      _RL alpha, tauValue, rValue, sigma, fCori, tauSphere
      _RL sourceEast(BOM_ENV_NSOURCE)
      _RL sourceNorth(BOM_ENV_NSOURCE)
      _RL sourceDtEast(BOM_ENV_NSOURCE)
      _RL sourceDtNorth(BOM_ENV_NSOURCE)
      _RL gradEastEast(BOM_ENV_NSOURCE)
      _RL gradNorthEast(BOM_ENV_NSOURCE)
      _RL gradEastNorth(BOM_ENV_NSOURCE)
      _RL gradNorthNorth(BOM_ENV_NSOURCE)
      _RL rhsDiag(BOM_RHS_NDIAG), stageCFL
      LOGICAL stokesApplied, rhsValid
      INTEGER failCode, failStage
      _RL candidate(BOM_RHS_NDIAG), cflCandidate
      INTEGER iDiag, iSource, modeFail
      LOGICAL modeValid, cflValid
CEOP

      DO iDiag=1,BOM_RHS_NDIAG
        rhsDiag(iDiag) = 0. _d 0
        candidate(iDiag) = 0. _d 0
      ENDDO
      stageCFL = 0. _d 0
      stokesApplied = .FALSE.
      failCode = BOM_FAIL_EQUATION
      failStage = rhsStage
      rhsValid = .FALSE.

C--   Retain the exact RK stage supplied by the future P2.4 caller.
      IF ( rhsStage.LT.BOM_STAGE_K1 .OR.
     &     rhsStage.GT.BOM_STAGE_FINAL ) RETURN

C--   Source/de-duplication failures precede equation arithmetic.
      IF ( currentPolicy.EQ.'PRECOMBINED' ) THEN
        IF ( hasExplicitStokes ) THEN
          failCode = BOM_FAIL_STOKES_DUPLICATE
          RETURN
        ENDIF
        IF ( .NOT.IEEE_IS_FINITE(sigma) ) RETURN
        IF ( sigma.NE.0. _d 0 ) THEN
          failCode = BOM_FAIL_FIELD_SOURCE
          RETURN
        ENDIF
      ELSEIF ( currentPolicy.EQ.'EULERIAN' ) THEN
        IF ( .NOT.IEEE_IS_FINITE(sigma) ) RETURN
        IF ( .NOT.hasExplicitStokes .AND. sigma.NE.0. _d 0 ) THEN
          failCode = BOM_FAIL_FIELD_SOURCE
          RETURN
        ENDIF
      ELSE
        failCode = BOM_FAIL_FIELD_SOURCE
        RETURN
      ENDIF

C--   A declared absent source must be represented by exact zero candidates.
      IF ( .NOT.hasExplicitStokes ) THEN
        iSource = BOM_ENV_STOKES
        failCode = BOM_FAIL_FIELD_SOURCE
        IF ( .NOT.IEEE_IS_FINITE(sourceEast(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(sourceNorth(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(sourceDtEast(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(sourceDtNorth(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(gradEastEast(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(gradNorthEast(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(gradEastNorth(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(gradNorthNorth(iSource)) ) RETURN
        IF ( sourceEast(iSource).NE.0. _d 0 .OR.
     &       sourceNorth(iSource).NE.0. _d 0 .OR.
     &       sourceDtEast(iSource).NE.0. _d 0 .OR.
     &       sourceDtNorth(iSource).NE.0. _d 0 .OR.
     &       gradEastEast(iSource).NE.0. _d 0 .OR.
     &       gradNorthEast(iSource).NE.0. _d 0 .OR.
     &       gradEastNorth(iSource).NE.0. _d 0 .OR.
     &       gradNorthNorth(iSource).NE.0. _d 0 ) THEN
          failCode = BOM_FAIL_FIELD_SOURCE
          RETURN
        ENDIF
      ENDIF
      stokesApplied = hasExplicitStokes

C--   The setup gate owns user diagnostics; the stage gate rechecks all SI
C     controls and every candidate source before nonlinear arithmetic.
      failCode = BOM_FAIL_EQUATION
      IF ( .NOT.IEEE_IS_FINITE(trialDt) .OR.
     &     .NOT.IEEE_IS_FINITE(recipDx) .OR.
     &     .NOT.IEEE_IS_FINITE(recipDy) .OR.
     &     .NOT.IEEE_IS_FINITE(advCFL) .OR.
     &     .NOT.IEEE_IS_FINITE(alpha) .OR.
     &     .NOT.IEEE_IS_FINITE(tauValue) .OR.
     &     .NOT.IEEE_IS_FINITE(rValue) .OR.
     &     .NOT.IEEE_IS_FINITE(sigma) .OR.
     &     .NOT.IEEE_IS_FINITE(fCori) .OR.
     &     .NOT.IEEE_IS_FINITE(tauSphere) ) RETURN
      IF ( trialDt.LT.0. _d 0 .OR. recipDx.LE.0. _d 0 .OR.
     &     recipDy.LE.0. _d 0 .OR. advCFL.LE.0. _d 0 .OR.
     &     alpha.LT.0. _d 0 .OR. alpha.GT.1. _d 0 .OR.
     &     tauValue.LT.0. _d 0 .OR. rValue.LE.0. _d 0 .OR.
     &     rValue.GT.1. _d 0 .OR. sigma.LT.0. _d 0 ) RETURN
      DO iSource=1,BOM_ENV_NSOURCE
        IF ( .NOT.IEEE_IS_FINITE(sourceEast(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(sourceNorth(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(sourceDtEast(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(sourceDtNorth(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(gradEastEast(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(gradNorthEast(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(gradEastNorth(iSource)) .OR.
     &       .NOT.IEEE_IS_FINITE(gradNorthNorth(iSource)) ) RETURN
      ENDDO

      IF ( equationMode.EQ.'PAPER2024' ) THEN
        CALL BOM_RHS_PAPER2024(
     I       alpha, tauValue, rValue, sigma, fCori, tauSphere,
     I       sourceEast, sourceNorth, sourceDtEast, sourceDtNorth,
     I       gradEastEast, gradNorthEast,
     I       gradEastNorth, gradNorthNorth,
     O       candidate, modeFail, modeValid )
      ELSEIF ( equationMode.EQ.'JULIA' ) THEN
        CALL BOM_RHS_JULIA(
     I       alpha, tauValue, rValue, sigma, fCori, tauSphere,
     I       sourceEast, sourceNorth, sourceDtEast, sourceDtNorth,
     I       gradEastEast, gradNorthEast,
     I       gradEastNorth, gradNorthNorth,
     O       candidate, modeFail, modeValid )
      ELSE
        RETURN
      ENDIF
      IF ( .NOT.modeValid ) THEN
        failCode = modeFail
        RETURN
      ENDIF

C--   CFL is the last physical equation check and uses total drift, not u.
      failCode = BOM_FAIL_CFL
      CALL BOM_RHS_CFL_GUARD(
     I     candidate(BOM_RHS_DRIFT_E),
     I     candidate(BOM_RHS_DRIFT_N),
     I     trialDt, recipDx, recipDy, advCFL,
     O     cflCandidate, cflValid )
      stageCFL = cflCandidate
      IF ( .NOT.cflValid ) RETURN

      DO iDiag=1,BOM_RHS_NDIAG
        rhsDiag(iDiag) = candidate(iDiag)
      ENDDO
      failCode = BOM_FAIL_NONE
      failStage = BOM_STAGE_NONE
      rhsValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_RHS_CFL_GUARD(
     I                 driftEast, driftNorth,
     I                 trialDt, recipDx, recipDy, advCFL,
     O                 stageCFL, cflValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL driftEast, driftNorth, trialDt, recipDx, recipDy, advCFL
      _RL stageCFL, cflEast, cflNorth, cflRate
      LOGICAL cflValid, validEast, validNorth, validTime

      stageCFL = 0. _d 0
      cflValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(driftEast) .OR.
     &     .NOT.IEEE_IS_FINITE(driftNorth) .OR.
     &     .NOT.IEEE_IS_FINITE(trialDt) .OR.
     &     .NOT.IEEE_IS_FINITE(recipDx) .OR.
     &     .NOT.IEEE_IS_FINITE(recipDy) .OR.
     &     .NOT.IEEE_IS_FINITE(advCFL) ) RETURN
      IF ( trialDt.LT.0. _d 0 .OR. recipDx.LE.0. _d 0 .OR.
     &     recipDy.LE.0. _d 0 .OR. advCFL.LE.0. _d 0 ) RETURN

      CALL BOM_SAFE_MULT_RL(ABS(driftEast),recipDx,
     O                      cflEast,validEast)
      CALL BOM_SAFE_MULT_RL(ABS(driftNorth),recipDy,
     O                      cflNorth,validNorth)
      IF ( .NOT.validEast .OR. .NOT.validNorth ) THEN
        stageCFL = HUGE(stageCFL)
        RETURN
      ENDIF
      cflRate = MAX(cflEast,cflNorth)
      CALL BOM_SAFE_MULT_RL(trialDt,cflRate,
     O                      stageCFL,validTime)
      IF ( .NOT.validTime ) THEN
        stageCFL = HUGE(stageCFL)
        RETURN
      ENDIF
      IF ( stageCFL.GT.advCFL ) RETURN
      cflValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_RHS_COMBINE(
     I                 valueBase, scale, valueExtra,
     O                 result, combineValid )

      IMPLICIT NONE
      _RL valueBase, scale, valueExtra, result, scaledExtra
      LOGICAL combineValid, multValid

      result = 0. _d 0
      combineValid = .FALSE.
      CALL BOM_SAFE_MULT_RL(scale,valueExtra,scaledExtra,multValid)
      IF ( .NOT.multValid ) RETURN
      CALL BOM_SAFE_ADD_RL(valueBase,scaledExtra,
     O                     result,combineValid)

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_RHS_BLEND(
     I                 valueOcean, valueWind, alpha,
     O                 result, blendValid )

      IMPLICIT NONE
      _RL valueOcean, valueWind, alpha, result
      _RL oneMinusAlpha, oceanTerm, windTerm
      LOGICAL blendValid, valid1, valid2

      result = 0. _d 0
      blendValid = .FALSE.
      CALL BOM_SAFE_ADD_RL(1. _d 0,-alpha,oneMinusAlpha,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_MULT_RL(oneMinusAlpha,valueOcean,
     O                      oceanTerm,valid1)
      CALL BOM_SAFE_MULT_RL(alpha,valueWind,
     O                      windTerm,valid2)
      IF ( .NOT.valid1 .OR. .NOT.valid2 ) RETURN
      CALL BOM_SAFE_ADD_RL(oceanTerm,windTerm,result,blendValid)

      RETURN
      END
