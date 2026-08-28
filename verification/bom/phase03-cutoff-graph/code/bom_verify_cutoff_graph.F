#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_CUTOFF_GRAPH( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER myThid
      INTEGER nFail, globalFail

      nFail = 0
      CALL BOM_P32_TEST_CELL_FACES(nFail,myThid)
      CALL BOM_P32_TEST_EXACT_GRAPH(nFail,myThid)
      CALL BOM_P32_TEST_SHUFFLE_DUPLICATE(nFail,myThid)
      CALL BOM_P32_TEST_SAME_RANK_TILES(nFail,myThid)
      CALL BOM_P32_TEST_SPHERICAL(nFail,myThid)
      CALL BOM_P32_TEST_CAPACITY(nFail,myThid)
      CALL BOM_P32_TEST_RANDOM_ORACLE(nFail,myThid)
      CALL BOM_P32_TEST_FIXED_DENSITY(nFail,myThid)

      globalFail = nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.NE.0 ) THEN
        IF ( myProcId.EQ.0 )
     &    WRITE(errorMessageUnit,'(A,I8)')
     &      'P3.2 CUTOFF GRAPH FAIL: assertions=',globalFail
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P3.2 CUTOFF GRAPH'
      ENDIF

      IF ( myProcId.EQ.0 ) THEN
        WRITE(standardMessageUnit,'(A)')
     &    'P3-L01 PASS: half-open bounded Cartesian cell lists'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-N01 PASS: exact symmetric inclusive cutoff graph'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-L02 PASS: spherical row reach and periodic seam'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-N02 PASS: deterministic all-pairs oracle equality'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-N10 PASS: exact bounded failure and rollback'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-X01 PASS: balanced counters and bounded candidates'
      ENDIF

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_TEST_CELL_FACES( nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nFail, myThid
      INTEGER nCellX, nCellY, nCell, reachY, failCode, failPhase
      INTEGER cellX, cellY, cellIndex
      _RL widthX, widthY
      INTEGER rowReach(bomMaxCell)
      INTEGER*8 need, capacity
      LOGICAL valid, indexValid

      nCellX = -1
      nCellY = -1
      nCell = -1
      widthX = -1. _d 0
      widthY = -1. _d 0
      reachY = -1
      CALL BOM_INIT_CELL_GEOMETRY(
     I     .TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,oneRL,bomMaxCell,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     rowReach,need,capacity,failCode,failPhase,valid)
      CALL BOM_P32_ASSERT(valid .AND. failCode.EQ.BOM_FAIL_NONE,
     &     'L01 Cartesian plan valid',nFail,myThid)
      CALL BOM_P32_ASSERT(nCellX.EQ.8 .AND. nCellY.EQ.6
     &     .AND. nCell.EQ.48 .AND. widthX.EQ.oneRL
     &     .AND. widthY.EQ.oneRL .AND. reachY.EQ.1,
     &     'L01 exact Cartesian plan',nFail,myThid)

      CALL BOM_CELL_INDEX(
     I     0. _d 0,0. _d 0,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     nCellX,nCellY,nCell,widthX,widthY,
     O     cellX,cellY,cellIndex,failCode,indexValid)
      CALL BOM_P32_ASSERT(indexValid .AND. cellX.EQ.1
     &     .AND. cellY.EQ.1 .AND. cellIndex.EQ.1,
     &     'L01 lower corner',nFail,myThid)
      CALL BOM_CELL_INDEX(
     I     oneRL,oneRL,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     nCellX,nCellY,nCell,widthX,widthY,
     O     cellX,cellY,cellIndex,failCode,indexValid)
      CALL BOM_P32_ASSERT(indexValid .AND. cellX.EQ.2
     &     .AND. cellY.EQ.2 .AND. cellIndex.EQ.10,
     &     'L01 mathematical floor face',nFail,myThid)
      CALL BOM_CELL_INDEX(
     I     7.999 _d 0,5.999 _d 0,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     nCellX,nCellY,nCell,widthX,widthY,
     O     cellX,cellY,cellIndex,failCode,indexValid)
      CALL BOM_P32_ASSERT(indexValid .AND. cellX.EQ.8
     &     .AND. cellY.EQ.6 .AND. cellIndex.EQ.48,
     &     'L01 upper interior corner',nFail,myThid)
      cellIndex = -77
      CALL BOM_CELL_INDEX(
     I     8. _d 0,oneRL,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     nCellX,nCellY,nCell,widthX,widthY,
     O     cellX,cellY,cellIndex,failCode,indexValid)
      CALL BOM_P32_ASSERT(.NOT.indexValid .AND. cellIndex.EQ.-77,
     &     'L01 regional edge not clamped',nFail,myThid)
      CALL BOM_CELL_INDEX(
     I     8. _d 0,oneRL,.TRUE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,8. _d 0,
     I     nCellX,nCellY,nCell,widthX,widthY,
     O     cellX,cellY,cellIndex,failCode,indexValid)
      CALL BOM_P32_ASSERT(indexValid .AND. cellX.EQ.1,
     &     'L01 periodic upper face wraps',nFail,myThid)
      CALL BOM_CELL_INDEX(
     I     -oneRL,oneRL,.TRUE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,8. _d 0,
     I     nCellX,nCellY,nCell,widthX,widthY,
     O     cellX,cellY,cellIndex,failCode,indexValid)
      CALL BOM_P32_ASSERT(indexValid .AND. cellX.EQ.8,
     &     'L01 periodic negative wraps',nFail,myThid)

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_TEST_EXACT_GRAPH( nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
#include "BOM_P32_TEST.h"
      INTEGER nFail, myThid, rec
      INTEGER nCellX, nCellY, nCell, reachY, failCode, failPhase
      _RL widthX, widthY
      INTEGER*8 owners, ghosts, nonEmpty, comparisons
      INTEGER*8 directed, undirected, maxNeighbors, need, capacity
      LOGICAL valid

      CALL BOM_P32_CLEAR_WORKSPACE
      DO rec=1,6
        p32RecordId(rec) = 10_8*rec
        p32RecordStatus(rec) = BOM_ALIVE
        p32RecordOwner(rec) = rec
      ENDDO
      p32RecordX(1) = 0.25 _d 0
      p32RecordY(1) = 0.5 _d 0
      p32RecordX(2) = 1.249 _d 0
      p32RecordY(2) = 0.5 _d 0
      p32RecordX(3) = 0.25 _d 0
      p32RecordY(3) = 2.5 _d 0
      p32RecordX(4) = 1.25 _d 0
      p32RecordY(4) = 2.5 _d 0
      p32RecordX(5) = 4.25 _d 0
      p32RecordY(5) = 4.5 _d 0
      p32RecordX(6) = 5.251 _d 0
      p32RecordY(6) = 4.5 _d 0
      CALL BOM_P32_EXECUTE(
     I     6,6,.TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,1. _d -12,oneRL,
     I     bomMaxCell,bomMaxCellRecord,
     I     bomMaxCandidate,bomMaxNeighbor,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O     maxNeighbors,need,capacity,failCode,failPhase,valid)
      CALL BOM_P32_ASSERT(valid .AND. failCode.EQ.BOM_FAIL_NONE
     &     .AND. failPhase.EQ.BOM_P3_PHASE_NONE,
     &     'N01 graph transaction valid',nFail,myThid)
      CALL BOM_P32_ASSERT(p32NeighborCount(1).EQ.1
     &     .AND. p32NeighborId(1,1).EQ.20_8
     &     .AND. p32NeighborCount(2).EQ.1
     &     .AND. p32NeighborId(1,2).EQ.10_8,
     &     'N01 below-cutoff edge',nFail,myThid)
      CALL BOM_P32_ASSERT(p32NeighborCount(3).EQ.1
     &     .AND. p32NeighborId(1,3).EQ.40_8
     &     .AND. p32NeighborCount(4).EQ.1
     &     .AND. p32NeighborId(1,4).EQ.30_8,
     &     'N01 cutoff equality included',nFail,myThid)
      CALL BOM_P32_ASSERT(p32NeighborCount(5).EQ.0
     &     .AND. p32NeighborCount(6).EQ.0,
     &     'N01 above-cutoff excluded',nFail,myThid)
      CALL BOM_P32_ASSERT(directed.EQ.4_8
     &     .AND. undirected.EQ.2_8 .AND. maxNeighbors.EQ.1_8,
     &     'N01 symmetric counters',nFail,myThid)

C--   Periodic seam is authoritative and equality remains included.
      CALL BOM_P32_CLEAR_WORKSPACE
      p32RecordId(1) = 900_8
      p32RecordId(2) = 100_8
      p32RecordStatus(1) = BOM_ALIVE
      p32RecordStatus(2) = BOM_ALIVE
      p32RecordOwner(1) = 1
      p32RecordOwner(2) = 2
      p32RecordX(1) = 0.25 _d 0
      p32RecordX(2) = 7.25 _d 0
      p32RecordY(1) = 0.5 _d 0
      p32RecordY(2) = 0.5 _d 0
      CALL BOM_P32_EXECUTE(
     I     2,2,.TRUE.,.FALSE.,.TRUE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,8. _d 0,
     I     oneRL,1. _d -12,oneRL,
     I     bomMaxCell,bomMaxCellRecord,
     I     bomMaxCandidate,bomMaxNeighbor,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O     maxNeighbors,need,capacity,failCode,failPhase,valid)
      CALL BOM_P32_ASSERT(valid .AND. directed.EQ.2_8
     &     .AND. p32NeighborId(1,1).EQ.100_8
     &     .AND. p32NeighborId(1,2).EQ.900_8,
     &     'N01 periodic seam equality',nFail,myThid)

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_TEST_SHUFFLE_DUPLICATE( nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
#include "BOM_P32_TEST.h"
      INTEGER nFail, myThid, rec
      INTEGER nCellX, nCellY, nCell, reachY, failCode, failPhase
      INTEGER visitCount, cellIndex, link, seen(bomMaxCellRecord)
      _RL widthX, widthY
      INTEGER*8 owners, ghosts, nonEmpty, comparisons
      INTEGER*8 directed, undirected, maxNeighbors, need, capacity
      LOGICAL valid

      CALL BOM_P32_CLEAR_WORKSPACE
C--   Owner indices are ID-stable while record insertion is deliberately
C     shuffled.  Record 7 is a ghost copy of owner ID 20.
      p32RecordId(1) = 30_8
      p32RecordOwner(1) = 3
      p32RecordX(1) = 0.5 _d 0
      p32RecordY(1) = 0.5 _d 0
      p32RecordId(2) = 50_8
      p32RecordOwner(2) = 5
      p32RecordX(2) = 3.5 _d 0
      p32RecordY(2) = 3.5 _d 0
      p32RecordId(3) = 10_8
      p32RecordOwner(3) = 1
      p32RecordX(3) = 1.5 _d 0
      p32RecordY(3) = 0.5 _d 0
      p32RecordId(4) = 60_8
      p32RecordOwner(4) = 6
      p32RecordX(4) = 6.5 _d 0
      p32RecordY(4) = 5.5 _d 0
      p32RecordId(5) = 40_8
      p32RecordOwner(5) = 4
      p32RecordX(5) = 1.5 _d 0
      p32RecordY(5) = 1.5 _d 0
      p32RecordId(6) = 20_8
      p32RecordOwner(6) = 2
      p32RecordX(6) = 2.5 _d 0
      p32RecordY(6) = 0.5 _d 0
      p32RecordId(7) = 20_8
      p32RecordOwner(7) = 0
      p32RecordX(7) = 2.5 _d 0
      p32RecordY(7) = 0.5 _d 0
      DO rec=1,7
        p32RecordStatus(rec) = BOM_ALIVE
      ENDDO
      p32RecordStatus(2) = BOM_WAITING

      CALL BOM_P32_EXECUTE(
     I     7,6,.TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,1. _d -12,oneRL,
     I     bomMaxCell,bomMaxCellRecord,
     I     bomMaxCandidate,bomMaxNeighbor,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O     maxNeighbors,need,capacity,failCode,failPhase,valid)
      CALL BOM_P32_ASSERT(valid .AND. owners.EQ.5_8
     &     .AND. ghosts.EQ.1_8 .AND. nonEmpty.EQ.5_8,
     &     'L01 owner ghost and nonempty counters',nFail,myThid)
      CALL BOM_P32_ASSERT(p32NeighborCount(1).EQ.3
     &     .AND. p32NeighborId(1,1).EQ.20_8
     &     .AND. p32NeighborId(2,1).EQ.30_8
     &     .AND. p32NeighborId(3,1).EQ.40_8,
     &     'N01 ID-sorted tied neighbors',nFail,myThid)
      CALL BOM_P32_ASSERT(p32NeighborCount(2).EQ.1
     &     .AND. p32NeighborId(1,2).EQ.10_8,
     &     'N01 owner ghost duplicate removed',nFail,myThid)
      CALL BOM_P32_ASSERT(p32NeighborCount(3).EQ.1
     &     .AND. p32NeighborId(1,3).EQ.10_8
     &     .AND. p32NeighborCount(4).EQ.1
     &     .AND. p32NeighborId(1,4).EQ.10_8,
     &     'N01 reverse local edges',nFail,myThid)
      CALL BOM_P32_ASSERT(p32NeighborCount(5).EQ.0
     &     .AND. p32NeighborCount(6).EQ.0,
     &     'N01 waiting and singleton excluded',nFail,myThid)
      CALL BOM_P32_ASSERT(directed.EQ.6_8
     &     .AND. undirected.EQ.3_8 .AND. maxNeighbors.EQ.3_8,
     &     'N01 duplicate-safe graph counters',nFail,myThid)

C--   Head/next traversal must visit every stored ALIVE record once.
      DO rec=1,bomMaxCellRecord
        seen(rec) = 0
      ENDDO
      visitCount = 0
      DO cellIndex=1,nCell
        link = p32CellHead(cellIndex)
        DO WHILE ( link.NE.0 )
          visitCount = visitCount+1
          IF ( link.GE.1 .AND. link.LE.7 ) seen(link)=seen(link)+1
          IF ( visitCount.GT.7 ) link = 0
          IF ( link.NE.0 ) link = p32CellNext(link)
        ENDDO
      ENDDO
      CALL BOM_P32_ASSERT(visitCount.EQ.6,
     &     'L01 traversal count',nFail,myThid)
      DO rec=1,7
        IF ( p32RecordStatus(rec).EQ.BOM_ALIVE ) THEN
          CALL BOM_P32_ASSERT(seen(rec).EQ.1,
     &       'L01 each ALIVE record once',nFail,myThid)
        ELSE
          CALL BOM_P32_ASSERT(seen(rec).EQ.0,
     &       'L01 inactive record absent',nFail,myThid)
        ENDIF
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_TEST_SAME_RANK_TILES( nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
#include "BOM_P32_TEST.h"
      INTEGER nFail, myThid, rec
      INTEGER nCellX, nCellY, nCell, reachY, failCode, failPhase
      _RL widthX, widthY
      INTEGER*8 owners, ghosts, nonEmpty, comparisons
      INTEGER*8 directed, undirected, maxNeighbors, need, capacity
      LOGICAL valid

      CALL BOM_P32_CLEAR_WORKSPACE
      IF ( bomMaxOwnerRecord.GT.bomMaxPartTile ) THEN
        DO rec=1,bomMaxPartTile+1
          p32RecordId(rec) = 1000_8+INT(rec,8)
          p32RecordOwner(rec) = rec
          p32RecordStatus(rec) = BOM_WAITING
          p32RecordX(rec) = 4. _d 0
          p32RecordY(rec) = 3. _d 0
        ENDDO
        p32RecordStatus(1) = BOM_ALIVE
        p32RecordStatus(bomMaxPartTile+1) = BOM_ALIVE
        p32RecordX(1) = 3.75 _d 0
        p32RecordY(1) = 2.5 _d 0
        p32RecordX(bomMaxPartTile+1) = 4.25 _d 0
        p32RecordY(bomMaxPartTile+1) = 2.5 _d 0
        CALL BOM_P32_EXECUTE(
     I       bomMaxPartTile+1,bomMaxPartTile+1,
     I       .TRUE.,.FALSE.,.FALSE.,
     I       0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I       oneRL,1. _d -12,oneRL,
     I       bomMaxCell,bomMaxCellRecord,
     I       bomMaxCandidate,bomMaxNeighbor,
     O       nCellX,nCellY,nCell,widthX,widthY,reachY,
     O       owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O       maxNeighbors,need,capacity,failCode,failPhase,valid)
        CALL BOM_P32_ASSERT(valid .AND. owners.EQ.2_8
     &       .AND. directed.EQ.2_8,
     &       'L01 same-rank cross-tile flat owners',nFail,myThid)
        CALL BOM_P32_ASSERT(p32NeighborCount(1).EQ.1
     &       .AND. p32NeighborId(1,1)
     &         .EQ.1000_8+INT(bomMaxPartTile+1,8)
     &       .AND. p32NeighborCount(bomMaxPartTile+1).EQ.1,
     &       'L01 owner indices cross tile capacity',nFail,myThid)
      ENDIF

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_TEST_SPHERICAL( nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
#include "BOM_P32_TEST.h"
      INTEGER nFail, myThid, rec
      INTEGER nCellX, nCellY, nCell, reachY, failCode, failPhase
      INTEGER rowReach(bomMaxCell)
      _RL widthX, widthY
      INTEGER*8 owners, ghosts, nonEmpty, comparisons
      INTEGER*8 directed, undirected, maxNeighbors, need, capacity
      LOGICAL valid

C--   Regional spherical rows require a larger longitude reach poleward.
      CALL BOM_P32_CLEAR_WORKSPACE
      CALL BOM_INIT_CELL_GEOMETRY(
     I     .FALSE.,.TRUE.,.FALSE.,
     I     0. _d 0,60. _d 0,0. _d 0,60. _d 0,0. _d 0,
     I     6370000. _d 0,600000. _d 0,bomMaxCell,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     rowReach,need,capacity,failCode,failPhase,valid)
      CALL BOM_P32_ASSERT(valid .AND. nCellX.EQ.8
     &     .AND. nCellY.EQ.6 .AND. reachY.EQ.1,
     &     'L02 regional spherical plan',nFail,myThid)
      CALL BOM_P32_ASSERT(rowReach(1).EQ.1
     &     .AND. rowReach(nCellY).EQ.2,
     &     'L02 latitude-dependent longitude reach',nFail,myThid)

C--   The wider high-latitude stencil remains conservative; the exact
C     pair kernel removes its false positive.
      DO rec=1,3
        p32RecordId(rec) = 100_8*rec
        p32RecordStatus(rec) = BOM_ALIVE
        p32RecordOwner(rec) = rec
        p32RecordY(rec) = 55. _d 0
      ENDDO
      p32RecordX(1) = 0.5 _d 0
      p32RecordX(2) = 8.5 _d 0
      p32RecordX(3) = 20.5 _d 0
      CALL BOM_P32_EXECUTE(
     I     3,3,.FALSE.,.TRUE.,.FALSE.,
     I     0. _d 0,60. _d 0,0. _d 0,60. _d 0,0. _d 0,
     I     6370000. _d 0,1. _d -6,600000. _d 0,
     I     bomMaxCell,bomMaxCellRecord,
     I     bomMaxCandidate,bomMaxNeighbor,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O     maxNeighbors,need,capacity,failCode,failPhase,valid)
      CALL BOM_P32_ASSERT(valid .AND. directed.EQ.2_8
     &     .AND. undirected.EQ.1_8,
     &     'L02 exact high-latitude graph',nFail,myThid)
      CALL BOM_P32_ASSERT(p32NeighborCount(1).EQ.1
     &     .AND. p32NeighborId(1,1).EQ.200_8
     &     .AND. p32NeighborCount(2).EQ.1
     &     .AND. p32NeighborId(1,2).EQ.100_8
     &     .AND. p32NeighborCount(3).EQ.0,
     &     'L02 conservative false positive removed',nFail,myThid)

C--   Spherical periodic longitude uses the same canonical seam displacement.
      CALL BOM_P32_CLEAR_WORKSPACE
      p32RecordId(1) = 700_8
      p32RecordId(2) = 300_8
      DO rec=1,2
        p32RecordStatus(rec) = BOM_ALIVE
        p32RecordOwner(rec) = rec
        p32RecordY(rec) = 0. _d 0
      ENDDO
      p32RecordX(1) = 359.5 _d 0
      p32RecordX(2) = 0.5 _d 0
      CALL BOM_P32_EXECUTE(
     I     2,2,.FALSE.,.TRUE.,.TRUE.,
     I     0. _d 0,360. _d 0,-20. _d 0,20. _d 0,360. _d 0,
     I     6370000. _d 0,1. _d -6,200000. _d 0,
     I     bomMaxCell,bomMaxCellRecord,
     I     bomMaxCandidate,bomMaxNeighbor,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O     maxNeighbors,need,capacity,failCode,failPhase,valid)
      CALL BOM_P32_ASSERT(valid .AND. directed.EQ.2_8
     &     .AND. p32NeighborId(1,1).EQ.300_8
     &     .AND. p32NeighborId(1,2).EQ.700_8,
     &     'L02 spherical periodic seam',nFail,myThid)

C--   A row whose conservative band reaches the pole is rejected without
C     publishing a partial plan.
      nCellX = -81
      nCellY = -82
      nCell = -83
      widthX = -84. _d 0
      widthY = -85. _d 0
      reachY = -86
      DO rec=1,bomMaxCell
        rowReach(rec) = -87
      ENDDO
      CALL BOM_INIT_CELL_GEOMETRY(
     I     .FALSE.,.TRUE.,.TRUE.,
     I     0. _d 0,360. _d 0,80. _d 0,90. _d 0,360. _d 0,
     I     6370000. _d 0,200000. _d 0,bomMaxCell,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     rowReach,need,capacity,failCode,failPhase,valid)
      CALL BOM_P32_ASSERT(.NOT.valid
     &     .AND. failCode.EQ.BOM_FAIL_NEIGHBOR_CONFIG
     &     .AND. failPhase.EQ.BOM_P3_PHASE_CELL,
     &     'L02 pole-singularity rejection',nFail,myThid)
      CALL BOM_P32_ASSERT(nCellX.EQ.-81 .AND. nCellY.EQ.-82
     &     .AND. nCell.EQ.-83 .AND. widthX.EQ.-84. _d 0
     &     .AND. widthY.EQ.-85. _d 0 .AND. reachY.EQ.-86
     &     .AND. rowReach(1).EQ.-87,
     &     'L02 cell-plan rollback',nFail,myThid)

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_TEST_CAPACITY( nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
#include "BOM_P32_TEST.h"
      INTEGER nFail, myThid, rec, owner, neighbor
      INTEGER nCellX, nCellY, nCell, reachY, failCode, failPhase
      INTEGER rowReach(bomMaxCell)
      _RL widthX, widthY
      INTEGER*8 owners, ghosts, nonEmpty, comparisons
      INTEGER*8 directed, undirected, maxNeighbors, need, capacity
      LOGICAL valid, geometryValid, listValid

C--   Cell-plan capacity reports the exact need and leaves outputs untouched.
      nCellX = -71
      nCellY = -72
      nCell = -73
      widthX = -74. _d 0
      widthY = -75. _d 0
      reachY = -76
      DO rec=1,bomMaxCell
        rowReach(rec) = -77
      ENDDO
      CALL BOM_INIT_CELL_GEOMETRY(
     I     .TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,oneRL,47,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     rowReach,need,capacity,failCode,failPhase,geometryValid)
      CALL BOM_P32_ASSERT(.NOT.geometryValid
     &     .AND. failCode.EQ.BOM_FAIL_CELL_CAPACITY
     &     .AND. failPhase.EQ.BOM_P3_PHASE_CELL
     &     .AND. need.EQ.48_8 .AND. capacity.EQ.47_8,
     &     'N10 cell capacity accounting',nFail,myThid)
      CALL BOM_P32_ASSERT(nCellX.EQ.-71 .AND. nCellY.EQ.-72
     &     .AND. nCell.EQ.-73 .AND. rowReach(1).EQ.-77,
     &     'N10 cell capacity rollback',nFail,myThid)

C--   Build one valid plan for link, candidate, and neighbor failures.
      CALL BOM_P32_CLEAR_WORKSPACE
      CALL BOM_INIT_CELL_GEOMETRY(
     I     .TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,oneRL,bomMaxCell,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     p32RowReachX,need,capacity,failCode,failPhase,
     O     geometryValid)
      DO rec=1,4
        p32RecordId(rec) = 10_8*rec
        p32RecordStatus(rec) = BOM_ALIVE
        p32RecordOwner(rec) = rec
        p32RecordX(rec) = 0.45 _d 0+0.01 _d 0*rec
        p32RecordY(rec) = 0.5 _d 0
      ENDDO
      DO rec=1,bomMaxCellRecord
        p32CellNext(rec) = -91
        p32RecordCell(rec) = -92
      ENDDO
      DO rec=1,bomMaxCell
        p32CellHead(rec) = -93
      ENDDO
      owners = -94_8
      ghosts = -95_8
      nonEmpty = -96_8
      CALL BOM_BUILD_CELL_LIST(
     I     3,3,2,p32RecordId,p32RecordStatus,
     I     p32RecordX,p32RecordY,p32RecordOwner,
     I     .FALSE.,0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     nCellX,nCellY,nCell,widthX,widthY,
     O     p32CellHead,p32CellNext,p32RecordCell,
     O     owners,ghosts,nonEmpty,need,capacity,
     O     failCode,failPhase,listValid)
      CALL BOM_P32_ASSERT(.NOT.listValid
     &     .AND. failCode.EQ.BOM_FAIL_CELL_CAPACITY
     &     .AND. failPhase.EQ.BOM_P3_PHASE_CELL
     &     .AND. need.EQ.3_8 .AND. capacity.EQ.2_8,
     &     'N10 link capacity accounting',nFail,myThid)
      CALL BOM_P32_ASSERT(p32CellHead(1).EQ.-93
     &     .AND. p32CellNext(1).EQ.-91
     &     .AND. p32RecordCell(1).EQ.-92
     &     .AND. owners.EQ.-94_8,
     &     'N10 link capacity rollback',nFail,myThid)

C--   Publish the four-record list, then fail the reused candidate workspace.
      CALL BOM_P32_CLEAR_WORKSPACE
      CALL BOM_INIT_CELL_GEOMETRY(
     I     .TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,oneRL,bomMaxCell,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     p32RowReachX,need,capacity,failCode,failPhase,
     O     geometryValid)
      DO rec=1,4
        p32RecordId(rec) = 10_8*rec
        p32RecordStatus(rec) = BOM_ALIVE
        p32RecordOwner(rec) = rec
        p32RecordX(rec) = 0.45 _d 0+0.01 _d 0*rec
        p32RecordY(rec) = 0.5 _d 0
      ENDDO
      CALL BOM_BUILD_CELL_LIST(
     I     4,4,bomMaxCellRecord,
     I     p32RecordId,p32RecordStatus,p32RecordX,p32RecordY,
     I     p32RecordOwner,
     I     .FALSE.,0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     nCellX,nCellY,nCell,widthX,widthY,
     O     p32CellHead,p32CellNext,p32RecordCell,
     O     owners,ghosts,nonEmpty,need,capacity,
     O     failCode,failPhase,listValid)
      DO owner=1,bomMaxOwnerRecord
        p32NeighborCount(owner) = -101
        DO neighbor=1,bomMaxNeighbor
          p32NeighborId(neighbor,owner) = -102_8
          p32NeighborRecord(neighbor,owner) = -103
        ENDDO
      ENDDO
      directed = -104_8
      undirected = -105_8
      comparisons = -106_8
      maxNeighbors = -107_8
      CALL BOM_BUILD_NEIGHBORS(
     I     4,4,2,bomMaxNeighbor,
     I     p32RecordId,p32RecordStatus,p32RecordX,p32RecordY,
     I     p32RecordOwner,p32CellHead,p32CellNext,p32RecordCell,
     I     .TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,1. _d -12,oneRL,
     I     nCellX,nCellY,nCell,reachY,p32RowReachX,
     O     p32NeighborCount,p32NeighborId,p32NeighborRecord,
     O     owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O     maxNeighbors,need,capacity,failCode,failPhase,valid)
      CALL BOM_P32_ASSERT(.NOT.valid
     &     .AND. failCode.EQ.BOM_FAIL_CELL_CAPACITY
     &     .AND. failPhase.EQ.BOM_P3_PHASE_CELL
     &     .AND. need.EQ.3_8 .AND. capacity.EQ.2_8,
     &     'N10 candidate capacity accounting',nFail,myThid)
      CALL BOM_P32_ASSERT(p32NeighborCount(1).EQ.-101
     &     .AND. p32NeighborId(1,1).EQ.-102_8
     &     .AND. p32NeighborRecord(1,1).EQ.-103
     &     .AND. directed.EQ.-104_8,
     &     'N10 candidate rollback',nFail,myThid)

C--   With candidate space restored, each owner needs three neighbors;
C     capacity one must fail on the exact second edge.
      CALL BOM_BUILD_NEIGHBORS(
     I     4,4,bomMaxCandidate,1,
     I     p32RecordId,p32RecordStatus,p32RecordX,p32RecordY,
     I     p32RecordOwner,p32CellHead,p32CellNext,p32RecordCell,
     I     .TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,1. _d -12,oneRL,
     I     nCellX,nCellY,nCell,reachY,p32RowReachX,
     O     p32NeighborCount,p32NeighborId,p32NeighborRecord,
     O     owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O     maxNeighbors,need,capacity,failCode,failPhase,valid)
      CALL BOM_P32_ASSERT(.NOT.valid
     &     .AND. failCode.EQ.BOM_FAIL_NEIGHBOR_CAPACITY
     &     .AND. failPhase.EQ.BOM_P3_PHASE_NEIGHBOR
     &     .AND. need.EQ.2_8 .AND. capacity.EQ.1_8,
     &     'N10 neighbor capacity accounting',nFail,myThid)
      CALL BOM_P32_ASSERT(p32NeighborCount(1).EQ.-101
     &     .AND. p32NeighborId(1,1).EQ.-102_8
     &     .AND. directed.EQ.-104_8,
     &     'N10 neighbor rollback',nFail,myThid)

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_TEST_RANDOM_ORACLE( nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
#include "BOM_P32_TEST.h"
      INTEGER nFail, myThid, seed, nOwner, rec
      INTEGER nCellX, nCellY, nCell, reachY, failCode, failPhase
      _RL widthX, widthY
      _RL sumEast, sumNorth
      INTEGER*8 owners, ghosts, nonEmpty, comparisons
      INTEGER*8 directed, undirected, maxNeighbors, need, capacity
      LOGICAL valid

      DO seed=1,5
        CALL BOM_P32_CLEAR_WORKSPACE
        nOwner = 12+seed
        DO rec=1,nOwner
          p32RecordId(rec) = 100000_8+1000_8*seed
     &         +37_8*INT(nOwner-rec+1,8)
          p32RecordStatus(rec) = BOM_ALIVE
          p32RecordOwner(rec) = rec
          p32RecordX(rec) = 0.05 _d 0
     &         +0.1 _d 0*MOD(17*rec+13*seed,79)
          p32RecordY(rec) = 0.05 _d 0
     &         +0.1 _d 0*MOD(19*rec+7*seed,59)
        ENDDO
        p32RecordStatus(nOwner) = BOM_WAITING
        CALL BOM_P32_EXECUTE(
     I       nOwner,nOwner,.TRUE.,.FALSE.,.FALSE.,
     I       0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I       oneRL,1. _d -12,1.35 _d 0,
     I       bomMaxCell,bomMaxCellRecord,
     I       bomMaxCandidate,bomMaxNeighbor,
     O       nCellX,nCellY,nCell,widthX,widthY,reachY,
     O       owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O       maxNeighbors,need,capacity,failCode,failPhase,valid)
        CALL BOM_P32_ASSERT(valid .AND. failCode.EQ.BOM_FAIL_NONE,
     &       'N02 randomized graph transaction',nFail,myThid)
        sumEast = 0. _d 0
        sumNorth = 0. _d 0
        CALL BOM_P32_CHECK_ORACLE(
     I       nOwner,1.35 _d 0,
     O       sumEast,sumNorth,
     U       nFail,
     I       myThid)
        IF ( myProcId.EQ.0 )
     &    WRITE(standardMessageUnit,'(A,I2,3(A,I12),2(A,1PE23.15))')
     &      'P32-GRAPH-RECORD seed=',seed,
     &      ' directed=',directed,' undirected=',undirected,
     &      ' compared=',comparisons,
     &      ' springE=',sumEast,' springN=',sumNorth
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_CHECK_ORACLE(
     I                 nOwner, cutoff,
     O                 sumEast, sumNorth,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
#include "BOM_P32_TEST.h"
      INTEGER nOwner, nFail, myThid
      _RL cutoff, sumEast, sumNorth
      INTEGER owner, rec, count, scan, keyRec, graphRec
      INTEGER oracleRec(bomMaxOwnerRecord)
      INTEGER pairFail, accumFail
      _RL dEast, dNorth, distance, graphDistance
      _RL pairEast, pairNorth, stiffness, graphStiffness
      _RL oraclePairEast, oraclePairNorth
      _RL graphPairEast, graphPairNorth
      _RL oracleEast, oracleNorth, graphEast, graphNorth
      _RL nextEast, nextNorth
      LOGICAL pairValid, graphValid, accumValid

      sumEast = 0. _d 0
      sumNorth = 0. _d 0
      DO owner=1,nOwner
        IF ( p32RecordStatus(owner).EQ.BOM_ALIVE ) THEN
          count = 0
          DO rec=1,nOwner
            IF ( rec.NE.owner .AND.
     &           p32RecordStatus(rec).EQ.BOM_ALIVE ) THEN
              CALL BOM_PAIR_GEOMETRY(
     I             p32RecordId(owner),p32RecordX(owner),
     I             p32RecordY(owner),p32RecordId(rec),
     I             p32RecordX(rec),p32RecordY(rec),
     I             .TRUE.,.FALSE.,.FALSE.,
     I             0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I             oneRL,1. _d -12,
     O             dEast,dNorth,distance,pairFail,pairValid)
              IF ( pairValid .AND. distance.LE.cutoff ) THEN
                count = count+1
                oracleRec(count) = rec
              ENDIF
            ENDIF
          ENDDO
C--       The verification-only all-pairs oracle publishes ID order.
          DO rec=2,count
            keyRec = oracleRec(rec)
            scan = rec-1
            DO WHILE ( scan.GE.1 .AND.
     &          p32RecordId(oracleRec(scan)).GT.p32RecordId(keyRec) )
              oracleRec(scan+1) = oracleRec(scan)
              scan = scan-1
            ENDDO
            oracleRec(scan+1) = keyRec
          ENDDO
          CALL BOM_P32_ASSERT(p32NeighborCount(owner).EQ.count,
     &       'N02 oracle neighbor count',nFail,myThid)
          oracleEast = 0. _d 0
          oracleNorth = 0. _d 0
          graphEast = 0. _d 0
          graphNorth = 0. _d 0
          DO rec=1,count
            CALL BOM_P32_ASSERT(
     &         p32NeighborId(rec,owner)
     &           .EQ.p32RecordId(oracleRec(rec)),
     &         'N02 oracle ID order',nFail,myThid)
            graphRec = p32NeighborRecord(rec,owner)
            CALL BOM_PAIR_GEOMETRY(
     I           p32RecordId(owner),p32RecordX(owner),
     I           p32RecordY(owner),p32RecordId(oracleRec(rec)),
     I           p32RecordX(oracleRec(rec)),p32RecordY(oracleRec(rec)),
     I           .TRUE.,.FALSE.,.FALSE.,
     I           0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I           oneRL,1. _d -12,
     O           dEast,dNorth,distance,pairFail,pairValid)
            CALL BOM_PAIR_GEOMETRY(
     I           p32RecordId(owner),p32RecordX(owner),
     I           p32RecordY(owner),p32RecordId(graphRec),
     I           p32RecordX(graphRec),p32RecordY(graphRec),
     I           .TRUE.,.FALSE.,.FALSE.,
     I           0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I           oneRL,1. _d -12,
     O           pairEast,pairNorth,graphDistance,
     O           pairFail,graphValid)
            CALL BOM_P32_ASSERT(pairValid .AND. graphValid
     &         .AND. dEast.EQ.pairEast .AND. dNorth.EQ.pairNorth
     &         .AND. distance.EQ.graphDistance,
     &         'N02 geometry and distance equality',nFail,myThid)
            CALL BOM_SPRING_PAIR(
     I           'HOOKE',0.25 _d 0,oneRL,2. _d 0,
     I           oneRL,oneRL,dEast,dNorth,distance,
     O           oraclePairEast,oraclePairNorth,
     O           stiffness,pairFail,pairValid)
            CALL BOM_SPRING_PAIR(
     I           'HOOKE',0.25 _d 0,oneRL,2. _d 0,
     I           oneRL,oneRL,pairEast,pairNorth,graphDistance,
     O           graphPairEast,graphPairNorth,
     O           graphStiffness,pairFail,graphValid)
            CALL BOM_P32_ASSERT(pairValid .AND. graphValid
     &         .AND. stiffness.EQ.graphStiffness
     &         .AND. oraclePairEast.EQ.graphPairEast
     &         .AND. oraclePairNorth.EQ.graphPairNorth,
     &         'N02 Hooke stiffness equality',nFail,myThid)
            IF ( p32RecordId(owner).GT.p32NeighborId(rec,owner) ) THEN
              oraclePairEast = -oraclePairEast
              oraclePairNorth = -oraclePairNorth
              graphPairEast = -graphPairEast
              graphPairNorth = -graphPairNorth
            ENDIF
            CALL BOM_SPRING_ACCUMULATE(
     I           oracleEast,oracleNorth,
     I           oraclePairEast,oraclePairNorth,
     O           nextEast,nextNorth,accumFail,accumValid)
            oracleEast = nextEast
            oracleNorth = nextNorth
            CALL BOM_SPRING_ACCUMULATE(
     I           graphEast,graphNorth,graphPairEast,graphPairNorth,
     O           nextEast,nextNorth,accumFail,graphValid)
            graphEast = nextEast
            graphNorth = nextNorth
            CALL BOM_P32_ASSERT(accumValid .AND. graphValid,
     &         'N02 finite spring accumulation',nFail,myThid)
          ENDDO
          CALL BOM_P32_ASSERT(oracleEast.EQ.graphEast
     &       .AND. oracleNorth.EQ.graphNorth,
     &       'N02 accumulated velocity equality',nFail,myThid)
          sumEast = sumEast+graphEast
          sumNorth = sumNorth+graphNorth
        ENDIF
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_TEST_FIXED_DENSITY( nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
#include "BOM_P32_TEST.h"
      INTEGER nFail, myThid, rec, iIndex, jIndex
      INTEGER nCellX, nCellY, nCell, reachY, failCode, failPhase
      _RL widthX, widthY
      INTEGER*8 owners, ghosts, nonEmpty, comparisons
      INTEGER*8 directed, undirected, maxNeighbors, need, capacity
      LOGICAL valid

      CALL BOM_P32_CLEAR_WORKSPACE
      rec = 0
      DO jIndex=1,6
        DO iIndex=1,8
          rec = rec+1
          p32RecordId(rec) = 5000_8+13_8*rec
          p32RecordStatus(rec) = BOM_ALIVE
          p32RecordOwner(rec) = rec
          p32RecordX(rec) = DFLOAT(iIndex)-0.5 _d 0
          p32RecordY(rec) = DFLOAT(jIndex)-0.5 _d 0
        ENDDO
      ENDDO
      CALL BOM_P32_EXECUTE(
     I     48,48,.TRUE.,.FALSE.,.FALSE.,
     I     0. _d 0,8. _d 0,0. _d 0,6. _d 0,0. _d 0,
     I     oneRL,1. _d -12,1.01 _d 0,
     I     bomMaxCell,bomMaxCellRecord,
     I     bomMaxCandidate,bomMaxNeighbor,
     O     nCellX,nCellY,nCell,widthX,widthY,reachY,
     O     owners,ghosts,nonEmpty,comparisons,directed,undirected,
     O     maxNeighbors,need,capacity,failCode,failPhase,valid)
      CALL BOM_P32_ASSERT(valid .AND. owners.EQ.48_8
     &     .AND. ghosts.EQ.0_8,
     &     'X01 fixed-density graph valid',nFail,myThid)
      CALL BOM_P32_ASSERT(undirected.EQ.82_8
     &     .AND. directed.EQ.164_8 .AND. maxNeighbors.EQ.4_8,
     &     'X01 fixed-density graph counters',nFail,myThid)
      CALL BOM_P32_ASSERT(comparisons.GE.directed
     &     .AND. comparisons.LE.768_8,
     &     'X01 bounded candidate work',nFail,myThid)

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_CLEAR_WORKSPACE

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
#include "BOM_P32_TEST.h"
      INTEGER rec, owner, neighbor, cell

      DO rec=1,bomMaxCellRecord
        p32RecordId(rec) = 0_8
        p32RecordStatus(rec) = BOM_UNUSED
        p32RecordOwner(rec) = 0
        p32RecordX(rec) = 0. _d 0
        p32RecordY(rec) = 0. _d 0
        p32CellNext(rec) = 0
        p32RecordCell(rec) = 0
      ENDDO
      DO cell=1,bomMaxCell
        p32CellHead(cell) = 0
        p32RowReachX(cell) = 0
      ENDDO
      DO owner=1,bomMaxOwnerRecord
        p32NeighborCount(owner) = 0
        DO neighbor=1,bomMaxNeighbor
          p32NeighborId(neighbor,owner) = 0_8
          p32NeighborRecord(neighbor,owner) = 0
        ENDDO
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_EXECUTE(
     I                 nRecord, nOwner,
     I                 cartesianGrid, sphericalGrid, periodicX,
     I                 xMin, xMax, yMin, yMax, xPeriod,
     I                 sphereRadius, pairDistanceMin, neighborCutoff,
     I                 cellCapacity, linkCapacity,
     I                 candidateCapacity, neighborCapacity,
     O                 nCellX, nCellY, nCell,
     O                 cellWidthX, cellWidthY, cellReachY,
     O                 ownerRecords, ghostRecords, nonEmptyCells,
     O                 candidateComparisons, directedNeighbors,
     O                 undirectedEdges, maximumNeighbors,
     O                 failureNeed, failureCapacity,
     O                 failCode, p3FailPhase, graphValid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
#include "BOM_P32_TEST.h"
      INTEGER nRecord, nOwner
      LOGICAL cartesianGrid, sphericalGrid, periodicX
      _RL xMin, xMax, yMin, yMax, xPeriod
      _RL sphereRadius, pairDistanceMin, neighborCutoff
      INTEGER cellCapacity, linkCapacity
      INTEGER candidateCapacity, neighborCapacity
      INTEGER nCellX, nCellY, nCell, cellReachY
      _RL cellWidthX, cellWidthY
      INTEGER*8 ownerRecords, ghostRecords, nonEmptyCells
      INTEGER*8 candidateComparisons, directedNeighbors
      INTEGER*8 undirectedEdges, maximumNeighbors
      INTEGER*8 failureNeed, failureCapacity
      INTEGER failCode, p3FailPhase
      LOGICAL graphValid, geometryValid, listValid

      graphValid = .FALSE.
      CALL BOM_INIT_CELL_GEOMETRY(
     I     cartesianGrid,sphericalGrid,periodicX,
     I     xMin,xMax,yMin,yMax,xPeriod,
     I     sphereRadius,neighborCutoff,cellCapacity,
     O     nCellX,nCellY,nCell,cellWidthX,cellWidthY,cellReachY,
     O     p32RowReachX,failureNeed,failureCapacity,
     O     failCode,p3FailPhase,geometryValid)
      IF ( .NOT.geometryValid ) RETURN

      CALL BOM_BUILD_CELL_LIST(
     I     nRecord,nOwner,linkCapacity,
     I     p32RecordId,p32RecordStatus,p32RecordX,p32RecordY,
     I     p32RecordOwner,
     I     periodicX,xMin,xMax,yMin,yMax,xPeriod,
     I     nCellX,nCellY,nCell,cellWidthX,cellWidthY,
     O     p32CellHead,p32CellNext,p32RecordCell,
     O     ownerRecords,ghostRecords,nonEmptyCells,
     O     failureNeed,failureCapacity,
     O     failCode,p3FailPhase,listValid)
      IF ( .NOT.listValid ) RETURN

      CALL BOM_BUILD_NEIGHBORS(
     I     nRecord,nOwner,candidateCapacity,neighborCapacity,
     I     p32RecordId,p32RecordStatus,p32RecordX,p32RecordY,
     I     p32RecordOwner,p32CellHead,p32CellNext,p32RecordCell,
     I     cartesianGrid,sphericalGrid,periodicX,
     I     xMin,xMax,yMin,yMax,xPeriod,
     I     sphereRadius,pairDistanceMin,neighborCutoff,
     I     nCellX,nCellY,nCell,cellReachY,p32RowReachX,
     O     p32NeighborCount,p32NeighborId,p32NeighborRecord,
     O     ownerRecords,ghostRecords,nonEmptyCells,
     O     candidateComparisons,directedNeighbors,
     O     undirectedEdges,maximumNeighbors,
     O     failureNeed,failureCapacity,
     O     failCode,p3FailPhase,graphValid)

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P32_ASSERT(
     I                 condition, label,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      LOGICAL condition
      CHARACTER*(*) label
      INTEGER nFail, myThid

      IF ( .NOT.condition ) THEN
        nFail = nFail+1
        IF ( myProcId.EQ.0 )
     &    WRITE(errorMessageUnit,'(3A)')
     &      'P3.2 ASSERT FAIL: ',label,' '
      ENDIF

      RETURN
      END
