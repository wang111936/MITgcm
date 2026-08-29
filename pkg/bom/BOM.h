CBOP
C     !ROUTINE: BOM.h
C     !INTERFACE:
C     #include "BOM.h"

C     !DESCRIPTION:
C     Runtime controls, compact owner state, and environmental grid fields.
CEOP

      CHARACTER*8  bomMode
      CHARACTER*12 bomEquationMode
      CHARACTER*8  bomIntegrator
      CHARACTER*8  bomWindSource
      CHARACTER*8  bomStokesSource
      CHARACTER*12 bomCurrentPolicy
      CHARACTER*8  bomSpringLaw
      CHARACTER*8  bomNeighborPolicy
      CHARACTER*8  bomTempSource
      CHARACTER*8  bomNSource
      CHARACTER*12 bomBiologyMissingPolicy
      CHARACTER*(MAX_LEN_FNAM) bomInitialFile
      CHARACTER*(MAX_LEN_FNAM) bomUStokesFile
      CHARACTER*(MAX_LEN_FNAM) bomVStokesFile
      CHARACTER*(MAX_LEN_FNAM) bomNFile
      CHARACTER*(MAX_LEN_FNAM) bomEventFile
      COMMON /BOM_PARM_C/
     &       bomMode, bomEquationMode, bomIntegrator,
     &       bomWindSource, bomStokesSource,
     &       bomCurrentPolicy, bomSpringLaw,
     &       bomNeighborPolicy, bomTempSource, bomNSource,
     &       bomBiologyMissingPolicy, bomInitialFile,
     &       bomUStokesFile, bomVStokesFile,
     &       bomNFile, bomEventFile

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
      _RL bomSpringL
      _RL bomHookeK
      _RL bomSpringA
      _RL bomSpringDelta
      _RL bomNeighborCutoff
      _RL bomPairDistanceMin
      _RL bomSpringCFL
      _RL bomMuMaxDay
      _RL bomMortDay
      _RL bomMuMax
      _RL bomMort
      _RL bomKN
      _RL bomTMin
      _RL bomTMax
      _RL bomS0
      _RL bomSMin
      _RL bomSMax
      _RL bomNStartTime
      _RL bomNPeriod
      _RL bomNRepCycle
      _RL bomNInScale
      COMMON /BOM_PARM_R/
     &       bomDeltaTTarget, bomOutputFreq, bomPickupFreq,
     &       bomLeewayWindCoeff, bomWetWeightMin, bomAdvCFL,
     &       bomAlpha, bomTauDays, bomTau, bomR, bomSigma,
     &       bomStokesStartTime, bomStokesPeriod,
     &       bomStokesRepCycle, bomStokesInScale,
     &       bomSpringL, bomHookeK, bomSpringA,
     &       bomSpringDelta, bomNeighborCutoff,
     &       bomPairDistanceMin, bomSpringCFL,
     &       bomMuMaxDay, bomMortDay, bomMuMax, bomMort,
     &       bomKN, bomTMin, bomTMax,
     &       bomS0, bomSMin, bomSMax,
     &       bomNStartTime, bomNPeriod,
     &       bomNRepCycle, bomNInScale

      INTEGER bomSeed
      INTEGER bomMaxParticles
      INTEGER bomMaxHop
      INTEGER bomInitGlobalLimit
      INTEGER bomInitialIter
      INTEGER bomStokesFilePrec
      INTEGER bomBirthMaxTry
      INTEGER bomNTracerIndex
      INTEGER bomNFilePrec
      COMMON /BOM_PARM_I/
     &       bomSeed, bomMaxParticles, bomMaxHop,
     &       bomInitGlobalLimit, bomInitialIter,
     &       bomStokesFilePrec, bomBirthMaxTry,
     &       bomNTracerIndex, bomNFilePrec

      LOGICAL bomCheckEverySubstep
      LOGICAL bomRaftDiagnostics
      LOGICAL bomUseBiology
      LOGICAL bomUseLand
      COMMON /BOM_PARM_L/
     &       bomCheckEverySubstep, bomRaftDiagnostics,
     &       bomUseBiology, bomUseLand

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
      INTEGER BOM_FAIL_NEIGHBOR_CONFIG
      INTEGER BOM_FAIL_PAIR_GEOMETRY
      INTEGER BOM_FAIL_CELL_CAPACITY
      INTEGER BOM_FAIL_GHOST_CAPACITY
      INTEGER BOM_FAIL_NEIGHBOR_CAPACITY
      INTEGER BOM_FAIL_GHOST_PACKET
      INTEGER BOM_FAIL_SPRING_LAW
      INTEGER BOM_FAIL_SPRING_CFL
      INTEGER BOM_FAIL_COMPONENT
      INTEGER BOM_FAIL_PICKUP_SCHEMA3
      INTEGER BOM_FAIL_BIOLOGY_CONFIG
      INTEGER BOM_FAIL_BIOLOGY_FIELD
      INTEGER BOM_FAIL_BROOKS
      INTEGER BOM_FAIL_BOUNDARY_EVENT
      INTEGER BOM_FAIL_EVENT_CAPACITY
      INTEGER BOM_FAIL_EVENT_TRANSACTION
      INTEGER BOM_FAIL_BIRTH_CAPACITY
      INTEGER BOM_FAIL_BIRTH_RNG
      INTEGER BOM_FAIL_BIRTH_ID
      INTEGER BOM_FAIL_PICKUP_SCHEMA4
      INTEGER BOM_FAIL_EVENT_IO
      INTEGER BOM_FAIL_EVENT_BUDGET
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
      PARAMETER ( BOM_FAIL_NEIGHBOR_CONFIG  = 16 )
      PARAMETER ( BOM_FAIL_PAIR_GEOMETRY    = 17 )
      PARAMETER ( BOM_FAIL_CELL_CAPACITY    = 18 )
      PARAMETER ( BOM_FAIL_GHOST_CAPACITY   = 19 )
      PARAMETER ( BOM_FAIL_NEIGHBOR_CAPACITY= 20 )
      PARAMETER ( BOM_FAIL_GHOST_PACKET     = 21 )
      PARAMETER ( BOM_FAIL_SPRING_LAW       = 22 )
      PARAMETER ( BOM_FAIL_SPRING_CFL       = 23 )
      PARAMETER ( BOM_FAIL_COMPONENT        = 24 )
      PARAMETER ( BOM_FAIL_PICKUP_SCHEMA3   = 25 )
      PARAMETER ( BOM_FAIL_BIOLOGY_CONFIG   = 26 )
      PARAMETER ( BOM_FAIL_BIOLOGY_FIELD    = 27 )
      PARAMETER ( BOM_FAIL_BROOKS           = 28 )
      PARAMETER ( BOM_FAIL_BOUNDARY_EVENT   = 29 )
      PARAMETER ( BOM_FAIL_EVENT_CAPACITY   = 30 )
      PARAMETER ( BOM_FAIL_EVENT_TRANSACTION= 31 )
      PARAMETER ( BOM_FAIL_BIRTH_CAPACITY   = 32 )
      PARAMETER ( BOM_FAIL_BIRTH_RNG        = 33 )
      PARAMETER ( BOM_FAIL_BIRTH_ID         = 34 )
      PARAMETER ( BOM_FAIL_PICKUP_SCHEMA4   = 35 )
      PARAMETER ( BOM_FAIL_EVENT_IO         = 36 )
      PARAMETER ( BOM_FAIL_EVENT_BUDGET     = 37 )

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

