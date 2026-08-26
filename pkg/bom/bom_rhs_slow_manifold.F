#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_RHS_SLOW_MANIFOLD
C !INTERFACE:
      SUBROUTINE BOM_RHS_SLOW_MANIFOLD(
     I                 xx, yy, stageTime, trialDt, bi, bj, rhsStage,
     O                 rhsX, rhsY, ix, jy, rhsDiag,
     O                 wetWeight, stageCFL,
     O                 isOwner, isValid, failCode, failStage,
     I                 myThid )

C !DESCRIPTION:
C     Build one stateless Phase-2 particle-stage RHS candidate.  Accepted
C     endpoint values, time secants, endpoint gradients, metrics, and CFL
C     metrics are interpolated with one common wet bilinear stencil before
C     nonlinear equation terms are formed.  No particle COMMON state is
C     written here.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL xx, yy, stageTime, trialDt
      INTEGER bi, bj, rhsStage, myThid

C !OUTPUT PARAMETERS:
      _RL rhsX, rhsY, ix, jy
      _RL rhsDiag(BOM_RHS_NDIAG), wetWeight, stageCFL
      LOGICAL isOwner, isValid
      INTEGER failCode, failStage
CEOP

C !LOCAL VARIABLES:
      INTEGER iDiag
#ifdef ALLOW_BOM
      INTEGER i1, j1, ii, jj, i, j, iSource
      _RL xMap, fracI, fracJ, weight, normWeight
      _RL weights(0:1,0:1)
      _RL pointEast, pointNorth, pointDtEast, pointDtNorth
      _RL pointEE, pointNE, pointEN, pointNN
      _RL sourceEast(BOM_ENV_NSOURCE)
      _RL sourceNorth(BOM_ENV_NSOURCE)
      _RL sourceDtEast(BOM_ENV_NSOURCE)
      _RL sourceDtNorth(BOM_ENV_NSOURCE)
      _RL gradEastEast(BOM_ENV_NSOURCE)
      _RL gradNorthEast(BOM_ENV_NSOURCE)
      _RL gradEastNorth(BOM_ENV_NSOURCE)
      _RL gradNorthNorth(BOM_ENV_NSOURCE)
      _RL stageFCori, stageTauSphere
      _RL stageRecipDx, stageRecipDy
      _RL pointFCori, pointTau, pointRecipDx, pointRecipDy
      _RL cosLat, cosMin, denomX, denomY
      INTEGER pointFailCode, pointFailStage
      LOGICAL hasStencil, pointValid, interpValid
      LOGICAL derivativeValid, stokesApplied, componentValid
      LOGICAL hasExplicitStokes
#endif

      rhsX = 0. _d 0
      rhsY = 0. _d 0
      ix = -1. _d 0
      jy = -1. _d 0
      wetWeight = 0. _d 0
      stageCFL = 0. _d 0
      isOwner = .FALSE.
      isValid = .FALSE.
      failCode = BOM_FAIL_NONFINITE
      failStage = rhsStage
      DO iDiag=1,BOM_RHS_NDIAG
        rhsDiag(iDiag) = 0. _d 0
      ENDDO

#ifdef ALLOW_BOM
C--   State/time and source-policy checks precede spatial mapping.
      IF ( rhsStage.LT.BOM_STAGE_K1 .OR.
     &     rhsStage.GT.BOM_STAGE_FINAL ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(xx) .OR.
     &     .NOT.IEEE_IS_FINITE(yy) .OR.
     &     .NOT.IEEE_IS_FINITE(stageTime) .OR.
     &     .NOT.IEEE_IS_FINITE(trialDt) ) RETURN
      IF ( trialDt.LT.0. _d 0 ) RETURN
      failCode = BOM_FAIL_FIELD_SOURCE
      hasExplicitStokes = bomStokesSource.NE.'NONE'
      IF ( bomCurrentPolicy.EQ.'PRECOMBINED' ) THEN
        IF ( hasExplicitStokes ) THEN
          failCode = BOM_FAIL_STOKES_DUPLICATE
          RETURN
        ENDIF
        IF ( bomSigma.NE.0. _d 0 ) RETURN
      ELSEIF ( bomCurrentPolicy.EQ.'EULERIAN' ) THEN
        IF ( .NOT.hasExplicitStokes .AND.
     &       bomSigma.NE.0. _d 0 ) RETURN
      ELSE
        RETURN
      ENDIF
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) THEN
        failCode = BOM_FAIL_MAP
        RETURN
      ENDIF

C--   Map on the input owner tile or its exchanged overlap.
      failCode = BOM_FAIL_MAP
      CALL BOM_NORMALIZE_X( xx, xMap, interpValid, myThid )
      IF ( .NOT.interpValid .OR.
     &     yy.LT.bomMapYLo .OR. yy.GE.bomMapYHi ) RETURN
      CALL BOM_MAP_XY2IJLOCAL(
     I     xx, yy, bi, bj,
     O     xMap, ix, jy, isOwner, hasStencil,
     I     myThid )
      IF ( .NOT.IEEE_IS_FINITE(ix) .OR.
     &     .NOT.IEEE_IS_FINITE(jy) ) RETURN
      IF ( .NOT.hasStencil ) THEN
        failCode = BOM_FAIL_STENCIL
        RETURN
      ENDIF

