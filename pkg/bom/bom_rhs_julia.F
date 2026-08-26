#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_RHS_JULIA
C !INTERFACE:
      SUBROUTINE BOM_RHS_JULIA(
     I                 alpha, tauValue, rValue, sigma,
     I                 fCori, tauSphere,
     I                 sourceEast, sourceNorth,
     I                 sourceDtEast, sourceDtNorth,
     I                 gradEastEast, gradNorthEast,
     I                 gradEastNorth, gradNorthNorth,
     O                 rhsDiag, failCode, rhsValid )

C !DESCRIPTION:
C     Locked Julia compatibility algebra.  Per-source self derivatives are
C     formed before weighting and vorticity is base-current only.  This is a
C     deliberately separate path from PAPER2024 and is never the default.

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
      _RL rhsDiag(BOM_RHS_NDIAG), workDiag(BOM_RHS_NDIAG)
      _RL vEast, vNorth, uEast, uNorth
      _RL dSelfE(BOM_ENV_NSOURCE), dSelfN(BOM_ENV_NSOURCE)
      _RL sourceVort(BOM_ENV_NSOURCE)
      _RL dvEast, dvNorth, duEast, duNorth, omega
      INTEGER failCode, localFail, iDiag, iSource
      LOGICAL rhsValid, valid1, covValid
CEOP

      DO iDiag=1,BOM_RHS_NDIAG
        rhsDiag(iDiag) = 0. _d 0
        workDiag(iDiag) = 0. _d 0
      ENDDO
      failCode = BOM_FAIL_EQUATION
      rhsValid = .FALSE.

C--   Preserve the locked per-source evaluation order.
      DO iSource=1,BOM_ENV_NSOURCE
        CALL BOM_EVAL_COVARIANT(
     I       sourceEast(iSource), sourceNorth(iSource),
     I       sourceDtEast(iSource), sourceDtNorth(iSource),
     I       gradEastEast(iSource), gradNorthEast(iSource),
     I       gradEastNorth(iSource), gradNorthNorth(iSource),
     I       tauSphere,
     O       dSelfE(iSource), dSelfN(iSource), sourceVort(iSource),
     O       localFail, covValid )
        IF ( .NOT.covValid ) RETURN
      ENDDO

      CALL BOM_RHS_COMBINE(sourceEast(BOM_ENV_EULERIAN),sigma,
     &     sourceEast(BOM_ENV_STOKES),vEast,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_COMBINE(sourceNorth(BOM_ENV_EULERIAN),sigma,
     &     sourceNorth(BOM_ENV_STOKES),vNorth,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_COMBINE(dSelfE(BOM_ENV_EULERIAN),sigma,
     &     dSelfE(BOM_ENV_STOKES),dvEast,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_COMBINE(dSelfN(BOM_ENV_EULERIAN),sigma,
     &     dSelfN(BOM_ENV_STOKES),dvNorth,valid1)
      IF ( .NOT.valid1 ) RETURN

      CALL BOM_RHS_BLEND(vEast,sourceEast(BOM_ENV_WIND),alpha,
     &                   uEast,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_BLEND(vNorth,sourceNorth(BOM_ENV_WIND),alpha,
     &                   uNorth,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_BLEND(dvEast,dSelfE(BOM_ENV_WIND),alpha,
     &                   duEast,valid1)
      IF ( .NOT.valid1 ) RETURN
      CALL BOM_RHS_BLEND(dvNorth,dSelfN(BOM_ENV_WIND),alpha,
     &                   duNorth,valid1)
      IF ( .NOT.valid1 ) RETURN
      omega = sourceVort(BOM_ENV_EULERIAN)

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