C--   Stable Phase-3 operation-phase values.  These refine failStage without
C     changing the accepted Runge--Kutta stage numbering above.
      INTEGER BOM_P3_PHASE_NONE
      INTEGER BOM_P3_PHASE_POSITION
      INTEGER BOM_P3_PHASE_GHOST
      INTEGER BOM_P3_PHASE_CELL
      INTEGER BOM_P3_PHASE_NEIGHBOR
      INTEGER BOM_P3_PHASE_SPRING
      INTEGER BOM_P3_PHASE_BASE_RHS
      INTEGER BOM_P3_PHASE_NATIVE_RATE
      INTEGER BOM_P3_PHASE_COMPONENT
      INTEGER BOM_P3_PHASE_SCHEMA3
      PARAMETER ( BOM_P3_PHASE_NONE        = 0 )
      PARAMETER ( BOM_P3_PHASE_POSITION    = 1 )
      PARAMETER ( BOM_P3_PHASE_GHOST       = 2 )
      PARAMETER ( BOM_P3_PHASE_CELL        = 3 )
      PARAMETER ( BOM_P3_PHASE_NEIGHBOR    = 4 )
      PARAMETER ( BOM_P3_PHASE_SPRING      = 5 )
      PARAMETER ( BOM_P3_PHASE_BASE_RHS    = 6 )
      PARAMETER ( BOM_P3_PHASE_NATIVE_RATE = 7 )
      PARAMETER ( BOM_P3_PHASE_COMPONENT   = 8 )
      PARAMETER ( BOM_P3_PHASE_SCHEMA3     = 9 )

