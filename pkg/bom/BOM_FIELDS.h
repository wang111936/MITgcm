CBOP
C     !ROUTINE: BOM_FIELDS.h
C     !INTERFACE:
C     #include "BOM_FIELDS.h"

C     !DESCRIPTION:
C     Phase-2 accepted environmental endpoint state.  Providers build
C     scratch values and publish these COMMON blocks only after validation.
CEOP

C--   Stable source and endpoint codes.  Numeric values are part of the
C     trajectory/pickup contract and must not be reused.
      INTEGER BOM_ENV_EULERIAN
      INTEGER BOM_ENV_STOKES
      INTEGER BOM_ENV_WIND
      INTEGER BOM_ENV_NSOURCE
      INTEGER BOM_ENV_OLD
      INTEGER BOM_ENV_NEW
      INTEGER BOM_ENV_NEND
      PARAMETER ( BOM_ENV_EULERIAN = 1 )
      PARAMETER ( BOM_ENV_STOKES   = 2 )
      PARAMETER ( BOM_ENV_WIND     = 3 )
      PARAMETER ( BOM_ENV_NSOURCE  = 3 )
      PARAMETER ( BOM_ENV_OLD      = 1 )
      PARAMETER ( BOM_ENV_NEW      = 2 )
      PARAMETER ( BOM_ENV_NEND     = 2 )

      _RL bomEnvEast(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL bomEnvNorth(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      COMMON /BOM_ENV_FIELD_R/
     &       bomEnvEast, bomEnvNorth

      _RL bomEnvTime(BOM_ENV_NEND)
      COMMON /BOM_ENV_TIME_R/ bomEnvTime

      INTEGER bomEnvIter(BOM_ENV_NEND)
      COMMON /BOM_ENV_TIME_I/ bomEnvIter

      LOGICAL bomEnvValid(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      COMMON /BOM_ENV_FIELD_L/ bomEnvValid

      LOGICAL bomEnvReady
      COMMON /BOM_ENV_STATE_L/ bomEnvReady

C--   Internal transaction workspace.  These arrays are never accepted
C     state and are not part of the pickup interface.
      _RL bomEnvEastScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL bomEnvNorthScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      COMMON /BOM_ENV_SCRATCH_R/
     &       bomEnvEastScratch, bomEnvNorthScratch

      _RL bomEnvUWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomEnvVWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomEnvEastWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomEnvNorthWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      COMMON /BOM_ENV_WORK_R/
     &       bomEnvUWork, bomEnvVWork,
     &       bomEnvEastWork, bomEnvNorthWork

      _RL bomEnvTimeScratch(BOM_ENV_NEND)
      COMMON /BOM_ENV_SCRATCH_TIME_R/ bomEnvTimeScratch

      INTEGER bomEnvIterScratch(BOM_ENV_NEND)
      COMMON /BOM_ENV_SCRATCH_TIME_I/ bomEnvIterScratch

      LOGICAL bomEnvValidScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      COMMON /BOM_ENV_SCRATCH_L/ bomEnvValidScratch
