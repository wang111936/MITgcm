#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_RK2_SPRING_ENSEMBLE(
     I                 tSub0, tSub1, myIter, mySubstep,
     O                 failStage, p3FailPhase, failCode, isValid,
     I                 myThid )
      IMPLICIT NONE
      _RL tSub0, tSub1
      INTEGER myIter, mySubstep, failStage, p3FailPhase, failCode
      INTEGER myThid
      LOGICAL isValid
      CALL BOM_SPRING_ENSEMBLE(
     I     2,tSub0,tSub1,myIter,mySubstep,
     O     failStage,p3FailPhase,failCode,isValid,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_RK4_SPRING_ENSEMBLE(
     I                 tSub0, tSub1, myIter, mySubstep,
     O                 failStage, p3FailPhase, failCode, isValid,
     I                 myThid )
      IMPLICIT NONE
      _RL tSub0, tSub1
      INTEGER myIter, mySubstep, failStage, p3FailPhase, failCode
      INTEGER myThid
      LOGICAL isValid
      CALL BOM_SPRING_ENSEMBLE(
     I     4,tSub0,tSub1,myIter,mySubstep,
     O     failStage,p3FailPhase,failCode,isValid,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_SPRING_ENSEMBLE
C !INTERFACE:
      SUBROUTINE BOM_SPRING_ENSEMBLE(
     I                 integratorOrder, tSub0, tSub1,
     I                 myIter, mySubstep,
     O                 failStage, p3FailPhase, failCode, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Snapshot one complete nominal substep, advance every interacting owner
C     from synchronized RK stages, and commit once.  Release events inside a
C     nominal substep create globally identical scratch intervals; no owner
C     state is published between them.  Migration remains the caller's single
C     post-commit action.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER integratorOrder, myIter, mySubstep, myThid
      _RL tSub0, tSub1
      INTEGER failStage, p3FailPhase, failCode
      LOGICAL isValid
CEOP

#ifdef ALLOW_BOM
      INTEGER nOwner, owner, ip, bi, bj, iDiag
      INTEGER epochCounter, localFail, localPhase
      INTEGER globalFail, globalPhase, activeLocal, activeGlobal
      INTEGER ownerIp(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord)
      INTEGER ownerBj(bomMaxOwnerRecord)
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER status0(bomMaxOwnerRecord)
      INTEGER statusFinal(bomMaxOwnerRecord)
      INTEGER statusStage(bomMaxOwnerRecord)
      _RL releaseTime(bomMaxOwnerRecord)
      _RL age0(bomMaxOwnerRecord), ageFinal(bomMaxOwnerRecord)
      _RL activeStart(bomMaxOwnerRecord)
      _RL xWork(bomMaxOwnerRecord), yWork(bomMaxOwnerRecord)
      _RL xNext(bomMaxOwnerRecord), yNext(bomMaxOwnerRecord)
      _RL finalRateX(bomMaxOwnerRecord)
      _RL finalRateY(bomMaxOwnerRecord)
      _RL finalI(bomMaxOwnerRecord), finalJ(bomMaxOwnerRecord)
      _RL finalDiag(BOM_RHS_NDIAG,bomMaxOwnerRecord)
      _RL finalSpringEast(bomMaxOwnerRecord)
      _RL finalSpringNorth(bomMaxOwnerRecord)
      INTEGER finalNeighbor(bomMaxOwnerRecord)
      INTEGER*8 finalRaftId(bomMaxOwnerRecord)
      INTEGER finalRaftSize(bomMaxOwnerRecord)
      _RL finalWet(bomMaxOwnerRecord), finalCFL(bomMaxOwnerRecord)
      LOGICAL refreshFinal(bomMaxOwnerRecord)
      LOGICAL releaseValid, doAdvance, doRefresh
      LOGICAL globalValid, intervalValid, finalValid
      LOGICAL calcValid, statsValid, componentValid
      INTEGER releaseFail, finalFail, finalPhase, componentFail
      _RL dtActive, activeCandidate, currentTime, nextTime
      _RL intervalDt
      INTEGER*8 ownerRecords, ghostRecords, nonEmptyCells
      INTEGER*8 candidateComparisons, directedNeighbors
      INTEGER*8 undirectedEdges, maximumNeighbors
      INTEGER*8 maxOwnerRecords, maxGhostRecords
      INTEGER*8 maxNonEmptyCells, sumComparisons
      INTEGER*8 sumDirected, sumUndirected, maxNeighbors
      INTEGER*8 rebuildCount, sumPacketsSent, sumPacketsReceived
      INTEGER*8 sumBytesSent, sumBytesReceived
      SAVE finalDiag
#endif

      failStage = BOM_STAGE_NONE
      p3FailPhase = BOM_P3_PHASE_NONE
      failCode = BOM_FAIL_STATE
      isValid = .FALSE.

#ifdef ALLOW_BOM
      nOwner = 0
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          nOwner = nOwner+1
          IF ( nOwner.LE.bomMaxOwnerRecord ) THEN
            ownerIp(nOwner) = ip
            ownerBi(nOwner) = bi
            ownerBj(nOwner) = bj
            ownerId(nOwner) = bomId(ip,bi,bj)
            status0(nOwner) = bomStatus(ip,bi,bj)
            releaseTime(nOwner) = bomReleaseTime(ip,bi,bj)
            age0(nOwner) = bomAge(ip,bi,bj)
            xWork(nOwner) = bomX(ip,bi,bj)
            yWork(nOwner) = bomY(ip,bi,bj)
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      IF ( nOwner.GT.bomMaxOwnerRecord ) THEN
        localFail = BOM_FAIL_CELL_CAPACITY
        localPhase = BOM_P3_PHASE_POSITION
      ELSEIF ( integratorOrder.NE.2 .AND.
     &         integratorOrder.NE.4 ) THEN
        localFail = BOM_FAIL_STATE
        localPhase = BOM_P3_PHASE_POSITION
      ELSEIF ( .NOT.IEEE_IS_FINITE(tSub0) .OR.
     &         .NOT.IEEE_IS_FINITE(tSub1) .OR.
     &         tSub1.LT.tSub0 .OR. mySubstep.LE.0 ) THEN
        localFail = BOM_FAIL_RELEASE
        localPhase = BOM_P3_PHASE_POSITION
      ELSE
        localFail = BOM_FAIL_NONE
        localPhase = BOM_P3_PHASE_NONE
      ENDIF

C--   Freeze release/status/age candidates for the complete nominal step.
      DO owner=1,MAX(0,MIN(nOwner,bomMaxOwnerRecord))
        IF ( localFail.EQ.BOM_FAIL_NONE ) THEN
          CALL BOM_RELEASE_STEP(
     I         status0(owner),releaseTime(owner),age0(owner),
     I         tSub0,tSub1,
     O         statusFinal(owner),dtActive,ageFinal(owner),
     O         doAdvance,doRefresh,
     O         releaseFail,releaseValid)
          IF ( .NOT.releaseValid ) THEN
            localFail = releaseFail
            localPhase = BOM_P3_PHASE_POSITION
          ELSE
            refreshFinal(owner) = doRefresh
            IF ( statusFinal(owner).EQ.BOM_ALIVE ) THEN
              CALL BOM_SAFE_ADD_RL(
     I             tSub1,-dtActive,
     O             activeCandidate,calcValid)
              IF ( .NOT.calcValid ) THEN
                localFail = BOM_FAIL_NONFINITE
                localPhase = BOM_P3_PHASE_POSITION
              ELSE
                activeStart(owner) = activeCandidate
              ENDIF
            ELSE
              activeStart(owner) = HUGE(activeStart(owner))
            ENDIF
          ENDIF
        ENDIF
      ENDDO
      CALL BOM_P3_GLOBAL_STATUS(
     I     localFail,localPhase,
     O     globalFail,globalPhase,globalValid,myThid)
      IF ( .NOT.globalValid ) THEN
        failCode = globalFail
        p3FailPhase = globalPhase
        RETURN
      ENDIF

      epochCounter = 0
      maxOwnerRecords = 0_8
      maxGhostRecords = 0_8
      maxNonEmptyCells = 0_8
      sumComparisons = 0_8
      sumDirected = 0_8
      sumUndirected = 0_8
      maxNeighbors = 0_8
      rebuildCount = 0_8
      sumPacketsSent = 0_8
      sumPacketsReceived = 0_8
      sumBytesSent = 0_8
      sumBytesReceived = 0_8
      currentTime = tSub0

C--   Globally synchronized release intervals remain scratch until commit.
      DO WHILE ( currentTime.LT.tSub1 )
        nextTime = tSub1
        DO owner=1,nOwner
          IF ( activeStart(owner).GT.currentTime .AND.
     &         activeStart(owner).LT.nextTime )
     &         nextTime = activeStart(owner)
        ENDDO
        CALL BOM_P3_GLOBAL_MIN_TIME(
     I       nextTime,
     O       nextTime,globalValid,myThid)
        IF ( .NOT.globalValid .OR.
     &       nextTime.LE.currentTime .OR.
     &       nextTime.GT.tSub1 ) THEN
          failCode = BOM_FAIL_RELEASE
          p3FailPhase = BOM_P3_PHASE_POSITION
          RETURN
        ENDIF
        activeLocal = 0
        DO owner=1,nOwner
          IF ( statusFinal(owner).EQ.BOM_ALIVE .AND.
     &         activeStart(owner).LE.currentTime ) THEN
            statusStage(owner) = BOM_ALIVE
            activeLocal = activeLocal+1
          ELSE
            statusStage(owner) = BOM_WAITING
          ENDIF
        ENDDO
        activeGlobal = activeLocal
        CALL GLOBAL_SUM_INT(activeGlobal,myThid)
        CALL BOM_NONNEG_TIME_DIFF(
     I       nextTime,currentTime,
     O       intervalDt,calcValid)
        IF ( .NOT.calcValid ) THEN
          failCode = BOM_FAIL_RELEASE
          p3FailPhase = BOM_P3_PHASE_POSITION
          RETURN
        ENDIF
        IF ( activeGlobal.GT.0 .AND.
     &       intervalDt.GT.0. _d 0 ) THEN
          CALL BOM_SPRING_RK_INTERVAL(
     I         integratorOrder,nOwner,ownerId,statusStage,
     I         xWork,yWork,ownerBi,ownerBj,
     I         currentTime,intervalDt,mySubstep,
     U         epochCounter,
     O         xNext,yNext,
     U         maxOwnerRecords,maxGhostRecords,
     U         maxNonEmptyCells,sumComparisons,
     U         sumDirected,sumUndirected,maxNeighbors,
     U         rebuildCount,sumPacketsSent,
     U         sumPacketsReceived,sumBytesSent,
     U         sumBytesReceived,
     O         failStage,finalPhase,finalFail,
     O         intervalValid,myThid)
          IF ( .NOT.intervalValid ) THEN
            failCode = finalFail
            p3FailPhase = finalPhase
            RETURN
          ENDIF
          DO owner=1,nOwner
            IF ( statusStage(owner).EQ.BOM_ALIVE ) THEN
              xWork(owner) = xNext(owner)
              yWork(owner) = yNext(owner)
            ENDIF
          ENDDO
        ENDIF
        currentTime = nextTime
      ENDDO

C--   FINAL graph, spring and base RHS use accepted trial positions.
      DO owner=1,nOwner
        statusStage(owner) = statusFinal(owner)
      ENDDO
      failStage = BOM_STAGE_FINAL
      CALL BOM_VALIDATE_SPRING_POSITIONS(
     I     nOwner,statusStage,xWork,yWork,ownerBi,ownerBj,
     I     BOM_STAGE_FINAL,
     O     finalFail,finalPhase,globalValid,myThid)
      IF ( .NOT.globalValid ) THEN
        failCode = finalFail
        p3FailPhase = finalPhase
        RETURN
      ENDIF
      IF ( epochCounter.GE.HUGE(epochCounter) ) THEN
        failCode = BOM_FAIL_STATE
        p3FailPhase = BOM_P3_PHASE_GHOST
        RETURN
      ENDIF
      epochCounter = epochCounter+1
      CALL BOM_SPRING_RHS_STAGE(
     I     nOwner,ownerId,statusStage,xWork,yWork,ownerBi,ownerBj,
     I     tSub1,0. _d 0,BOM_STAGE_FINAL,
     I     epochCounter,mySubstep,
     O     finalRateX,finalRateY,finalI,finalJ,
     O     finalDiag,finalSpringEast,finalSpringNorth,
     O     finalNeighbor,finalWet,finalCFL,
     O     ownerRecords,ghostRecords,nonEmptyCells,
     O     candidateComparisons,directedNeighbors,
     O     undirectedEdges,maximumNeighbors,
     O     finalFail,finalPhase,finalValid,myThid)
      IF ( .NOT.finalValid ) THEN
        failCode = finalFail
        p3FailPhase = finalPhase
        RETURN
      ENDIF
      IF ( bomRaftDiagnostics ) THEN
        CALL BOM_COMPONENT_FETCH(
     I       nOwner,ownerId,BOM_STAGE_FINAL,
     I       epochCounter,mySubstep,
     O       finalRaftId,finalRaftSize,
     O       componentFail,componentValid,myThid)
        IF ( .NOT.componentValid ) THEN
          failCode = componentFail
          p3FailPhase = BOM_P3_PHASE_COMPONENT
          RETURN
        ENDIF
      ELSE
        DO owner=1,nOwner
          finalRaftId(owner) = 0_8
          finalRaftSize(owner) = 0
        ENDDO
      ENDIF
      CALL BOM_P3_ACCUMULATE_STAGE_STATS(
     I     ownerRecords,ghostRecords,nonEmptyCells,
     I     candidateComparisons,directedNeighbors,
     I     undirectedEdges,maximumNeighbors,
     I     bomGhostRecordsSent,bomGhostRecordsReceived,
     I     bomGhostBytesSent,bomGhostBytesReceived,
     U     maxOwnerRecords,maxGhostRecords,maxNonEmptyCells,
     U     sumComparisons,sumDirected,sumUndirected,maxNeighbors,
     U     rebuildCount,sumPacketsSent,sumPacketsReceived,
     U     sumBytesSent,sumBytesReceived,
     O     statsValid)
      localFail = BOM_FAIL_NONE
      localPhase = BOM_P3_PHASE_NONE
      IF ( .NOT.statsValid ) THEN
        localFail = BOM_FAIL_CELL_CAPACITY
        localPhase = BOM_P3_PHASE_CELL
      ENDIF
      CALL BOM_P3_GLOBAL_STATUS(
     I     localFail,localPhase,
     O     globalFail,globalPhase,globalValid,myThid)
      IF ( .NOT.globalValid ) THEN
        failCode = globalFail
        p3FailPhase = globalPhase
        RETURN
      ENDIF

C--   The only authoritative owner and P3 diagnostic publication.
      DO owner=1,nOwner
        IF ( refreshFinal(owner) ) THEN
          ip = ownerIp(owner)
          bi = ownerBi(owner)
          bj = ownerBj(owner)
          bomX(ip,bi,bj) = xWork(owner)
          bomY(ip,bi,bj) = yWork(owner)
          bomStatus(ip,bi,bj) = statusFinal(owner)
          bomAge(ip,bi,bj) = ageFinal(owner)
          bomI(ip,bi,bj) = finalI(owner)
          bomJ(ip,bi,bj) = finalJ(owner)
          bomVEast(ip,bi,bj) =
     &         finalDiag(BOM_RHS_VBASE_E,owner)
          bomVNorth(ip,bi,bj) =
     &         finalDiag(BOM_RHS_VBASE_N,owner)
          bomWindEast(ip,bi,bj) =
     &         finalDiag(BOM_RHS_VW_E,owner)
          bomWindNorth(ip,bi,bj) =
     &         finalDiag(BOM_RHS_VW_N,owner)
          bomDriftEast(ip,bi,bj) =
     &         finalDiag(BOM_RHS_DRIFT_E,owner)
          bomDriftNorth(ip,bi,bj) =
     &         finalDiag(BOM_RHS_DRIFT_N,owner)
          bomSpringEast(ip,bi,bj) = finalSpringEast(owner)
          bomSpringNorth(ip,bi,bj) = finalSpringNorth(owner)
          bomNeighborCount(ip,bi,bj) = finalNeighbor(owner)
          bomRaftId(ip,bi,bj) = finalRaftId(owner)
          bomRaftSize(ip,bi,bj) = finalRaftSize(owner)
          DO iDiag=1,BOM_RHS_NDIAG
            bomRhsDiag(iDiag,ip,bi,bj) = finalDiag(iDiag,owner)
          ENDDO
        ENDIF
      ENDDO
      bomP3OwnerRecords = maxOwnerRecords
      bomP3GhostRecords = maxGhostRecords
      bomP3NonEmptyCells = maxNonEmptyCells
      bomP3CandidateComparisons = sumComparisons
      bomP3DirectedNeighbors = sumDirected
      bomP3UndirectedEdges = sumUndirected
      bomP3MaximumNeighbors = maxNeighbors
      bomP3RebuildCount = rebuildCount
      bomP3GhostPacketsSent = sumPacketsSent
      bomP3GhostPacketsReceived = sumPacketsReceived
      bomP3GhostBytesSent = sumBytesSent
      bomP3GhostBytesReceived = sumBytesReceived
      failStage = BOM_STAGE_NONE
      p3FailPhase = BOM_P3_PHASE_NONE
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
#endif /* ALLOW_BOM */
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_SPRING_RK_INTERVAL
C !INTERFACE:
      SUBROUTINE BOM_SPRING_RK_INTERVAL(
     I                 integratorOrder, nOwner, ownerId, ownerStatus,
     I                 x0, y0, ownerBi, ownerBj,
     I                 stageTime0, deltaT, ghostSubstep,
     U                 epochCounter,
     O                 xOut, yOut,
     U                 maxOwnerRecords, maxGhostRecords,
     U                 maxNonEmptyCells, sumComparisons,
     U                 sumDirected, sumUndirected, maxNeighbors,
     U                 rebuildCount, sumPacketsSent,
     U                 sumPacketsReceived, sumBytesSent,
     U                 sumBytesReceived,
     O                 failStage, p3FailPhase, failCode, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Advance one positive release interval.  Every K stage is formed from
C     the same interval X0 and previously accepted complete K arrays.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER integratorOrder, nOwner, ghostSubstep
      INTEGER epochCounter, failStage, p3FailPhase, failCode, myThid
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord), ownerBj(bomMaxOwnerRecord)
      _RL x0(bomMaxOwnerRecord), y0(bomMaxOwnerRecord)
      _RL stageTime0, deltaT
      _RL xOut(bomMaxOwnerRecord), yOut(bomMaxOwnerRecord)
      INTEGER*8 maxOwnerRecords, maxGhostRecords
      INTEGER*8 maxNonEmptyCells, sumComparisons
      INTEGER*8 sumDirected, sumUndirected, maxNeighbors
      INTEGER*8 rebuildCount, sumPacketsSent, sumPacketsReceived
      INTEGER*8 sumBytesSent, sumBytesReceived
      LOGICAL isValid
CEOP

      INTEGER owner, iDiag, stageFail, stagePhase, coordErrors
      INTEGER globalFail, globalPhase
      _RL xStage(bomMaxOwnerRecord), yStage(bomMaxOwnerRecord)
      _RL k1X(bomMaxOwnerRecord), k1Y(bomMaxOwnerRecord)
      _RL k2X(bomMaxOwnerRecord), k2Y(bomMaxOwnerRecord)
      _RL k3X(bomMaxOwnerRecord), k3Y(bomMaxOwnerRecord)
      _RL k4X(bomMaxOwnerRecord), k4Y(bomMaxOwnerRecord)
      _RL mappedI(bomMaxOwnerRecord), mappedJ(bomMaxOwnerRecord)
      _RL rhsDiag(BOM_RHS_NDIAG,bomMaxOwnerRecord)
      _RL springEast(bomMaxOwnerRecord)
      _RL springNorth(bomMaxOwnerRecord)
      INTEGER neighborCount(bomMaxOwnerRecord)
      _RL wetWeight(bomMaxOwnerRecord), stageCFL(bomMaxOwnerRecord)
      _RL timeMid, timeFinal
      INTEGER*8 ownerRecords, ghostRecords, nonEmptyCells
      INTEGER*8 comparisons, directed, undirected, maximum
      LOGICAL coordValid, stageValid, globalValid, statsValid
      SAVE rhsDiag

      failStage = BOM_STAGE_NONE
      p3FailPhase = BOM_P3_PHASE_NONE
      failCode = BOM_FAIL_STATE
      isValid = .FALSE.
      IF ( integratorOrder.NE.2 .AND. integratorOrder.NE.4 ) RETURN
      IF ( deltaT.LE.0. _d 0 ) RETURN

      CALL BOM_RK_COORD_UPDATE(
     I     stageTime0,oneRL,deltaT,halfRL,
     O     timeMid,coordValid)
      IF ( .NOT.coordValid ) RETURN
      CALL BOM_RK_COORD_UPDATE(
     I     stageTime0,oneRL,deltaT,oneRL,
     O     timeFinal,coordValid)
      IF ( .NOT.coordValid ) RETURN

C--   K1.
      failStage = BOM_STAGE_K1
      CALL BOM_VALIDATE_SPRING_POSITIONS(
     I     nOwner,ownerStatus,x0,y0,ownerBi,ownerBj,BOM_STAGE_K1,
     O     stageFail,stagePhase,globalValid,myThid)
      IF ( .NOT.globalValid ) GOTO 900
      epochCounter = epochCounter+1
      CALL BOM_SPRING_RHS_STAGE(
     I     nOwner,ownerId,ownerStatus,x0,y0,ownerBi,ownerBj,
     I     stageTime0,deltaT,BOM_STAGE_K1,
     I     epochCounter,ghostSubstep,
     O     k1X,k1Y,mappedI,mappedJ,rhsDiag,
     O     springEast,springNorth,neighborCount,
     O     wetWeight,stageCFL,ownerRecords,ghostRecords,
     O     nonEmptyCells,comparisons,directed,undirected,maximum,
     O     stageFail,stagePhase,stageValid,myThid)
      IF ( .NOT.stageValid ) GOTO 900
      CALL BOM_P3_ACCUMULATE_STAGE_STATS(
     I     ownerRecords,ghostRecords,nonEmptyCells,
     I     comparisons,directed,undirected,maximum,
     I     bomGhostRecordsSent,bomGhostRecordsReceived,
     I     bomGhostBytesSent,bomGhostBytesReceived,
     U     maxOwnerRecords,maxGhostRecords,maxNonEmptyCells,
     U     sumComparisons,sumDirected,sumUndirected,maxNeighbors,
     U     rebuildCount,sumPacketsSent,sumPacketsReceived,
     U     sumBytesSent,sumBytesReceived,
     O     statsValid)
      CALL BOM_P3_STATS_STATUS(
     I     statsValid,
     O     globalFail,globalPhase,globalValid,myThid)
      IF ( .NOT.globalValid ) THEN
        stageFail = globalFail
        stagePhase = globalPhase
        GOTO 900
      ENDIF

C--   K2 uses X0 + dt*K1/2 for both integrators.
      failStage = BOM_STAGE_K2
      coordErrors = 0
      DO owner=1,nOwner
        xStage(owner) = x0(owner)
        yStage(owner) = y0(owner)
        IF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
          CALL BOM_RK_COORD_UPDATE(
     I         x0(owner),k1X(owner),deltaT,halfRL,
     O         xStage(owner),coordValid)
          IF ( .NOT.coordValid ) coordErrors=coordErrors+1
          CALL BOM_RK_COORD_UPDATE(
     I         y0(owner),k1Y(owner),deltaT,halfRL,
     O         yStage(owner),coordValid)
          IF ( .NOT.coordValid ) coordErrors=coordErrors+1
        ENDIF
      ENDDO
      IF ( coordErrors.GT.0 ) THEN
        stageFail = BOM_FAIL_NONFINITE
        stagePhase = BOM_P3_PHASE_POSITION
      ELSE
        stageFail = BOM_FAIL_NONE
        stagePhase = BOM_P3_PHASE_NONE
      ENDIF
      CALL BOM_P3_GLOBAL_STATUS(
     I     stageFail,stagePhase,
     O     globalFail,globalPhase,globalValid,myThid)
      IF ( .NOT.globalValid ) THEN
        stageFail = globalFail
        stagePhase = globalPhase
        GOTO 900
      ENDIF
      CALL BOM_VALIDATE_SPRING_POSITIONS(
     I     nOwner,ownerStatus,xStage,yStage,ownerBi,ownerBj,
     I     BOM_STAGE_K2,
     O     stageFail,stagePhase,globalValid,myThid)
      IF ( .NOT.globalValid ) GOTO 900
      epochCounter = epochCounter+1
      CALL BOM_SPRING_RHS_STAGE(
     I     nOwner,ownerId,ownerStatus,xStage,yStage,ownerBi,ownerBj,
     I     timeMid,deltaT,BOM_STAGE_K2,
     I     epochCounter,ghostSubstep,
     O     k2X,k2Y,mappedI,mappedJ,rhsDiag,
     O     springEast,springNorth,neighborCount,
     O     wetWeight,stageCFL,ownerRecords,ghostRecords,
     O     nonEmptyCells,comparisons,directed,undirected,maximum,
     O     stageFail,stagePhase,stageValid,myThid)
      IF ( .NOT.stageValid ) GOTO 900
      CALL BOM_P3_ACCUMULATE_STAGE_STATS(
     I     ownerRecords,ghostRecords,nonEmptyCells,
     I     comparisons,directed,undirected,maximum,
     I     bomGhostRecordsSent,bomGhostRecordsReceived,
     I     bomGhostBytesSent,bomGhostBytesReceived,
     U     maxOwnerRecords,maxGhostRecords,maxNonEmptyCells,
     U     sumComparisons,sumDirected,sumUndirected,maxNeighbors,
     U     rebuildCount,sumPacketsSent,sumPacketsReceived,
     U     sumBytesSent,sumBytesReceived,
     O     statsValid)
      CALL BOM_P3_STATS_STATUS(
     I     statsValid,
     O     globalFail,globalPhase,globalValid,myThid)
      IF ( .NOT.globalValid ) THEN
        stageFail = globalFail
        stagePhase = globalPhase
        GOTO 900
      ENDIF

      IF ( integratorOrder.EQ.2 ) THEN
        coordErrors = 0
        DO owner=1,nOwner
          xOut(owner) = x0(owner)
          yOut(owner) = y0(owner)
          IF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
            CALL BOM_RK_COORD_UPDATE(
     I           x0(owner),k2X(owner),deltaT,oneRL,
     O           xOut(owner),coordValid)
            IF ( .NOT.coordValid ) coordErrors=coordErrors+1
            CALL BOM_RK_COORD_UPDATE(
     I           y0(owner),k2Y(owner),deltaT,oneRL,
     O           yOut(owner),coordValid)
            IF ( .NOT.coordValid ) coordErrors=coordErrors+1
          ENDIF
        ENDDO
      ELSE
C--     RK4 K3.
        failStage = BOM_STAGE_K3
        coordErrors = 0
        DO owner=1,nOwner
          xStage(owner) = x0(owner)
          yStage(owner) = y0(owner)
          IF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
            CALL BOM_RK_COORD_UPDATE(
     I           x0(owner),k2X(owner),deltaT,halfRL,
     O           xStage(owner),coordValid)
            IF ( .NOT.coordValid ) coordErrors=coordErrors+1
            CALL BOM_RK_COORD_UPDATE(
     I           y0(owner),k2Y(owner),deltaT,halfRL,
     O           yStage(owner),coordValid)
            IF ( .NOT.coordValid ) coordErrors=coordErrors+1
          ENDIF
        ENDDO
        IF ( coordErrors.GT.0 ) THEN
          stageFail = BOM_FAIL_NONFINITE
          stagePhase = BOM_P3_PHASE_POSITION
        ELSE
          stageFail = BOM_FAIL_NONE
          stagePhase = BOM_P3_PHASE_NONE
        ENDIF
        CALL BOM_P3_GLOBAL_STATUS(
     I       stageFail,stagePhase,
     O       globalFail,globalPhase,globalValid,myThid)
        IF ( .NOT.globalValid ) THEN
          stageFail = globalFail
          stagePhase = globalPhase
          GOTO 900
        ENDIF
        CALL BOM_VALIDATE_SPRING_POSITIONS(
     I       nOwner,ownerStatus,xStage,yStage,ownerBi,ownerBj,
     I       BOM_STAGE_K3,
     O       stageFail,stagePhase,globalValid,myThid)
        IF ( .NOT.globalValid ) GOTO 900
        epochCounter = epochCounter+1
        CALL BOM_SPRING_RHS_STAGE(
     I       nOwner,ownerId,ownerStatus,xStage,yStage,
     I       ownerBi,ownerBj,timeMid,deltaT,BOM_STAGE_K3,
     I       epochCounter,ghostSubstep,
     O       k3X,k3Y,mappedI,mappedJ,rhsDiag,
     O       springEast,springNorth,neighborCount,
     O       wetWeight,stageCFL,ownerRecords,ghostRecords,
     O       nonEmptyCells,comparisons,directed,undirected,maximum,
     O       stageFail,stagePhase,stageValid,myThid)
        IF ( .NOT.stageValid ) GOTO 900
        CALL BOM_P3_ACCUMULATE_STAGE_STATS(
     I       ownerRecords,ghostRecords,nonEmptyCells,
     I       comparisons,directed,undirected,maximum,
     I       bomGhostRecordsSent,bomGhostRecordsReceived,
     I       bomGhostBytesSent,bomGhostBytesReceived,
     U       maxOwnerRecords,maxGhostRecords,maxNonEmptyCells,
     U       sumComparisons,sumDirected,sumUndirected,maxNeighbors,
     U       rebuildCount,sumPacketsSent,sumPacketsReceived,
     U       sumBytesSent,sumBytesReceived,
     O       statsValid)
        CALL BOM_P3_STATS_STATUS(
     I       statsValid,
     O       globalFail,globalPhase,globalValid,myThid)
        IF ( .NOT.globalValid ) THEN
          stageFail = globalFail
          stagePhase = globalPhase
          GOTO 900
        ENDIF

C--     RK4 K4.
        failStage = BOM_STAGE_K4
        coordErrors = 0
        DO owner=1,nOwner
          xStage(owner) = x0(owner)
          yStage(owner) = y0(owner)
          IF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
            CALL BOM_RK_COORD_UPDATE(
     I           x0(owner),k3X(owner),deltaT,oneRL,
     O           xStage(owner),coordValid)
            IF ( .NOT.coordValid ) coordErrors=coordErrors+1
            CALL BOM_RK_COORD_UPDATE(
     I           y0(owner),k3Y(owner),deltaT,oneRL,
     O           yStage(owner),coordValid)
            IF ( .NOT.coordValid ) coordErrors=coordErrors+1
          ENDIF
        ENDDO
        IF ( coordErrors.GT.0 ) THEN
          stageFail = BOM_FAIL_NONFINITE
          stagePhase = BOM_P3_PHASE_POSITION
        ELSE
          stageFail = BOM_FAIL_NONE
          stagePhase = BOM_P3_PHASE_NONE
        ENDIF
        CALL BOM_P3_GLOBAL_STATUS(
     I       stageFail,stagePhase,
     O       globalFail,globalPhase,globalValid,myThid)
        IF ( .NOT.globalValid ) THEN
          stageFail = globalFail
          stagePhase = globalPhase
          GOTO 900
        ENDIF
        CALL BOM_VALIDATE_SPRING_POSITIONS(
     I       nOwner,ownerStatus,xStage,yStage,ownerBi,ownerBj,
     I       BOM_STAGE_K4,
     O       stageFail,stagePhase,globalValid,myThid)
        IF ( .NOT.globalValid ) GOTO 900
        epochCounter = epochCounter+1
        CALL BOM_SPRING_RHS_STAGE(
     I       nOwner,ownerId,ownerStatus,xStage,yStage,
     I       ownerBi,ownerBj,timeFinal,deltaT,BOM_STAGE_K4,
     I       epochCounter,ghostSubstep,
     O       k4X,k4Y,mappedI,mappedJ,rhsDiag,
     O       springEast,springNorth,neighborCount,
     O       wetWeight,stageCFL,ownerRecords,ghostRecords,
     O       nonEmptyCells,comparisons,directed,undirected,maximum,
     O       stageFail,stagePhase,stageValid,myThid)
        IF ( .NOT.stageValid ) GOTO 900
        CALL BOM_P3_ACCUMULATE_STAGE_STATS(
     I       ownerRecords,ghostRecords,nonEmptyCells,
     I       comparisons,directed,undirected,maximum,
     I       bomGhostRecordsSent,bomGhostRecordsReceived,
     I       bomGhostBytesSent,bomGhostBytesReceived,
     U       maxOwnerRecords,maxGhostRecords,maxNonEmptyCells,
     U       sumComparisons,sumDirected,sumUndirected,maxNeighbors,
     U       rebuildCount,sumPacketsSent,sumPacketsReceived,
     U       sumBytesSent,sumBytesReceived,
     O       statsValid)
        CALL BOM_P3_STATS_STATUS(
     I       statsValid,
     O       globalFail,globalPhase,globalValid,myThid)
        IF ( .NOT.globalValid ) THEN
          stageFail = globalFail
          stagePhase = globalPhase
          GOTO 900
        ENDIF

        coordErrors = 0
        DO owner=1,nOwner
          xOut(owner) = x0(owner)
          yOut(owner) = y0(owner)
          IF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
            CALL BOM_RK4_COORD_UPDATE(
     I           x0(owner),k1X(owner),k2X(owner),
     I           k3X(owner),k4X(owner),deltaT,
     O           xOut(owner),coordValid)
            IF ( .NOT.coordValid ) coordErrors=coordErrors+1
            CALL BOM_RK4_COORD_UPDATE(
     I           y0(owner),k1Y(owner),k2Y(owner),
     I           k3Y(owner),k4Y(owner),deltaT,
     O           yOut(owner),coordValid)
            IF ( .NOT.coordValid ) coordErrors=coordErrors+1
          ENDIF
        ENDDO
      ENDIF

      IF ( coordErrors.GT.0 ) THEN
        stageFail = BOM_FAIL_NONFINITE
        stagePhase = BOM_P3_PHASE_POSITION
      ELSE
        stageFail = BOM_FAIL_NONE
        stagePhase = BOM_P3_PHASE_NONE
      ENDIF
      CALL BOM_P3_GLOBAL_STATUS(
     I     stageFail,stagePhase,
     O     globalFail,globalPhase,globalValid,myThid)
      IF ( .NOT.globalValid ) THEN
        stageFail = globalFail
        stagePhase = globalPhase
        GOTO 900
      ENDIF

      failStage = BOM_STAGE_FINAL
      CALL BOM_VALIDATE_SPRING_POSITIONS(
     I     nOwner,ownerStatus,xOut,yOut,ownerBi,ownerBj,
     I     BOM_STAGE_FINAL,
     O     stageFail,stagePhase,globalValid,myThid)
      IF ( .NOT.globalValid ) GOTO 900
      failStage = BOM_STAGE_NONE
      p3FailPhase = BOM_P3_PHASE_NONE
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
      RETURN

  900 CONTINUE
      failCode = stageFail
      p3FailPhase = stagePhase
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VALIDATE_SPRING_POSITIONS(
     I                 nOwner, ownerStatus, ownerX, ownerY,
     I                 ownerBi, ownerBj, rhsStage,
     O                 failCode, p3FailPhase, isValid,
     I                 myThid )
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nOwner, rhsStage, myThid
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord), ownerBj(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord), ownerY(bomMaxOwnerRecord)
      INTEGER failCode, p3FailPhase
      LOGICAL isValid
      INTEGER owner, localFail, localPhase, globalFail, globalPhase
      _RL xMap, ix, jy
      LOGICAL isOwner, hasStencil, globalValid

      localFail = BOM_FAIL_NONE
      localPhase = BOM_P3_PHASE_NONE
      IF ( nOwner.LT.0 .OR. nOwner.GT.bomMaxOwnerRecord .OR.
     &     rhsStage.LT.BOM_STAGE_K1 .OR.
     &     rhsStage.GT.BOM_STAGE_FINAL ) THEN
        localFail = BOM_FAIL_STATE
        localPhase = BOM_P3_PHASE_POSITION
      ENDIF
      DO owner=1,MAX(0,MIN(nOwner,bomMaxOwnerRecord))
        IF ( localFail.EQ.BOM_FAIL_NONE .AND.
     &       ownerStatus(owner).EQ.BOM_ALIVE ) THEN
          IF ( .NOT.IEEE_IS_FINITE(ownerX(owner)) .OR.
     &         .NOT.IEEE_IS_FINITE(ownerY(owner)) ) THEN
            localFail = BOM_FAIL_NONFINITE
            localPhase = BOM_P3_PHASE_POSITION
          ELSEIF ( ownerBi(owner).LT.1 .OR.
     &             ownerBi(owner).GT.nSx .OR.
     &             ownerBj(owner).LT.1 .OR.
     &             ownerBj(owner).GT.nSy ) THEN
            localFail = BOM_FAIL_OWNER
            localPhase = BOM_P3_PHASE_POSITION
          ELSE
            CALL BOM_MAP_XY2IJLOCAL(
     I           ownerX(owner),ownerY(owner),
     I           ownerBi(owner),ownerBj(owner),
     O           xMap,ix,jy,isOwner,hasStencil,myThid)
            IF ( .NOT.hasStencil ) THEN
              localFail = BOM_FAIL_STENCIL
              localPhase = BOM_P3_PHASE_POSITION
            ENDIF
          ENDIF
        ELSEIF ( localFail.EQ.BOM_FAIL_NONE .AND.
     &           ownerStatus(owner).NE.BOM_WAITING .AND.
     &           ownerStatus(owner).NE.BOM_ALIVE ) THEN
          localFail = BOM_FAIL_STATE
          localPhase = BOM_P3_PHASE_POSITION
        ENDIF
      ENDDO
      CALL BOM_P3_GLOBAL_STATUS(
     I     localFail,localPhase,
     O     globalFail,globalPhase,globalValid,myThid)
      failCode = globalFail
      p3FailPhase = globalPhase
      isValid = globalValid
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P3_GLOBAL_MIN_TIME(
     I                 localTime,
     O                 globalTime, isValid,
     I                 myThid )
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
      _RL localTime, globalTime
      INTEGER myThid
      LOGICAL isValid
#ifdef ALLOW_USE_MPI
      INTEGER mpiRC
#endif
      globalTime = localTime
      isValid = IEEE_IS_FINITE(localTime)
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allreduce(
     I       localTime,globalTime,1,_MPI_TYPE_RL,MPI_MIN,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) isValid=.FALSE.
      ENDIF
#endif
      isValid = isValid.AND.IEEE_IS_FINITE(globalTime)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P3_STATS_STATUS(
     I                 statsValid,
     O                 failCode, failPhase, isValid,
     I                 myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      LOGICAL statsValid, isValid
      INTEGER failCode, failPhase, myThid
      INTEGER localFail, localPhase
      IF ( statsValid ) THEN
        localFail = BOM_FAIL_NONE
        localPhase = BOM_P3_PHASE_NONE
      ELSE
        localFail = BOM_FAIL_CELL_CAPACITY
        localPhase = BOM_P3_PHASE_CELL
      ENDIF
      CALL BOM_P3_GLOBAL_STATUS(
     I     localFail,localPhase,
     O     failCode,failPhase,isValid,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P3_ACCUMULATE_STAGE_STATS(
     I                 ownerRecords, ghostRecords, nonEmptyCells,
     I                 comparisons, directed, undirected, maximum,
     I                 packetsSent, packetsReceived,
     I                 bytesSent, bytesReceived,
     U                 maxOwnerRecords, maxGhostRecords,
     U                 maxNonEmptyCells, sumComparisons,
     U                 sumDirected, sumUndirected, maxNeighbors,
     U                 rebuildCount, sumPacketsSent,
     U                 sumPacketsReceived, sumBytesSent,
     U                 sumBytesReceived,
     O                 isValid )
      IMPLICIT NONE
      INTEGER*8 ownerRecords, ghostRecords, nonEmptyCells
      INTEGER*8 comparisons, directed, undirected, maximum
      INTEGER*8 packetsSent, packetsReceived, bytesSent, bytesReceived
      INTEGER*8 maxOwnerRecords, maxGhostRecords, maxNonEmptyCells
      INTEGER*8 sumComparisons, sumDirected, sumUndirected
      INTEGER*8 maxNeighbors, rebuildCount
      INTEGER*8 sumPacketsSent, sumPacketsReceived
      INTEGER*8 sumBytesSent, sumBytesReceived
      LOGICAL isValid

      isValid = .FALSE.
      IF ( MIN(ownerRecords,ghostRecords,nonEmptyCells,
     &         comparisons,directed,undirected,maximum,
     &         packetsSent,packetsReceived,
     &         bytesSent,bytesReceived).LT.0_8 ) RETURN
      IF ( sumComparisons.GT.HUGE(sumComparisons)-comparisons ) RETURN
      IF ( sumDirected.GT.HUGE(sumDirected)-directed ) RETURN
      IF ( sumUndirected.GT.HUGE(sumUndirected)-undirected ) RETURN
      IF ( rebuildCount.EQ.HUGE(rebuildCount) ) RETURN
      IF ( sumPacketsSent.GT.HUGE(sumPacketsSent)-packetsSent ) RETURN
      IF ( sumPacketsReceived.GT.
     &     HUGE(sumPacketsReceived)-packetsReceived ) RETURN
      IF ( sumBytesSent.GT.HUGE(sumBytesSent)-bytesSent ) RETURN
      IF ( sumBytesReceived.GT.
     &     HUGE(sumBytesReceived)-bytesReceived ) RETURN
      maxOwnerRecords = MAX(maxOwnerRecords,ownerRecords)
      maxGhostRecords = MAX(maxGhostRecords,ghostRecords)
      maxNonEmptyCells = MAX(maxNonEmptyCells,nonEmptyCells)
      sumComparisons = sumComparisons+comparisons
      sumDirected = sumDirected+directed
      sumUndirected = sumUndirected+undirected
      maxNeighbors = MAX(maxNeighbors,maximum)
      rebuildCount = rebuildCount+1_8
      sumPacketsSent = sumPacketsSent+packetsSent
      sumPacketsReceived = sumPacketsReceived+packetsReceived
      sumBytesSent = sumBytesSent+bytesSent
      sumBytesReceived = sumBytesReceived+bytesReceived
      isValid = .TRUE.
      RETURN
      END
