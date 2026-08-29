#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_TRY_STAGE_BOUNDARY
C !INTERFACE:
      SUBROUTINE BOM_TRY_STAGE_BOUNDARY(
     I                 attemptedX,attemptedY,sourceBi,sourceBj,stage,
     O                 terminalType,terminalAttemptX,terminalAttemptY,
     O                 isTerminal,failCode,p4FailPhase,isValid,
     I                 myThid)

C !DESCRIPTION:
C     Stateless RK-stage boundary preflight.  WET continues, finite dry or
C     non-periodic exterior becomes a terminal candidate, and every other
C     classifier result remains fatal.  No owner or event state is changed.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL attemptedX,attemptedY,terminalAttemptX,terminalAttemptY
      _RL xMap,ix,jy
      INTEGER sourceBi,sourceBj,stage,terminalType
      INTEGER ownerRank,ownerBi,ownerBj
      INTEGER boundaryClass,failCode,p4FailPhase,myThid
      LOGICAL isTerminal,isValid

      terminalType = BOM_EVENT_NONE
      terminalAttemptX = 0. _d 0
      terminalAttemptY = 0. _d 0
      isTerminal = .FALSE.
      failCode = BOM_FAIL_NONE
      p4FailPhase = BOM_P4_PHASE_NONE
      isValid = .TRUE.
      IF ( .NOT.bomUseLand ) RETURN
      IF ( stage.LT.BOM_STAGE_K1 .OR. stage.GT.BOM_STAGE_FINAL ) THEN
        failCode = BOM_FAIL_BOUNDARY_EVENT
        p4FailPhase = BOM_P4_PHASE_BOUNDARY
        isValid = .FALSE.
        RETURN
      ENDIF

      CALL BOM_CLASSIFY_BOUNDARY(
     I     attemptedX,attemptedY,sourceBi,sourceBj,
     O     boundaryClass,xMap,ix,jy,
     O     ownerRank,ownerBi,ownerBj,
     O     failCode,p4FailPhase,isValid,
     I     myThid)
      IF ( .NOT.isValid ) RETURN
      IF ( boundaryClass.EQ.BOM_BOUNDARY_WET ) RETURN
      IF ( boundaryClass.EQ.BOM_BOUNDARY_BEACHED ) THEN
        terminalType = BOM_EVENT_BEACHED
      ELSEIF ( boundaryClass.EQ.BOM_BOUNDARY_OUTSIDE ) THEN
        terminalType = BOM_EVENT_OUTSIDE
      ELSE
        failCode = BOM_FAIL_BOUNDARY_EVENT
        p4FailPhase = BOM_P4_PHASE_BOUNDARY
        isValid = .FALSE.
        RETURN
      ENDIF
      terminalAttemptX = attemptedX
      terminalAttemptY = attemptedY
      isTerminal = .TRUE.
      failCode = BOM_FAIL_NONE
      p4FailPhase = BOM_P4_PHASE_NONE
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_EVENT_TRANSACTION
C !INTERFACE:
      SUBROUTINE BOM_EVENT_TRANSACTION(
     I                 tSub0,tSub1,myIter,mySubstep,injectPhase,
     O                 failCode,p4FailPhase,failRank,
     O                 failBi,failBj,failSlot,failId,isValid,
     I                 myThid)

C !DESCRIPTION:
C     Complete the P4.2 post-migration event phase.  Boundary scratch is
C     rebound by exact ID, biology survivors/deaths are planned, and every
C     capacity/budget/free-tail condition is checked globally before the
C     first authoritative write.  P4.2 rejects birth proposals because P4.3
C     owns placement, global ordering and child IDs.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL tSub0,tSub1
      INTEGER myIter,mySubstep,injectPhase,myThid
      INTEGER failCode,p4FailPhase,failRank,failBi,failBj,failSlot
      INTEGER*8 failId
      LOGICAL isValid

