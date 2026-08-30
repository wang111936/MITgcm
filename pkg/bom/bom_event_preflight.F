#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_EVENT_PREFLIGHT
C !INTERFACE:
      SUBROUTINE BOM_EVENT_PREFLIGHT(
     I     globalOwners,globalTerminal,nGlobalBirth,nGlobalProposal,
     I     nPlan,nBirth,eventBufferCount,tileSurvivor,tileBirth,
     I     nextIdBefore,
     O     failCode,p4FailPhase,failRank,failBi,failBj,failSlot,
     O     failId,failureNeed,failureCapacity,isValid )

C !DESCRIPTION:
C     Validate every bounded Phase-4 event resource without modifying owner,
C     free-stack, event, counter, endpoint, schedule, or graph state.  Exact
C     equality is accepted.  The first local failure reports stable code and
C     phase plus the required and available counts; the caller applies the
C     canonical cross-rank failure selector before commit.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER globalOwners,globalTerminal,nGlobalBirth,nGlobalProposal
      INTEGER nPlan,nBirth,eventBufferCount
      INTEGER tileSurvivor(nSx,nSy),tileBirth(nSx,nSy)
      INTEGER*8 nextIdBefore
      INTEGER failCode,p4FailPhase,failRank,failBi,failBj,failSlot
      INTEGER*8 failId,failureNeed,failureCapacity
      LOGICAL isValid

#ifdef ALLOW_BOM
      INTEGER bi,bj
      INTEGER*8 required,capacity,globalAfter,eventNeed

      failCode=BOM_FAIL_NONE
      p4FailPhase=BOM_P4_PHASE_NONE
      failRank=-1
      failBi=0
      failBj=0
      failSlot=0
      failId=0_8
      failureNeed=0_8
      failureCapacity=0_8
      isValid=.TRUE.

C--   Global live capacity is a birth-capacity condition, not a diagnostic
C     budget failure.  Rank zero owns the unique global failure context.
      globalAfter=INT(globalOwners,8)-INT(globalTerminal,8)
     &     +INT(nGlobalBirth,8)
      IF ( myProcId.EQ.0 .AND.
     &    (globalOwners.LT.0 .OR. globalTerminal.LT.0 .OR.
     &     nGlobalBirth.LT.0 .OR. globalAfter.LT.0_8 .OR.
     &     globalAfter.GT.INT(bomMaxParticles,8)) ) THEN
        required=MAX(0_8,globalAfter)
        capacity=MAX(0_8,INT(bomMaxParticles,8))
        CALL BOM_PREFLIGHT_SET_FAILURE(
     I       BOM_P4_PHASE_CAPACITY,BOM_FAIL_BIRTH_CAPACITY,
     I       myProcId,0,0,0,0_8,required,capacity,
     U       failCode,p4FailPhase,failRank,failBi,failBj,failSlot,
     U       failId,failureNeed,failureCapacity,isValid)
      ENDIF

C--   Destination tiles are checked in the frozen (rank,bj,bi) order.
      DO bj=1,nSy
       DO bi=1,nSx
        required=INT(tileSurvivor(bi,bj),8)
     &       +INT(tileBirth(bi,bj),8)
        capacity=INT(bomMaxPartTile,8)
        IF ( tileSurvivor(bi,bj).LT.0 .OR.
     &       tileBirth(bi,bj).LT.0 .OR. required.LT.0_8 .OR.
     &       required.GT.capacity ) CALL BOM_PREFLIGHT_SET_FAILURE(
     I       BOM_P4_PHASE_CAPACITY,BOM_FAIL_BIRTH_CAPACITY,
     I       myProcId,bi,bj,0,0_8,MAX(0_8,required),capacity,
     U       failCode,p4FailPhase,failRank,failBi,failBj,failSlot,
     U       failId,failureNeed,failureCapacity,isValid)
       ENDDO
      ENDDO

C--   Candidate/allgather and unflushed-buffer bounds are independent.
      required=INT(nGlobalProposal,8)
      capacity=INT(bomMaxEventBuffer,8)
      IF ( myProcId.EQ.0 .AND.
     &    (nGlobalProposal.LT.0 .OR. required.GT.capacity) )
     &     CALL BOM_PREFLIGHT_SET_FAILURE(
     I       BOM_P4_PHASE_CAPACITY,BOM_FAIL_EVENT_CAPACITY,
     I       myProcId,0,0,0,0_8,MAX(0_8,required),capacity,
     U       failCode,p4FailPhase,failRank,failBi,failBj,failSlot,
     U       failId,failureNeed,failureCapacity,isValid)
      eventNeed=INT(nPlan,8)+INT(nBirth,8)
      IF ( nPlan.LT.0 .OR. nBirth.LT.0 .OR. eventNeed.LT.0_8 .OR.
     &     eventNeed.GT.capacity ) CALL BOM_PREFLIGHT_SET_FAILURE(
     I       BOM_P4_PHASE_CAPACITY,BOM_FAIL_EVENT_CAPACITY,
     I       myProcId,0,0,0,0_8,MAX(0_8,eventNeed),capacity,
     U       failCode,p4FailPhase,failRank,failBi,failBj,failSlot,
     U       failId,failureNeed,failureCapacity,isValid)
      required=INT(eventBufferCount,8)+eventNeed
      IF ( eventBufferCount.LT.0 .OR. required.LT.0_8 .OR.
     &     required.GT.capacity ) CALL BOM_PREFLIGHT_SET_FAILURE(
     I       BOM_P4_PHASE_CAPACITY,BOM_FAIL_EVENT_CAPACITY,
     I       myProcId,0,0,0,0_8,MAX(0_8,required),capacity,
     U       failCode,p4FailPhase,failRank,failBi,failBj,failSlot,
     U       failId,failureNeed,failureCapacity,isValid)

