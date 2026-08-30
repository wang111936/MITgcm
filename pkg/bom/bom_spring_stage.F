#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_SPRING_STAGE
C !INTERFACE:
      SUBROUTINE BOM_SPRING_STAGE(
     I                 nOwner, ownerId, ownerStatus,
     I                 ownerX, ownerY, ghostStage,
     I                 ghostEpoch, ghostSubstep, dtGuard,
     O                 springEast, springNorth, ownerNeighborCount,
     O                 ownerRecords, ghostRecords, nonEmptyCells,
     O                 candidateComparisons, directedNeighbors,
     O                 undirectedEdges, maximumNeighbors,
     O                 failCode, p3FailPhase, stageValid,
     I                 myThid )

C !DESCRIPTION:
C     Build the exact current-stage graph from authoritative trial owners
C     and the accepted one-stage ghost publication, then accumulate each
C     owner's spring velocity in strictly increasing neighbor-ID order.
C     Outputs are published only after the full local stage validates.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"

      INTEGER nOwner
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER ownerStatus(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord), ownerY(bomMaxOwnerRecord)
      INTEGER ghostStage, ghostEpoch, ghostSubstep
      _RL dtGuard
      _RL springEast(bomMaxOwnerRecord)
      _RL springNorth(bomMaxOwnerRecord)
      INTEGER ownerNeighborCount(bomMaxOwnerRecord)
      INTEGER*8 ownerRecords, ghostRecords, nonEmptyCells
      INTEGER*8 candidateComparisons, directedNeighbors
      INTEGER*8 undirectedEdges, maximumNeighbors
      INTEGER failCode, p3FailPhase, myThid
      LOGICAL stageValid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER owner, rec, ig, bi, bj, neighbor
      INTEGER nGhostRaw, writeRecord, ownerIndex
      INTEGER nRecord, nCellX, nCellY, nCell, cellReachY
      INTEGER localFail, geometryFail, listFail, graphFail
      INTEGER componentFail
      INTEGER componentIterations, maximumComponentSize
      INTEGER localPhase, geometryPhase, listPhase, graphPhase
      INTEGER globalFail, globalPhase
      INTEGER recordStatus(bomMaxCellRecord)
      INTEGER recordOwner(bomMaxCellRecord)
      INTEGER*8 recordId(bomMaxCellRecord)
      INTEGER*8 ownerIdSort(bomMaxOwnerRecord)
      INTEGER*8 ownerIndexSort(bomMaxOwnerRecord)
      INTEGER*8 ownerIndex8, lastGhostId
      _RL recordX(bomMaxCellRecord), recordY(bomMaxCellRecord)
      _RL lastGhostX, lastGhostY
      INTEGER cellHead(bomMaxCell)
      INTEGER cellNext(bomMaxCellRecord)
      INTEGER recordCell(bomMaxCellRecord)
      INTEGER rowReachX(bomMaxCell)
      INTEGER neighborCountWork(bomMaxOwnerRecord)
      INTEGER*8 neighborId(bomMaxNeighbor,bomMaxOwnerRecord)
      INTEGER neighborRecord(bomMaxNeighbor,bomMaxOwnerRecord)
      INTEGER*8 raftIdWork(bomMaxOwnerRecord)
      INTEGER raftSizeWork(bomMaxOwnerRecord)
      _RL springEastWork(bomMaxOwnerRecord)
      _RL springNorthWork(bomMaxOwnerRecord)
      _RL cellWidthX, cellWidthY
      _RL dEast, dNorth, distance, pairEast, pairNorth
      _RL stiffness, contributionEast, contributionNorth
      _RL accumEast, accumNorth, nextEast, nextNorth
      _RL kMaximum, tauK, neighborFactor, springNumber
      INTEGER*8 cellOwnerRecords, cellGhostRecords
      INTEGER*8 cellNonEmpty, graphOwnerRecords
      INTEGER*8 graphGhostRecords, graphNonEmpty
      INTEGER*8 comparisonsWork, directedWork, undirectedWork
      INTEGER*8 maximumWork, failureNeed, failureCapacity
      LOGICAL geometryValid, listValid, neighborsValid
      LOGICAL pairValid, accumulationValid, calcValid
      INTEGER lastGhostStatus
      LOGICAL componentValid,sortValid,found
      LOGICAL globalValid
      SAVE neighborId, neighborRecord
      SAVE recordId, recordStatus, recordOwner, recordX, recordY
