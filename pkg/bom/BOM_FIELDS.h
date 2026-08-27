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

C--   Stable component identifiers for copied COUPLER Stokes publication.
      INTEGER BOM_COUPLER_EAST
      INTEGER BOM_COUPLER_NORTH
      INTEGER BOM_COUPLER_NCOMP
      PARAMETER ( BOM_COUPLER_EAST  = 1 )
      PARAMETER ( BOM_COUPLER_NORTH = 2 )
      PARAMETER ( BOM_COUPLER_NCOMP = 2 )

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

C--   EXF wind is evaluated in BOM-owned current/record arrays.  The
C     EXF package global current and record arrays are never aliased.
      _RL bomExfWindUWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomExfWindVWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomExfWindEastWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomExfWindNorthWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      COMMON /BOM_EXF_WIND_WORK_R/
     &       bomExfWindUWork, bomExfWindVWork,
     &       bomExfWindEastWork, bomExfWindNorthWork

      _RL bomExfWindU0(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomExfWindU1(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomExfWindV0(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomExfWindV1(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      COMMON /BOM_EXF_WIND_REC_R/
     &       bomExfWindU0, bomExfWindU1,
     &       bomExfWindV0, bomExfWindV1

C--   FILES Stokes is read and interpolated entirely in BOM-owned arrays.
C     Raw U/V records use MITgcm model-grid directions at C points; accepted
C     endpoint values are rotated geographic east/north components.
      _RL bomStokesUWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomStokesVWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomStokesEastWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomStokesNorthWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      COMMON /BOM_STOKES_WORK_R/
     &       bomStokesUWork, bomStokesVWork,
     &       bomStokesEastWork, bomStokesNorthWork

      _RL bomStokesU0(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomStokesU1(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomStokesV0(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomStokesV1(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      COMMON /BOM_STOKES_REC_R/
     &       bomStokesU0, bomStokesU1,
     &       bomStokesV0, bomStokesV1

C--   Compiled COUPLER publication is copied into BOM-owned geographic
C     east/north C-point arrays.  Component readiness and exact labels are
C     separate so that missing and partial external publications are fatal.
      _RL bomCouplerStokesEast(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomCouplerStokesNorth(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      COMMON /BOM_COUPLER_STOKES_R/
     &       bomCouplerStokesEast, bomCouplerStokesNorth

      _RL bomCouplerStokesTime(BOM_COUPLER_NCOMP)
      COMMON /BOM_COUPLER_STOKES_TIME_R/ bomCouplerStokesTime

      INTEGER bomCouplerStokesIter(BOM_COUPLER_NCOMP)
      COMMON /BOM_COUPLER_STOKES_TIME_I/ bomCouplerStokesIter

      LOGICAL bomCouplerStokesReady(BOM_COUPLER_NCOMP)
      COMMON /BOM_COUPLER_STOKES_L/ bomCouplerStokesReady

      _RL bomEnvTimeScratch(BOM_ENV_NEND)
      COMMON /BOM_ENV_SCRATCH_TIME_R/ bomEnvTimeScratch

      INTEGER bomEnvIterScratch(BOM_ENV_NEND)
      COMMON /BOM_ENV_SCRATCH_TIME_I/ bomEnvIterScratch

      LOGICAL bomEnvValidScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      COMMON /BOM_ENV_SCRATCH_L/ bomEnvValidScratch