C--   Stable Phase-4 event and operation-phase values.  P4.1 produces
C     immutable event plans only; later work packages own their commit.
      INTEGER BOM_EVENT_NONE
      INTEGER BOM_EVENT_BIRTH
      INTEGER BOM_EVENT_DEAD_BIO
      INTEGER BOM_EVENT_BEACHED
      INTEGER BOM_EVENT_OUTSIDE
      INTEGER BOM_EVENT_BIRTH_CANCEL
      PARAMETER ( BOM_EVENT_NONE         = 0 )
      PARAMETER ( BOM_EVENT_BIRTH        = 1 )
      PARAMETER ( BOM_EVENT_DEAD_BIO     = 2 )
      PARAMETER ( BOM_EVENT_BEACHED      = 3 )
      PARAMETER ( BOM_EVENT_OUTSIDE      = 4 )
      PARAMETER ( BOM_EVENT_BIRTH_CANCEL = 5 )

      INTEGER BOM_P4_PHASE_NONE
      INTEGER BOM_P4_PHASE_ENDPOINT
      INTEGER BOM_P4_PHASE_BOUNDARY
      INTEGER BOM_P4_PHASE_BIOLOGY
      INTEGER BOM_P4_PHASE_TERMINAL
      INTEGER BOM_P4_PHASE_BIRTH_ORDER
      INTEGER BOM_P4_PHASE_BIRTH_PLACE
      INTEGER BOM_P4_PHASE_CAPACITY
      INTEGER BOM_P4_PHASE_GRAPH
      INTEGER BOM_P4_PHASE_SCHEMA4
      INTEGER BOM_P4_PHASE_EVENT_IO
      INTEGER BOM_P4_PHASE_BUDGET
      PARAMETER ( BOM_P4_PHASE_NONE        = 0 )
      PARAMETER ( BOM_P4_PHASE_ENDPOINT    = 1 )
      PARAMETER ( BOM_P4_PHASE_BOUNDARY    = 2 )
      PARAMETER ( BOM_P4_PHASE_BIOLOGY     = 3 )
      PARAMETER ( BOM_P4_PHASE_TERMINAL    = 4 )
      PARAMETER ( BOM_P4_PHASE_BIRTH_ORDER = 5 )
      PARAMETER ( BOM_P4_PHASE_BIRTH_PLACE = 6 )
      PARAMETER ( BOM_P4_PHASE_CAPACITY    = 7 )
      PARAMETER ( BOM_P4_PHASE_GRAPH       = 8 )
      PARAMETER ( BOM_P4_PHASE_SCHEMA4     = 9 )
      PARAMETER ( BOM_P4_PHASE_EVENT_IO    = 10 )
      PARAMETER ( BOM_P4_PHASE_BUDGET      = 11 )

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

C--   Phase-2 accepted final-position diagnostic vector.  P2.5 persists all
C     components in versioned BOM trajectory and pickup schema-2 records.
      _RL bomRhsDiag(
     &     BOM_RHS_NDIAG,bomMaxPartTile,nSx,nSy)
      COMMON /BOM_STATE_DIAG_R/ bomRhsDiag

C--   Phase-3 accepted owner diagnostics.  Raft fields are the deterministic
C     minimum-ID and exact size of the successful FINAL cutoff component.
      _RL bomSpringEast(bomMaxPartTile,nSx,nSy)
      _RL bomSpringNorth(bomMaxPartTile,nSx,nSy)
      COMMON /BOM_P3_STATE_R/ bomSpringEast, bomSpringNorth

      INTEGER bomNeighborCount(bomMaxPartTile,nSx,nSy)
      INTEGER bomRaftSize(bomMaxPartTile,nSx,nSy)
      COMMON /BOM_P3_STATE_I/ bomNeighborCount, bomRaftSize

      INTEGER*8 bomRaftId(bomMaxPartTile,nSx,nSy)
      COMMON /BOM_P3_STATE_I8/ bomRaftId

