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

C--   Stable P4.1 scalar-source codes.  Temperature and nutrient codes are
C     separate namespaces and are persisted with each accepted endpoint.
      INTEGER BOM_BIO_TEMP_NONE
      INTEGER BOM_BIO_TEMP_THETA
      INTEGER BOM_BIO_N_NONE
      INTEGER BOM_BIO_N_PTRACER
      INTEGER BOM_BIO_N_FILES
      PARAMETER ( BOM_BIO_TEMP_NONE  = 0 )
      PARAMETER ( BOM_BIO_TEMP_THETA = 1 )
      PARAMETER ( BOM_BIO_N_NONE     = 0 )
      PARAMETER ( BOM_BIO_N_PTRACER  = 1 )
      PARAMETER ( BOM_BIO_N_FILES    = 2 )

C--   Accepted surface temperature/nutrient bracket.  One shared validity
C     flag proves that both scalars are present at a wet C point.
      _RL bomBioTemp(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,nSx,nSy)
      _RL bomBioN(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,nSx,nSy)
      COMMON /BOM_BIO_FIELD_R/ bomBioTemp, bomBioN

      _RL bomBioTime(BOM_ENV_NEND)
      COMMON /BOM_BIO_TIME_R/ bomBioTime

      INTEGER bomBioIter(BOM_ENV_NEND)
      INTEGER bomBioTempSource(BOM_ENV_NEND)
      INTEGER bomBioNSource(BOM_ENV_NEND)
      COMMON /BOM_BIO_TIME_I/
     &       bomBioIter, bomBioTempSource, bomBioNSource

      LOGICAL bomBioValid(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,nSx,nSy)
      LOGICAL bomBioReady
      COMMON /BOM_BIO_FIELD_L/ bomBioValid
      COMMON /BOM_BIO_STATE_L/ bomBioReady

C--   P4.1 transaction scratch and BOM-owned one-level provider storage.
      _RL bomBioTempScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,nSx,nSy)
      _RL bomBioNScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,nSx,nSy)
      COMMON /BOM_BIO_SCRATCH_R/
     &       bomBioTempScratch, bomBioNScratch

      _RL bomBioTimeScratch(BOM_ENV_NEND)
      COMMON /BOM_BIO_SCRATCH_TIME_R/ bomBioTimeScratch

      INTEGER bomBioIterScratch(BOM_ENV_NEND)
      INTEGER bomBioTempSourceScratch(BOM_ENV_NEND)
      INTEGER bomBioNSourceScratch(BOM_ENV_NEND)
      COMMON /BOM_BIO_SCRATCH_TIME_I/
     &       bomBioIterScratch, bomBioTempSourceScratch,
     &       bomBioNSourceScratch

      LOGICAL bomBioValidScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,nSx,nSy)
      COMMON /BOM_BIO_SCRATCH_L/ bomBioValidScratch

      _RL bomBioTempWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomBioNWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomBioN0(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL bomBioN1(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      COMMON /BOM_BIO_WORK_R/
     &       bomBioTempWork, bomBioNWork, bomBioN0, bomBioN1

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

C--   Accepted endpoint gradients of geographic C-point components.
C     The first direction in each name is the physical derivative
C     direction; the second is the differentiated vector component.
      _RL bomGradEastEast(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL bomGradNorthEast(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL bomGradEastNorth(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL bomGradNorthNorth(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      COMMON /BOM_GRAD_FIELD_R/
     &       bomGradEastEast, bomGradNorthEast,
     &       bomGradEastNorth, bomGradNorthNorth

      LOGICAL bomGradValid(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      COMMON /BOM_GRAD_FIELD_L/ bomGradValid

      LOGICAL bomGradReady
      COMMON /BOM_GRAD_STATE_L/ bomGradReady

C--   Accepted time-invariant C-point metric state.  tauSphere is zero on
C     Cartesian grids and tan(latitude)/rSphere on supported spherical grids.
C     fCori is copied from the MITgcm C-point grid field without redefinition.
      _RL bomTauSphere(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL bomFCori(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      COMMON /BOM_METRIC_FIELD_R/ bomTauSphere, bomFCori

      LOGICAL bomMetricValid(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      COMMON /BOM_METRIC_FIELD_L/ bomMetricValid

      LOGICAL bomMetricReady
      COMMON /BOM_METRIC_STATE_L/ bomMetricReady

C--   Metric transaction workspace.  A numeric validity mask is exchanged
C     with the two scalar fields and decoded only after global validation.
      _RL bomTauSphereScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL bomFCoriScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL bomMetricValidWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      COMMON /BOM_METRIC_SCRATCH_R/
     &       bomTauSphereScratch, bomFCoriScratch,
     &       bomMetricValidWork

      LOGICAL bomMetricValidScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      COMMON /BOM_METRIC_SCRATCH_L/ bomMetricValidScratch

C--   Derivative transaction workspace.  Four gradient arrays and one
C     numeric validity exchange are published only after global success.
      _RL bomGradEastEastScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL bomGradNorthEastScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL bomGradEastNorthScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL bomGradNorthNorthScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL bomGradValidWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL bomGradExchangeWork(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      COMMON /BOM_GRAD_SCRATCH_R/
     &       bomGradEastEastScratch, bomGradNorthEastScratch,
     &       bomGradEastNorthScratch, bomGradNorthNorthScratch,
     &       bomGradValidWork
      COMMON /BOM_GRAD_EXCHANGE_R/ bomGradExchangeWork

      LOGICAL bomGradValidScratch(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      COMMON /BOM_GRAD_SCRATCH_L/ bomGradValidScratch

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
