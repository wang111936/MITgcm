CBOP
C     !ROUTINE: BOM.h
C     !INTERFACE:
C     #include "BOM.h"

C     !DESCRIPTION:
C     Runtime controls, compact P1.4 owner state, and surface grid fields.
CEOP

      CHARACTER*8  bomMode
      CHARACTER*12 bomEquationMode
      CHARACTER*8  bomIntegrator
      CHARACTER*8  bomWindSource
      CHARACTER*8  bomStokesSource
      CHARACTER*12 bomCurrentPolicy
      CHARACTER*(MAX_LEN_FNAM) bomInitialFile
      CHARACTER*(MAX_LEN_FNAM) bomUStokesFile
      CHARACTER*(MAX_LEN_FNAM) bomVStokesFile
      COMMON /BOM_PARM_C/
     &       bomMode, bomEquationMode, bomIntegrator,
     &       bomWindSource, bomStokesSource,
     &       bomCurrentPolicy, bomInitialFile,
     &       bomUStokesFile, bomVStokesFile

      _RL bomDeltaTTarget
      _RL bomOutputFreq
      _RL bomPickupFreq
      _RL bomLeewayWindCoeff
      _RL bomWetWeightMin
      _RL bomAdvCFL
      _RL bomAlpha
      _RL bomTauDays
      _RL bomTau
      _RL bomR
      _RL bomSigma
      _RL bomStokesStartTime
      _RL bomStokesPeriod
      _RL bomStokesRepCycle
      _RL bomStokesInScale
      COMMON /BOM_PARM_R/
     &       bomDeltaTTarget, bomOutputFreq, bomPickupFreq,
     &       bomLeewayWindCoeff, bomWetWeightMin, bomAdvCFL,
     &       bomAlpha, bomTauDays, bomTau, bomR, bomSigma,
     &       bomStokesStartTime, bomStokesPeriod,
     &       bomStokesRepCycle, bomStokesInScale

      INTEGER bomSeed
      INTEGER bomMaxParticles
      INTEGER bomMaxHop
      INTEGER bomInitGlobalLimit
      INTEGER bomInitialIter
      INTEGER bomStokesFilePrec
      COMMON /BOM_PARM_I/
     &       bomSeed, bomMaxParticles, bomMaxHop,
     &       bomInitGlobalLimit, bomInitialIter,
     &       bomStokesFilePrec

      LOGICAL bomCheckEverySubstep
      COMMON /BOM_PARM_L/ bomCheckEverySubstep

C--   P1.5 trajectory schedule.  The next time is advanced only after a
C     complete post-migration output event.
      _RL bomNextOutputTime
      COMMON /BOM_OUTPUT_R/ bomNextOutputTime

      LOGICAL bomOutputScheduleReady
      COMMON /BOM_OUTPUT_L/ bomOutputScheduleReady

C--   Stable status values.  Biology and beaching are reserved until
C     Phase 4, but their numeric codes must not be reused.
      INTEGER BOM_UNUSED
      INTEGER BOM_ALIVE
      INTEGER BOM_DEAD_BIO
      INTEGER BOM_BEACHED
      INTEGER BOM_OUTSIDE
      INTEGER BOM_INVALID
      INTEGER BOM_WAITING
      PARAMETER ( BOM_UNUSED   = 0 )
      PARAMETER ( BOM_ALIVE    = 1 )
      PARAMETER ( BOM_DEAD_BIO = 2 )
      PARAMETER ( BOM_BEACHED  = 3 )
      PARAMETER ( BOM_OUTSIDE  = 4 )
      PARAMETER ( BOM_INVALID  = 5 )
      PARAMETER ( BOM_WAITING  = 6 )