#ifdef ALLOW_BOM
      INTEGER bi,bj,ip,jp,nPart,nPlan,matchCount,matchPlan
      INTEGER bindBi,bindBj,bindSlot,searchBi,searchBj
      INTEGER localFailCode,localFailPhase,localFailBi,localFailBj
      INTEGER localFailSlot,globalOwners,globalTerminal,globalAfter
      INTEGER localOwners,localTerminal,freeFailCode,newStatus
      INTEGER localDeath,localBeach,localOutside
      INTEGER globalDeath,globalBeach,globalOutside
      INTEGER localMissing,globalMissing,firstEventSlot
      INTEGER planType(bomMaxInitRecords)
      INTEGER planStage(bomMaxInitRecords)
      INTEGER planBi(bomMaxInitRecords)
      INTEGER planBj(bomMaxInitRecords)
      INTEGER planSlot(bomMaxInitRecords)
      INTEGER planSourceRank(bomMaxInitRecords)
      INTEGER planSourceBi(bomMaxInitRecords)
      INTEGER planSourceBj(bomMaxInitRecords)
      INTEGER*8 localFailId,planId(bomMaxInitRecords)
      _RL planAcceptedX(bomMaxInitRecords)
      _RL planAcceptedY(bomMaxInitRecords)
      _RL planAttemptX(bomMaxInitRecords)
      _RL planAttemptY(bomMaxInitRecords)
      _RL planSBefore(bomMaxInitRecords)
      _RL planSTrial(bomMaxInitRecords)
      _RL planSAfter(bomMaxInitRecords)
      _RL sWork(bomMaxPartTile,nSx,nSy)
      _RL temperature,nutrient,wetWeight,dtActive,activeStart
      _RL tempFactor,nutrientFactor,dSdt,sTrial,sCandidate
      INTEGER bioFail,bioPhase,eventType,eventSlot
      INTEGER*8 movedId
      LOGICAL terminalSlot(bomMaxPartTile,nSx,nSy)
      LOGICAL sPublish(bomMaxPartTile,nSx,nSy)
      LOGICAL pointValid,interpValid,missingGrowth,planValid
      LOGICAL slotClear,freeValid

      failCode = BOM_FAIL_EVENT_TRANSACTION
      p4FailPhase = BOM_P4_PHASE_TERMINAL
      failRank = myProcId
      failBi = 0
      failBj = 0
      failSlot = 0
      failId = 0_8
      isValid = .FALSE.
      localFailCode = BOM_FAIL_NONE
      localFailPhase = BOM_P4_PHASE_NONE
      localFailBi = 0
      localFailBj = 0
      localFailSlot = 0
      localFailId = 0_8
      nPlan = 0
      localOwners = 0
      localTerminal = 0
      localDeath = 0
      localBeach = 0
      localOutside = 0
      localMissing = 0

      IF ( .NOT.IEEE_IS_FINITE(tSub0) .OR.
     &     .NOT.IEEE_IS_FINITE(tSub1) .OR. tSub1.LT.tSub0 .OR.
     &     mySubstep.LT.1 ) THEN
        CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_TERMINAL,BOM_FAIL_EVENT_TRANSACTION,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ENDIF

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        nPart = bomNPartTile(bi,bj)
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
          sWork(ip,bi,bj)=bomS(ip,bi,bj)
          IF ( ip.GT.nPart ) THEN
            CALL BOM_OWNER_SLOT_IS_CLEAR(ip,bi,bj,slotClear)
            IF ( .NOT.slotClear ) CALL BOM_P4_KEEP_FAILURE(
     I           BOM_P4_PHASE_TERMINAL,BOM_FAIL_EVENT_TRANSACTION,
     I           myProcId,bi,bj,ip,bomId(ip,bi,bj),
     U           localFailPhase,localFailCode,localFailBi,localFailBj,
     U           localFailSlot,localFailId)
          ENDIF
        ENDDO
       ENDDO
      ENDDO

C--   Boundary scratch may occupy a pre-migration slot.  Bind its exact ID
C     against the current local compact prefixes before any state change.
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
            ELSEIF ( nPlan.GE.bomMaxInitRecords ) THEN
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

