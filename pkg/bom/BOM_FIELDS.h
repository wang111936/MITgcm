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