C--   Stable failure values for the Phase-1 particle kernels.  The first
C     failure in one trial is retained; numeric codes must not be reused.
      INTEGER BOM_FAIL_NONE
      INTEGER BOM_FAIL_MAP
      INTEGER BOM_FAIL_OWNER
      INTEGER BOM_FAIL_STENCIL
      INTEGER BOM_FAIL_INTERP
      INTEGER BOM_FAIL_NONFINITE
      INTEGER BOM_FAIL_CFL
      INTEGER BOM_FAIL_STATE
      INTEGER BOM_FAIL_RELEASE
      INTEGER BOM_FAIL_FIELD_TIME
      INTEGER BOM_FAIL_FIELD_SOURCE
      INTEGER BOM_FAIL_METRIC
      INTEGER BOM_FAIL_GRADIENT
      INTEGER BOM_FAIL_EQUATION
      INTEGER BOM_FAIL_STOKES_DUPLICATE
      INTEGER BOM_FAIL_PICKUP_SCHEMA
      PARAMETER ( BOM_FAIL_NONE      = 0 )
      PARAMETER ( BOM_FAIL_MAP       = 1 )
      PARAMETER ( BOM_FAIL_OWNER     = 2 )
      PARAMETER ( BOM_FAIL_STENCIL   = 3 )
      PARAMETER ( BOM_FAIL_INTERP    = 4 )
      PARAMETER ( BOM_FAIL_NONFINITE = 5 )
      PARAMETER ( BOM_FAIL_CFL       = 6 )
      PARAMETER ( BOM_FAIL_STATE     = 7 )
      PARAMETER ( BOM_FAIL_RELEASE   = 8 )
      PARAMETER ( BOM_FAIL_FIELD_TIME       = 9 )
      PARAMETER ( BOM_FAIL_FIELD_SOURCE     = 10 )
      PARAMETER ( BOM_FAIL_METRIC           = 11 )
      PARAMETER ( BOM_FAIL_GRADIENT         = 12 )
      PARAMETER ( BOM_FAIL_EQUATION         = 13 )
      PARAMETER ( BOM_FAIL_STOKES_DUPLICATE = 14 )
      PARAMETER ( BOM_FAIL_PICKUP_SCHEMA    = 15 )

C--   Stable Runge--Kutta diagnostic stage values.  FINAL is the
C     accepted-position refresh, not an additional integration stage.
      INTEGER BOM_STAGE_NONE
      INTEGER BOM_STAGE_K1
      INTEGER BOM_STAGE_K2
      INTEGER BOM_STAGE_K3
      INTEGER BOM_STAGE_K4
      INTEGER BOM_STAGE_FINAL
      INTEGER BOM_STAGE_FIELD_OLD
      INTEGER BOM_STAGE_FIELD_NEW
      INTEGER BOM_STAGE_DERIVATIVE
      PARAMETER ( BOM_STAGE_NONE  = 0 )
      PARAMETER ( BOM_STAGE_K1    = 1 )
      PARAMETER ( BOM_STAGE_K2    = 2 )
      PARAMETER ( BOM_STAGE_K3    = 3 )
      PARAMETER ( BOM_STAGE_K4    = 4 )
      PARAMETER ( BOM_STAGE_FINAL = 5 )
      PARAMETER ( BOM_STAGE_FIELD_OLD  = 6 )
      PARAMETER ( BOM_STAGE_FIELD_NEW  = 7 )
      PARAMETER ( BOM_STAGE_DERIVATIVE = 8 )

C--   Stable stateless Phase-2 RHS diagnostic-vector indices.  Every entry
C     is an SI physical component; native coordinate-rate conversion remains
C     in the particle-stage wrapper introduced in P2.4.
      INTEGER BOM_RHS_VBASE_E
      INTEGER BOM_RHS_VBASE_N
      INTEGER BOM_RHS_VS_E
      INTEGER BOM_RHS_VS_N
      INTEGER BOM_RHS_VW_E
      INTEGER BOM_RHS_VW_N
      INTEGER BOM_RHS_V_E
      INTEGER BOM_RHS_V_N
      INTEGER BOM_RHS_U_E
      INTEGER BOM_RHS_U_N
      INTEGER BOM_RHS_DV_E
      INTEGER BOM_RHS_DV_N
      INTEGER BOM_RHS_DU_E
      INTEGER BOM_RHS_DU_N
      INTEGER BOM_RHS_OMEGA
      INTEGER BOM_RHS_FCORI
      INTEGER BOM_RHS_TAUSPHERE
      INTEGER BOM_RHS_CV
      INTEGER BOM_RHS_CU
      INTEGER BOM_RHS_ROT_VE
      INTEGER BOM_RHS_ROT_VN
      INTEGER BOM_RHS_ROT_UE
      INTEGER BOM_RHS_ROT_UN
      INTEGER BOM_RHS_INERT_E
      INTEGER BOM_RHS_INERT_N
      INTEGER BOM_RHS_DRIFT_E
      INTEGER BOM_RHS_DRIFT_N
      INTEGER BOM_RHS_NDIAG
      PARAMETER ( BOM_RHS_VBASE_E  =  1 )
      PARAMETER ( BOM_RHS_VBASE_N  =  2 )
      PARAMETER ( BOM_RHS_VS_E     =  3 )
      PARAMETER ( BOM_RHS_VS_N     =  4 )
      PARAMETER ( BOM_RHS_VW_E     =  5 )
      PARAMETER ( BOM_RHS_VW_N     =  6 )
      PARAMETER ( BOM_RHS_V_E      =  7 )
      PARAMETER ( BOM_RHS_V_N      =  8 )
      PARAMETER ( BOM_RHS_U_E      =  9 )
      PARAMETER ( BOM_RHS_U_N      = 10 )
      PARAMETER ( BOM_RHS_DV_E     = 11 )
      PARAMETER ( BOM_RHS_DV_N     = 12 )
      PARAMETER ( BOM_RHS_DU_E     = 13 )
      PARAMETER ( BOM_RHS_DU_N     = 14 )
      PARAMETER ( BOM_RHS_OMEGA    = 15 )
      PARAMETER ( BOM_RHS_FCORI    = 16 )
      PARAMETER ( BOM_RHS_TAUSPHERE= 17 )
      PARAMETER ( BOM_RHS_CV       = 18 )
      PARAMETER ( BOM_RHS_CU       = 19 )
      PARAMETER ( BOM_RHS_ROT_VE   = 20 )
      PARAMETER ( BOM_RHS_ROT_VN   = 21 )
      PARAMETER ( BOM_RHS_ROT_UE   = 22 )
      PARAMETER ( BOM_RHS_ROT_UN   = 23 )
      PARAMETER ( BOM_RHS_INERT_E  = 24 )
      PARAMETER ( BOM_RHS_INERT_N  = 25 )
      PARAMETER ( BOM_RHS_DRIFT_E  = 26 )
      PARAMETER ( BOM_RHS_DRIFT_N  = 27 )
      PARAMETER ( BOM_RHS_NDIAG    = 27 )

