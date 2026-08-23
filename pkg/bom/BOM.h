CBOP
C     !ROUTINE: BOM.h
C     !INTERFACE:
C     #include "BOM.h"

C     !DESCRIPTION:
C     Runtime controls and Phase-1.1 compact owner state for pkg/bom.
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

C--   Valid owner records occupy slots 1:bomNPartTile on each tile.
      INTEGER bomNPartTile(nSx,nSy)
      INTEGER bomStatus(bomMaxPartTile,nSx,nSy)
      COMMON /BOM_STATE_I/ bomNPartTile, bomStatus

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

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
