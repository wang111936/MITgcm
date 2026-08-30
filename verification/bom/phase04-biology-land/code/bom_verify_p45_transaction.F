#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_TRANSACTION(myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid,nFail,globalFail

      nFail=0
      CALL BOM_VERIFY_P45_TILE_EQUALITY(nFail,myThid)
      CALL BOM_VERIFY_P45_GLOBAL_ROLLBACK(nFail,myThid)
      CALL BOM_VERIFY_P45_TILE_ROLLBACK(nFail,myThid)
      CALL BOM_VERIFY_P45_BUFFER_ROLLBACK(nFail,myThid)
      globalFail=nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.NE.0 ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P4.5 TRANSACTION FIXTURE'
      ENDIF
      IF ( myProcId.EQ.0 ) CALL PRINT_MESSAGE(
     &     'B19-ROLLBACK PASS: global, tile and buffer transactions',
     &     standardMessageUnit,SQUEEZE_RIGHT,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_TILE_EQUALITY(nFail,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nFail,myThid,failCode,phase,rank,bi,bj,slot
      INTEGER ownerRank,ownerBi,ownerBj
      INTEGER*8 failId
      LOGICAL valid
      CALL BOM_VERIFY_P45_SEED(
     I     bomMaxPartTile-1,.TRUE.,.FALSE.,bomMaxPartTile,
     O     ownerRank,ownerBi,ownerBj,
     U     nFail,myThid)
      CALL BOM_EVENT_TRANSACTION_P43(
     I     0. _d 0,deltaTClock,51,1,BOM_P4_PHASE_NONE,
     O     failCode,phase,rank,bi,bj,slot,failId,valid,myThid)
      CALL BOM_VERIFY_P45_ASSERT(valid .AND.
     &     bomNPartLiveExpected.EQ.bomMaxPartTile .AND.
     &     bomNextId.EQ.1001_8,
     &     'B19 destination tile exact equality commits',nFail,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_GLOBAL_ROLLBACK(nFail,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nFail,myThid,failCode,phase,rank,bi,bj,slot
      INTEGER ownerRank,ownerBi,ownerBj
      INTEGER*8 failId
      LOGICAL valid
      CALL BOM_VERIFY_P45_SEED(
     I     1,.TRUE.,.FALSE.,1,
     O     ownerRank,ownerBi,ownerBj,
     U     nFail,myThid)
      CALL BOM_VERIFY_P45_PRINT_STATE('GLOBAL','BEFORE',myThid)
      CALL BOM_EVENT_TRANSACTION_P43(
     I     0. _d 0,deltaTClock,52,1,BOM_P4_PHASE_NONE,
     O     failCode,phase,rank,bi,bj,slot,failId,valid,myThid)
      CALL BOM_VERIFY_P45_PRINT_STATE('GLOBAL','AFTER ',myThid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_BIRTH_CAPACITY .AND.
     &     phase.EQ.BOM_P4_PHASE_CAPACITY .AND. rank.EQ.0 .AND.
     &     bi.EQ.0 .AND. bj.EQ.0,
     &     'B19 global live stable transaction failure',nFail,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_TILE_ROLLBACK(nFail,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nFail,myThid,failCode,phase,rank,bi,bj,slot
      INTEGER ownerRank,ownerBi,ownerBj
      INTEGER*8 failId
      LOGICAL valid
      CALL BOM_VERIFY_P45_SEED(
     I     bomMaxPartTile,.TRUE.,.FALSE.,2*bomMaxPartTile,
     O     ownerRank,ownerBi,ownerBj,
     U     nFail,myThid)
      CALL BOM_VERIFY_P45_PRINT_STATE('TILE','BEFORE',myThid)
      CALL BOM_EVENT_TRANSACTION_P43(
     I     0. _d 0,deltaTClock,53,1,BOM_P4_PHASE_NONE,
     O     failCode,phase,rank,bi,bj,slot,failId,valid,myThid)
      CALL BOM_VERIFY_P45_PRINT_STATE('TILE','AFTER ',myThid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_BIRTH_CAPACITY .AND.
     &     phase.EQ.BOM_P4_PHASE_CAPACITY .AND.
     &     rank.EQ.ownerRank .AND. bi.EQ.ownerBi .AND.
     &     bj.EQ.ownerBj,
     &     'B19 destination tile stable transaction failure',
     &     nFail,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_BUFFER_ROLLBACK(nFail,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nFail,myThid,failCode,phase,rank,bi,bj,slot
      INTEGER ownerRank,ownerBi,ownerBj
      INTEGER*8 failId
      LOGICAL valid
      CALL BOM_VERIFY_P45_SEED(
     I     1,.TRUE.,.FALSE.,2,
     O     ownerRank,ownerBi,ownerBj,
     U     nFail,myThid)
      bomEventBufferCount=bomMaxEventBuffer
      CALL BOM_VERIFY_P45_PRINT_STATE('BUFFER','BEFORE',myThid)
      CALL BOM_EVENT_TRANSACTION_P43(
     I     0. _d 0,deltaTClock,54,1,BOM_P4_PHASE_NONE,
     O     failCode,phase,rank,bi,bj,slot,failId,valid,myThid)
      CALL BOM_VERIFY_P45_PRINT_STATE('BUFFER','AFTER ',myThid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_EVENT_CAPACITY .AND.
     &     phase.EQ.BOM_P4_PHASE_CAPACITY .AND.
     &     rank.EQ.ownerRank,
     &     'B19 unflushed buffer stable transaction failure',
     &     nFail,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_GRAPH(myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid,nFail,globalFail,failCode,phase,rank,bi,bj,slot
      INTEGER ownerRank,ownerBi,ownerBj
      INTEGER*8 failId
      LOGICAL valid
      CHARACTER*(MAX_LEN_MBUF) msgBuf

      nFail=0
      CALL BOM_VERIFY_P45_SEED(
     I     MIN(bomMaxNeighbor,bomMaxGhostTile)-1,.TRUE.,.TRUE.,
     I     MIN(bomMaxNeighbor,bomMaxGhostTile),
     O     ownerRank,ownerBi,ownerBj,
     U     nFail,myThid)
      CALL BOM_EVENT_TRANSACTION_P43(
     I     0. _d 0,deltaTClock,55,1,BOM_P4_PHASE_NONE,
     O     failCode,phase,rank,bi,bj,slot,failId,valid,myThid)
      CALL BOM_VERIFY_P45_ASSERT(valid .AND.
     &     bomNPartLiveExpected.EQ.
     &       MIN(bomMaxNeighbor,bomMaxGhostTile),
     &     'B19 post-birth graph equality commits',nFail,myThid)
      CALL BOM_VERIFY_P45_GRAPH_LIMITS(nFail,ownerRank,myThid)
      CALL BOM_VERIFY_P45_GHOST_LIMITS(
     U     nFail,
     I     ownerRank,ownerBi,ownerBj,myThid)
      WRITE(msgBuf,1000) myProcId,bomP3GhostPacketsSent,
     &     bomP3GhostPacketsReceived,bomP3MaximumNeighbors,
     &     bomMaxGhostTile,bomMaxNeighbor
      CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                   SQUEEZE_RIGHT,myThid)

      CALL BOM_VERIFY_P45_SEED(
     I     bomMaxNeighbor+1,.TRUE.,.TRUE.,bomMaxNeighbor+2,
     O     ownerRank,ownerBi,ownerBj,
     U     nFail,myThid)
      CALL BOM_VERIFY_P45_PRINT_STATE('GRAPH','BEFORE',myThid)
      CALL BOM_EVENT_TRANSACTION_P43(
     I     0. _d 0,deltaTClock,56,1,BOM_P4_PHASE_NONE,
     O     failCode,phase,rank,bi,bj,slot,failId,valid,myThid)
      CALL BOM_VERIFY_P45_PRINT_STATE('GRAPH','AFTER ',myThid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     phase.EQ.BOM_P4_PHASE_GRAPH .AND.
     &     failCode.EQ.BOM_FAIL_NEIGHBOR_CAPACITY .AND.
     &     rank.EQ.0 .AND. bi.EQ.0 .AND. bj.EQ.0 .AND.
     &     slot.EQ.0 .AND. failId.EQ.0_8,
     &     'B19 post-birth bounded graph failure',nFail,myThid)
      WRITE(msgBuf,1001) myProcId,failCode,phase,rank,
     &     bomMaxGhostTile+1,bomMaxGhostTile,
     &     bomMaxNeighbor+1,bomMaxNeighbor
      CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                   SQUEEZE_RIGHT,myThid)
      globalFail=nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.NE.0 ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P4.5 GRAPH FIXTURE'
      ENDIF
      IF ( myProcId.EQ.0 ) CALL PRINT_MESSAGE(
     &     'B19-GRAPH PASS: post-birth equality and rollback',
     &     standardMessageUnit,SQUEEZE_RIGHT,myThid)
      RETURN
 1000 FORMAT('B19-GRAPH-EQUALITY rank/sent/recv/max/caps=',
     &       I4,3I8,2I8)
 1001 FORMAT('B19-GRAPH-OVERFLOW rank/code/phase/context=',
     &       4I8,' need/cap ghost=',2I8,' neighbor=',2I8)
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_GRAPH_LIMITS(
     I     nFail,ownerRank,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nFail,ownerRank,myThid,bi,bj,ip,rec,owner
      INTEGER nOwner,nRecord,nCellX,nCellY,nCell,cellReachY
      INTEGER failCode,failPhase
      INTEGER recordStatus(bomMaxCellRecord)
      INTEGER recordOwner(bomMaxCellRecord)
      INTEGER cellHead(bomMaxCell),cellNext(bomMaxCellRecord)
      INTEGER recordCell(bomMaxCellRecord),rowReachX(bomMaxCell)
      INTEGER neighborCount(bomMaxOwnerRecord)
      INTEGER neighborRecord(bomMaxNeighbor,bomMaxOwnerRecord)
      INTEGER*8 recordId(bomMaxCellRecord)
      INTEGER*8 neighborId(bomMaxNeighbor,bomMaxOwnerRecord)
      INTEGER*8 owners,ghosts,nonEmpty,comparisons
      INTEGER*8 directed,undirected,maximum,need,capacity
      _RL recordX(bomMaxCellRecord),recordY(bomMaxCellRecord)
      LOGICAL valid,bornFound

      IF ( myProcId.NE.ownerRank ) RETURN
      nOwner=0
      bornFound=.FALSE.
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          IF ( bomStatus(ip,bi,bj).EQ.BOM_ALIVE ) THEN
            nOwner=nOwner+1
            recordId(nOwner)=bomId(ip,bi,bj)
            recordStatus(nOwner)=BOM_ALIVE
            recordOwner(nOwner)=nOwner
            recordX(nOwner)=0.45 _d 0+0.01 _d 0*DFLOAT(nOwner)
            recordY(nOwner)=0.5 _d 0
            IF ( bomParentId(ip,bi,bj).GT.0_8 ) bornFound=.TRUE.
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      CALL BOM_VERIFY_P45_ASSERT(
     &     nOwner.EQ.bomMaxNeighbor .AND. bornFound,
     &     'B19 graph limits use committed child set',nFail,myThid)
      IF ( nOwner.NE.bomMaxNeighbor ) RETURN
      nRecord=nOwner
      nCellX=1
      nCellY=1
      nCell=1
      cellReachY=1
      DO rec=1,bomMaxCell
        cellHead(rec)=0
        rowReachX(rec)=1
      ENDDO
      cellHead(1)=1
      DO rec=1,bomMaxCellRecord
        cellNext(rec)=0
        recordCell(rec)=0
      ENDDO
      DO rec=1,nRecord
        recordCell(rec)=1
        IF ( rec.LT.nRecord ) cellNext(rec)=rec+1
      ENDDO

C--   Exact candidate and neighbor limits both accept the committed set.
      CALL BOM_BUILD_NEIGHBORS(
     I     nRecord,nOwner,nOwner,nOwner-1,
     I     recordId,recordStatus,recordX,recordY,recordOwner,
     I     cellHead,cellNext,recordCell,
     I     .TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,1. _d -12,oneRL,
     I     nCellX,nCellY,nCell,cellReachY,rowReachX,
     O     neighborCount,neighborId,neighborRecord,
     O     owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O     maximum,need,capacity,failCode,failPhase,valid)
      CALL BOM_VERIFY_P45_ASSERT(valid .AND.
     &     maximum.EQ.INT(nOwner-1,8),
     &     'B19 candidate and neighbor equality succeeds',
     &     nFail,myThid)

C--   One-past candidate workspace reports 4/3 and publishes nothing.
      DO owner=1,bomMaxOwnerRecord
        neighborCount(owner)=-301
        DO rec=1,bomMaxNeighbor
          neighborId(rec,owner)=-302_8
          neighborRecord(rec,owner)=-303
        ENDDO
      ENDDO
      owners=-304_8
      ghosts=-305_8
      nonEmpty=-306_8
      comparisons=-307_8
      directed=-308_8
      undirected=-309_8
      maximum=-310_8
      CALL BOM_BUILD_NEIGHBORS(
     I     nRecord,nOwner,nOwner-1,nOwner-1,
     I     recordId,recordStatus,recordX,recordY,recordOwner,
     I     cellHead,cellNext,recordCell,
     I     .TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,1. _d -12,oneRL,
     I     nCellX,nCellY,nCell,cellReachY,rowReachX,
     O     neighborCount,neighborId,neighborRecord,
     O     owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O     maximum,need,capacity,failCode,failPhase,valid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_CELL_CAPACITY .AND.
     &     failPhase.EQ.BOM_P3_PHASE_CELL .AND.
     &     need.EQ.INT(nOwner,8) .AND.
     &     capacity.EQ.INT(nOwner-1,8),
     &     'B19 candidate overflow need and capacity',nFail,myThid)
      CALL BOM_VERIFY_P45_ASSERT(
     &     neighborCount(1).EQ.-301 .AND.
     &     neighborId(1,1).EQ.-302_8 .AND.
     &     neighborRecord(1,1).EQ.-303 .AND.
     &     owners.EQ.-304_8 .AND. directed.EQ.-308_8,
     &     'B19 candidate overflow rollback',nFail,myThid)

C--   One-past neighbor workspace reports 3/2 and publishes nothing.
      CALL BOM_BUILD_NEIGHBORS(
     I     nRecord,nOwner,nOwner,nOwner-2,
     I     recordId,recordStatus,recordX,recordY,recordOwner,
     I     cellHead,cellNext,recordCell,
     I     .TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,1. _d -12,oneRL,
     I     nCellX,nCellY,nCell,cellReachY,rowReachX,
     O     neighborCount,neighborId,neighborRecord,
     O     owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O     maximum,need,capacity,failCode,failPhase,valid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_NEIGHBOR_CAPACITY .AND.
     &     failPhase.EQ.BOM_P3_PHASE_NEIGHBOR .AND.
     &     need.EQ.INT(nOwner-1,8) .AND.
     &     capacity.EQ.INT(nOwner-2,8),
     &     'B19 neighbor overflow need and capacity',nFail,myThid)
      CALL BOM_VERIFY_P45_ASSERT(
     &     neighborCount(1).EQ.-301 .AND.
     &     neighborId(1,1).EQ.-302_8 .AND.
     &     neighborRecord(1,1).EQ.-303 .AND.
     &     owners.EQ.-304_8 .AND. directed.EQ.-308_8,
     &     'B19 neighbor overflow rollback',nFail,myThid)
      CALL PRINT_MESSAGE(
     &     'B19-CANDIDATE PASS: equality 4/4 overflow 4/3 rollback',
     &     standardMessageUnit,SQUEEZE_RIGHT,myThid)
      CALL PRINT_MESSAGE(
     &     'B19-NEIGHBOR PASS: equality 3/3 overflow 3/2 rollback',
     &     standardMessageUnit,SQUEEZE_RIGHT,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_GHOST_LIMITS(
     U     nFail,
     I     ownerRank,sourceBi,sourceBj,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nFail,ownerRank,sourceBi,sourceBj,myThid
      INTEGER nOwner,bi,bj,ip,maxGhost,limitHit,failCode,failPhase
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord),ownerBj(bomMaxOwnerRecord)
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord),ownerY(bomMaxOwnerRecord)
      LOGICAL valid,ghostClear

C--   Reuse the exact committed child set and make every other tile relevant.
      nOwner=0
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          IF ( bomStatus(ip,bi,bj).EQ.BOM_ALIVE ) THEN
            nOwner=nOwner+1
            ownerId(nOwner)=bomId(ip,bi,bj)
            ownerStatus(nOwner)=BOM_ALIVE
            ownerX(nOwner)=bomX(ip,bi,bj)
            ownerY(nOwner)=bomY(ip,bi,bj)
            ownerBi(nOwner)=bi
            ownerBj(nOwner)=bj
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      bomNeighborCutoff=2500. _d 0
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_FINAL,57,1,
     O     failCode,failPhase,valid,myThid)
      maxGhost=0
      DO bj=1,nSy
       DO bi=1,nSx
        maxGhost=MAX(maxGhost,bomNGhostTile(bi,bj))
       ENDDO
      ENDDO
      limitHit=0
      IF ( maxGhost.EQ.bomMaxGhostTile ) limitHit=1
      CALL GLOBAL_SUM_INT(limitHit,myThid)
      CALL BOM_VERIFY_P45_ASSERT(valid .AND.
     &     limitHit.GE.1,
     &     'B19 post-birth ghost equality succeeds',nFail,myThid)
      CALL BOM_GHOST_INVALIDATE

C--   Add one valid prospective child; 5/4 must fail before publication.
      IF ( myProcId.EQ.ownerRank ) THEN
        nOwner=nOwner+1
        ownerId(nOwner)=9000001_8
        ownerStatus(nOwner)=BOM_ALIVE
        ownerX(nOwner)=-1975. _d 0
        ownerY(nOwner)=-894. _d 0
        ownerBi(nOwner)=sourceBi
        ownerBj(nOwner)=sourceBj
      ENDIF
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_FINAL,58,1,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_VERIFY_P45_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_GHOST_CAPACITY .AND.
     &     failPhase.EQ.BOM_P3_PHASE_GHOST,
     &     'B19 post-birth ghost overflow need 5 capacity 4',
     &     nFail,myThid)
      ghostClear=.TRUE.
      DO bj=1,nSy
       DO bi=1,nSx
        ghostClear=ghostClear .AND.
     &       bomNGhostTile(bi,bj).EQ.0 .AND.
     &       .NOT.bomGhostReady(bi,bj)
       ENDDO
      ENDDO
      CALL BOM_VERIFY_P45_ASSERT(ghostClear,
     &     'B19 ghost overflow rollback',nFail,myThid)
      bomNeighborCutoff=100. _d 0
      IF ( myProcId.EQ.0 ) CALL PRINT_MESSAGE(
     &     'B19-GHOST PASS: equality 4/4 overflow 5/4 rollback',
     &     standardMessageUnit,SQUEEZE_RIGHT,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_SEED(
     I     nOwner,makeBirth,useGraph,runtimeLimit,
     O     ownerRank,ownerBi,ownerBj,
     U     nFail,
     I     myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nOwner,runtimeLimit,ownerRank,ownerBi,ownerBj
      INTEGER nFail,myThid,ip,hop,newSlot,seedFail
      INTEGER rank,bi,bj
      _RL xMap,yMap,xSeed,ySeed,sSeed
      LOGICAL makeBirth,useGraph,locateValid,seedValid

      CALL BOM_INIT_STATE(myThid)
      CALL BOM_VERIFY_P45_CONFIG(useGraph,myThid)
      bomMaxParticles=runtimeLimit
      ownerRank=-1
      ownerBi=0
      ownerBj=0
      DO ip=1,nOwner
        xSeed=-2000. _d 0+5. _d 0*DFLOAT(ip-1)
        ySeed=-900. _d 0+3. _d 0*DFLOAT(MOD(ip-1,2))
        CALL BOM_LOCATE_OWNER(
     I       xSeed,ySeed,1,1,
     O       xMap,yMap,rank,bi,bj,hop,locateValid,myThid)
        IF ( ip.EQ.1 ) THEN
          ownerRank=rank
          ownerBi=bi
          ownerBj=bj
        ELSE
          locateValid=locateValid .AND. rank.EQ.ownerRank .AND.
     &         bi.EQ.ownerBi .AND. bj.EQ.ownerBj
        ENDIF
        sSeed=oneRL
        IF ( makeBirth .AND. ip.EQ.1 ) sSeed=4. _d 0
        seedValid=.TRUE.
        IF ( myProcId.EQ.rank ) CALL BOM_VERIFY_P45_ALLOC(
     I       bi,bj,INT(100+ip,8),sSeed,xSeed,ySeed,
     O       newSlot,seedFail,seedValid,myThid)
        CALL BOM_VERIFY_P45_ASSERT(locateValid .AND. seedValid,
     &       'B19 transaction owner seed',nFail,myThid)
      ENDDO
      bomNPartExpected=nOwner
      bomNPartLiveExpected=nOwner
      bomNextId=1000_8
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_CONFIG(useGraph,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      LOGICAL useGraph
      INTEGER myThid,bi,bj,i,j,iEnd,iSource

      bomMode='BOM'
      bomEquationMode='PAPER2024'
      bomIntegrator='RK2'
      bomCurrentPolicy='EULERIAN'
      bomStokesSource='NONE'
      bomWindSource='NONE'
      bomUseLand=.TRUE.
      bomUseBiology=.TRUE.
      bomTempSource='THETA'
      bomNSource='PTRACER'
      bomBiologyMissingPolicy='STOP'
      bomMuMax=0. _d 0
      bomMort=0. _d 0
      bomKN=oneRL
      bomTMin=0. _d 0
      bomTMax=40. _d 0
      bomS0=oneRL
      bomSMin=0.2 _d 0
      bomSMax=3. _d 0
      bomSeed=314159
      bomBirthMaxTry=8
      bomSpringL=50. _d 0
      bomAlpha=0. _d 0
      bomTau=oneRL
      bomR=0.823 _d 0
      bomSigma=0. _d 0
      bomAdvCFL=10. _d 0
      bomWetWeightMin=0.5 _d 0
      bomNeighborPolicy='NONE'
      bomSpringLaw='NONE'
      bomRaftDiagnostics=.FALSE.
      IF ( useGraph ) THEN
        bomNeighborPolicy='CUTOFF'
        bomSpringLaw='HOOKE'
        bomHookeK=0.001 _d 0
        bomSpringA=0. _d 0
        bomSpringDelta=0. _d 0
        bomNeighborCutoff=100. _d 0
        bomPairDistanceMin=1. _d -6
        bomSpringCFL=10. _d 0
        bomRaftDiagnostics=.TRUE.
      ENDIF
      bomEnvTime(BOM_ENV_OLD)=0. _d 0
      bomEnvTime(BOM_ENV_NEW)=deltaTClock
      bomEnvIter(BOM_ENV_OLD)=0
      bomEnvIter(BOM_ENV_NEW)=1
      bomBioTime(BOM_ENV_OLD)=0. _d 0
      bomBioTime(BOM_ENV_NEW)=deltaTClock
      bomBioIter(BOM_ENV_OLD)=0
      bomBioIter(BOM_ENV_NEW)=1
      DO iEnd=1,BOM_ENV_NEND
        bomBioTempSource(iEnd)=BOM_BIO_TEMP_THETA
        bomBioNSource(iEnd)=BOM_BIO_N_PTRACER
      ENDDO
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          maskC(i,j,1,bi,bj)=1.
          bomMetricValid(i,j,bi,bj)=.TRUE.
          bomTauSphere(i,j,bi,bj)=0. _d 0
          bomFCori(i,j,bi,bj)=0. _d 0
          DO iEnd=1,BOM_ENV_NEND
            bomBioTemp(i,j,iEnd,bi,bj)=20. _d 0
            bomBioN(i,j,iEnd,bi,bj)=oneRL
            bomBioValid(i,j,iEnd,bi,bj)=.TRUE.
            DO iSource=1,BOM_ENV_NSOURCE
              bomEnvEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomEnvNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomEnvValid(i,j,iEnd,iSource,bi,bj)=.TRUE.
              bomGradEastEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomGradNorthEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomGradEastNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomGradNorthNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomGradValid(i,j,iEnd,iSource,bi,bj)=.TRUE.
            ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      bomEnvReady=.TRUE.
      bomGradReady=.TRUE.
      bomMetricReady=.TRUE.
      bomBioReady=.TRUE.
      bomFieldsReady=.TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_ALLOC(
     I     bi,bj,candidateId,candidateS,candidateX,candidateY,
     O     newSlot,failCode,isValid,
     I     myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER bi,bj,newSlot,failCode,myThid,iDiag
      INTEGER*8 candidateId
      _RL candidateS,candidateX,candidateY
      _RL diag(BOM_RHS_NDIAG),xMap,ix,jy
      LOGICAL isValid,isOwner,hasStencil
      DO iDiag=1,BOM_RHS_NDIAG
        diag(iDiag)=0. _d 0
      ENDDO
      CALL BOM_MAP_XY2IJLOCAL(
     I     candidateX,candidateY,bi,bj,
     O     xMap,ix,jy,isOwner,hasStencil,myThid)
      IF ( .NOT.isOwner .OR. .NOT.hasStencil ) THEN
        newSlot=0
        failCode=BOM_FAIL_MAP
        isValid=.FALSE.
        RETURN
      ENDIF
      CALL BOM_FREE_ALLOC(
     I     bi,bj,candidateId,0_8,BOM_ALIVE,0,
     I     candidateX,candidateY,0. _d 0,0. _d 0,ix,jy,
     I     0. _d 0,0. _d 0,0. _d 0,0. _d 0,
     I     0. _d 0,0. _d 0,candidateS,0. _d 0,0. _d 0,
     I     0,0_8,0,diag,newSlot,failCode,isValid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P45_PRINT_STATE(tag,point,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) tag,point
      INTEGER myThid,bi,bj,ip
      CHARACTER*(MAX_LEN_MBUF) msgBuf

      WRITE(msgBuf,1000) tag,point,myProcId,
     &     bomNPartExpected,bomNPartLiveExpected,bomMaxParticles,
     &     bomNextId,bomEventTimeIndex,bomBirthEvents,bomDeathEvents,
     &     bomBeachEvents,bomOutsideEvents,bomCancelEvents,
     &     bomMissingGrowthEvents,bomFreeRebuildOps,bomFreeRemoveOps,
     &     bomFreeAllocOps,bomEventBufferCount
      CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                   SQUEEZE_RIGHT,myThid)
      DO bj=1,nSy
       DO bi=1,nSx
        WRITE(msgBuf,1001) tag,point,myProcId,bi,bj,
     &       bomNPartTile(bi,bj),bomFreeCount(bi,bj)
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        DO ip=1,bomMaxPartTile
          WRITE(msgBuf,1002) tag,point,myProcId,bi,bj,ip,
     &         bomId(ip,bi,bj),bomParentId(ip,bi,bj),
     &         bomStatus(ip,bi,bj),bomBirthCount(ip,bi,bj),
     &         bomFreeStack(ip,bi,bj),bomTerminalType(ip,bi,bj),
     &         bomTerminalStage(ip,bi,bj),bomTerminalId(ip,bi,bj),
     &         MERGE(1,0,bomTerminalReady(ip,bi,bj))
          CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                       SQUEEZE_RIGHT,myThid)
          WRITE(msgBuf,1003) tag,point,myProcId,bi,bj,ip,
     &         TRANSFER(bomX(ip,bi,bj),0_8),
     &         TRANSFER(bomY(ip,bi,bj),0_8),
     &         TRANSFER(bomReleaseTime(ip,bi,bj),0_8),
     &         TRANSFER(bomAge(ip,bi,bj),0_8),
     &         TRANSFER(bomI(ip,bi,bj),0_8),
     &         TRANSFER(bomJ(ip,bi,bj),0_8),
     &         TRANSFER(bomS(ip,bi,bj),0_8),
     &         TRANSFER(bomSpringEast(ip,bi,bj),0_8),
     &         TRANSFER(bomSpringNorth(ip,bi,bj),0_8)
          CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                       SQUEEZE_RIGHT,myThid)
        ENDDO
       ENDDO
      ENDDO
      DO ip=1,bomMaxEventBuffer
        WRITE(msgBuf,1004) tag,point,myProcId,ip,
     &       bomEventTypeBuffer(ip),bomEventStageBuffer(ip),
     &       bomEventOldStatusBuffer(ip),bomEventNewStatusBuffer(ip),
     &       bomEventIterBuffer(ip),bomEventSubstepBuffer(ip),
     &       bomEventSourceRankBuffer(ip),bomEventSourceBiBuffer(ip),
     &       bomEventSourceBjBuffer(ip),bomEventDestRankBuffer(ip),
     &       bomEventDestBiBuffer(ip),bomEventDestBjBuffer(ip),
     &       bomEventRetryBuffer(ip),bomEventIndexBuffer(ip),
     &       bomEventSubjectIdBuffer(ip),bomEventParentIdBuffer(ip),
     &       bomEventChildIdBuffer(ip)
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(msgBuf,1005) tag,point,myProcId,ip,
     &       TRANSFER(bomEventTimeBuffer(ip),0_8),
     &       TRANSFER(bomEventAcceptedXBuffer(ip),0_8),
     &       TRANSFER(bomEventAcceptedYBuffer(ip),0_8),
     &       TRANSFER(bomEventAttemptXBuffer(ip),0_8),
     &       TRANSFER(bomEventAttemptYBuffer(ip),0_8),
     &       TRANSFER(bomEventSBeforeBuffer(ip),0_8),
     &       TRANSFER(bomEventSTrialBuffer(ip),0_8),
     &       TRANSFER(bomEventSAfterBuffer(ip),0_8)
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
      ENDDO
 1000 FORMAT('P45-SNAP-G ',A8,1X,A6,1X,4I8,11I21,I8)
 1001 FORMAT('P45-SNAP-T ',A8,1X,A6,1X,5I8)
 1002 FORMAT('P45-SNAP-I ',A8,1X,A6,1X,4I8,2I21,5I8,I21,I8)
 1003 FORMAT('P45-SNAP-R ',A8,1X,A6,1X,4I8,9I21)
 1004 FORMAT('P45-SNAP-E ',A8,1X,A6,1X,15I8,4I21)
 1005 FORMAT('P45-SNAP-Q ',A8,1X,A6,1X,2I8,8I21)
      RETURN
      END