C--   Valid owner records occupy slots 1:bomNPartTile on each tile.
C     bomNPartExpected is the immutable successful initial owner budget.
      INTEGER bomNPartTile(nSx,nSy)
      INTEGER bomStatus(bomMaxPartTile,nSx,nSy)
      INTEGER bomNPartExpected
      COMMON /BOM_STATE_I/
     &       bomNPartTile, bomStatus, bomNPartExpected

      INTEGER*8 bomId(bomMaxPartTile,nSx,nSy)
      COMMON /BOM_STATE_I8/ bomId

      _RL bomX(bomMaxPartTile,nSx,nSy)
      _RL bomY(bomMaxPartTile,nSx,nSy)
      _RL bomReleaseTime(bomMaxPartTile,nSx,nSy)
      _RL bomAge(bomMaxPartTile,nSx,nSy)
      _RL bomI(bomMaxPartTile,nSx,nSy)
      _RL bomJ(bomMaxPartTile,nSx,nSy)
      _RL bomVEast(bomMaxPartTile,nSx,nSy)
      _RL bomVNorth(bomMaxPartTile,nSx,nSy)
      _RL bomWindEast(bomMaxPartTile,nSx,nSy)
      _RL bomWindNorth(bomMaxPartTile,nSx,nSy)
      _RL bomDriftEast(bomMaxPartTile,nSx,nSy)
      _RL bomDriftNorth(bomMaxPartTile,nSx,nSy)
      COMMON /BOM_STATE_R/
     &       bomX, bomY, bomReleaseTime, bomAge, bomI, bomJ,
     &       bomVEast, bomVNorth, bomWindEast, bomWindNorth,
     &       bomDriftEast, bomDriftNorth

C--   Static regular-grid mapping and surface-field publication state.
      _RL bomMapXLo
      _RL bomMapXHi
      _RL bomMapYLo
      _RL bomMapYHi
      _RL bomMapXPeriod
      _RL bomMapTol
      _RL bomFieldTime
      _RL bomWindFieldTime
      _RL bomMapXFace(0:Nx)
      _RL bomMapYFace(0:Ny)
      COMMON /BOM_MAP_R/
     &       bomMapXLo, bomMapXHi, bomMapYLo, bomMapYHi,
     &       bomMapXPeriod, bomMapTol,
     &       bomFieldTime, bomWindFieldTime,
     &       bomMapXFace, bomMapYFace

      INTEGER bomFieldIter
      INTEGER bomWindFieldIter
      COMMON /BOM_MAP_I/ bomFieldIter, bomWindFieldIter

      LOGICAL bomMapPeriodicX
      LOGICAL bomFieldsReady
      COMMON /BOM_MAP_L/ bomMapPeriodicX, bomFieldsReady

C--   Single-level C-grid work arrays and geographic C-point fields.
      _RL bomGridUWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomGridVWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomGridVEast(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomGridVNorth(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomGridWindEast(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomGridWindNorth(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      COMMON /BOM_FIELD_R/
     &       bomGridUWork, bomGridVWork,
     &       bomGridVEast, bomGridVNorth,
     &       bomGridWindEast, bomGridWindNorth

#include "BOM_FIELDS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