#endif

      failCode = BOM_FAIL_SPRING_LAW
      p3FailPhase = BOM_P3_PHASE_SPRING
      stageValid = .FALSE.

#ifdef ALLOW_BOM
      IF ( ghostStage.EQ.BOM_STAGE_FINAL )
     &     CALL BOM_COMPONENT_INVALIDATE
      localFail = BOM_FAIL_NONE
      localPhase = BOM_P3_PHASE_NONE
      IF ( nOwner.LT.0 .OR.
     &     nOwner.GT.bomMaxOwnerRecord ) THEN
        localFail = BOM_FAIL_CELL_CAPACITY
        localPhase = BOM_P3_PHASE_CELL
      ELSEIF ( .NOT.IEEE_IS_FINITE(dtGuard) .OR.
     &         dtGuard.LT.0. _d 0 ) THEN
        localFail = BOM_FAIL_SPRING_LAW
      ELSEIF ( bomGhostStage.NE.ghostStage .OR.
     &         bomGhostEpoch.NE.ghostEpoch .OR.
     &         bomGhostSubstep.NE.ghostSubstep ) THEN
        localFail = BOM_FAIL_GHOST_PACKET
        localPhase = BOM_P3_PHASE_GHOST
      ENDIF
      DO bj=1,nSy
       DO bi=1,nSx
        IF ( .NOT.bomGhostReady(bi,bj) .OR.
     &       bomNGhostTile(bi,bj).LT.0 .OR.
     &       bomNGhostTile(bi,bj).GT.bomMaxGhostTile ) THEN
          IF ( localFail.EQ.BOM_FAIL_NONE ) THEN
            localFail = BOM_FAIL_GHOST_PACKET
            localPhase = BOM_P3_PHASE_GHOST
          ENDIF
        ENDIF
       ENDDO
      ENDDO
      IF ( localFail.NE.BOM_FAIL_NONE ) THEN
        failCode = localFail
        p3FailPhase = localPhase
        GOTO 800
      ENDIF
      failCode = BOM_FAIL_NONE
      p3FailPhase = BOM_P3_PHASE_NONE