C--   One bilinear stencil and wet sum govern every interpolated input.
      IF ( ix.LT.DFLOAT(1-OLx) .OR. ix.GE.DFLOAT(sNx+OLx)
     &     .OR. jy.LT.DFLOAT(1-OLy)
     &     .OR. jy.GE.DFLOAT(sNy+OLy) ) THEN
        failCode = BOM_FAIL_STENCIL
        RETURN
      ENDIF
      i1 = INT(ix)
      IF ( DFLOAT(i1).GT.ix ) i1 = i1 - 1
      j1 = INT(jy)
      IF ( DFLOAT(j1).GT.jy ) j1 = j1 - 1
      IF ( i1.LT.1-OLx .OR. i1+1.GT.sNx+OLx .OR.
     &     j1.LT.1-OLy .OR. j1+1.GT.sNy+OLy ) THEN
        failCode = BOM_FAIL_STENCIL
        RETURN
      ENDIF
      fracI = ix-DFLOAT(i1)
      fracJ = jy-DFLOAT(j1)
      weights(0,0) = (oneRL-fracI)*(oneRL-fracJ)
      weights(1,0) = fracI*(oneRL-fracJ)
      weights(0,1) = (oneRL-fracI)*fracJ
      weights(1,1) = fracI*fracJ
      IF ( .NOT.IEEE_IS_FINITE(bomWetWeightMin) .OR.
     &     bomWetWeightMin.LE.0. _d 0 .OR.
     &     bomWetWeightMin.GT.oneRL ) THEN
        failCode = BOM_FAIL_INTERP
        RETURN
      ENDIF
      DO jj=0,1
       DO ii=0,1
        IF ( maskC(i1+ii,j1+jj,1,bi,bj).GT.0. )
     &       wetWeight = wetWeight + weights(ii,jj)
       ENDDO
      ENDDO
      IF ( .NOT.IEEE_IS_FINITE(wetWeight) .OR.
     &     wetWeight.LT.bomWetWeightMin ) THEN
        failCode = BOM_FAIL_INTERP
        RETURN
      ENDIF

      DO iSource=1,BOM_ENV_NSOURCE
        sourceEast(iSource) = 0. _d 0
        sourceNorth(iSource) = 0. _d 0
        sourceDtEast(iSource) = 0. _d 0
        sourceDtNorth(iSource) = 0. _d 0
        gradEastEast(iSource) = 0. _d 0
        gradNorthEast(iSource) = 0. _d 0
        gradEastNorth(iSource) = 0. _d 0
        gradNorthNorth(iSource) = 0. _d 0
      ENDDO
      stageFCori = 0. _d 0
      stageTauSphere = 0. _d 0
      stageRecipDx = 0. _d 0
      stageRecipDy = 0. _d 0