C--   Transactional FINAL component candidate.  The spring stage publishes
C     this scratch only after label convergence and exact size aggregation;
C     the ensemble validates the owner identity tuple before its one commit.
      INTEGER bomComponentNOwner
      INTEGER bomComponentStage
      INTEGER bomComponentEpoch
      INTEGER bomComponentSubstep
      INTEGER bomComponentIterations
      INTEGER bomComponentMaximumSize
      INTEGER bomComponentRaftSize(bomMaxPartTile*nSx*nSy)
      COMMON /BOM_COMPONENT_CANDIDATE_I/
     &       bomComponentNOwner, bomComponentStage,
     &       bomComponentEpoch, bomComponentSubstep,
     &       bomComponentIterations, bomComponentMaximumSize,
     &       bomComponentRaftSize

      INTEGER*8 bomComponentOwnerId(bomMaxPartTile*nSx*nSy)
      INTEGER*8 bomComponentRaftId(bomMaxPartTile*nSx*nSy)
      COMMON /BOM_COMPONENT_CANDIDATE_I8/
     &       bomComponentOwnerId, bomComponentRaftId

      LOGICAL bomComponentReady
      COMMON /BOM_COMPONENT_CANDIDATE_L/ bomComponentReady

C--   One-stage read-only ghost publication.  Counts/readiness and metadata
C     are published only after the complete collective transaction validates.
      INTEGER bomNGhostTile(nSx,nSy)
      INTEGER bomGhostStatus(bomMaxGhostTile,nSx,nSy)
      INTEGER bomGhostSourceRank(bomMaxGhostTile,nSx,nSy)
      INTEGER bomGhostSourceBi(bomMaxGhostTile,nSx,nSy)
      INTEGER bomGhostSourceBj(bomMaxGhostTile,nSx,nSy)
      INTEGER bomGhostStage
      INTEGER bomGhostEpoch
      INTEGER bomGhostSubstep
      COMMON /BOM_GHOST_STATE_I/
     &       bomNGhostTile, bomGhostStatus,
     &       bomGhostSourceRank, bomGhostSourceBi,
     &       bomGhostSourceBj, bomGhostStage,
     &       bomGhostEpoch, bomGhostSubstep

      INTEGER*8 bomGhostId(bomMaxGhostTile,nSx,nSy)
      INTEGER*8 bomGhostRecordsSent
      INTEGER*8 bomGhostRecordsReceived
      INTEGER*8 bomGhostBytesSent
      INTEGER*8 bomGhostBytesReceived
      COMMON /BOM_GHOST_STATE_I8/
     &       bomGhostId, bomGhostRecordsSent,
     &       bomGhostRecordsReceived,
     &       bomGhostBytesSent, bomGhostBytesReceived

C--   Last successful spring-enabled nominal-substep work counters.
      INTEGER*8 bomP3OwnerRecords
      INTEGER*8 bomP3GhostRecords
      INTEGER*8 bomP3NonEmptyCells
      INTEGER*8 bomP3CandidateComparisons
      INTEGER*8 bomP3DirectedNeighbors
      INTEGER*8 bomP3UndirectedEdges
      INTEGER*8 bomP3MaximumNeighbors
      INTEGER*8 bomP3RebuildCount
      INTEGER*8 bomP3GhostPacketsSent
      INTEGER*8 bomP3GhostPacketsReceived
      INTEGER*8 bomP3GhostBytesSent
      INTEGER*8 bomP3GhostBytesReceived
      INTEGER*8 bomP3MaximumComponentSize
      INTEGER*8 bomP3ComponentIterations
      COMMON /BOM_P3_COUNTER_I8/
     &       bomP3OwnerRecords, bomP3GhostRecords,
     &       bomP3NonEmptyCells, bomP3CandidateComparisons,
     &       bomP3DirectedNeighbors, bomP3UndirectedEdges,
     &       bomP3MaximumNeighbors, bomP3RebuildCount,
     &       bomP3GhostPacketsSent, bomP3GhostPacketsReceived,
     &       bomP3GhostBytesSent, bomP3GhostBytesReceived,
     &       bomP3MaximumComponentSize,
     &       bomP3ComponentIterations

      _RL bomGhostX(bomMaxGhostTile,nSx,nSy)
      _RL bomGhostY(bomMaxGhostTile,nSx,nSy)
      COMMON /BOM_GHOST_STATE_R/ bomGhostX, bomGhostY

      LOGICAL bomGhostReady(nSx,nSy)
      COMMON /BOM_GHOST_STATE_L/ bomGhostReady

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