C--   Biology is evaluated only for surviving ALIVE owners at tSub1.
      IF ( bomUseBiology ) THEN
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          DO ip=1,bomNPartTile(bi,bj)
            IF ( .NOT.terminalSlot(ip,bi,bj) .AND.
     &           bomStatus(ip,bi,bj).EQ.BOM_ALIVE ) THEN
              activeStart=MAX(tSub0,bomReleaseTime(ip,bi,bj))
              dtActive=MAX(0. _d 0,tSub1-activeStart)
              CALL BOM_INTERP_BIO_PAIR(
     I             bomI(ip,bi,bj),bomJ(ip,bi,bj),bi,bj,tSub1,
     O             temperature,nutrient,wetWeight,pointValid,
     O             bioFail,eventSlot,bioPhase,interpValid,
     I             myThid)
              IF ( .NOT.interpValid ) THEN
                CALL BOM_P4_KEEP_FAILURE(
     I               bioPhase,bioFail,myProcId,bi,bj,ip,
     I               bomId(ip,bi,bj),
     U               localFailPhase,localFailCode,
     U               localFailBi,localFailBj,localFailSlot,localFailId)
              ELSE
                CALL BOM_BIOLOGY_PLAN(
     I               bomStatus(ip,bi,bj),bomS(ip,bi,bj),
     I               temperature,nutrient,dtActive,pointValid,
     O               tempFactor,nutrientFactor,dSdt,
     O               sTrial,sCandidate,eventType,missingGrowth,
     O               bioFail,bioPhase,planValid)
                IF ( .NOT.planValid ) THEN
                  CALL BOM_P4_KEEP_FAILURE(
     I                 bioPhase,bioFail,myProcId,bi,bj,ip,
     I                 bomId(ip,bi,bj),
     U                 localFailPhase,localFailCode,
     U                 localFailBi,localFailBj,
     U                 localFailSlot,localFailId)
                ELSEIF ( missingGrowth ) THEN
                  localMissing=localMissing+1
                  sWork(ip,bi,bj)=sCandidate
                  sPublish(ip,bi,bj)=.TRUE.
                ELSEIF ( eventType.EQ.BOM_EVENT_BIRTH ) THEN
C--               Birth placement and IDs are deliberately P4.3 scope.
                  CALL BOM_P4_KEEP_FAILURE(
     I                 BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I                 myProcId,bi,bj,ip,bomId(ip,bi,bj),
     U                 localFailPhase,localFailCode,
     U                 localFailBi,localFailBj,
     U                 localFailSlot,localFailId)
                ELSEIF ( eventType.EQ.BOM_EVENT_DEAD_BIO ) THEN
                  IF ( nPlan.GE.bomMaxInitRecords ) THEN
                    CALL BOM_P4_KEEP_FAILURE(
     I                   BOM_P4_PHASE_CAPACITY,
     I                   BOM_FAIL_EVENT_CAPACITY,
     I                   myProcId,bi,bj,ip,bomId(ip,bi,bj),
     U                   localFailPhase,localFailCode,
     U                   localFailBi,localFailBj,
     U                   localFailSlot,localFailId)
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
     I                 BOM_P4_PHASE_BIOLOGY,BOM_FAIL_BROOKS,
     I                 myProcId,bi,bj,ip,bomId(ip,bi,bj),
     U                 localFailPhase,localFailCode,
     U                 localFailBi,localFailBj,
     U                 localFailSlot,localFailId)
                ENDIF
              ENDIF
            ELSEIF ( .NOT.terminalSlot(ip,bi,bj) .AND.
     &               bomStatus(ip,bi,bj).NE.BOM_WAITING ) THEN
              CALL BOM_P4_KEEP_FAILURE(
     I             BOM_P4_PHASE_TERMINAL,
     I             BOM_FAIL_EVENT_TRANSACTION,
     I             myProcId,bi,bj,ip,bomId(ip,bi,bj),
     U             localFailPhase,localFailCode,
     U             localFailBi,localFailBj,
     U             localFailSlot,localFailId)
            ENDIF
          ENDDO
         ENDDO
        ENDDO
      ENDIF
      IF ( injectPhase.EQ.BOM_P4_PHASE_BIOLOGY .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_BIOLOGY,BOM_FAIL_BROOKS,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)

