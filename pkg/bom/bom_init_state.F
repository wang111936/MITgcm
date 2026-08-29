#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_STATE

C !INTERFACE:
      SUBROUTINE BOM_INIT_STATE( myThid )

C !DESCRIPTION:
C     Reset owner, Phase-3 component/ghost, and environmental state
C     deterministically.
C     Valid records later occupy 1:bomNPartTile on each tile.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER bi, bj, i, j, ip, ig, iEnd, iSource, iComponent
      INTEGER iOwner
      INTEGER iDiag, iEvent

      _BEGIN_MASTER(myThid)
      bomFieldsReady = .FALSE.
      bomFieldTime = 0. _d 0
      bomWindFieldTime = 0. _d 0
      bomFieldIter = 0
      bomWindFieldIter = 0
      bomNPartExpected = 0
      bomNPartLiveExpected = 0
      bomFreeRebuildOps = 0_8
      bomFreeRemoveOps = 0_8
      bomFreeAllocOps = 0_8
      bomNextId = 1_8
      bomEventTimeIndex = 0_8
      bomBirthEvents = 0_8
      bomDeathEvents = 0_8
      bomBeachEvents = 0_8
      bomOutsideEvents = 0_8
      bomCancelEvents = 0_8
      bomEventBufferCount = 0
      bomNextOutputTime = 0. _d 0
      bomOutputScheduleReady = .FALSE.
      bomEnvReady = .FALSE.
      bomGradReady = .FALSE.
      bomMetricReady = .FALSE.
      bomBioReady = .FALSE.
      bomGhostStage = BOM_STAGE_NONE
      bomGhostEpoch = 0
      bomGhostSubstep = 0
      bomGhostRecordsSent = 0_8
      bomGhostRecordsReceived = 0_8
      bomGhostBytesSent = 0_8
      bomGhostBytesReceived = 0_8
      bomComponentReady = .FALSE.
      bomComponentNOwner = 0
      bomComponentStage = BOM_STAGE_NONE
      bomComponentEpoch = 0
      bomComponentSubstep = 0
      bomComponentIterations = 0
      bomComponentMaximumSize = 0
      DO iOwner=1,bomMaxPartTile*nSx*nSy
        bomComponentOwnerId(iOwner) = 0_8
        bomComponentRaftId(iOwner) = 0_8
        bomComponentRaftSize(iOwner) = 0
      ENDDO
      bomP3OwnerRecords = 0_8
      bomP3GhostRecords = 0_8
      bomP3NonEmptyCells = 0_8
      bomP3CandidateComparisons = 0_8
      bomP3DirectedNeighbors = 0_8
      bomP3UndirectedEdges = 0_8
      bomP3MaximumNeighbors = 0_8
      bomP3RebuildCount = 0_8
      bomP3GhostPacketsSent = 0_8
      bomP3GhostPacketsReceived = 0_8
      bomP3GhostBytesSent = 0_8
      bomP3GhostBytesReceived = 0_8
      bomP3MaximumComponentSize = 0_8
      bomP3ComponentIterations = 0_8
      DO iEnd=1,BOM_ENV_NEND
        bomEnvTime(iEnd) = 0. _d 0
        bomEnvIter(iEnd) = 0
        bomEnvTimeScratch(iEnd) = 0. _d 0
        bomEnvIterScratch(iEnd) = 0
        bomBioTime(iEnd) = 0. _d 0
        bomBioIter(iEnd) = 0
        bomBioTempSource(iEnd) = BOM_BIO_TEMP_NONE
        bomBioNSource(iEnd) = BOM_BIO_N_NONE
        bomBioTimeScratch(iEnd) = 0. _d 0
        bomBioIterScratch(iEnd) = 0
        bomBioTempSourceScratch(iEnd) = BOM_BIO_TEMP_NONE
        bomBioNSourceScratch(iEnd) = BOM_BIO_N_NONE
      ENDDO
      DO iComponent=1,BOM_COUPLER_NCOMP
        bomCouplerStokesTime(iComponent) = 0. _d 0
        bomCouplerStokesIter(iComponent) = 0
        bomCouplerStokesReady(iComponent) = .FALSE.
      ENDDO
      DO iEvent=1,bomMaxEventBuffer
        bomEventTypeBuffer(iEvent) = BOM_EVENT_NONE
        bomEventStageBuffer(iEvent) = BOM_STAGE_NONE
        bomEventOldStatusBuffer(iEvent) = BOM_UNUSED
        bomEventNewStatusBuffer(iEvent) = BOM_UNUSED
        bomEventIterBuffer(iEvent) = 0
        bomEventSubstepBuffer(iEvent) = 0
        bomEventSourceRankBuffer(iEvent) = -1
        bomEventSourceBiBuffer(iEvent) = 0
        bomEventSourceBjBuffer(iEvent) = 0
        bomEventDestRankBuffer(iEvent) = -1
        bomEventDestBiBuffer(iEvent) = 0
        bomEventDestBjBuffer(iEvent) = 0
        bomEventRetryBuffer(iEvent) = 0
        bomEventIndexBuffer(iEvent) = 0_8
        bomEventSubjectIdBuffer(iEvent) = 0_8
        bomEventParentIdBuffer(iEvent) = 0_8
        bomEventChildIdBuffer(iEvent) = 0_8
        bomEventTimeBuffer(iEvent) = 0. _d 0
        bomEventAcceptedXBuffer(iEvent) = 0. _d 0
        bomEventAcceptedYBuffer(iEvent) = 0. _d 0
        bomEventAttemptXBuffer(iEvent) = 0. _d 0
        bomEventAttemptYBuffer(iEvent) = 0. _d 0
        bomEventSBeforeBuffer(iEvent) = 0. _d 0
        bomEventSTrialBuffer(iEvent) = 0. _d 0
        bomEventSAfterBuffer(iEvent) = 0. _d 0
      ENDDO
      DO bj=1,nSy
       DO bi=1,nSx
        bomNPartTile(bi,bj) = 0
        bomFreeCount(bi,bj) = bomMaxPartTile
        bomNGhostTile(bi,bj) = 0
        bomGhostReady(bi,bj) = .FALSE.
        DO ig=1,bomMaxGhostTile
          bomGhostId(ig,bi,bj) = 0_8
          bomGhostStatus(ig,bi,bj) = BOM_UNUSED
          bomGhostSourceRank(ig,bi,bj) = -1
          bomGhostSourceBi(ig,bi,bj) = 0
          bomGhostSourceBj(ig,bi,bj) = 0
          bomGhostX(ig,bi,bj) = 0. _d 0
          bomGhostY(ig,bi,bj) = 0. _d 0
        ENDDO
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomGridUWork(i,j,1,bi,bj) = 0. _d 0
          bomGridVWork(i,j,1,bi,bj) = 0. _d 0
          bomGridVEast(i,j,1,bi,bj) = 0. _d 0
          bomGridVNorth(i,j,1,bi,bj) = 0. _d 0
          bomGridWindEast(i,j,1,bi,bj) = 0. _d 0
          bomGridWindNorth(i,j,1,bi,bj) = 0. _d 0
          bomEnvUWork(i,j,1,bi,bj) = 0. _d 0
          bomEnvVWork(i,j,1,bi,bj) = 0. _d 0
          bomEnvEastWork(i,j,1,bi,bj) = 0. _d 0
          bomEnvNorthWork(i,j,1,bi,bj) = 0. _d 0
          bomGradExchangeWork(i,j,1,bi,bj) = 0. _d 0
          bomExfWindUWork(i,j,1,bi,bj) = 0. _d 0
          bomExfWindVWork(i,j,1,bi,bj) = 0. _d 0
          bomExfWindEastWork(i,j,1,bi,bj) = 0. _d 0
          bomExfWindNorthWork(i,j,1,bi,bj) = 0. _d 0
          bomExfWindU0(i,j,1,bi,bj) = 0. _d 0
          bomExfWindU1(i,j,1,bi,bj) = 0. _d 0
          bomExfWindV0(i,j,1,bi,bj) = 0. _d 0
          bomExfWindV1(i,j,1,bi,bj) = 0. _d 0
          bomStokesUWork(i,j,1,bi,bj) = 0. _d 0
          bomStokesVWork(i,j,1,bi,bj) = 0. _d 0
          bomTauSphere(i,j,bi,bj) = 0. _d 0
          bomFCori(i,j,bi,bj) = 0. _d 0
          bomMetricValid(i,j,bi,bj) = .FALSE.
          bomTauSphereScratch(i,j,bi,bj) = 0. _d 0
          bomFCoriScratch(i,j,bi,bj) = 0. _d 0
          bomMetricValidWork(i,j,bi,bj) = 0. _d 0
          bomMetricValidScratch(i,j,bi,bj) = .FALSE.
          bomStokesEastWork(i,j,1,bi,bj) = 0. _d 0
          bomStokesNorthWork(i,j,1,bi,bj) = 0. _d 0
          bomStokesU0(i,j,1,bi,bj) = 0. _d 0
          bomStokesU1(i,j,1,bi,bj) = 0. _d 0
          bomStokesV0(i,j,1,bi,bj) = 0. _d 0
          bomStokesV1(i,j,1,bi,bj) = 0. _d 0
          bomCouplerStokesEast(i,j,1,bi,bj) = 0. _d 0
          bomCouplerStokesNorth(i,j,1,bi,bj) = 0. _d 0
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            bomEnvEast(i,j,iEnd,iSource,bi,bj) = 0. _d 0
            bomEnvNorth(i,j,iEnd,iSource,bi,bj) = 0. _d 0
            bomEnvValid(i,j,iEnd,iSource,bi,bj) = .FALSE.
            bomEnvEastScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradEastEast(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradNorthEast(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradEastNorth(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradNorthNorth(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradValid(i,j,iEnd,iSource,bi,bj) = .FALSE.
            bomGradEastEastScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradNorthEastScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradEastNorthScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradNorthNorthScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradValidScratch(i,j,iEnd,iSource,bi,bj) =
     &           .FALSE.
            bomGradValidWork(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomEnvNorthScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomEnvValidScratch(i,j,iEnd,iSource,bi,bj) =
     &           .FALSE.
           ENDDO
          ENDDO
         ENDDO
        ENDDO
        DO ip=1,bomMaxPartTile
          bomFreeStack(ip,bi,bj) = bomMaxPartTile-ip+1
          bomId(ip,bi,bj)          = 0
          bomParentId(ip,bi,bj)    = 0_8
          bomStatus(ip,bi,bj)      = BOM_UNUSED
          bomBirthCount(ip,bi,bj)  = 0
          bomX(ip,bi,bj)           = 0. _d 0
          bomY(ip,bi,bj)           = 0. _d 0
          bomReleaseTime(ip,bi,bj) = 0. _d 0
          bomAge(ip,bi,bj)         = 0. _d 0
          bomI(ip,bi,bj)           = 0. _d 0
          bomJ(ip,bi,bj)           = 0. _d 0
          bomVEast(ip,bi,bj)       = 0. _d 0
          bomVNorth(ip,bi,bj)      = 0. _d 0
          bomWindEast(ip,bi,bj)    = 0. _d 0
          bomWindNorth(ip,bi,bj)   = 0. _d 0
          bomDriftEast(ip,bi,bj)   = 0. _d 0
          bomDriftNorth(ip,bi,bj)  = 0. _d 0
          bomS(ip,bi,bj)           = 0. _d 0
          bomSpringEast(ip,bi,bj)  = 0. _d 0
          bomSpringNorth(ip,bi,bj) = 0. _d 0
          bomNeighborCount(ip,bi,bj) = 0
          bomRaftId(ip,bi,bj) = 0_8
          bomRaftSize(ip,bi,bj) = 0
          bomTerminalType(ip,bi,bj) = BOM_EVENT_NONE
          bomTerminalStage(ip,bi,bj) = BOM_STAGE_NONE
          bomTerminalId(ip,bi,bj) = 0_8
          bomTerminalAcceptedX(ip,bi,bj) = 0. _d 0
          bomTerminalAcceptedY(ip,bi,bj) = 0. _d 0
          bomTerminalAttemptX(ip,bi,bj) = 0. _d 0
          bomTerminalAttemptY(ip,bi,bj) = 0. _d 0
          bomTerminalReady(ip,bi,bj) = .FALSE.
          DO iDiag=1,BOM_RHS_NDIAG
            bomRhsDiag(iDiag,ip,bi,bj) = 0. _d 0
          ENDDO
        ENDDO
       ENDDO
      ENDDO
      _END_MASTER(myThid)
      _BARRIER
#endif

      RETURN
      END
