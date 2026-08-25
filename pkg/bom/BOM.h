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
      CHARACTER*(MAX_LEN_FNAM) bomInitialFile
      COMMON /BOM_PARM_C/
     &       bomMode, bomEquationMode, bomIntegrator,
     &       bomWindSource, bomStokesSource,
     &       bomInitialFile

      _RL bomDeltaTTarget
      _RL bomOutputFreq
      _RL bomPickupFreq
      _RL bomLeewayWindCoeff
      _RL bomWetWeightMin
      _RL bomAdvCFL
      COMMON /BOM_PARM_R/
     &       bomDeltaTTarget, bomOutputFreq, bomPickupFreq,
     &       bomLeewayWindCoeff, bomWetWeightMin, bomAdvCFL

      INTEGER bomSeed
      INTEGER bomMaxParticles
      INTEGER bomMaxHop
      INTEGER bomInitGlobalLimit
      COMMON /BOM_PARM_I/
     &       bomSeed, bomMaxParticles, bomMaxHop,
     &       bomInitGlobalLimit

      LOGICAL bomCheckEverySubstep
      COMMON /BOM_PARM_L/ bomCheckEverySubstep

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
      PARAMETER ( BOM_FAIL_NONE      = 0 )
      PARAMETER ( BOM_FAIL_MAP       = 1 )
      PARAMETER ( BOM_FAIL_OWNER     = 2 )
      PARAMETER ( BOM_FAIL_STENCIL   = 3 )
      PARAMETER ( BOM_FAIL_INTERP    = 4 )
      PARAMETER ( BOM_FAIL_NONFINITE = 5 )
      PARAMETER ( BOM_FAIL_CFL       = 6 )
      PARAMETER ( BOM_FAIL_STATE     = 7 )
      PARAMETER ( BOM_FAIL_RELEASE   = 8 )

C--   Stable Runge--Kutta diagnostic stage values.  FINAL is the
C     accepted-position refresh, not an additional integration stage.
      INTEGER BOM_STAGE_NONE
      INTEGER BOM_STAGE_K1
      INTEGER BOM_STAGE_K2
      INTEGER BOM_STAGE_K3
      INTEGER BOM_STAGE_K4
      INTEGER BOM_STAGE_FINAL
      PARAMETER ( BOM_STAGE_NONE  = 0 )
      PARAMETER ( BOM_STAGE_K1    = 1 )
      PARAMETER ( BOM_STAGE_K2    = 2 )
      PARAMETER ( BOM_STAGE_K3    = 3 )
      PARAMETER ( BOM_STAGE_K4    = 4 )
      PARAMETER ( BOM_STAGE_FINAL = 5 )

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

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