C--   Preflight exact binding, local buffer space and the global live budget.
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
      IF ( bomEventBufferCount.LT.0 .OR.
     &     bomEventBufferCount.GT.bomMaxEventBuffer .OR.
     &     nPlan.GT.bomMaxEventBuffer-bomEventBufferCount )
     &     CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_CAPACITY,BOM_FAIL_EVENT_CAPACITY,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      IF ( injectPhase.EQ.BOM_P4_PHASE_TERMINAL .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_TERMINAL,BOM_FAIL_EVENT_TRANSACTION,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)
      IF ( injectPhase.EQ.BOM_P4_PHASE_CAPACITY .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_CAPACITY,BOM_FAIL_EVENT_CAPACITY,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)
      IF ( injectPhase.EQ.BOM_P4_PHASE_GRAPH .AND.
     &     myProcId.EQ.0 ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_GRAPH,BOM_FAIL_COMPONENT,
     I     myProcId,1,1,1,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)

C--   Validate every compact prefix and every counter increment before the
C     global decision.  The following commit therefore contains no expected
C     failure or collective operation.
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
      IF ( bomFreeRebuildOps.GT.HUGE(bomFreeRebuildOps)
     &     -INT(nSx*nSy,8) .OR.
     &     bomFreeRemoveOps.LT.0_8 .OR.
     &     bomFreeRemoveOps.GT.HUGE(bomFreeRemoveOps)-INT(nPlan,8) )
     &     CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BUDGET,BOM_FAIL_EVENT_BUDGET,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)

      DO jp=1,nPlan
        IF ( planType(jp).EQ.BOM_EVENT_DEAD_BIO ) THEN
          localDeath=localDeath+1
        ELSEIF ( planType(jp).EQ.BOM_EVENT_BEACHED ) THEN
          localBeach=localBeach+1
        ELSEIF ( planType(jp).EQ.BOM_EVENT_OUTSIDE ) THEN
          localOutside=localOutside+1
        ELSE
          CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_TERMINAL,BOM_FAIL_EVENT_TRANSACTION,
     I       myProcId,planBi(jp),planBj(jp),planSlot(jp),planId(jp),
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
        ENDIF
      ENDDO
      globalDeath=localDeath
      globalBeach=localBeach
      globalOutside=localOutside
      globalMissing=localMissing
      CALL GLOBAL_SUM_INT(globalDeath,myThid)
      CALL GLOBAL_SUM_INT(globalBeach,myThid)
      CALL GLOBAL_SUM_INT(globalOutside,myThid)
      CALL GLOBAL_SUM_INT(globalMissing,myThid)
      IF ( bomDeathEvents.LT.0_8 .OR.
     &     bomDeathEvents.GT.HUGE(bomDeathEvents)-INT(globalDeath,8)
     &     .OR. bomBeachEvents.LT.0_8 .OR.
     &     bomBeachEvents.GT.HUGE(bomBeachEvents)-INT(globalBeach,8)
     &     .OR. bomOutsideEvents.LT.0_8 .OR.
     &     bomOutsideEvents.GT.HUGE(bomOutsideEvents)
     &                              -INT(globalOutside,8)
     &     .OR. bomMissingGrowthEvents.LT.0_8
     &     .OR. bomMissingGrowthEvents.GT.
     &     HUGE(bomMissingGrowthEvents)-INT(globalMissing,8)
     &     .OR. bomEventTimeIndex.LT.0_8 .OR.
     &     bomEventTimeIndex.EQ.HUGE(bomEventTimeIndex) )
     &     CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BUDGET,BOM_FAIL_EVENT_BUDGET,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)

      localTerminal=nPlan
      globalOwners=localOwners
      globalTerminal=localTerminal
      CALL GLOBAL_SUM_INT(globalOwners,myThid)
      CALL GLOBAL_SUM_INT(globalTerminal,myThid)
      globalAfter=globalOwners-globalTerminal
      IF ( globalOwners.NE.bomNPartLiveExpected .OR.
     &     globalAfter.LT.0 .OR. globalAfter.GT.bomMaxParticles )
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
     O     failId,isValid,
     I     myThid)
      IF ( .NOT.isValid ) RETURN

