#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_CAPACITY(myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid,nFail,globalFail

      nFail=0
      CALL BOM_VERIFY_P45_EVENT_LIMITS(nFail,myThid)
      CALL BOM_VERIFY_P45_EVENT_ORDER(nFail,myThid)
      CALL BOM_VERIFY_P45_ID_RANGE(nFail,myThid)
      CALL BOM_VERIFY_P45_EXCHANGE_LIMITS(nFail,myThid)
      globalFail=nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.NE.0 ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P4.5 CAPACITY FIXTURE'
      ENDIF
      IF ( myProcId.EQ.0 ) CALL PRINT_MESSAGE(
     &     'B19-CAPACITY PASS: exact limits and stable overflow',
     &     standardMessageUnit,SQUEEZE_RIGHT,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_EVENT_LIMITS(nFail,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nFail,myThid,bi,bj
      INTEGER tileSurvivor(nSx,nSy),tileBirth(nSx,nSy)
      INTEGER failCode,phase,rank,failBi,failBj,slot
      INTEGER*8 failId,need,capacity,nextId
      LOGICAL valid

      DO bj=1,nSy
       DO bi=1,nSx
        tileSurvivor(bi,bj)=0
        tileBirth(bi,bj)=0
       ENDDO
      ENDDO
      bomMaxParticles=2
      nextId=100_8
      CALL BOM_EVENT_PREFLIGHT(
     I     1,0,1,0,0,0,0,tileSurvivor,tileBirth,nextId,
     O     failCode,phase,rank,failBi,failBj,slot,failId,
     O     need,capacity,valid)
      CALL BOM_VERIFY_P45_ASSERT(valid,
     &     'B19 global live equality succeeds',nFail,myThid)
      bomMaxParticles=1
      CALL BOM_EVENT_PREFLIGHT(
     I     1,0,1,0,0,0,0,tileSurvivor,tileBirth,nextId,
     O     failCode,phase,rank,failBi,failBj,slot,failId,
     O     need,capacity,valid)
      IF ( myProcId.EQ.0 ) THEN
        CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &       failCode.EQ.BOM_FAIL_BIRTH_CAPACITY .AND.
     &       phase.EQ.BOM_P4_PHASE_CAPACITY .AND. rank.EQ.0 .AND.
     &       failBi.EQ.0 .AND. failBj.EQ.0 .AND.
     &       need.EQ.2_8 .AND. capacity.EQ.1_8,
     &       'B19 global live overflow context',nFail,myThid)
      ELSE
        CALL BOM_VERIFY_P45_ASSERT(valid,
     &       'B19 global failure has unique rank owner',nFail,myThid)
      ENDIF
      CALL BOM_VERIFY_P45_CANONICAL(
     I     failCode,phase,rank,failBi,failBj,slot,failId,
     I     BOM_FAIL_BIRTH_CAPACITY,BOM_P4_PHASE_CAPACITY,0,0,0,
     U     nFail,myThid)

      bomMaxParticles=bomMaxPartTile*nSx*nSy*nPx*nPy
      tileSurvivor(1,1)=bomMaxPartTile-1
      tileBirth(1,1)=1
      CALL BOM_EVENT_PREFLIGHT(
     I     0,0,0,0,0,0,0,tileSurvivor,tileBirth,nextId,
     O     failCode,phase,rank,failBi,failBj,slot,failId,
     O     need,capacity,valid)
      CALL BOM_VERIFY_P45_ASSERT(valid,
     &     'B19 destination tile equality succeeds',nFail,myThid)
      tileSurvivor(1,1)=bomMaxPartTile
      CALL BOM_EVENT_PREFLIGHT(
     I     0,0,0,0,0,0,0,tileSurvivor,tileBirth,nextId,
     O     failCode,phase,rank,failBi,failBj,slot,failId,
     O     need,capacity,valid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_BIRTH_CAPACITY .AND.
     &     phase.EQ.BOM_P4_PHASE_CAPACITY .AND.
     &     failBi.EQ.1 .AND. failBj.EQ.1 .AND.
     &     need.EQ.INT(bomMaxPartTile+1,8) .AND.
     &     capacity.EQ.INT(bomMaxPartTile,8),
     &     'B19 destination tile overflow context',nFail,myThid)
      CALL BOM_VERIFY_P45_CANONICAL(
     I     failCode,phase,rank,failBi,failBj,slot,failId,
     I     BOM_FAIL_BIRTH_CAPACITY,BOM_P4_PHASE_CAPACITY,0,1,1,
     U     nFail,myThid)
      tileSurvivor(1,1)=0
      tileBirth(1,1)=0

      CALL BOM_EVENT_PREFLIGHT(
     I     0,0,0,bomMaxEventBuffer,0,0,0,
     I     tileSurvivor,tileBirth,nextId,
     O     failCode,phase,rank,failBi,failBj,slot,failId,
     O     need,capacity,valid)
      CALL BOM_VERIFY_P45_ASSERT(valid,
     &     'B19 event allgather equality succeeds',nFail,myThid)
      CALL BOM_EVENT_PREFLIGHT(
     I     0,0,0,bomMaxEventBuffer+1,0,0,0,
     I     tileSurvivor,tileBirth,nextId,
     O     failCode,phase,rank,failBi,failBj,slot,failId,
     O     need,capacity,valid)
      IF ( myProcId.EQ.0 ) CALL BOM_VERIFY_P45_ASSERT(
     &     .NOT.valid .AND. failCode.EQ.BOM_FAIL_EVENT_CAPACITY
     &     .AND. phase.EQ.BOM_P4_PHASE_CAPACITY .AND.
     &     need.EQ.INT(bomMaxEventBuffer+1,8) .AND.
     &     capacity.EQ.INT(bomMaxEventBuffer,8),
     &     'B19 event allgather overflow context',nFail,myThid)
      CALL BOM_VERIFY_P45_CANONICAL(
     I     failCode,phase,rank,failBi,failBj,slot,failId,
     I     BOM_FAIL_EVENT_CAPACITY,BOM_P4_PHASE_CAPACITY,0,0,0,
     U     nFail,myThid)

      CALL BOM_EVENT_PREFLIGHT(
     I     0,0,0,0,2,0,bomMaxEventBuffer-2,
     I     tileSurvivor,tileBirth,nextId,
     O     failCode,phase,rank,failBi,failBj,slot,failId,
     O     need,capacity,valid)
      CALL BOM_VERIFY_P45_ASSERT(valid,
     &     'B19 unflushed buffer equality succeeds',nFail,myThid)
      CALL BOM_EVENT_PREFLIGHT(
     I     0,0,0,0,2,0,bomMaxEventBuffer-1,
     I     tileSurvivor,tileBirth,nextId,
     O     failCode,phase,rank,failBi,failBj,slot,failId,
     O     need,capacity,valid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_EVENT_CAPACITY .AND.
     &     phase.EQ.BOM_P4_PHASE_CAPACITY .AND.
     &     need.EQ.INT(bomMaxEventBuffer+1,8) .AND.
     &     capacity.EQ.INT(bomMaxEventBuffer,8),
     &     'B19 unflushed buffer overflow context',nFail,myThid)
      CALL BOM_VERIFY_P45_CANONICAL(
     I     failCode,phase,rank,failBi,failBj,slot,failId,
     I     BOM_FAIL_EVENT_CAPACITY,BOM_P4_PHASE_CAPACITY,0,0,0,
     U     nFail,myThid)

      nextId=HUGE(nextId)-1_8
      CALL BOM_EVENT_PREFLIGHT(
     I     0,0,1,0,0,0,0,tileSurvivor,tileBirth,nextId,
     O     failCode,phase,rank,failBi,failBj,slot,failId,
     O     need,capacity,valid)
      CALL BOM_VERIFY_P45_ASSERT(valid,
     &     'B19 exact ID equality succeeds',nFail,myThid)
      nextId=HUGE(nextId)
      CALL BOM_EVENT_PREFLIGHT(
     I     0,0,1,0,0,0,0,tileSurvivor,tileBirth,nextId,
     O     failCode,phase,rank,failBi,failBj,slot,failId,
     O     need,capacity,valid)
      IF ( myProcId.EQ.0 ) CALL BOM_VERIFY_P45_ASSERT(
     &     .NOT.valid .AND. failCode.EQ.BOM_FAIL_BIRTH_ID .AND.
     &     phase.EQ.BOM_P4_PHASE_BIRTH_ORDER .AND.
     &     failId.EQ.nextId .AND. need.EQ.1_8 .AND.
     &     capacity.EQ.0_8,
     &     'B19 exact ID overflow context',nFail,myThid)
      CALL BOM_VERIFY_P45_CANONICAL(
     I     failCode,phase,rank,failBi,failBj,slot,failId,
     I     BOM_FAIL_BIRTH_ID,BOM_P4_PHASE_BIRTH_ORDER,0,0,0,
     U     nFail,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_EVENT_ORDER(nFail,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nFail,myThid,nLocal,nGlobal,ip,base,remainder
      INTEGER localBi(bomMaxEventBuffer),localBj(bomMaxEventBuffer)
      INTEGER localSlot(bomMaxEventBuffer)
      INTEGER localOrdinal(bomMaxEventBuffer)
      INTEGER failCode,phase,rank,failBi,failBj,failSlot
      INTEGER*8 parentId(bomMaxEventBuffer),failId
      LOGICAL valid

      base=bomMaxEventBuffer/(nPx*nPy)
      remainder=MOD(bomMaxEventBuffer,nPx*nPy)
      nLocal=base
      IF ( myProcId.LT.remainder ) nLocal=nLocal+1
      DO ip=1,bomMaxEventBuffer
        parentId(ip)=INT(1000+myProcId*bomMaxEventBuffer+ip,8)
        localBi(ip)=1
        localBj(ip)=1
        localSlot(ip)=MIN(ip,bomMaxPartTile)
      ENDDO
      CALL BOM_BIRTH_PARENT_ORDER(
     I     nLocal,parentId,localBi,localBj,localSlot,
     O     localOrdinal,nGlobal,
     O     failCode,phase,rank,failBi,failBj,failSlot,failId,
     O     valid,myThid)
      CALL BOM_VERIFY_P45_ASSERT(valid .AND.
     &     nGlobal.EQ.bomMaxEventBuffer,
     &     'B19 production allgather exact equality',nFail,myThid)

      base=(bomMaxEventBuffer+1)/(nPx*nPy)
      remainder=MOD(bomMaxEventBuffer+1,nPx*nPy)
      nLocal=base
      IF ( myProcId.LT.remainder ) nLocal=nLocal+1
      CALL BOM_BIRTH_PARENT_ORDER(
     I     nLocal,parentId,localBi,localBj,localSlot,
     O     localOrdinal,nGlobal,
     O     failCode,phase,rank,failBi,failBj,failSlot,failId,
     O     valid,myThid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_EVENT_CAPACITY .AND.
     &     phase.EQ.BOM_P4_PHASE_CAPACITY .AND. rank.EQ.0,
     &     'B19 production allgather one-past failure',nFail,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_ID_RANGE(nFail,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nFail,myThid,nLocal,nGlobal,ip
      INTEGER birthCount(bomMaxEventBuffer),attempt(bomMaxEventBuffer)
      INTEGER sourceBi(bomMaxEventBuffer),sourceBj(bomMaxEventBuffer)
      INTEGER sourceSlot(bomMaxEventBuffer)
      INTEGER destRank(bomMaxEventBuffer),destBi(bomMaxEventBuffer)
      INTEGER destBj(bomMaxEventBuffer)
      INTEGER globalBirthCount(bomMaxEventBuffer)
      INTEGER globalAttempt(bomMaxEventBuffer)
      INTEGER globalSourceRank(bomMaxEventBuffer)
      INTEGER globalSourceBi(bomMaxEventBuffer)
      INTEGER globalSourceBj(bomMaxEventBuffer)
      INTEGER globalSourceSlot(bomMaxEventBuffer)
      INTEGER globalDestRank(bomMaxEventBuffer)
      INTEGER globalDestBi(bomMaxEventBuffer)
      INTEGER globalDestBj(bomMaxEventBuffer)
      INTEGER failCode,phase,rank,failBi,failBj,failSlot
      INTEGER*8 parentId(bomMaxEventBuffer)
      INTEGER*8 eventIndex(bomMaxEventBuffer)
      INTEGER*8 childId(bomMaxEventBuffer)
      INTEGER*8 globalParentId(bomMaxEventBuffer)
      INTEGER*8 globalChildId(bomMaxEventBuffer)
      INTEGER*8 globalEventIndex(bomMaxEventBuffer)
      INTEGER*8 nextBefore,nextAfter,failId
      _RL x(bomMaxEventBuffer),y(bomMaxEventBuffer)
      _RL globalX(bomMaxEventBuffer),globalY(bomMaxEventBuffer)
      LOGICAL valid

      bomBirthMaxTry=8
      bomEventTimeIndex=7_8
      nLocal=0
      IF ( myProcId.EQ.0 ) nLocal=1
      DO ip=1,bomMaxEventBuffer
        parentId(ip)=INT(10+ip,8)
        birthCount(ip)=ip-1
        eventIndex(ip)=bomEventTimeIndex
        attempt(ip)=0
        sourceBi(ip)=1
        sourceBj(ip)=1
        sourceSlot(ip)=1
        destRank(ip)=0
        destBi(ip)=1
        destBj(ip)=1
        x(ip)=0. _d 0
        y(ip)=0. _d 0
      ENDDO
      nextBefore=HUGE(nextBefore)-1_8
      CALL BOM_BIRTH_ACCEPT_ORDER(
     I     nLocal,parentId,birthCount,eventIndex,attempt,
     I     sourceBi,sourceBj,sourceSlot,destRank,destBi,destBj,
     I     x,y,nextBefore,
     O     childId,nGlobal,globalParentId,globalChildId,
     O     globalBirthCount,globalEventIndex,globalAttempt,
     O     globalSourceRank,globalSourceBi,globalSourceBj,
     O     globalSourceSlot,globalDestRank,globalDestBi,globalDestBj,
     O     globalX,globalY,nextAfter,
     O     failCode,phase,rank,failBi,failBj,failSlot,failId,
     O     valid,myThid)
      CALL BOM_VERIFY_P45_ASSERT(valid .AND. nGlobal.EQ.1 .AND.
     &     nextAfter.EQ.HUGE(nextAfter),
     &     'B19 production ID exact equality',nFail,myThid)
      nextBefore=HUGE(nextBefore)
      CALL BOM_BIRTH_ACCEPT_ORDER(
     I     nLocal,parentId,birthCount,eventIndex,attempt,
     I     sourceBi,sourceBj,sourceSlot,destRank,destBi,destBj,
     I     x,y,nextBefore,
     O     childId,nGlobal,globalParentId,globalChildId,
     O     globalBirthCount,globalEventIndex,globalAttempt,
     O     globalSourceRank,globalSourceBi,globalSourceBj,
     O     globalSourceSlot,globalDestRank,globalDestBi,globalDestBj,
     O     globalX,globalY,nextAfter,
     O     failCode,phase,rank,failBi,failBj,failSlot,failId,
     O     valid,myThid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_BIRTH_ID .AND.
     &     phase.EQ.BOM_P4_PHASE_BIRTH_ORDER .AND. rank.EQ.0 .AND.
     &     failId.EQ.nextBefore .AND. nextAfter.EQ.nextBefore,
     &     'B19 production ID one-past rollback',nFail,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_EXCHANGE_LIMITS(nFail,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nFail,myThid,bi,bj
      INTEGER targetCount(nSx,nSy)
      INTEGER failCode,phase,rank,failBi,failBj
      INTEGER*8 need,capacity
      LOGICAL valid

      DO bj=1,nSy
       DO bi=1,nSx
        targetCount(bi,bj)=0
       ENDDO
      ENDDO
      targetCount(1,1)=bomMaxPartTile
      CALL BOM_OWNER_EXCHANGE_PREFLIGHT(
     I     bomMaxExchange,bomMaxExchange,targetCount,.TRUE.,
     O     failCode,phase,rank,failBi,failBj,need,capacity,valid)
      CALL BOM_VERIFY_P45_ASSERT(valid,
     &     'B19 owner exchange equality succeeds',nFail,myThid)
      CALL BOM_OWNER_EXCHANGE_PREFLIGHT(
     I     bomMaxExchange+1,bomMaxExchange,targetCount,.FALSE.,
     O     failCode,phase,rank,failBi,failBj,need,capacity,valid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_BIRTH_CAPACITY .AND.
     &     phase.EQ.BOM_P4_PHASE_CAPACITY .AND.
     &     need.EQ.INT(bomMaxExchange+1,8) .AND.
     &     capacity.EQ.INT(bomMaxExchange,8),
     &     'B19 owner exchange overflow context',nFail,myThid)
      targetCount(1,1)=bomMaxPartTile+1
      CALL BOM_OWNER_EXCHANGE_PREFLIGHT(
     I     0,0,targetCount,.TRUE.,
     O     failCode,phase,rank,failBi,failBj,need,capacity,valid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failBi.EQ.1 .AND. failBj.EQ.1 .AND.
     &     need.EQ.INT(bomMaxPartTile+1,8) .AND.
     &     capacity.EQ.INT(bomMaxPartTile,8),
     &     'B19 owner target-tile overflow context',nFail,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_CANONICAL(
     I     localCode,localPhase,localRank,localBi,localBj,localSlot,
     I     localId,expectedCode,expectedPhase,expectedRank,
     I     expectedBi,expectedBj,
     U     nFail,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      INTEGER localCode,localPhase,localRank,localBi,localBj,localSlot
      INTEGER expectedCode,expectedPhase,expectedRank
      INTEGER expectedBi,expectedBj,nFail,myThid
      INTEGER code,phase,rank,bi,bj,slot
      INTEGER*8 localId,failId
      LOGICAL valid
      CALL BOM_P4_SELECT_FAILURE(
     I     localPhase,localCode,localRank,localBi,localBj,
     I     localSlot,localId,
     O     phase,code,rank,bi,bj,slot,failId,valid,myThid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     code.EQ.expectedCode .AND. phase.EQ.expectedPhase .AND.
     &     rank.EQ.expectedRank .AND. bi.EQ.expectedBi .AND.
     &     bj.EQ.expectedBj,
     &     'B19 canonical first-failure context',nFail,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_ASSERT(
     I     condition,label,
     U     nFail,
     I     myThid)
      IMPLICIT NONE
#include "EEPARAMS.h"
      LOGICAL condition
      CHARACTER*(*) label
      INTEGER nFail,myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      IF ( .NOT.condition ) THEN
        nFail=nFail+1
        WRITE(msgBuf,'(A,A)') 'P4.5 ASSERT FAIL: ',label
        CALL PRINT_ERROR(msgBuf,myThid)
      ENDIF
      RETURN
      END
