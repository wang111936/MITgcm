#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_RHS_PAPER2024
C !INTERFACE:
      SUBROUTINE BOM_RHS_PAPER2024(
     I                 alpha, tauValue, rValue, sigma,
     I                 fCori, tauSphere,
     I                 sourceEast, sourceNorth,
     I                 sourceDtEast, sourceDtNorth,
     I                 gradEastEast, gradNorthEast,
     I                 gradEastNorth, gradNorthNorth,
     O                 rhsDiag, failCode, rhsValid )

C !DESCRIPTION:
C     Paper equation (2b) without spring force.  Total ocean and carrying
C     fields are combined before nonlinear covariant derivatives and total
C     vorticity are formed.  Outputs publish only after every term succeeds.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL alpha, tauValue, rValue, sigma, fCori, tauSphere
      _RL sourceEast(BOM_ENV_NSOURCE)
      _RL sourceNorth(BOM_ENV_NSOURCE)
      _RL sourceDtEast(BOM_ENV_NSOURCE)
      _RL sourceDtNorth(BOM_ENV_NSOURCE)
      _RL gradEastEast(BOM_ENV_NSOURCE)
      _RL gradNorthEast(BOM_ENV_NSOURCE)
      _RL gradEastNorth(BOM_ENV_NSOURCE)
      _RL gradNorthNorth(BOM_ENV_NSOURCE)
      _RL rhsDiag(BOM_RHS_NDIAG)
      _RL workDiag(BOM_RHS_NDIAG)
      _RL vEast, vNorth, uEast, uNorth
      _RL dtVEast, dtVNorth, dtUEast, dtUNorth
      _RL vEE, vNE, vEN, vNN, uEE, uNE, uEN, uNN
      _RL dvEast, dvNorth, duEast, duNorth, omega, omegaU
      INTEGER failCode, localFail, iDiag
      LOGICAL rhsValid, valid1, covValid
CEOP

      DO iDiag=1,BOM_RHS_NDIAG
        rhsDiag(iDiag) = 0. _d 0
        workDiag(iDiag) = 0. _d 0
      ENDDO
      failCode = BOM_FAIL_EQUATION
      rhsValid = .FALSE.