C--   Owner records precede ghosts.  The exchange routes one source to every
C     relevant tile, but this rank-wide cell list needs one exact-ID record.
C     Sort and validate all copies before compacting them; a same-rank owner
C     copy is not a graph ghost.
      nRecord = nOwner
      DO owner=1,nOwner
        recordId(owner) = ownerId(owner)
        recordStatus(owner) = ownerStatus(owner)
        recordX(owner) = ownerX(owner)
        recordY(owner) = ownerY(owner)
        recordOwner(owner) = owner
        ownerIdSort(owner) = ownerId(owner)
        ownerIndexSort(owner) = INT(owner,8)
      ENDDO
      CALL BOM_COMPONENT_SORT_PAIRS_I8(
     U     ownerIdSort,ownerIndexSort,
     I     nOwner,bomMaxOwnerRecord,
     O     sortValid)
      IF ( .NOT.sortValid ) THEN
        failCode = BOM_FAIL_GHOST_PACKET
        p3FailPhase = BOM_P3_PHASE_GHOST
        GOTO 800
      ENDIF
      DO bj=1,nSy
       DO bi=1,nSx
        DO ig=1,bomNGhostTile(bi,bj)
          IF ( nRecord.GE.bomMaxCellRecord ) THEN
            failCode = BOM_FAIL_GHOST_CAPACITY
            p3FailPhase = BOM_P3_PHASE_GHOST
            GOTO 800
          ENDIF
          nRecord = nRecord+1
          recordId(nRecord) = bomGhostId(ig,bi,bj)
          recordStatus(nRecord) = bomGhostStatus(ig,bi,bj)
          recordX(nRecord) = bomGhostX(ig,bi,bj)
          recordY(nRecord) = bomGhostY(ig,bi,bj)
          recordOwner(nRecord) = 0
        ENDDO
       ENDDO
      ENDDO
      nGhostRaw = nRecord-nOwner
      CALL BOM_SPRING_SORT_GHOST_RECORDS(
     U     recordId,recordStatus,recordX,recordY,
     I     nOwner+1,nGhostRaw,bomMaxCellRecord,
     O     sortValid)
      IF ( .NOT.sortValid ) THEN
        failCode = BOM_FAIL_GHOST_PACKET
        p3FailPhase = BOM_P3_PHASE_GHOST
        GOTO 800
      ENDIF
      writeRecord = nOwner
      lastGhostId = 0_8
      lastGhostStatus = BOM_UNUSED
      lastGhostX = 0. _d 0
      lastGhostY = 0. _d 0
      DO rec=nOwner+1,nOwner+nGhostRaw
        IF ( rec.EQ.nOwner+1 .OR.
     &       recordId(rec).NE.lastGhostId ) THEN
          lastGhostId = recordId(rec)
          lastGhostStatus = recordStatus(rec)
          lastGhostX = recordX(rec)
          lastGhostY = recordY(rec)
          CALL BOM_COMPONENT_FIND_I8(
     I         recordId(rec),ownerIdSort,ownerIndexSort,nOwner,
     O         ownerIndex8,found)
          IF ( found ) THEN
            ownerIndex = INT(ownerIndex8)
            IF ( ownerIndex.LT.1 .OR. ownerIndex.GT.nOwner .OR.
     &           ownerStatus(ownerIndex).NE.recordStatus(rec) .OR.
     &           ownerX(ownerIndex).NE.recordX(rec) .OR.
     &           ownerY(ownerIndex).NE.recordY(rec) ) THEN
              failCode = BOM_FAIL_GHOST_PACKET
              p3FailPhase = BOM_P3_PHASE_GHOST
              GOTO 800
            ENDIF
          ELSE
            writeRecord = writeRecord+1
            recordId(writeRecord) = recordId(rec)
            recordStatus(writeRecord) = recordStatus(rec)
            recordX(writeRecord) = recordX(rec)
            recordY(writeRecord) = recordY(rec)
            recordOwner(writeRecord) = 0
          ENDIF
        ELSEIF ( recordStatus(rec).NE.lastGhostStatus .OR.
     &           recordX(rec).NE.lastGhostX .OR.
     &           recordY(rec).NE.lastGhostY ) THEN
          failCode = BOM_FAIL_GHOST_PACKET
          p3FailPhase = BOM_P3_PHASE_GHOST
          GOTO 800
        ENDIF
      ENDDO
      nRecord = writeRecord

      CALL BOM_INIT_CELL_GEOMETRY(
     I     usingCartesianGrid,usingSphericalPolarGrid,
     I     bomMapPeriodicX,bomMapXLo,bomMapXHi,
     I     bomMapYLo,bomMapYHi,bomMapXPeriod,
     I     rSphere,bomNeighborCutoff,bomMaxCell,
     O     nCellX,nCellY,nCell,cellWidthX,cellWidthY,
     O     cellReachY,rowReachX,failureNeed,failureCapacity,
     O     geometryFail,geometryPhase,geometryValid)
      IF ( .NOT.geometryValid ) THEN
        failCode = geometryFail
        p3FailPhase = geometryPhase
        GOTO 800
      ENDIF

      CALL BOM_BUILD_CELL_LIST(
     I     nRecord,nOwner,bomMaxCellRecord,
     I     recordId,recordStatus,recordX,recordY,recordOwner,
     I     bomMapPeriodicX,bomMapXLo,bomMapXHi,
     I     bomMapYLo,bomMapYHi,bomMapXPeriod,
     I     nCellX,nCellY,nCell,cellWidthX,cellWidthY,
     O     cellHead,cellNext,recordCell,
     O     cellOwnerRecords,cellGhostRecords,cellNonEmpty,
     O     failureNeed,failureCapacity,
     O     listFail,listPhase,listValid)
      IF ( .NOT.listValid ) THEN
        failCode = listFail
        p3FailPhase = listPhase
        GOTO 800
      ENDIF

      CALL BOM_BUILD_NEIGHBORS(
     I     nRecord,nOwner,bomMaxCandidate,bomMaxNeighbor,
     I     recordId,recordStatus,recordX,recordY,recordOwner,
     I     cellHead,cellNext,recordCell,
     I     usingCartesianGrid,usingSphericalPolarGrid,
     I     bomMapPeriodicX,bomMapXLo,bomMapXHi,
     I     bomMapYLo,bomMapYHi,bomMapXPeriod,
     I     rSphere,bomPairDistanceMin,bomNeighborCutoff,
     I     nCellX,nCellY,nCell,cellReachY,rowReachX,
     O     neighborCountWork,neighborId,neighborRecord,
     O     graphOwnerRecords,graphGhostRecords,graphNonEmpty,
     O     comparisonsWork,directedWork,undirectedWork,
     O     maximumWork,failureNeed,failureCapacity,
     O     graphFail,graphPhase,neighborsValid)
      IF ( .NOT.neighborsValid ) THEN
        failCode = graphFail
        p3FailPhase = graphPhase
        GOTO 800
      ENDIF

      IF ( bomSpringLaw.EQ.'HOOKE' ) THEN
        kMaximum = bomHookeK
      ELSEIF ( bomSpringLaw.EQ.'EBOMB' ) THEN
        kMaximum = bomSpringA
      ELSE
        failCode = BOM_FAIL_SPRING_LAW
        p3FailPhase = BOM_P3_PHASE_SPRING
        GOTO 800
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(kMaximum) .OR.
     &     kMaximum.LE.0. _d 0 ) THEN
        failCode = BOM_FAIL_SPRING_LAW
        p3FailPhase = BOM_P3_PHASE_SPRING
        GOTO 800
      ENDIF

      DO owner=1,nOwner
        springEastWork(owner) = 0. _d 0
        springNorthWork(owner) = 0. _d 0
        IF ( recordStatus(owner).EQ.BOM_ALIVE ) THEN
          accumEast = 0. _d 0
          accumNorth = 0. _d 0
          DO neighbor=1,neighborCountWork(owner)
            rec = neighborRecord(neighbor,owner)
            IF ( rec.LT.1 .OR. rec.GT.nRecord ) THEN
              failCode = BOM_FAIL_PAIR_GEOMETRY
              p3FailPhase = BOM_P3_PHASE_NEIGHBOR
              GOTO 800
            ENDIF
            IF ( neighbor.GT.1 ) THEN
              IF ( neighborId(neighbor,owner).LE.
     &             neighborId(neighbor-1,owner) ) THEN
                failCode = BOM_FAIL_PAIR_GEOMETRY
                p3FailPhase = BOM_P3_PHASE_NEIGHBOR
                GOTO 800
              ENDIF
            ENDIF
            CALL BOM_PAIR_GEOMETRY(
     I           recordId(owner),recordX(owner),recordY(owner),
     I           recordId(rec),recordX(rec),recordY(rec),
     I           usingCartesianGrid,usingSphericalPolarGrid,
     I           bomMapPeriodicX,bomMapXLo,bomMapXHi,
     I           bomMapYLo,bomMapYHi,bomMapXPeriod,
     I           rSphere,bomPairDistanceMin,
     O           dEast,dNorth,distance,geometryFail,pairValid)
            IF ( .NOT.pairValid ) THEN
              failCode = geometryFail
              p3FailPhase = BOM_P3_PHASE_NEIGHBOR
              GOTO 800
            ENDIF
            CALL BOM_SPRING_PAIR(
     I           bomSpringLaw,bomTau,bomSpringL,
     I           bomHookeK,bomSpringA,bomSpringDelta,
     I           dEast,dNorth,distance,
     O           pairEast,pairNorth,stiffness,
     O           localFail,pairValid)
            IF ( .NOT.pairValid ) THEN
              failCode = localFail
              p3FailPhase = BOM_P3_PHASE_SPRING
              GOTO 800
            ENDIF
            IF ( recordId(owner).LT.recordId(rec) ) THEN
              contributionEast = pairEast
              contributionNorth = pairNorth
            ELSE
              contributionEast = -pairEast
              contributionNorth = -pairNorth
            ENDIF
            CALL BOM_SPRING_ACCUMULATE(
     I           accumEast,accumNorth,
     I           contributionEast,contributionNorth,
     O           nextEast,nextNorth,
     O           localFail,accumulationValid)
            IF ( .NOT.accumulationValid ) THEN
              failCode = localFail
              p3FailPhase = BOM_P3_PHASE_SPRING
              GOTO 800
            ENDIF
            accumEast = nextEast
            accumNorth = nextNorth
          ENDDO
          springEastWork(owner) = accumEast
          springNorthWork(owner) = accumNorth

