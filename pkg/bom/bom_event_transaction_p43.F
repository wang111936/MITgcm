#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_EVENT_TRANSACTION_P43
C !INTERFACE:
      SUBROUTINE BOM_EVENT_TRANSACTION_P43(
     I                 tSub0,tSub1,myIter,mySubstep,injectPhase,
     O                 failCode,p4FailPhase,failRank,
     O                 failBi,failBj,failSlot,failId,isValid,
     I                 myThid)

C !DESCRIPTION:
C     Execute one biology-enabled post-migration event transaction.  Death,
C     land terminals, deterministic birth placement, contiguous child IDs,
C     and the post-event cutoff graph are preflighted before one owner/event
C     commit.  Collectives carry bounded event metadata, never live owners.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      _RL tSub0,tSub1
      INTEGER myIter,mySubstep,injectPhase,myThid
      INTEGER failCode,p4FailPhase,failRank,failBi,failBj,failSlot
      INTEGER*8 failId
      LOGICAL isValid

#ifdef ALLOW_BOM
      INTEGER bi,bj,ip,jp,kp,nPart,matchCount,matchPlan
      INTEGER bindBi,bindBj,bindSlot,searchBi,searchBj
      INTEGER nPlan,nBirth,nAccept,nGlobalBirth,nGlobalProposal
      INTEGER nCandidate,nLocalDest,nLocalTerminal,eventSlot
      INTEGER localOwners,globalOwners,globalTerminal,globalAfter
      INTEGER localDeath,localBeach,localOutside,localCancel
      INTEGER globalDeath,globalBeach,globalOutside,globalCancel
      INTEGER localMissing,globalMissing,firstEventSlot
      INTEGER localFailCode,localFailPhase,localFailBi,localFailBj
      INTEGER localFailSlot,orderFail,orderPhase,orderRank
      INTEGER orderBi,orderBj,orderSlot,freeFailCode,newSlot
      INTEGER birthEvent,birthDestRank,birthDestBi,birthDestBj
      INTEGER birthFail,birthPhase,ordinal
      INTEGER bioFail,bioPhase,eventType,bioSlot,newStatus
      INTEGER graphFail,graphPhase,graphEpoch
      INTEGER componentFail,componentIterations,maximumComponent
      INTEGER preflightFail,preflightPhase,preflightRank
      INTEGER preflightBi,preflightBj,preflightSlot
      INTEGER tileSurvivor(nSx,nSy),tileBirth(nSx,nSy)
      INTEGER planType(bomMaxEventBuffer)
      INTEGER planStage(bomMaxEventBuffer)
      INTEGER planBi(bomMaxEventBuffer)
      INTEGER planBj(bomMaxEventBuffer)
      INTEGER planSlot(bomMaxEventBuffer)
      INTEGER planSourceRank(bomMaxEventBuffer)
      INTEGER planSourceBi(bomMaxEventBuffer)
      INTEGER planSourceBj(bomMaxEventBuffer)
      INTEGER bBi(bomMaxEventBuffer),bBj(bomMaxEventBuffer)
      INTEGER bSlot(bomMaxEventBuffer),bOrdinal(bomMaxEventBuffer)
      INTEGER bCount(bomMaxEventBuffer),bAttempt(bomMaxEventBuffer)
      INTEGER bEvent(bomMaxEventBuffer),bDestRank(bomMaxEventBuffer)
      INTEGER bDestBi(bomMaxEventBuffer),bDestBj(bomMaxEventBuffer)
      INTEGER aCount(bomMaxEventBuffer),aAttempt(bomMaxEventBuffer)
      INTEGER aBi(bomMaxEventBuffer),aBj(bomMaxEventBuffer)
      INTEGER aSlot(bomMaxEventBuffer),aDestRank(bomMaxEventBuffer)
      INTEGER aDestBi(bomMaxEventBuffer),aDestBj(bomMaxEventBuffer)
      INTEGER aBirthIndex(bomMaxEventBuffer)
      INTEGER gCount(bomMaxEventBuffer),gAttempt(bomMaxEventBuffer)
      INTEGER gSourceRank(bomMaxEventBuffer)
      INTEGER gSourceBi(bomMaxEventBuffer)
      INTEGER gSourceBj(bomMaxEventBuffer)
      INTEGER gSourceSlot(bomMaxEventBuffer)
      INTEGER gDestRank(bomMaxEventBuffer)
      INTEGER gDestBi(bomMaxEventBuffer)
      INTEGER gDestBj(bomMaxEventBuffer)
      INTEGER cStatus(bomMaxOwnerRecord)
      INTEGER cBirthCount(bomMaxOwnerRecord)
      INTEGER cBi(bomMaxOwnerRecord),cBj(bomMaxOwnerRecord)
      INTEGER cNeighbor(bomMaxOwnerRecord),cRaftSize(bomMaxOwnerRecord)
      INTEGER graphNeighbor(bomMaxOwnerRecord)
      INTEGER*8 localFailId,orderId,movedId
      INTEGER*8 nextIdAfter
      INTEGER*8 preflightId,preflightNeed,preflightCapacity
      INTEGER*8 planId(bomMaxEventBuffer)
      INTEGER*8 bParentId(bomMaxEventBuffer)
      INTEGER*8 bWord(bomMaxEventBuffer),bChildId(bomMaxEventBuffer)
      INTEGER*8 aParentId(bomMaxEventBuffer)
      INTEGER*8 aEventIndex(bomMaxEventBuffer)
      INTEGER*8 aChildId(bomMaxEventBuffer)
      INTEGER*8 gParentId(bomMaxEventBuffer)
      INTEGER*8 gChildId(bomMaxEventBuffer)
      INTEGER*8 gEventIndex(bomMaxEventBuffer)
      INTEGER*8 cId(bomMaxOwnerRecord),cParentId(bomMaxOwnerRecord)
      INTEGER*8 cRaftId(bomMaxOwnerRecord)
      INTEGER*8 graphRaftId(bomMaxOwnerRecord)
      _RL planAcceptedX(bomMaxEventBuffer)
      _RL planAcceptedY(bomMaxEventBuffer)
      _RL planAttemptX(bomMaxEventBuffer)
      _RL planAttemptY(bomMaxEventBuffer)
      _RL planSBefore(bomMaxEventBuffer)
      _RL planSTrial(bomMaxEventBuffer)
      _RL planSAfter(bomMaxEventBuffer)
      _RL bSBefore(bomMaxEventBuffer),bSTrial(bomMaxEventBuffer)
      _RL bX(bomMaxEventBuffer),bY(bomMaxEventBuffer)
      _RL bPlaceI(bomMaxEventBuffer),bPlaceJ(bomMaxEventBuffer)
      _RL bFirstX(bomMaxEventBuffer),bFirstY(bomMaxEventBuffer)
      _RL bAngle(bomMaxEventBuffer)
      _RL aX(bomMaxEventBuffer),aY(bomMaxEventBuffer)
      _RL gX(bomMaxEventBuffer),gY(bomMaxEventBuffer)
      _RL sWork(bomMaxPartTile,nSx,nSy)
      _RL temperature,nutrient,wetWeight,dtActive,activeStart
      _RL tempFactor,nutrientFactor,dSdt,sTrial,sCandidate
      _RL rhsX,rhsY,stageWet,stageCFL
      _RL cX(bomMaxOwnerRecord),cY(bomMaxOwnerRecord)
      _RL cRelease(bomMaxOwnerRecord),cAge(bomMaxOwnerRecord)
      _RL cI(bomMaxOwnerRecord),cJ(bomMaxOwnerRecord)
      _RL cVEast(bomMaxOwnerRecord),cVNorth(bomMaxOwnerRecord)
      _RL cWindEast(bomMaxOwnerRecord),cWindNorth(bomMaxOwnerRecord)
      _RL cDriftEast(bomMaxOwnerRecord)
      _RL cDriftNorth(bomMaxOwnerRecord),cS(bomMaxOwnerRecord)
      _RL cSpringEast(bomMaxOwnerRecord)
      _RL cSpringNorth(bomMaxOwnerRecord)
      _RL cDiag(BOM_RHS_NDIAG,bomMaxOwnerRecord)
      _RL graphRateX(bomMaxOwnerRecord)
      _RL graphRateY(bomMaxOwnerRecord)
      _RL graphI(bomMaxOwnerRecord),graphJ(bomMaxOwnerRecord)
      _RL graphSpringEast(bomMaxOwnerRecord)
      _RL graphSpringNorth(bomMaxOwnerRecord)
      _RL graphWet(bomMaxOwnerRecord),graphCFL(bomMaxOwnerRecord)
      _RL graphDiag(BOM_RHS_NDIAG,bomMaxOwnerRecord)
      INTEGER*8 ownerRecords,ghostRecords,nonEmptyCells
      INTEGER*8 comparisons,directed,undirected,maximumNeighbors
      LOGICAL terminalSlot(bomMaxPartTile,nSx,nSy)
      LOGICAL sPublish(bomMaxPartTile,nSx,nSy)
      LOGICAL birthAccepted(bomMaxPartTile,nSx,nSy)
      LOGICAL birthCanceled(bomMaxPartTile,nSx,nSy)
      LOGICAL pointValid,interpValid,missingGrowth,planValid
      LOGICAL slotClear,freeValid,orderValid,birthValid
      LOGICAL rhsOwner,rhsValid,graphValid,componentValid
      LOGICAL doGraph,preflightValid
      INTEGER iDiag
      SAVE cDiag,graphDiag

      failCode=BOM_FAIL_EVENT_TRANSACTION
      p4FailPhase=BOM_P4_PHASE_TERMINAL
      failRank=myProcId
      failBi=0
      failBj=0
      failSlot=0
      failId=0_8
      isValid=.FALSE.
      localFailCode=BOM_FAIL_NONE
      localFailPhase=BOM_P4_PHASE_NONE
      localFailBi=0
      localFailBj=0
      localFailSlot=0
      localFailId=0_8
      nPlan=0
      nBirth=0
      nAccept=0
      localOwners=0
      localDeath=0
      localBeach=0
      localOutside=0
      localCancel=0
      localMissing=0

      IF ( .NOT.bomUseBiology .OR.
     &     .NOT.IEEE_IS_FINITE(tSub0) .OR.
     &     .NOT.IEEE_IS_FINITE(tSub1) .OR. tSub1.LT.tSub0 .OR.
     &     mySubstep.LT.1 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_TERMINAL,BOM_FAIL_EVENT_TRANSACTION,
     I     myProcId,0,0,0,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        nPart=bomNPartTile(bi,bj)
        IF ( nPart.LT.0 .OR. nPart.GT.bomMaxPartTile ) THEN
          CALL BOM_P4_KEEP_FAILURE(
     I         BOM_P4_PHASE_TERMINAL,BOM_FAIL_EVENT_TRANSACTION,
     I         myProcId,bi,bj,0,0_8,
     U         localFailPhase,localFailCode,localFailBi,localFailBj,
     U         localFailSlot,localFailId)
          nPart=MAX(0,MIN(bomMaxPartTile,nPart))
        ENDIF
        localOwners=localOwners+nPart
        DO ip=1,bomMaxPartTile
          terminalSlot(ip,bi,bj)=.FALSE.
          sPublish(ip,bi,bj)=.FALSE.
          birthAccepted(ip,bi,bj)=.FALSE.
          birthCanceled(ip,bi,bj)=.FALSE.
          sWork(ip,bi,bj)=bomS(ip,bi,bj)
          IF ( ip.GT.nPart ) THEN
            CALL BOM_OWNER_SLOT_IS_CLEAR(ip,bi,bj,slotClear)
            IF ( .NOT.slotClear ) CALL BOM_P4_KEEP_FAILURE(
     I           BOM_P4_PHASE_TERMINAL,
     I           BOM_FAIL_EVENT_TRANSACTION,
     I           myProcId,bi,bj,ip,bomId(ip,bi,bj),
     U           localFailPhase,localFailCode,
     U           localFailBi,localFailBj,localFailSlot,localFailId)
          ENDIF
        ENDDO
       ENDDO
      ENDDO

C--   Bind pre-migration terminal scratch by exact post-migration ID.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomMaxPartTile
          IF ( bomTerminalReady(ip,bi,bj) ) THEN
            IF ( .NOT.IEEE_IS_FINITE(
     &           bomTerminalAcceptedX(ip,bi,bj)) .OR.
     &           .NOT.IEEE_IS_FINITE(
     &           bomTerminalAcceptedY(ip,bi,bj)) .OR.
     &           .NOT.IEEE_IS_FINITE(
     &           bomTerminalAttemptX(ip,bi,bj)) .OR.
     &           .NOT.IEEE_IS_FINITE(
     &           bomTerminalAttemptY(ip,bi,bj)) .OR.
     &           bomTerminalId(ip,bi,bj).LE.0_8 .OR.
     &          (bomTerminalType(ip,bi,bj).NE.BOM_EVENT_BEACHED
     &           .AND. bomTerminalType(ip,bi,bj).NE.BOM_EVENT_OUTSIDE)
     &           .OR. bomTerminalStage(ip,bi,bj).LT.BOM_STAGE_K1
     &           .OR. bomTerminalStage(ip,bi,bj).GT.BOM_STAGE_FINAL )
     &           CALL BOM_P4_KEEP_FAILURE(
     I             BOM_P4_PHASE_BOUNDARY,BOM_FAIL_BOUNDARY_EVENT,
     I             myProcId,bi,bj,ip,bomTerminalId(ip,bi,bj),
     U             localFailPhase,localFailCode,
     U             localFailBi,localFailBj,localFailSlot,localFailId)
            matchCount=0
            matchPlan=0
            DO jp=1,nPlan
              IF ( planId(jp).EQ.bomTerminalId(ip,bi,bj) )
     &             matchPlan=matchPlan+1
            ENDDO
            bindBi=0
            bindBj=0
            bindSlot=0
            DO searchBj=myByLo(myThid),myByHi(myThid)
             DO searchBi=myBxLo(myThid),myBxHi(myThid)
              DO jp=1,bomNPartTile(searchBi,searchBj)
                IF ( bomId(jp,searchBi,searchBj).EQ.
     &               bomTerminalId(ip,bi,bj) ) THEN
                  matchCount=matchCount+1
                  bindBi=searchBi
                  bindBj=searchBj
                  bindSlot=jp
                ENDIF
              ENDDO
             ENDDO
            ENDDO
            IF ( matchCount.NE.1 .OR. matchPlan.NE.0 ) THEN
              CALL BOM_P4_KEEP_FAILURE(
     I             BOM_P4_PHASE_BOUNDARY,BOM_FAIL_BOUNDARY_EVENT,
     I             myProcId,bi,bj,ip,bomTerminalId(ip,bi,bj),
     U             localFailPhase,localFailCode,
     U             localFailBi,localFailBj,localFailSlot,localFailId)
            ELSEIF ( nPlan.GE.bomMaxEventBuffer ) THEN
              CALL BOM_P4_KEEP_FAILURE(
     I             BOM_P4_PHASE_CAPACITY,BOM_FAIL_EVENT_CAPACITY,
     I             myProcId,bi,bj,ip,bomTerminalId(ip,bi,bj),
     U             localFailPhase,localFailCode,
     U             localFailBi,localFailBj,localFailSlot,localFailId)
            ELSE
              nPlan=nPlan+1
              planType(nPlan)=bomTerminalType(ip,bi,bj)
              planStage(nPlan)=bomTerminalStage(ip,bi,bj)
              planBi(nPlan)=bindBi
              planBj(nPlan)=bindBj
              planSlot(nPlan)=bindSlot
              planSourceRank(nPlan)=myProcId
              planSourceBi(nPlan)=bi
              planSourceBj(nPlan)=bj
              planId(nPlan)=bomTerminalId(ip,bi,bj)
              planAcceptedX(nPlan)=bomTerminalAcceptedX(ip,bi,bj)
              planAcceptedY(nPlan)=bomTerminalAcceptedY(ip,bi,bj)
              planAttemptX(nPlan)=bomTerminalAttemptX(ip,bi,bj)
              planAttemptY(nPlan)=bomTerminalAttemptY(ip,bi,bj)
              planSBefore(nPlan)=bomS(bindSlot,bindBi,bindBj)
              planSTrial(nPlan)=bomS(bindSlot,bindBi,bindBj)
              planSAfter(nPlan)=0. _d 0
              terminalSlot(bindSlot,bindBi,bindBj)=.TRUE.
            ENDIF
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      IF ( injectPhase.EQ.BOM_P4_PHASE_BOUNDARY .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_BOUNDARY,BOM_FAIL_BOUNDARY_EVENT,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)

C--   Plan biology without changing S, birth counters, or topology.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomNPartTile(bi,bj)
          IF ( .NOT.terminalSlot(ip,bi,bj) .AND.
     &         bomStatus(ip,bi,bj).EQ.BOM_ALIVE ) THEN
            activeStart=MAX(tSub0,bomReleaseTime(ip,bi,bj))
            dtActive=MAX(0. _d 0,tSub1-activeStart)
            CALL BOM_INTERP_BIO_PAIR(
     I           bomI(ip,bi,bj),bomJ(ip,bi,bj),bi,bj,tSub1,
     O           temperature,nutrient,wetWeight,pointValid,
     O           bioFail,bioSlot,bioPhase,interpValid,
     I           myThid)
            IF ( .NOT.interpValid ) THEN
              CALL BOM_P4_KEEP_FAILURE(
     I             bioPhase,bioFail,myProcId,bi,bj,ip,
     I             bomId(ip,bi,bj),
     U             localFailPhase,localFailCode,
     U             localFailBi,localFailBj,localFailSlot,localFailId)
            ELSE
              CALL BOM_BIOLOGY_PLAN(
     I             bomStatus(ip,bi,bj),bomS(ip,bi,bj),
     I             temperature,nutrient,dtActive,pointValid,
     O             tempFactor,nutrientFactor,dSdt,
     O             sTrial,sCandidate,eventType,missingGrowth,
     O             bioFail,bioPhase,planValid)
              IF ( .NOT.planValid ) THEN
                CALL BOM_P4_KEEP_FAILURE(
     I               bioPhase,bioFail,myProcId,bi,bj,ip,
     I               bomId(ip,bi,bj),
     U               localFailPhase,localFailCode,
     U               localFailBi,localFailBj,
     U               localFailSlot,localFailId)
              ELSEIF ( missingGrowth ) THEN
                localMissing=localMissing+1
                sWork(ip,bi,bj)=sCandidate
                sPublish(ip,bi,bj)=.TRUE.
              ELSEIF ( eventType.EQ.BOM_EVENT_BIRTH ) THEN
                IF ( nBirth.GE.bomMaxEventBuffer ) THEN
                  CALL BOM_P4_KEEP_FAILURE(
     I                 BOM_P4_PHASE_CAPACITY,
     I                 BOM_FAIL_EVENT_CAPACITY,
     I                 myProcId,bi,bj,ip,bomId(ip,bi,bj),
     U                 localFailPhase,localFailCode,
     U                 localFailBi,localFailBj,
     U                 localFailSlot,localFailId)
                ELSE
                  nBirth=nBirth+1
                  bParentId(nBirth)=bomId(ip,bi,bj)
                  bBi(nBirth)=bi
                  bBj(nBirth)=bj
                  bSlot(nBirth)=ip
                  bCount(nBirth)=bomBirthCount(ip,bi,bj)
                  bSBefore(nBirth)=bomS(ip,bi,bj)
                  bSTrial(nBirth)=sTrial
                  bEvent(nBirth)=BOM_EVENT_NONE
                  bChildId(nBirth)=0_8
                ENDIF
              ELSEIF ( eventType.EQ.BOM_EVENT_DEAD_BIO ) THEN
                IF ( nPlan.GE.bomMaxEventBuffer ) THEN
                  CALL BOM_P4_KEEP_FAILURE(
     I                 BOM_P4_PHASE_CAPACITY,
     I                 BOM_FAIL_EVENT_CAPACITY,
     I                 myProcId,bi,bj,ip,bomId(ip,bi,bj),
     U                 localFailPhase,localFailCode,
     U                 localFailBi,localFailBj,
     U                 localFailSlot,localFailId)
                ELSE
                  nPlan=nPlan+1
                  planType(nPlan)=BOM_EVENT_DEAD_BIO
                  planStage(nPlan)=BOM_STAGE_NONE
                  planBi(nPlan)=bi
                  planBj(nPlan)=bj
                  planSlot(nPlan)=ip
                  planSourceRank(nPlan)=myProcId
                  planSourceBi(nPlan)=bi
                  planSourceBj(nPlan)=bj
                  planId(nPlan)=bomId(ip,bi,bj)
                  planAcceptedX(nPlan)=bomX(ip,bi,bj)
                  planAcceptedY(nPlan)=bomY(ip,bi,bj)
                  planAttemptX(nPlan)=bomX(ip,bi,bj)
                  planAttemptY(nPlan)=bomY(ip,bi,bj)
                  planSBefore(nPlan)=bomS(ip,bi,bj)
                  planSTrial(nPlan)=sTrial
                  planSAfter(nPlan)=0. _d 0
                  terminalSlot(ip,bi,bj)=.TRUE.
                ENDIF
              ELSEIF ( eventType.EQ.BOM_EVENT_NONE ) THEN
                sWork(ip,bi,bj)=sCandidate
                sPublish(ip,bi,bj)=.TRUE.
              ELSE
                CALL BOM_P4_KEEP_FAILURE(
     I               BOM_P4_PHASE_BIOLOGY,BOM_FAIL_BROOKS,
     I               myProcId,bi,bj,ip,bomId(ip,bi,bj),
     U               localFailPhase,localFailCode,
     U               localFailBi,localFailBj,
     U               localFailSlot,localFailId)
              ENDIF
            ENDIF
          ELSEIF ( .NOT.terminalSlot(ip,bi,bj) .AND.
     &             bomStatus(ip,bi,bj).NE.BOM_WAITING ) THEN
            CALL BOM_P4_KEEP_FAILURE(
     I           BOM_P4_PHASE_TERMINAL,
     I           BOM_FAIL_EVENT_TRANSACTION,
     I           myProcId,bi,bj,ip,bomId(ip,bi,bj),
     U           localFailPhase,localFailCode,
     U           localFailBi,localFailBj,localFailSlot,localFailId)
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      IF ( injectPhase.EQ.BOM_P4_PHASE_BIOLOGY .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_BIOLOGY,BOM_FAIL_BROOKS,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)

C--   Freeze prospective parent order before any retry or child ID work.
      CALL BOM_BIRTH_PARENT_ORDER(
     I     nBirth,bParentId,bBi,bBj,bSlot,
     O     bOrdinal,nGlobalProposal,
     O     orderFail,orderPhase,orderRank,orderBi,orderBj,
     O     orderSlot,orderId,orderValid,myThid)
      IF ( .NOT.orderValid .AND. myProcId.EQ.orderRank )
     &     CALL BOM_P4_KEEP_FAILURE(
     I       orderPhase,orderFail,orderRank,orderBi,orderBj,
     I       orderSlot,orderId,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      IF ( injectPhase.EQ.BOM_P4_PHASE_BIRTH_ORDER .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)

C--   The stateless retries are visited in exact global parent order.
      DO ordinal=1,nGlobalProposal
        DO ip=1,nBirth
          IF ( bOrdinal(ip).EQ.ordinal ) THEN
            CALL BOM_BIRTH_PLACE(
     I           bomX(bSlot(ip),bBi(ip),bBj(ip)),
     I           bomY(bSlot(ip),bBi(ip),bBj(ip)),
     I           bBi(ip),bBj(ip),bParentId(ip),bCount(ip),
     I           bomEventTimeIndex,
     O           bX(ip),bY(ip),bPlaceI(ip),bPlaceJ(ip),
     O           bFirstX(ip),bFirstY(ip),bWord(ip),bAngle(ip),
     O           bAttempt(ip),birthEvent,birthDestRank,
     O           birthDestBi,birthDestBj,birthFail,birthPhase,
     O           birthValid,myThid)
            IF ( .NOT.birthValid ) THEN
              CALL BOM_P4_KEEP_FAILURE(
     I             birthPhase,birthFail,myProcId,
     I             bBi(ip),bBj(ip),bSlot(ip),bParentId(ip),
     U             localFailPhase,localFailCode,
     U             localFailBi,localFailBj,localFailSlot,localFailId)
            ELSEIF ( birthEvent.EQ.BOM_EVENT_BIRTH ) THEN
              bEvent(ip)=birthEvent
              bDestRank(ip)=birthDestRank
              bDestBi(ip)=birthDestBi
              bDestBj(ip)=birthDestBj
              birthAccepted(bSlot(ip),bBi(ip),bBj(ip))=.TRUE.
              nAccept=nAccept+1
              aBirthIndex(nAccept)=ip
              aParentId(nAccept)=bParentId(ip)
              aCount(nAccept)=bCount(ip)
              aEventIndex(nAccept)=bomEventTimeIndex
              aAttempt(nAccept)=bAttempt(ip)
              aBi(nAccept)=bBi(ip)
              aBj(nAccept)=bBj(ip)
              aSlot(nAccept)=bSlot(ip)
              aDestRank(nAccept)=bDestRank(ip)
              aDestBi(nAccept)=bDestBi(ip)
              aDestBj(nAccept)=bDestBj(ip)
              aX(nAccept)=bX(ip)
              aY(nAccept)=bY(ip)
            ELSEIF ( birthEvent.EQ.BOM_EVENT_BIRTH_CANCEL ) THEN
              bEvent(ip)=birthEvent
              birthCanceled(bSlot(ip),bBi(ip),bBj(ip))=.TRUE.
              localCancel=localCancel+1
            ELSE
              CALL BOM_P4_KEEP_FAILURE(
     I             BOM_P4_PHASE_BIRTH_PLACE,
     I             BOM_FAIL_BIRTH_RNG,myProcId,
     I             bBi(ip),bBj(ip),bSlot(ip),bParentId(ip),
     U             localFailPhase,localFailCode,
     U             localFailBi,localFailBj,localFailSlot,localFailId)
            ENDIF
          ENDIF
        ENDDO
      ENDDO
      IF ( injectPhase.EQ.BOM_P4_PHASE_BIRTH_PLACE .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_BIRTH_PLACE,BOM_FAIL_BIRTH_RNG,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)

C--   Canceled proposals never enter this accepted metadata collective.
      CALL BOM_BIRTH_ACCEPT_ORDER(
     I     nAccept,aParentId,aCount,aEventIndex,aAttempt,
     I     aBi,aBj,aSlot,aDestRank,aDestBi,aDestBj,aX,aY,bomNextId,
     O     aChildId,nGlobalBirth,gParentId,gChildId,
     O     gCount,gEventIndex,gAttempt,gSourceRank,
     O     gSourceBi,gSourceBj,gSourceSlot,
     O     gDestRank,gDestBi,gDestBj,gX,gY,nextIdAfter,
     O     orderFail,orderPhase,orderRank,orderBi,orderBj,
     O     orderSlot,orderId,orderValid,myThid)
      IF ( .NOT.orderValid .AND. myProcId.EQ.orderRank )
     &     CALL BOM_P4_KEEP_FAILURE(
     I       orderPhase,orderFail,orderRank,orderBi,orderBj,
     I       orderSlot,orderId,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      DO jp=1,nAccept
        ip=aBirthIndex(jp)
        bChildId(ip)=aChildId(jp)
      ENDDO

C--   Validate exact source binding.  All capacity classes are evaluated by
C     the common event preflight after global and destination counts exist.
      DO jp=1,nPlan
        bi=planBi(jp)
        bj=planBj(jp)
        ip=planSlot(jp)
        IF ( bi.LT.myBxLo(myThid) .OR. bi.GT.myBxHi(myThid)
     &       .OR. bj.LT.myByLo(myThid) .OR.
     &       bj.GT.myByHi(myThid) .OR. ip.LT.1 .OR.
     &       ip.GT.bomNPartTile(bi,bj) .OR.
     &       bomId(ip,bi,bj).NE.planId(jp) .OR.
     &       bomStatus(ip,bi,bj).NE.BOM_ALIVE )
     &       CALL BOM_P4_KEEP_FAILURE(
     I         BOM_P4_PHASE_TERMINAL,BOM_FAIL_EVENT_TRANSACTION,
     I         myProcId,bi,bj,ip,planId(jp),
     U         localFailPhase,localFailCode,localFailBi,localFailBj,
     U         localFailSlot,localFailId)
      ENDDO
      DO jp=1,nBirth
        bi=bBi(jp)
        bj=bBj(jp)
        ip=bSlot(jp)
        IF ( ip.LT.1 .OR. ip.GT.bomNPartTile(bi,bj) .OR.
     &       bomId(ip,bi,bj).NE.bParentId(jp) .OR.
     &       bomStatus(ip,bi,bj).NE.BOM_ALIVE .OR.
     &       terminalSlot(ip,bi,bj) .OR. bCount(jp).LT.0 .OR.
     &       bCount(jp).EQ.HUGE(bCount(jp)) )
     &       CALL BOM_P4_KEEP_FAILURE(
     I         BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I         myProcId,bi,bj,ip,bParentId(jp),
     U         localFailPhase,localFailCode,localFailBi,localFailBj,
     U         localFailSlot,localFailId)
      ENDDO
C--   Compute exact post-event tile capacities from accepted metadata.
      nLocalTerminal=0
      nLocalDest=0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        tileSurvivor(bi,bj)=bomNPartTile(bi,bj)
        tileBirth(bi,bj)=0
        DO ip=1,bomNPartTile(bi,bj)
          IF ( terminalSlot(ip,bi,bj) ) THEN
            tileSurvivor(bi,bj)=tileSurvivor(bi,bj)-1
            nLocalTerminal=nLocalTerminal+1
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      DO jp=1,nGlobalBirth
        IF ( gDestRank(jp).EQ.myProcId ) THEN
          tileBirth(gDestBi(jp),gDestBj(jp))=
     &         tileBirth(gDestBi(jp),gDestBj(jp))+1
          nLocalDest=nLocalDest+1
        ENDIF
      ENDDO
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        CALL BOM_FREE_VALIDATE(bi,bj,freeFailCode,freeValid)
        IF ( .NOT.freeValid ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_TERMINAL,freeFailCode,
     I       myProcId,bi,bj,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
       ENDDO
      ENDDO

      IF ( injectPhase.EQ.BOM_P4_PHASE_TERMINAL .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_TERMINAL,BOM_FAIL_EVENT_TRANSACTION,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)
      IF ( injectPhase.EQ.BOM_P4_PHASE_CAPACITY .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_CAPACITY,BOM_FAIL_BIRTH_CAPACITY,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)

C--   Counter and global live-budget checks complete initial preflight.
      DO jp=1,nPlan
        IF ( planType(jp).EQ.BOM_EVENT_DEAD_BIO ) THEN
          localDeath=localDeath+1
        ELSEIF ( planType(jp).EQ.BOM_EVENT_BEACHED ) THEN
          localBeach=localBeach+1
        ELSEIF ( planType(jp).EQ.BOM_EVENT_OUTSIDE ) THEN
          localOutside=localOutside+1
        ELSE
          CALL BOM_P4_KEEP_FAILURE(
     I         BOM_P4_PHASE_TERMINAL,BOM_FAIL_EVENT_TRANSACTION,
     I         myProcId,planBi(jp),planBj(jp),planSlot(jp),
     I         planId(jp),
     U         localFailPhase,localFailCode,
     U         localFailBi,localFailBj,localFailSlot,localFailId)
        ENDIF
      ENDDO
      globalDeath=localDeath
      globalBeach=localBeach
      globalOutside=localOutside
      globalCancel=localCancel
      globalMissing=localMissing
      CALL GLOBAL_SUM_INT(globalDeath,myThid)
      CALL GLOBAL_SUM_INT(globalBeach,myThid)
      CALL GLOBAL_SUM_INT(globalOutside,myThid)
      CALL GLOBAL_SUM_INT(globalCancel,myThid)
      CALL GLOBAL_SUM_INT(globalMissing,myThid)
      globalOwners=localOwners
      globalTerminal=nPlan
      CALL GLOBAL_SUM_INT(globalOwners,myThid)
      CALL GLOBAL_SUM_INT(globalTerminal,myThid)
      globalAfter=globalOwners-globalTerminal+nGlobalBirth
      CALL BOM_EVENT_PREFLIGHT(
     I     globalOwners,globalTerminal,nGlobalBirth,nGlobalProposal,
     I     nPlan,nBirth,bomEventBufferCount,tileSurvivor,tileBirth,
     I     bomNextId,
     O     preflightFail,preflightPhase,preflightRank,
     O     preflightBi,preflightBj,preflightSlot,preflightId,
     O     preflightNeed,preflightCapacity,preflightValid)
      IF ( .NOT.preflightValid ) CALL BOM_P4_KEEP_FAILURE(
     I     preflightPhase,preflightFail,preflightRank,
     I     preflightBi,preflightBj,preflightSlot,preflightId,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)
      IF ( globalOwners.NE.bomNPartLiveExpected )
     &     CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BUDGET,BOM_FAIL_EVENT_BUDGET,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      IF ( bomFreeRebuildOps.LT.0_8 .OR.
     &     bomFreeRebuildOps.GT.HUGE(bomFreeRebuildOps)
     &       -INT(nSx*nSy,8) .OR.
     &     bomFreeRemoveOps.LT.0_8 .OR.
     &     bomFreeRemoveOps.GT.HUGE(bomFreeRemoveOps)
     &       -INT(nPlan,8) .OR.
     &     bomFreeAllocOps.LT.0_8 .OR.
     &     bomFreeAllocOps.GT.HUGE(bomFreeAllocOps)
     &       -INT(nLocalDest,8) .OR.
     &     bomDeathEvents.LT.0_8 .OR.
     &     bomDeathEvents.GT.HUGE(bomDeathEvents)
     &       -INT(globalDeath,8) .OR.
     &     bomBeachEvents.LT.0_8 .OR.
     &     bomBeachEvents.GT.HUGE(bomBeachEvents)
     &       -INT(globalBeach,8) .OR.
     &     bomOutsideEvents.LT.0_8 .OR.
     &     bomOutsideEvents.GT.HUGE(bomOutsideEvents)
     &       -INT(globalOutside,8) .OR.
     &     bomBirthEvents.LT.0_8 .OR.
     &     bomBirthEvents.GT.HUGE(bomBirthEvents)
     &       -INT(nGlobalBirth,8) .OR.
     &     bomCancelEvents.LT.0_8 .OR.
     &     bomCancelEvents.GT.HUGE(bomCancelEvents)
     &       -INT(globalCancel,8) .OR.
     &     bomMissingGrowthEvents.LT.0_8 .OR.
     &     bomMissingGrowthEvents.GT.HUGE(bomMissingGrowthEvents)
     &       -INT(globalMissing,8) .OR.
     &     bomEventTimeIndex.LT.0_8 .OR.
     &     bomEventTimeIndex.EQ.HUGE(bomEventTimeIndex) )
     &     CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BUDGET,BOM_FAIL_EVENT_BUDGET,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      IF ( injectPhase.EQ.BOM_P4_PHASE_BUDGET .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_BUDGET,BOM_FAIL_EVENT_BUDGET,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)

      CALL BOM_P4_SELECT_FAILURE(
     I     localFailPhase,localFailCode,myProcId,
     I     localFailBi,localFailBj,localFailSlot,localFailId,
     O     p4FailPhase,failCode,failRank,failBi,failBj,failSlot,
     O     failId,isValid,myThid)
      IF ( .NOT.isValid ) RETURN
      GOTO 700

C--   Commit begins: initialize compact-tail stacks after the last failure.
  800 CONTINUE
      firstEventSlot=bomEventBufferCount+1
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        CALL BOM_FREE_INIT(bi,bj,freeFailCode,freeValid)
        IF ( .NOT.freeValid ) THEN
          CALL ALL_PROC_DIE(0)
          STOP 'ABNORMAL END: P4.3 EVENT FREE PREFLIGHT'
        ENDIF
       ENDDO
      ENDDO

C--   Publish terminal event records in the frozen P4.2 local order.
      DO jp=1,nPlan
        eventSlot=bomEventBufferCount+jp
        IF ( planType(jp).EQ.BOM_EVENT_DEAD_BIO ) THEN
          newStatus=BOM_DEAD_BIO
        ELSEIF ( planType(jp).EQ.BOM_EVENT_BEACHED ) THEN
          newStatus=BOM_BEACHED
        ELSE
          newStatus=BOM_OUTSIDE
        ENDIF
        bomEventTypeBuffer(eventSlot)=planType(jp)
        bomEventStageBuffer(eventSlot)=planStage(jp)
        bomEventOldStatusBuffer(eventSlot)=BOM_ALIVE
        bomEventNewStatusBuffer(eventSlot)=newStatus
        bomEventIterBuffer(eventSlot)=myIter
        bomEventSubstepBuffer(eventSlot)=mySubstep
        bomEventSourceRankBuffer(eventSlot)=planSourceRank(jp)
        bomEventSourceBiBuffer(eventSlot)=planSourceBi(jp)
        bomEventSourceBjBuffer(eventSlot)=planSourceBj(jp)
        bomEventDestRankBuffer(eventSlot)=myProcId
        bomEventDestBiBuffer(eventSlot)=planBi(jp)
        bomEventDestBjBuffer(eventSlot)=planBj(jp)
        bomEventRetryBuffer(eventSlot)=0
        bomEventIndexBuffer(eventSlot)=bomEventTimeIndex
        bomEventSubjectIdBuffer(eventSlot)=planId(jp)
        bomEventParentIdBuffer(eventSlot)=
     &       bomParentId(planSlot(jp),planBi(jp),planBj(jp))
        bomEventChildIdBuffer(eventSlot)=0_8
        bomEventTimeBuffer(eventSlot)=tSub1
        bomEventAcceptedXBuffer(eventSlot)=planAcceptedX(jp)
        bomEventAcceptedYBuffer(eventSlot)=planAcceptedY(jp)
        bomEventAttemptXBuffer(eventSlot)=planAttemptX(jp)
        bomEventAttemptYBuffer(eventSlot)=planAttemptY(jp)
        bomEventSBeforeBuffer(eventSlot)=planSBefore(jp)
        bomEventSTrialBuffer(eventSlot)=planSTrial(jp)
        bomEventSAfterBuffer(eventSlot)=planSAfter(jp)
      ENDDO

C--   Every prospective parent emits exactly one BIRTH or BIRTH_CANCEL.
      DO jp=1,nBirth
        eventSlot=bomEventBufferCount+nPlan+jp
        bomEventTypeBuffer(eventSlot)=bEvent(jp)
        bomEventStageBuffer(eventSlot)=BOM_STAGE_NONE
        bomEventOldStatusBuffer(eventSlot)=BOM_ALIVE
        bomEventNewStatusBuffer(eventSlot)=BOM_ALIVE
        bomEventIterBuffer(eventSlot)=myIter
        bomEventSubstepBuffer(eventSlot)=mySubstep
        bomEventSourceRankBuffer(eventSlot)=myProcId
        bomEventSourceBiBuffer(eventSlot)=bBi(jp)
        bomEventSourceBjBuffer(eventSlot)=bBj(jp)
        IF ( bEvent(jp).EQ.BOM_EVENT_BIRTH ) THEN
          bomEventDestRankBuffer(eventSlot)=bDestRank(jp)
          bomEventDestBiBuffer(eventSlot)=bDestBi(jp)
          bomEventDestBjBuffer(eventSlot)=bDestBj(jp)
          bomEventRetryBuffer(eventSlot)=bAttempt(jp)
          bomEventChildIdBuffer(eventSlot)=bChildId(jp)
          bomEventAcceptedXBuffer(eventSlot)=bX(jp)
          bomEventAcceptedYBuffer(eventSlot)=bY(jp)
          bomEventSAfterBuffer(eventSlot)=bomS0
        ELSE
          bomEventDestRankBuffer(eventSlot)=myProcId
          bomEventDestBiBuffer(eventSlot)=bBi(jp)
          bomEventDestBjBuffer(eventSlot)=bBj(jp)
          bomEventRetryBuffer(eventSlot)=bomBirthMaxTry
          bomEventChildIdBuffer(eventSlot)=0_8
          bomEventAcceptedXBuffer(eventSlot)=
     &         bomX(bSlot(jp),bBi(jp),bBj(jp))
          bomEventAcceptedYBuffer(eventSlot)=
     &         bomY(bSlot(jp),bBi(jp),bBj(jp))
          bomEventSAfterBuffer(eventSlot)=bSBefore(jp)
        ENDIF
        bomEventIndexBuffer(eventSlot)=bomEventTimeIndex
        bomEventParentIdBuffer(eventSlot)=bParentId(jp)
        IF ( bEvent(jp).EQ.BOM_EVENT_BIRTH ) THEN
          bomEventSubjectIdBuffer(eventSlot)=bChildId(jp)
        ELSE
          bomEventSubjectIdBuffer(eventSlot)=bParentId(jp)
        ENDIF
        bomEventTimeBuffer(eventSlot)=tSub1
        bomEventAttemptXBuffer(eventSlot)=bFirstX(jp)
        bomEventAttemptYBuffer(eventSlot)=bFirstY(jp)
        bomEventSBeforeBuffer(eventSlot)=bSBefore(jp)
        bomEventSTrialBuffer(eventSlot)=bSTrial(jp)
      ENDDO
      bomEventBufferCount=bomEventBufferCount+nPlan+nBirth

C--   Descending source slots make terminal tail swaps deterministic.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=bomNPartTile(bi,bj),1,-1
          IF ( terminalSlot(ip,bi,bj) ) THEN
            matchPlan=0
            DO jp=1,nPlan
              IF ( planBi(jp).EQ.bi .AND. planBj(jp).EQ.bj .AND.
     &             planSlot(jp).EQ.ip ) matchPlan=jp
            ENDDO
            IF ( matchPlan.EQ.0 ) THEN
              CALL ALL_PROC_DIE(0)
              STOP 'ABNORMAL END: P4.3 EVENT PLAN COMMIT'
            ENDIF
            CALL BOM_FREE_REMOVE(
     I           ip,bi,bj,planId(matchPlan),
     O           movedId,freeFailCode,freeValid)
            IF ( .NOT.freeValid ) THEN
              CALL ALL_PROC_DIE(0)
              STOP 'ABNORMAL END: P4.3 EVENT REMOVE COMMIT'
            ENDIF
          ENDIF
        ENDDO
       ENDDO
      ENDDO

C--   Allocate children by the same global order that assigned their IDs.
      DO jp=1,nGlobalBirth
        IF ( gDestRank(jp).EQ.myProcId ) THEN
          kp=0
          DO ip=1,nCandidate
            IF ( cId(ip).EQ.gChildId(jp) ) kp=ip
          ENDDO
          IF ( kp.EQ.0 ) THEN
            CALL ALL_PROC_DIE(0)
            STOP 'ABNORMAL END: P4.3 EVENT CHILD COMMIT'
          ENDIF
          CALL BOM_FREE_ALLOC(
     I         gDestBi(jp),gDestBj(jp),cId(kp),cParentId(kp),
     I         cStatus(kp),cBirthCount(kp),cX(kp),cY(kp),
     I         cRelease(kp),cAge(kp),cI(kp),cJ(kp),
     I         cVEast(kp),cVNorth(kp),cWindEast(kp),cWindNorth(kp),
     I         cDriftEast(kp),cDriftNorth(kp),cS(kp),
     I         cSpringEast(kp),cSpringNorth(kp),cNeighbor(kp),
     I         cRaftId(kp),cRaftSize(kp),cDiag(1,kp),
     O         newSlot,freeFailCode,freeValid)
          IF ( .NOT.freeValid ) THEN
            CALL ALL_PROC_DIE(0)
            STOP 'ABNORMAL END: P4.3 EVENT ALLOC COMMIT'
          ENDIF
        ENDIF
      ENDDO

C--   Publish the preflighted complete candidate by exact ID after swaps.
      kp=0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomNPartTile(bi,bj)
          jp=0
          DO eventSlot=1,nCandidate
            IF ( cId(eventSlot).EQ.bomId(ip,bi,bj) ) jp=eventSlot
          ENDDO
          IF ( jp.EQ.0 ) THEN
            CALL ALL_PROC_DIE(0)
            STOP 'ABNORMAL END: P4.3 EVENT CANDIDATE COMMIT'
          ENDIF
          kp=kp+1
          bomParentId(ip,bi,bj)=cParentId(jp)
          bomStatus(ip,bi,bj)=cStatus(jp)
          bomBirthCount(ip,bi,bj)=cBirthCount(jp)
          bomX(ip,bi,bj)=cX(jp)
          bomY(ip,bi,bj)=cY(jp)
          bomReleaseTime(ip,bi,bj)=cRelease(jp)
          bomAge(ip,bi,bj)=cAge(jp)
          bomI(ip,bi,bj)=cI(jp)
          bomJ(ip,bi,bj)=cJ(jp)
          bomVEast(ip,bi,bj)=cVEast(jp)
          bomVNorth(ip,bi,bj)=cVNorth(jp)
          bomWindEast(ip,bi,bj)=cWindEast(jp)
          bomWindNorth(ip,bi,bj)=cWindNorth(jp)
          bomDriftEast(ip,bi,bj)=cDriftEast(jp)
          bomDriftNorth(ip,bi,bj)=cDriftNorth(jp)
          bomS(ip,bi,bj)=cS(jp)
          bomSpringEast(ip,bi,bj)=cSpringEast(jp)
          bomSpringNorth(ip,bi,bj)=cSpringNorth(jp)
          bomNeighborCount(ip,bi,bj)=cNeighbor(jp)
          bomRaftId(ip,bi,bj)=cRaftId(jp)
          bomRaftSize(ip,bi,bj)=cRaftSize(jp)
          DO iDiag=1,BOM_RHS_NDIAG
            bomRhsDiag(iDiag,ip,bi,bj)=cDiag(iDiag,jp)
          ENDDO
        ENDDO
       ENDDO
      ENDDO
      IF ( kp.NE.nCandidate ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P4.3 EVENT OWNER COUNT COMMIT'
      ENDIF

      bomBirthEvents=bomBirthEvents+INT(nGlobalBirth,8)
      bomDeathEvents=bomDeathEvents+INT(globalDeath,8)
      bomBeachEvents=bomBeachEvents+INT(globalBeach,8)
      bomOutsideEvents=bomOutsideEvents+INT(globalOutside,8)
      bomCancelEvents=bomCancelEvents+INT(globalCancel,8)
      bomMissingGrowthEvents=bomMissingGrowthEvents+
     &     INT(globalMissing,8)
      bomNextId=nextIdAfter
      bomNPartLiveExpected=globalAfter
      bomEventTimeIndex=bomEventTimeIndex+1_8
      IF ( doGraph ) THEN
        bomP3OwnerRecords=MAX(bomP3OwnerRecords,ownerRecords)
        bomP3GhostRecords=MAX(bomP3GhostRecords,ghostRecords)
        bomP3NonEmptyCells=MAX(bomP3NonEmptyCells,nonEmptyCells)
        bomP3CandidateComparisons=
     &       bomP3CandidateComparisons+comparisons
        bomP3DirectedNeighbors=bomP3DirectedNeighbors+directed
        bomP3UndirectedEdges=bomP3UndirectedEdges+undirected
        bomP3MaximumNeighbors=
     &       MAX(bomP3MaximumNeighbors,maximumNeighbors)
        bomP3RebuildCount=bomP3RebuildCount+1_8
        bomP3GhostPacketsSent=
     &       bomP3GhostPacketsSent+bomGhostRecordsSent
        bomP3GhostPacketsReceived=
     &       bomP3GhostPacketsReceived+bomGhostRecordsReceived
        bomP3GhostBytesSent=bomP3GhostBytesSent+bomGhostBytesSent
        bomP3GhostBytesReceived=
     &       bomP3GhostBytesReceived+bomGhostBytesReceived
        bomP3MaximumComponentSize=INT(maximumComponent,8)
        bomP3ComponentIterations=INT(componentIterations,8)
      ENDIF
      CALL BOM_EVENT_BUDGET_CHECK(localFailCode,myThid)
      IF ( localFailCode.NE.BOM_FAIL_NONE ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P4.4 EVENT BUDGET COMMIT'
      ENDIF
#ifdef ALLOW_DIAGNOSTICS
      IF ( useDiagnostics ) CALL BOM_DIAGNOSTICS_FILL(
     I     firstEventSlot,nPlan+nBirth,myThid)
#endif

C--   Terminal scratch is consumed only by this successful commit.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomMaxPartTile
          bomTerminalType(ip,bi,bj)=BOM_EVENT_NONE
          bomTerminalStage(ip,bi,bj)=BOM_STAGE_NONE
          bomTerminalId(ip,bi,bj)=0_8
          bomTerminalAcceptedX(ip,bi,bj)=0. _d 0
          bomTerminalAcceptedY(ip,bi,bj)=0. _d 0
          bomTerminalAttemptX(ip,bi,bj)=0. _d 0
          bomTerminalAttemptY(ip,bi,bj)=0. _d 0
          bomTerminalReady(ip,bi,bj)=.FALSE.
        ENDDO
       ENDDO
      ENDDO
      failCode=BOM_FAIL_NONE
      p4FailPhase=BOM_P4_PHASE_NONE
      failRank=-1
      failBi=0
      failBj=0
      failSlot=0
      failId=0_8
      isValid=.TRUE.
      GOTO 900

C--   Build the complete local post-event owner candidate in tile order.
  700 CONTINUE
      nCandidate=0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomNPartTile(bi,bj)
          IF ( .NOT.terminalSlot(ip,bi,bj) ) THEN
            nCandidate=nCandidate+1
            cId(nCandidate)=bomId(ip,bi,bj)
            cParentId(nCandidate)=bomParentId(ip,bi,bj)
            cStatus(nCandidate)=bomStatus(ip,bi,bj)
            cBirthCount(nCandidate)=bomBirthCount(ip,bi,bj)
            cX(nCandidate)=bomX(ip,bi,bj)
            cY(nCandidate)=bomY(ip,bi,bj)
            cRelease(nCandidate)=bomReleaseTime(ip,bi,bj)
            cAge(nCandidate)=bomAge(ip,bi,bj)
            cI(nCandidate)=bomI(ip,bi,bj)
            cJ(nCandidate)=bomJ(ip,bi,bj)
            cVEast(nCandidate)=bomVEast(ip,bi,bj)
            cVNorth(nCandidate)=bomVNorth(ip,bi,bj)
            cWindEast(nCandidate)=bomWindEast(ip,bi,bj)
            cWindNorth(nCandidate)=bomWindNorth(ip,bi,bj)
            cDriftEast(nCandidate)=bomDriftEast(ip,bi,bj)
            cDriftNorth(nCandidate)=bomDriftNorth(ip,bi,bj)
            cS(nCandidate)=bomS(ip,bi,bj)
            cSpringEast(nCandidate)=bomSpringEast(ip,bi,bj)
            cSpringNorth(nCandidate)=bomSpringNorth(ip,bi,bj)
            cNeighbor(nCandidate)=bomNeighborCount(ip,bi,bj)
            cRaftId(nCandidate)=bomRaftId(ip,bi,bj)
            cRaftSize(nCandidate)=bomRaftSize(ip,bi,bj)
            cBi(nCandidate)=bi
            cBj(nCandidate)=bj
            DO iDiag=1,BOM_RHS_NDIAG
              cDiag(iDiag,nCandidate)=bomRhsDiag(iDiag,ip,bi,bj)
            ENDDO
            IF ( birthAccepted(ip,bi,bj) ) THEN
              cS(nCandidate)=bomS0
              cBirthCount(nCandidate)=bomBirthCount(ip,bi,bj)+1
            ELSEIF ( birthCanceled(ip,bi,bj) ) THEN
              cS(nCandidate)=bomS(ip,bi,bj)
            ELSEIF ( sPublish(ip,bi,bj) ) THEN
              cS(nCandidate)=sWork(ip,bi,bj)
            ENDIF
          ENDIF
        ENDDO
       ENDDO
      ENDDO

C--   Append locally destined children in canonical global child-ID order.
      DO jp=1,nGlobalBirth
        IF ( gDestRank(jp).EQ.myProcId ) THEN
          nCandidate=nCandidate+1
          cId(nCandidate)=gChildId(jp)
          cParentId(nCandidate)=gParentId(jp)
          cStatus(nCandidate)=BOM_ALIVE
          cBirthCount(nCandidate)=0
          cX(nCandidate)=gX(jp)
          cY(nCandidate)=gY(jp)
          cRelease(nCandidate)=tSub1
          cAge(nCandidate)=0. _d 0
          cI(nCandidate)=0. _d 0
          cJ(nCandidate)=0. _d 0
          cVEast(nCandidate)=0. _d 0
          cVNorth(nCandidate)=0. _d 0
          cWindEast(nCandidate)=0. _d 0
          cWindNorth(nCandidate)=0. _d 0
          cDriftEast(nCandidate)=0. _d 0
          cDriftNorth(nCandidate)=0. _d 0
          cS(nCandidate)=bomS0
          cSpringEast(nCandidate)=0. _d 0
          cSpringNorth(nCandidate)=0. _d 0
          cNeighbor(nCandidate)=0
          cRaftId(nCandidate)=0_8
          cRaftSize(nCandidate)=0
          cBi(nCandidate)=gDestBi(jp)
          cBj(nCandidate)=gDestBj(jp)
          DO iDiag=1,BOM_RHS_NDIAG
            cDiag(iDiag,nCandidate)=0. _d 0
          ENDDO
        ENDIF
      ENDDO
      IF ( nCandidate.NE.localOwners-nPlan+nLocalDest .OR.
     &     nCandidate.GT.bomMaxOwnerRecord ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_CAPACITY,BOM_FAIL_BIRTH_CAPACITY,
     I     myProcId,0,0,0,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)

C--   A topology change rebuilds the FINAL cutoff graph before commit.
      doGraph=bomSpringLaw.NE.'NONE' .AND.
     &        globalTerminal+nGlobalBirth.GT.0
      componentValid=.TRUE.
      IF ( doGraph ) THEN
        graphEpoch=mySubstep
        CALL BOM_SPRING_RHS_STAGE(
     I       nCandidate,cId,cStatus,cX,cY,cBi,cBj,
     I       tSub1,0. _d 0,BOM_STAGE_FINAL,
     I       graphEpoch,mySubstep,
     O       graphRateX,graphRateY,graphI,graphJ,graphDiag,
     O       graphSpringEast,graphSpringNorth,graphNeighbor,
     O       graphWet,graphCFL,ownerRecords,ghostRecords,
     O       nonEmptyCells,comparisons,directed,undirected,
     O       maximumNeighbors,graphFail,graphPhase,graphValid,
     I       myThid)
        IF ( .NOT.graphValid ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_GRAPH,graphFail,myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
        IF ( graphValid .AND. bomRaftDiagnostics ) THEN
          CALL BOM_COMPONENT_FETCH(
     I         nCandidate,cId,BOM_STAGE_FINAL,
     I         graphEpoch,mySubstep,
     O         graphRaftId,cRaftSize,
     O         componentIterations,maximumComponent,
     O         componentFail,componentValid,myThid)
          IF ( .NOT.componentValid ) CALL BOM_P4_KEEP_FAILURE(
     I         BOM_P4_PHASE_GRAPH,componentFail,
     I         myProcId,0,0,0,0_8,
     U         localFailPhase,localFailCode,
     U         localFailBi,localFailBj,localFailSlot,localFailId)
        ELSEIF ( graphValid ) THEN
          componentIterations=0
          maximumComponent=0
          DO ip=1,nCandidate
            graphRaftId(ip)=0_8
            cRaftSize(ip)=0
          ENDDO
        ENDIF
        IF ( graphValid .AND. componentValid ) THEN
          DO ip=1,nCandidate
            cSpringEast(ip)=graphSpringEast(ip)
            cSpringNorth(ip)=graphSpringNorth(ip)
            cNeighbor(ip)=graphNeighbor(ip)
            cRaftId(ip)=graphRaftId(ip)
            IF ( cStatus(ip).EQ.BOM_ALIVE ) THEN
              cI(ip)=graphI(ip)
              cJ(ip)=graphJ(ip)
              cVEast(ip)=graphDiag(BOM_RHS_VBASE_E,ip)
              cVNorth(ip)=graphDiag(BOM_RHS_VBASE_N,ip)
              cWindEast(ip)=graphDiag(BOM_RHS_VW_E,ip)
              cWindNorth(ip)=graphDiag(BOM_RHS_VW_N,ip)
              cDriftEast(ip)=graphDiag(BOM_RHS_DRIFT_E,ip)
              cDriftNorth(ip)=graphDiag(BOM_RHS_DRIFT_N,ip)
              DO iDiag=1,BOM_RHS_NDIAG
                cDiag(iDiag,ip)=graphDiag(iDiag,ip)
              ENDDO
            ENDIF
          ENDDO
        ENDIF
      ELSEIF ( bomSpringLaw.EQ.'NONE' ) THEN
C--     Without springs, only new children require a final owner refresh.
        DO ip=1,nCandidate
          cSpringEast(ip)=0. _d 0
          cSpringNorth(ip)=0. _d 0
          cNeighbor(ip)=0
          cRaftId(ip)=0_8
          cRaftSize(ip)=0
          IF ( cId(ip).GE.bomNextId ) THEN
            CALL BOM_RHS_SLOW_MANIFOLD(
     I           cX(ip),cY(ip),tSub1,0. _d 0,
     I           cBi(ip),cBj(ip),BOM_STAGE_FINAL,
     O           rhsX,rhsY,cI(ip),cJ(ip),cDiag(1,ip),
     O           stageWet,stageCFL,rhsOwner,rhsValid,
     O           graphFail,graphPhase,myThid)
            IF ( .NOT.rhsValid .OR. .NOT.rhsOwner ) THEN
              CALL BOM_P4_KEEP_FAILURE(
     I             BOM_P4_PHASE_GRAPH,graphFail,myProcId,
     I             cBi(ip),cBj(ip),0,cId(ip),
     U             localFailPhase,localFailCode,
     U             localFailBi,localFailBj,
     U             localFailSlot,localFailId)
            ELSE
              cVEast(ip)=cDiag(BOM_RHS_VBASE_E,ip)
              cVNorth(ip)=cDiag(BOM_RHS_VBASE_N,ip)
              cWindEast(ip)=cDiag(BOM_RHS_VW_E,ip)
              cWindNorth(ip)=cDiag(BOM_RHS_VW_N,ip)
              cDriftEast(ip)=cDiag(BOM_RHS_DRIFT_E,ip)
              cDriftNorth(ip)=cDiag(BOM_RHS_DRIFT_N,ip)
            ENDIF
          ENDIF
        ENDDO
      ENDIF
      IF ( doGraph ) THEN
        IF ( bomP3CandidateComparisons.LT.0_8 .OR.
     &       bomP3CandidateComparisons.GT.
     &         HUGE(bomP3CandidateComparisons)-comparisons .OR.
     &       bomP3DirectedNeighbors.LT.0_8 .OR.
     &       bomP3DirectedNeighbors.GT.
     &         HUGE(bomP3DirectedNeighbors)-directed .OR.
     &       bomP3UndirectedEdges.LT.0_8 .OR.
     &       bomP3UndirectedEdges.GT.
     &         HUGE(bomP3UndirectedEdges)-undirected .OR.
     &       bomP3RebuildCount.LT.0_8 .OR.
     &       bomP3RebuildCount.EQ.HUGE(bomP3RebuildCount) .OR.
     &       bomP3GhostPacketsSent.LT.0_8 .OR.
     &       bomP3GhostPacketsSent.GT.
     &         HUGE(bomP3GhostPacketsSent)-bomGhostRecordsSent .OR.
     &       bomP3GhostPacketsReceived.LT.0_8 .OR.
     &       bomP3GhostPacketsReceived.GT.
     &         HUGE(bomP3GhostPacketsReceived)
     &         -bomGhostRecordsReceived .OR.
     &       bomP3GhostBytesSent.LT.0_8 .OR.
     &       bomP3GhostBytesSent.GT.
     &         HUGE(bomP3GhostBytesSent)-bomGhostBytesSent .OR.
     &       bomP3GhostBytesReceived.LT.0_8 .OR.
     &       bomP3GhostBytesReceived.GT.
     &         HUGE(bomP3GhostBytesReceived)
     &         -bomGhostBytesReceived ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BUDGET,BOM_FAIL_EVENT_BUDGET,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ENDIF
      IF ( injectPhase.EQ.BOM_P4_PHASE_GRAPH .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_GRAPH,BOM_FAIL_COMPONENT,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)

C--   Reject graph and child-refresh failures before any authoritative write.
      CALL BOM_P4_SELECT_FAILURE(
     I     localFailPhase,localFailCode,myProcId,
     I     localFailBi,localFailBj,localFailSlot,localFailId,
     O     p4FailPhase,failCode,failRank,failBi,failBj,failSlot,
     O     failId,isValid,myThid)
      IF ( .NOT.isValid ) RETURN
      GOTO 800

  900 CONTINUE
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