C--   v = vBase + sigma*vS, including its time/spatial derivatives.
      CALL BOM_RHS_COMBINE(sourceEast(BOM_ENV_EULERIAN),sigma,
     &     sourceEast(BOM_ENV_STOKES),vEast,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_COMBINE(sourceNorth(BOM_ENV_EULERIAN),sigma,
     &     sourceNorth(BOM_ENV_STOKES),vNorth,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_COMBINE(sourceDtEast(BOM_ENV_EULERIAN),sigma,
     &     sourceDtEast(BOM_ENV_STOKES),dtVEast,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_COMBINE(sourceDtNorth(BOM_ENV_EULERIAN),sigma,
     &     sourceDtNorth(BOM_ENV_STOKES),dtVNorth,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_COMBINE(gradEastEast(BOM_ENV_EULERIAN),sigma,
     &     gradEastEast(BOM_ENV_STOKES),vEE,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_COMBINE(gradNorthEast(BOM_ENV_EULERIAN),sigma,
     &     gradNorthEast(BOM_ENV_STOKES),vNE,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_COMBINE(gradEastNorth(BOM_ENV_EULERIAN),sigma,
     &     gradEastNorth(BOM_ENV_STOKES),vEN,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_COMBINE(gradNorthNorth(BOM_ENV_EULERIAN),sigma,
     &     gradNorthNorth(BOM_ENV_STOKES),vNN,valid1)
      IF ( .NOT.valid1 ) RETURN

C--   u = (1-alpha)*v + alpha*vW, with the same total-field ordering.
      CALL BOM_RHS_BLEND(vEast,sourceEast(BOM_ENV_WIND),alpha,
     &                   uEast,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_BLEND(vNorth,sourceNorth(BOM_ENV_WIND),alpha,
     &                   uNorth,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_BLEND(dtVEast,sourceDtEast(BOM_ENV_WIND),alpha,
     &                   dtUEast,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_BLEND(dtVNorth,sourceDtNorth(BOM_ENV_WIND),alpha,
     &                   dtUNorth,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_BLEND(vEE,gradEastEast(BOM_ENV_WIND),alpha,
     &                   uEE,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_BLEND(vNE,gradNorthEast(BOM_ENV_WIND),alpha,
     &                   uNE,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_BLEND(vEN,gradEastNorth(BOM_ENV_WIND),alpha,
     &                   uEN,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_BLEND(vNN,gradNorthNorth(BOM_ENV_WIND),alpha,
     &                   uNN,valid1)
      IF ( .NOT.valid1 ) RETURN

      CALL BOM_EVAL_COVARIANT(
     I     vEast, vNorth, dtVEast, dtVNorth,
     I     vEE, vNE, vEN, vNN, tauSphere,
     O     dvEast, dvNorth, omega, localFail, covValid )
      IF ( .NOT.covValid ) RETURN
      CALL BOM_EVAL_COVARIANT(
     I     uEast, uNorth, dtUEast, dtUNorth,
     I     uEE, uNE, uEN, uNN, tauSphere,
     O     duEast, duNorth, omegaU, localFail, covValid )
      IF ( .NOT.covValid ) RETURN

      CALL BOM_RHS_FINALIZE(
     I     sourceEast, sourceNorth,
     I     vEast, vNorth, uEast, uNorth,
     I     dvEast, dvNorth, duEast, duNorth, omega,
     I     fCori, tauSphere, tauValue, rValue,
     O     workDiag, localFail, valid1 )
      IF ( .NOT.valid1 ) RETURN

      DO iDiag=1,BOM_RHS_NDIAG
        rhsDiag(iDiag) = workDiag(iDiag)
      ENDDO
      failCode = BOM_FAIL_NONE
      rhsValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_RHS_FINALIZE(
     I                 sourceEast, sourceNorth,
     I                 vEast, vNorth, uEast, uNorth,
     I                 dvEast, dvNorth, duEast, duNorth, omega,
     I                 fCori, tauSphere, tauValue, rValue,
     O                 rhsDiag, failCode, rhsValid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL sourceEast(BOM_ENV_NSOURCE)
      _RL sourceNorth(BOM_ENV_NSOURCE)
      _RL vEast, vNorth, uEast, uNorth
      _RL dvEast, dvNorth, duEast, duNorth, omega
      _RL fCori, tauSphere, tauValue, rValue
      _RL rhsDiag(BOM_RHS_NDIAG), work(BOM_RHS_NDIAG)
      _RL omegaThird, cV, cU, metricU, rOmegaThird
      _RL rotVE, rotVN, rotUE, rotUN
      _RL rDvE, rDvN, sum1, sum2, inertE, inertN
      _RL tauInertE, tauInertN, driftE, driftN
      INTEGER failCode, iDiag
      LOGICAL rhsValid, valid1

      DO iDiag=1,BOM_RHS_NDIAG
        rhsDiag(iDiag) = 0. _d 0
        work(iDiag) = 0. _d 0
      ENDDO
      failCode = BOM_FAIL_EQUATION
      rhsValid = .FALSE.

      CALL BOM_SAFE_MULT_RL(omega,1. _d 0/3. _d 0,
     O                      omegaThird,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_ADD_RL(fCori,omegaThird,cV,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_MULT_RL(tauSphere,uEast,metricU,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_MULT_RL(rValue,omegaThird,rOmegaThird,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_ADD_RL(fCori,metricU,sum1,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_ADD_RL(sum1,rOmegaThird,cU,valid1)
      IF ( .NOT.valid1 ) RETURN

      CALL BOM_SAFE_MULT_RL(rValue,cV,sum1,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_MULT_RL(-sum1,vNorth,rotVE,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_MULT_RL(sum1,vEast,rotVN,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_MULT_RL(cU,uNorth,rotUE,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_MULT_RL(-cU,uEast,rotUN,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_MULT_RL(rValue,dvEast,rDvE,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_MULT_RL(rValue,dvNorth,rDvN,valid1)
      IF ( .NOT.valid1 ) RETURN

      CALL BOM_SAFE_ADD_RL(rDvE,rotVE,sum1,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_ADD_RL(sum1,-duEast,sum2,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_ADD_RL(sum2,rotUE,inertE,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_ADD_RL(rDvN,rotVN,sum1,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_ADD_RL(sum1,-duNorth,sum2,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_ADD_RL(sum2,rotUN,inertN,valid1)
      IF ( .NOT.valid1 ) RETURN

      CALL BOM_SAFE_MULT_RL(tauValue,inertE,tauInertE,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_MULT_RL(tauValue,inertN,tauInertN,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_ADD_RL(uEast,tauInertE,driftE,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_SAFE_ADD_RL(uNorth,tauInertN,driftN,valid1)
      IF ( .NOT.valid1 ) RETURN

      work(BOM_RHS_VBASE_E) = sourceEast(BOM_ENV_EULERIAN)
      work(BOM_RHS_VBASE_N) = sourceNorth(BOM_ENV_EULERIAN)
      work(BOM_RHS_VS_E) = sourceEast(BOM_ENV_STOKES)
      work(BOM_RHS_VS_N) = sourceNorth(BOM_ENV_STOKES)
      work(BOM_RHS_VW_E) = sourceEast(BOM_ENV_WIND)
      work(BOM_RHS_VW_N) = sourceNorth(BOM_ENV_WIND)
      work(BOM_RHS_V_E) = vEast
      work(BOM_RHS_V_N) = vNorth
      work(BOM_RHS_U_E) = uEast
      work(BOM_RHS_U_N) = uNorth
      work(BOM_RHS_DV_E) = dvEast
      work(BOM_RHS_DV_N) = dvNorth
      work(BOM_RHS_DU_E) = duEast
      work(BOM_RHS_DU_N) = duNorth
      work(BOM_RHS_OMEGA) = omega
      work(BOM_RHS_FCORI) = fCori
      work(BOM_RHS_TAUSPHERE) = tauSphere
      work(BOM_RHS_CV) = cV
      work(BOM_RHS_CU) = cU
      work(BOM_RHS_ROT_VE) = rotVE
      work(BOM_RHS_ROT_VN) = rotVN
      work(BOM_RHS_ROT_UE) = rotUE
      work(BOM_RHS_ROT_UN) = rotUN
      work(BOM_RHS_INERT_E) = inertE
      work(BOM_RHS_INERT_N) = inertN
      work(BOM_RHS_DRIFT_E) = driftE
      work(BOM_RHS_DRIFT_N) = driftN
      DO iDiag=1,BOM_RHS_NDIAG
        rhsDiag(iDiag) = work(iDiag)
      ENDDO
      failCode = BOM_FAIL_NONE
      rhsValid = .TRUE.

      RETURN
      END