C--       Arithmetic failure precedes a mathematical spring-CFL rejection.
          CALL BOM_SAFE_MULT_RL(bomTau,kMaximum,tauK,calcValid)
          IF ( .NOT.calcValid ) THEN
            failCode = BOM_FAIL_SPRING_LAW
            p3FailPhase = BOM_P3_PHASE_SPRING
            GOTO 800
          ENDIF
          CALL BOM_SAFE_MULT_RL(
     I         tauK,DFLOAT(neighborCountWork(owner)),
     O         neighborFactor,calcValid)
          IF ( .NOT.calcValid ) THEN
            failCode = BOM_FAIL_SPRING_LAW
            p3FailPhase = BOM_P3_PHASE_SPRING
            GOTO 800
          ENDIF
          CALL BOM_SAFE_MULT_RL(
     I         dtGuard,neighborFactor,
     O         springNumber,calcValid)
          IF ( .NOT.calcValid ) THEN
            failCode = BOM_FAIL_SPRING_LAW
            p3FailPhase = BOM_P3_PHASE_SPRING
            GOTO 800
          ENDIF
          IF ( dtGuard.GT.0. _d 0 .AND.
     &         springNumber.GT.bomSpringCFL ) THEN
            failCode = BOM_FAIL_SPRING_CFL
            p3FailPhase = BOM_P3_PHASE_SPRING
            GOTO 800
          ENDIF
        ELSE
          neighborCountWork(owner) = 0
        ENDIF
      ENDDO

