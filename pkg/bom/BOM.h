CBOP
C     !ROUTINE: BOM.h
C     !INTERFACE:
C     #include "BOM.h"

C     !DESCRIPTION:
C     Runtime controls for the MITGCM-BOM package skeleton.  Particle
C     state is intentionally absent until its ownership is tested.
CEOP

      CHARACTER*8  bomMode
      CHARACTER*12 bomEquationMode
      CHARACTER*8  bomIntegrator
      CHARACTER*(MAX_LEN_FNAM) bomInitialFile
      COMMON /BOM_PARM_C/
     &       bomMode, bomEquationMode, bomIntegrator,
     &       bomInitialFile

      _RL bomDeltaTTarget
      _RL bomOutputFreq
      _RL bomPickupFreq
      COMMON /BOM_PARM_R/
     &       bomDeltaTTarget, bomOutputFreq, bomPickupFreq

      INTEGER bomSeed
      INTEGER bomMaxParticles
      COMMON /BOM_PARM_I/ bomSeed, bomMaxParticles

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