C--   Time interpolation occurs at every used C point before the common
C     wet-weighted spatial sum.  Invalid dry points are never substituted.
      DO jj=0,1
       DO ii=0,1
        weight = weights(ii,jj)
        IF ( maskC(i1+ii,j1+jj,1,bi,bj).GT.0. .AND.
     &       weight.GT.0. _d 0 ) THEN
          i = i1+ii
          j = j1+jj
          normWeight = weight/wetWeight
          DO iSource=1,BOM_ENV_NSOURCE
            CALL BOM_INTERP_ENV_TIME(
     I           i, j, bi, bj, iSource, stageTime,
     O           pointEast, pointNorth,
     O           pointDtEast, pointDtNorth, pointValid,
     O           pointFailCode, pointFailStage, interpValid,
     I           myThid )
            IF ( .NOT.interpValid ) THEN
              failCode = pointFailCode
              RETURN
            ENDIF
            IF ( .NOT.pointValid ) THEN
              failCode = BOM_FAIL_FIELD_SOURCE
              RETURN
            ENDIF
            sourceEast(iSource) = sourceEast(iSource)
     &           + normWeight*pointEast
            sourceNorth(iSource) = sourceNorth(iSource)
     &           + normWeight*pointNorth
            sourceDtEast(iSource) = sourceDtEast(iSource)
     &           + normWeight*pointDtEast
            sourceDtNorth(iSource) = sourceDtNorth(iSource)
     &           + normWeight*pointDtNorth

            CALL BOM_INTERP_ENV_DERIVATIVES(
     I           i, j, bi, bj, iSource, stageTime,
     O           pointEE, pointNE, pointEN, pointNN,
     O           derivativeValid,
     O           pointFailCode, pointFailStage, interpValid,
     I           myThid )
            IF ( .NOT.interpValid ) THEN
              failCode = pointFailCode
              RETURN
            ENDIF
            IF ( .NOT.derivativeValid ) THEN
              failCode = BOM_FAIL_GRADIENT
              RETURN
            ENDIF
            gradEastEast(iSource) = gradEastEast(iSource)
     &           + normWeight*pointEE
            gradNorthEast(iSource) = gradNorthEast(iSource)
     &           + normWeight*pointNE
            gradEastNorth(iSource) = gradEastNorth(iSource)
     &           + normWeight*pointEN
            gradNorthNorth(iSource) = gradNorthNorth(iSource)
     &           + normWeight*pointNN
          ENDDO

          failCode = BOM_FAIL_METRIC
          IF ( .NOT.bomMetricReady .OR.
     &         .NOT.bomMetricValid(i,j,bi,bj) ) RETURN
          pointFCori = bomFCori(i,j,bi,bj)
          pointTau = bomTauSphere(i,j,bi,bj)
          pointRecipDx = recip_dxF(i,j,bi,bj)
          pointRecipDy = recip_dyF(i,j,bi,bj)
          IF ( .NOT.IEEE_IS_FINITE(pointFCori) .OR.
     &         .NOT.IEEE_IS_FINITE(pointTau) .OR.
     &         .NOT.IEEE_IS_FINITE(pointRecipDx) .OR.
     &         .NOT.IEEE_IS_FINITE(pointRecipDy) .OR.
     &         pointRecipDx.LE.0. _d 0 .OR.
     &         pointRecipDy.LE.0. _d 0 ) RETURN
          stageFCori = stageFCori + normWeight*pointFCori
          stageTauSphere = stageTauSphere + normWeight*pointTau
          stageRecipDx = stageRecipDx + normWeight*pointRecipDx
          stageRecipDy = stageRecipDy + normWeight*pointRecipDy
        ENDIF
       ENDDO
      ENDDO

C--   Form nonlinear equation terms only after all stage inputs exist.
      CALL BOM_RHS_COMPONENTS(
     I     bomEquationMode, bomCurrentPolicy,
     I     hasExplicitStokes, rhsStage,
     I     trialDt, stageRecipDx, stageRecipDy, bomAdvCFL,
     I     bomAlpha, bomTau, bomR, bomSigma,
     I     stageFCori, stageTauSphere,
     I     sourceEast, sourceNorth,
     I     sourceDtEast, sourceDtNorth,
     I     gradEastEast, gradNorthEast,
     I     gradEastNorth, gradNorthNorth,
     O     rhsDiag, stageCFL, stokesApplied,
     O     failCode, pointFailStage, componentValid )
      failStage = rhsStage
      IF ( .NOT.componentValid ) RETURN

C--   Convert final SI drift once to the model native coordinate rate.
      failCode = BOM_FAIL_EQUATION
      IF ( usingCartesianGrid .AND.
     &     .NOT.usingSphericalPolarGrid ) THEN
        rhsX = rhsDiag(BOM_RHS_DRIFT_E)
        rhsY = rhsDiag(BOM_RHS_DRIFT_N)
      ELSEIF ( usingSphericalPolarGrid .AND.
     &         .NOT.usingCartesianGrid ) THEN
        IF ( .NOT.IEEE_IS_FINITE(rSphere) .OR.
     &       rSphere.LE.0. _d 0 ) RETURN
        cosLat = COS(deg2rad*yy)
        cosMin = SQRT(EPSILON(oneRL))
        IF ( .NOT.IEEE_IS_FINITE(cosLat) .OR.
     &       ABS(cosLat).LT.cosMin ) RETURN
        denomY = rSphere*deg2rad
        denomX = denomY*cosLat
        IF ( .NOT.IEEE_IS_FINITE(denomX) .OR.
     &       .NOT.IEEE_IS_FINITE(denomY) .OR.
     &       ABS(denomX).LE.0. _d 0 .OR.
     &       denomY.LE.0. _d 0 ) RETURN
        IF ( ABS(denomX).LT.oneRL ) THEN
          IF ( ABS(rhsDiag(BOM_RHS_DRIFT_E))
     &         .GT.HUGE(rhsX)*ABS(denomX) ) RETURN
        ENDIF
        IF ( denomY.LT.oneRL ) THEN
          IF ( ABS(rhsDiag(BOM_RHS_DRIFT_N))
     &         .GT.HUGE(rhsY)*denomY ) RETURN
        ENDIF
        rhsX = rhsDiag(BOM_RHS_DRIFT_E)/denomX
        rhsY = rhsDiag(BOM_RHS_DRIFT_N)/denomY
      ELSE
        RETURN
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(rhsX) .OR.
     &     .NOT.IEEE_IS_FINITE(rhsY) ) RETURN

      failCode = BOM_FAIL_NONE
      failStage = BOM_STAGE_NONE
      isValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END