C--   Commit begins only after every rank has accepted the same preflight.
      firstEventSlot=bomEventBufferCount+1
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomNPartTile(bi,bj)
          IF ( sPublish(ip,bi,bj) ) bomS(ip,bi,bj)=sWork(ip,bi,bj)
        ENDDO
        CALL BOM_FREE_INIT(bi,bj,freeFailCode,freeValid)
        IF ( .NOT.freeValid ) THEN
          CALL ALL_PROC_DIE(0)
          STOP 'ABNORMAL END: P4 EVENT FREE PREFLIGHT'
        ENDIF
       ENDDO
      ENDDO

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
      bomEventBufferCount=bomEventBufferCount+nPlan

C--   Descending bound slots make every O(1) tail swap deterministic.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=bomNPartTile(bi,bj),1,-1
          IF ( terminalSlot(ip,bi,bj) ) THEN
            matchPlan=0
            DO jp=1,nPlan
              IF ( planBi(jp).EQ.bi .AND. planBj(jp).EQ.bj .AND.
     &             planSlot(jp).EQ.ip ) matchPlan=jp
            ENDDO
            CALL BOM_FREE_REMOVE(
     I           ip,bi,bj,planId(matchPlan),
     O           movedId,freeFailCode,freeValid)
            IF ( .NOT.freeValid ) THEN
              CALL ALL_PROC_DIE(0)
              STOP 'ABNORMAL END: P4 EVENT REMOVE COMMIT'
            ENDIF
          ENDIF
        ENDDO
       ENDDO
      ENDDO

      bomDeathEvents=bomDeathEvents+INT(globalDeath,8)
      bomBeachEvents=bomBeachEvents+INT(globalBeach,8)
      bomOutsideEvents=bomOutsideEvents+INT(globalOutside,8)
      bomMissingGrowthEvents=bomMissingGrowthEvents+
     &     INT(globalMissing,8)
      bomNPartLiveExpected=globalAfter
      bomEventTimeIndex=bomEventTimeIndex+1_8
      CALL BOM_EVENT_BUDGET_CHECK(localFailCode,myThid)
      IF ( localFailCode.NE.BOM_FAIL_NONE ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P4.4 EVENT BUDGET COMMIT'
      ENDIF
#ifdef ALLOW_DIAGNOSTICS
      IF ( useDiagnostics ) CALL BOM_DIAGNOSTICS_FILL(
     I     firstEventSlot,nPlan,myThid)
#endif

C--   Scratch is consumed only by the successful commit.
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
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P4_KEEP_FAILURE(
     I     phaseIn,codeIn,rankIn,biIn,bjIn,slotIn,idIn,
     U     phaseKeep,codeKeep,biKeep,bjKeep,slotKeep,idKeep)
      IMPLICIT NONE
      INTEGER phaseIn,codeIn,rankIn,biIn,bjIn,slotIn
      INTEGER phaseKeep,codeKeep,biKeep,bjKeep,slotKeep
      INTEGER*8 idIn,idKeep
      LOGICAL replace
      replace=codeKeep.EQ.0
      IF ( .NOT.replace ) THEN
        IF ( phaseIn.LT.phaseKeep ) THEN
          replace=.TRUE.
        ELSEIF ( phaseIn.EQ.phaseKeep ) THEN
          IF ( biIn.LT.biKeep ) THEN
            replace=.TRUE.
          ELSEIF ( biIn.EQ.biKeep .AND. bjIn.LT.bjKeep ) THEN
            replace=.TRUE.
          ELSEIF ( biIn.EQ.biKeep .AND. bjIn.EQ.bjKeep .AND.
     &             slotIn.LT.slotKeep ) THEN
            replace=.TRUE.
          ELSEIF ( biIn.EQ.biKeep .AND. bjIn.EQ.bjKeep .AND.
     &             slotIn.EQ.slotKeep .AND. idIn.LT.idKeep ) THEN
            replace=.TRUE.
          ENDIF
        ENDIF
      ENDIF
      IF ( replace ) THEN
        phaseKeep=phaseIn
        codeKeep=codeIn
        biKeep=biIn
        bjKeep=bjIn
        slotKeep=slotIn
        idKeep=idIn
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P4_SELECT_FAILURE(
     I     localPhase,localCode,localRank,localBi,localBj,
     I     localSlot,localId,
     O     failPhase,failCode,failRank,failBi,failBj,failSlot,
     O     failId,allValid,
     I     myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
      INTEGER localPhase,localCode,localRank,localBi,localBj,localSlot
      INTEGER failPhase,failCode,failRank,failBi,failBj,failSlot
      INTEGER*8 localId,failId,idRadix,idHi8,idLo8
      INTEGER localMeta(9),allMeta(9,nPx*nPy)
      INTEGER jp,mpiRC,best
      LOGICAL allValid,replace
      INTEGER myThid

      idRadix=4294967296_8
      localMeta(1)=0
      IF ( localCode.NE.0 ) localMeta(1)=1
      localMeta(2)=localPhase
      localMeta(3)=localCode
      localMeta(4)=localRank
      localMeta(5)=localBi
      localMeta(6)=localBj
      localMeta(7)=localSlot
      idHi8=localId/idRadix
      idLo8=MOD(localId,idRadix)
      localMeta(8)=INT(idHi8)
      IF ( idLo8.GT.2147483647_8 ) THEN
        localMeta(9)=INT(idLo8-idRadix)
      ELSE
        localMeta(9)=INT(idLo8)
      ENDIF
      DO jp=1,nPx*nPy
        allMeta(1,jp)=0
      ENDDO
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allgather(
     I       localMeta,9,MPI_INTEGER,
     O       allMeta,9,MPI_INTEGER,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.0 ) THEN
          allMeta(1,1)=1
          allMeta(2,1)=4
          allMeta(3,1)=31
          allMeta(4,1)=0
          allMeta(5,1)=0
          allMeta(6,1)=0
          allMeta(7,1)=0
          allMeta(8,1)=0
          allMeta(9,1)=0
        ENDIF
      ELSE
#endif
        DO jp=1,9
          allMeta(jp,1)=localMeta(jp)
        ENDDO
#ifdef ALLOW_USE_MPI
      ENDIF
#endif
      best=0
      DO jp=1,nPx*nPy
        IF ( allMeta(1,jp).NE.0 ) THEN
          replace=best.EQ.0
          IF ( .NOT.replace ) THEN
            IF ( allMeta(2,jp).LT.allMeta(2,best) ) THEN
              replace=.TRUE.
            ELSEIF ( allMeta(2,jp).EQ.allMeta(2,best) .AND.
     &               allMeta(4,jp).LT.allMeta(4,best) ) THEN
              replace=.TRUE.
            ELSEIF ( allMeta(2,jp).EQ.allMeta(2,best) .AND.
     &               allMeta(4,jp).EQ.allMeta(4,best) .AND.
     &               allMeta(5,jp).LT.allMeta(5,best) ) THEN
              replace=.TRUE.
            ELSEIF ( allMeta(2,jp).EQ.allMeta(2,best) .AND.
     &               allMeta(4,jp).EQ.allMeta(4,best) .AND.
     &               allMeta(5,jp).EQ.allMeta(5,best) .AND.
     &               allMeta(6,jp).LT.allMeta(6,best) ) THEN
              replace=.TRUE.
            ELSEIF ( allMeta(2,jp).EQ.allMeta(2,best) .AND.
     &               allMeta(4,jp).EQ.allMeta(4,best) .AND.
     &               allMeta(5,jp).EQ.allMeta(5,best) .AND.
     &               allMeta(6,jp).EQ.allMeta(6,best) .AND.
     &               allMeta(7,jp).LT.allMeta(7,best) ) THEN
              replace=.TRUE.
            ENDIF
          ENDIF
          IF ( replace ) best=jp
        ENDIF
      ENDDO
      IF ( best.EQ.0 ) THEN
        failPhase=0
        failCode=0
        failRank=-1
        failBi=0
        failBj=0
        failSlot=0
        failId=0_8
        allValid=.TRUE.
      ELSE
        failPhase=allMeta(2,best)
        failCode=allMeta(3,best)
        failRank=allMeta(4,best)
        failBi=allMeta(5,best)
        failBj=allMeta(6,best)
        failSlot=allMeta(7,best)
        idHi8=INT(allMeta(8,best),8)
        idLo8=INT(allMeta(9,best),8)
        IF ( idLo8.LT.0_8 ) idLo8=idLo8+idRadix
        failId=idHi8*idRadix+idLo8
        allValid=.FALSE.
      ENDIF
      RETURN
      END