C--   No rank enters component collectives until every local graph validates.
  800 CONTINUE
      localFail = failCode
      localPhase = p3FailPhase
      CALL BOM_P3_GLOBAL_STATUS(
     I     localFail,localPhase,
     O     globalFail,globalPhase,globalValid,myThid)
      IF ( .NOT.globalValid ) THEN
        failCode = globalFail
        p3FailPhase = globalPhase
        RETURN
      ENDIF

C--   Raft diagnostics consume this exact successful FINAL graph while its
C     ghost routes and sorted neighbor IDs are still authoritative.
      IF ( bomRaftDiagnostics .AND.
     &     ghostStage.EQ.BOM_STAGE_FINAL ) THEN
        CALL BOM_COMPONENTS_FINAL(
     I       nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I       neighborCountWork,neighborId,
     I       ghostStage,ghostEpoch,ghostSubstep,
     O       raftIdWork,raftSizeWork,
     O       componentIterations,maximumComponentSize,
     O       componentFail,componentValid,myThid)
        IF ( .NOT.componentValid ) THEN
          failCode = componentFail
          p3FailPhase = BOM_P3_PHASE_COMPONENT
          RETURN
        ENDIF
        CALL BOM_COMPONENT_PUBLISH(
     I       nOwner,ownerId,raftIdWork,raftSizeWork,
     I       componentIterations,maximumComponentSize,
     I       ghostStage,ghostEpoch,ghostSubstep)
      ENDIF