C--   The required count is the requested number of IDs; the capacity is
C     the exact remaining positive signed-ID range, so overflow is reportable
C     without itself overflowing INTEGER*8.
      required=INT(MAX(0,nGlobalBirth),8)
      IF ( nextIdBefore.GT.0_8 ) THEN
        capacity=HUGE(nextIdBefore)-nextIdBefore
      ELSE
        capacity=0_8
      ENDIF
      IF ( myProcId.EQ.0 .AND. (nextIdBefore.LE.0_8 .OR.
     &     required.GT.capacity) ) CALL BOM_PREFLIGHT_SET_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,0,0,0,nextIdBefore,required,capacity,
     U       failCode,p4FailPhase,failRank,failBi,failBj,failSlot,
     U       failId,failureNeed,failureCapacity,isValid)
#else
      failCode=BOM_FAIL_EVENT_TRANSACTION
      p4FailPhase=BOM_P4_PHASE_CAPACITY
      failRank=0
      failBi=0
      failBj=0
      failSlot=0
      failId=0_8
      failureNeed=0_8
      failureCapacity=0_8
      isValid=.FALSE.
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_OWNER_EXCHANGE_PREFLIGHT(
     I     sendTotal,recvTotal,targetCount,checkTiles,
     O     failCode,p4FailPhase,failRank,failBi,failBj,
     O     failureNeed,failureCapacity,isValid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER sendTotal,recvTotal,targetCount(nSx,nSy)
      LOGICAL checkTiles
      INTEGER failCode,p4FailPhase,failRank,failBi,failBj
      INTEGER*8 failureNeed,failureCapacity
      LOGICAL isValid
#ifdef ALLOW_BOM
      INTEGER bi,bj,failSlot
      INTEGER*8 failId,required,capacity

      failCode=BOM_FAIL_NONE
      p4FailPhase=BOM_P4_PHASE_NONE
      failRank=-1
      failBi=0
      failBj=0
      failSlot=0
      failId=0_8
      failureNeed=0_8
      failureCapacity=0_8
      isValid=.TRUE.
      capacity=INT(bomMaxExchange,8)
      required=INT(sendTotal,8)
      IF ( sendTotal.LT.0 .OR. required.GT.capacity )
     &     CALL BOM_PREFLIGHT_SET_FAILURE(
     I       BOM_P4_PHASE_CAPACITY,BOM_FAIL_BIRTH_CAPACITY,
     I       myProcId,0,0,0,0_8,MAX(0_8,required),capacity,
     U       failCode,p4FailPhase,failRank,failBi,failBj,failSlot,
     U       failId,failureNeed,failureCapacity,isValid)
      required=INT(recvTotal,8)
      IF ( recvTotal.LT.0 .OR. required.GT.capacity )
     &     CALL BOM_PREFLIGHT_SET_FAILURE(
     I       BOM_P4_PHASE_CAPACITY,BOM_FAIL_BIRTH_CAPACITY,
     I       myProcId,0,0,0,0_8,MAX(0_8,required),capacity,
     U       failCode,p4FailPhase,failRank,failBi,failBj,failSlot,
     U       failId,failureNeed,failureCapacity,isValid)
      IF ( checkTiles ) THEN
        capacity=INT(bomMaxPartTile,8)
        DO bj=1,nSy
         DO bi=1,nSx
          required=INT(targetCount(bi,bj),8)
          IF ( targetCount(bi,bj).LT.0 .OR.
     &         required.GT.capacity ) CALL BOM_PREFLIGHT_SET_FAILURE(
     I         BOM_P4_PHASE_CAPACITY,BOM_FAIL_BIRTH_CAPACITY,
     I         myProcId,bi,bj,0,0_8,MAX(0_8,required),capacity,
     U         failCode,p4FailPhase,failRank,failBi,failBj,failSlot,
     U         failId,failureNeed,failureCapacity,isValid)
         ENDDO
        ENDDO
      ENDIF
#else
      failCode=BOM_FAIL_BIRTH_CAPACITY
      p4FailPhase=BOM_P4_PHASE_CAPACITY
      failRank=0
      failBi=0
      failBj=0
      failureNeed=0_8
      failureCapacity=0_8
      isValid=.FALSE.
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_PREFLIGHT_SET_FAILURE(
     I     candidatePhase,candidateCode,candidateRank,
     I     candidateBi,candidateBj,candidateSlot,candidateId,
     I     candidateNeed,candidateCapacity,
     U     failCode,p4FailPhase,failRank,failBi,failBj,failSlot,
     U     failId,failureNeed,failureCapacity,isValid )
      IMPLICIT NONE
      INTEGER candidatePhase,candidateCode,candidateRank
      INTEGER candidateBi,candidateBj,candidateSlot
      INTEGER failCode,p4FailPhase,failRank,failBi,failBj,failSlot
      INTEGER*8 candidateId,candidateNeed,candidateCapacity
      INTEGER*8 failId,failureNeed,failureCapacity
      LOGICAL isValid

      IF ( isValid ) THEN
        failCode=candidateCode
        p4FailPhase=candidatePhase
        failRank=candidateRank
        failBi=candidateBi
        failBj=candidateBj
        failSlot=candidateSlot
        failId=candidateId
        failureNeed=candidateNeed
        failureCapacity=candidateCapacity
        isValid=.FALSE.
      ENDIF
      RETURN
      END