C--   Publish only after every owner, edge, accumulation and guard succeeds.
      DO owner=1,nOwner
        springEast(owner) = springEastWork(owner)
        springNorth(owner) = springNorthWork(owner)
        ownerNeighborCount(owner) = neighborCountWork(owner)
      ENDDO
      ownerRecords = graphOwnerRecords
      ghostRecords = graphGhostRecords
      nonEmptyCells = graphNonEmpty
      candidateComparisons = comparisonsWork
      directedNeighbors = directedWork
      undirectedEdges = undirectedWork
      maximumNeighbors = maximumWork
      failCode = BOM_FAIL_NONE
      p3FailPhase = BOM_P3_PHASE_NONE
      stageValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SPRING_SORT_GHOST_RECORDS(
     U                 recordId, recordStatus, recordX, recordY,
     I                 firstRecord, nValue, capacity,
     O                 isValid )
      IMPLICIT NONE
      INTEGER*8 recordId(*)
      INTEGER recordStatus(*)
      _RL recordX(*),recordY(*)
      INTEGER firstRecord,nValue,capacity
      INTEGER start,finish,root,child,rootRecord,childRecord
      LOGICAL isValid

      isValid = .FALSE.
      IF ( firstRecord.LT.1 .OR. nValue.LT.0 .OR.
     &     firstRecord-1.GT.capacity-nValue ) RETURN
      DO start=nValue/2,1,-1
        root = start
        DO WHILE ( 2*root.LE.nValue )
          child = 2*root
          IF ( child.LT.nValue ) THEN
            IF ( recordId(firstRecord+child-1).LT.
     &           recordId(firstRecord+child) ) child=child+1
          ENDIF
          rootRecord = firstRecord+root-1
          childRecord = firstRecord+child-1
          IF ( recordId(rootRecord).GE.recordId(childRecord) )
     &         GOTO 410
          CALL BOM_SPRING_SWAP_GHOST_RECORD(
     I         rootRecord,childRecord,
     U         recordId,recordStatus,recordX,recordY)
          root = child
        ENDDO
  410   CONTINUE
      ENDDO
      DO finish=nValue,2,-1
        CALL BOM_SPRING_SWAP_GHOST_RECORD(
     I       firstRecord,firstRecord+finish-1,
     U       recordId,recordStatus,recordX,recordY)
        root = 1
        DO WHILE ( 2*root.LE.finish-1 )
          child = 2*root
          IF ( child.LT.finish-1 ) THEN
            IF ( recordId(firstRecord+child-1).LT.
     &           recordId(firstRecord+child) ) child=child+1
          ENDIF
          rootRecord = firstRecord+root-1
          childRecord = firstRecord+child-1
          IF ( recordId(rootRecord).GE.recordId(childRecord) )
     &         GOTO 420
          CALL BOM_SPRING_SWAP_GHOST_RECORD(
     I         rootRecord,childRecord,
     U         recordId,recordStatus,recordX,recordY)
          root = child
        ENDDO
  420   CONTINUE
      ENDDO
      isValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SPRING_SWAP_GHOST_RECORD(
     I                 recordA, recordB,
     U                 recordId, recordStatus, recordX, recordY )
      IMPLICIT NONE
      INTEGER recordA,recordB,statusSwap
      INTEGER*8 recordId(*),idSwap
      INTEGER recordStatus(*)
      _RL recordX(*),recordY(*),realSwap
      idSwap = recordId(recordA)
      recordId(recordA) = recordId(recordB)
      recordId(recordB) = idSwap
      statusSwap = recordStatus(recordA)
      recordStatus(recordA) = recordStatus(recordB)
      recordStatus(recordB) = statusSwap
      realSwap = recordX(recordA)
      recordX(recordA) = recordX(recordB)
      recordX(recordB) = realSwap
      realSwap = recordY(recordA)
      recordY(recordA) = recordY(recordB)
      recordY(recordB) = realSwap
      RETURN
      END
