#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_COMPONENTS_SCHEMA3( myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER myThid, failRF01, failRF02, failN07
      INTEGER globalRF01, globalRF02, globalN07, failCode
      INTEGER nPoint, i
      _RL pointX(8), pointY(8)
      INTEGER*8 pointId(8), expectedRaft(8)
      INTEGER expectedSize(8), expectedNeighbor(8)
      LOGICAL valid

      failRF01 = 0
      failRF02 = 0
      failN07 = 0
      DO i=1,8
        pointX(i)=0. _d 0
        pointY(i)=0. _d 0
        pointId(i)=0_8
        expectedRaft(i)=0_8
        expectedSize(i)=0
        expectedNeighbor(i)=0
      ENDDO

C--   Singleton.
      nPoint=1
      pointX(1)=2050. _d 0
      pointY(1)=550. _d 0
      pointId(1)=4294967301_8
      expectedRaft(1)=pointId(1)
      expectedSize(1)=1
      expectedNeighbor(1)=0
      CALL BOM_P34_RUN_COMPONENT_CASE(
     I     nPoint,pointX,pointY,pointId,
     I     expectedRaft,expectedSize,expectedNeighbor,
     I     300. _d 0,101,.FALSE.,
     U     failRF01,myThid)

C--   Four-owner chain crossing the X process/tile seam.
      nPoint=4
      pointX(1)=1750. _d 0
      pointX(2)=1950. _d 0
      pointX(3)=2150. _d 0
      pointX(4)=2350. _d 0
      DO i=1,nPoint
        pointY(i)=550. _d 0
        expectedRaft(i)=100_8
        expectedSize(i)=4
      ENDDO
      pointId(1)=400_8
      pointId(2)=100_8
      pointId(3)=300_8
      pointId(4)=200_8
      expectedNeighbor(1)=1
      expectedNeighbor(2)=2
      expectedNeighbor(3)=2
      expectedNeighbor(4)=1
      CALL BOM_P34_RUN_COMPONENT_CASE(
     I     nPoint,pointX,pointY,pointId,
     I     expectedRaft,expectedSize,expectedNeighbor,
     I     250. _d 0,102,.FALSE.,
     U     failRF01,myThid)

C--   Same chain in reverse input order proves slot-order independence.
      DO i=1,nPoint/2
        CALL BOM_P34_SWAP_POINT(
     U       pointX,pointY,pointId,expectedRaft,
     U       expectedSize,expectedNeighbor,i,nPoint+1-i)
      ENDDO
      CALL BOM_P34_RUN_COMPONENT_CASE(
     I     nPoint,pointX,pointY,pointId,
     I     expectedRaft,expectedSize,expectedNeighbor,
     I     250. _d 0,103,.FALSE.,
     U     failRF01,myThid)

C--   Ring crossing both X and Y rank seams; diagonals are outside cutoff.
      nPoint=4
      pointX(1)=2000. _d 0
      pointY(1)=500. _d 0
      pointX(2)=2200. _d 0
      pointY(2)=500. _d 0
      pointX(3)=2200. _d 0
      pointY(3)=700. _d 0
      pointX(4)=2000. _d 0
      pointY(4)=700. _d 0
      pointId(1)=44_8
      pointId(2)=11_8
      pointId(3)=33_8
      pointId(4)=22_8
      DO i=1,nPoint
        expectedRaft(i)=11_8
        expectedSize(i)=4
        expectedNeighbor(i)=2
      ENDDO
      CALL BOM_P34_RUN_COMPONENT_CASE(
     I     nPoint,pointX,pointY,pointId,
     I     expectedRaft,expectedSize,expectedNeighbor,
     I     250. _d 0,104,.TRUE.,
     U     failRF01,myThid)

C--   Two disconnected two-owner components.
      nPoint=4
      pointX(1)=-1000. _d 0
      pointX(2)=-800. _d 0
      pointX(3)=3000. _d 0
      pointX(4)=3200. _d 0
      DO i=1,nPoint
        pointY(i)=1000. _d 0
        expectedSize(i)=2
        expectedNeighbor(i)=1
      ENDDO
      pointId(1)=902_8
      pointId(2)=901_8
      pointId(3)=30_8
      pointId(4)=20_8
      expectedRaft(1)=901_8
      expectedRaft(2)=901_8
      expectedRaft(3)=20_8
      expectedRaft(4)=20_8
      CALL BOM_P34_RUN_COMPONENT_CASE(
     I     nPoint,pointX,pointY,pointId,
     I     expectedRaft,expectedSize,expectedNeighbor,
     I     250. _d 0,105,.FALSE.,
     U     failRF01,myThid)

C--   Dynamic merge then split: no previous component state may persist.
      nPoint=2
      pointX(1)=1900. _d 0
      pointX(2)=2100. _d 0
      pointY(1)=550. _d 0
      pointY(2)=550. _d 0
      pointId(1)=700_8
      pointId(2)=600_8
      expectedRaft(1)=600_8
      expectedRaft(2)=600_8
      expectedSize(1)=2
      expectedSize(2)=2
      expectedNeighbor(1)=1
      expectedNeighbor(2)=1
      CALL BOM_P34_RUN_COMPONENT_CASE(
     I     nPoint,pointX,pointY,pointId,
     I     expectedRaft,expectedSize,expectedNeighbor,
     I     250. _d 0,106,.FALSE.,
     U     failRF02,myThid)
      pointX(1)=1750. _d 0
      pointX(2)=2250. _d 0
      expectedRaft(1)=700_8
      expectedRaft(2)=600_8
      expectedSize(1)=1
      expectedSize(2)=1
      expectedNeighbor(1)=0
      expectedNeighbor(2)=0
      CALL BOM_P34_RUN_COMPONENT_CASE(
     I     nPoint,pointX,pointY,pointId,
     I     expectedRaft,expectedSize,expectedNeighbor,
     I     250. _d 0,107,.FALSE.,
     U     failRF02,myThid)

C--   A stale/missing component candidate fails 24 without output writes.
      CALL BOM_COMPONENT_INVALIDATE
      pointId(1)=777_8
      expectedRaft(1)=-777_8
      expectedSize(1)=-777
      CALL BOM_COMPONENT_FETCH(
     I     1,pointId,BOM_STAGE_FINAL,999,1,
     O     expectedRaft,expectedSize,
     O     failCode,valid,myThid)
      CALL BOM_P34_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_COMPONENT .AND.
     &     expectedRaft(1).EQ.-777_8 .AND.
     &     expectedSize(1).EQ.-777,failN07)

      globalRF01=failRF01
      globalRF02=failRF02
      globalN07=failN07
      CALL GLOBAL_SUM_INT(globalRF01,myThid)
      CALL GLOBAL_SUM_INT(globalRF02,myThid)
      CALL GLOBAL_SUM_INT(globalN07,myThid)
      IF ( globalRF01+globalRF02+globalN07.NE.0 ) THEN
        IF ( myProcId.EQ.0 )
     &    WRITE(errorMessageUnit,'(A,2I8)')
     &      'P3.4 COMPONENT FAIL:',globalRF01,globalRF02
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P3.4 COMPONENT'
      ENDIF
      IF ( myProcId.EQ.0 ) THEN
        WRITE(standardMessageUnit,'(A)')
     &    'P3-RF01 PASS: deterministic FINAL components'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-RF02 PASS: instantaneous merge and split'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-N07 PASS: component failure preserves outputs'
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P34_RUN_COMPONENT_CASE(
     I                 nPoint, pointX, pointY, pointId,
     I                 expectedRaft, expectedSize, expectedNeighbor,
     I                 cutoff, epoch, emitCanonical,
     U                 nFail,
     I                 myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nPoint, epoch, nFail, myThid
      _RL pointX(*),pointY(*),cutoff
      INTEGER*8 pointId(*),expectedRaft(*)
      INTEGER expectedSize(*),expectedNeighbor(*)
      LOGICAL emitCanonical
      INTEGER nOwner, point, owner, rank, bi, bj, hop
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord),ownerBj(bomMaxOwnerRecord)
      INTEGER ownerNeighbor(bomMaxOwnerRecord)
      INTEGER ownerRaftSize(bomMaxOwnerRecord)
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER*8 ownerRaftId(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord),ownerY(bomMaxOwnerRecord)
      _RL xOwner,yOwner
      _RL springEast(bomMaxOwnerRecord)
      _RL springNorth(bomMaxOwnerRecord)
      INTEGER*8 ownerRecords,ghostRecords,nonEmptyCells
      INTEGER*8 comparisons,directed,edges,maxNeighbors
      INTEGER failCode,failPhase,expectedSlot
      LOGICAL valid,found

      CALL BOM_INIT_STATE(myThid)
      CALL BOM_P34_SET_CONFIG(myThid)
      _BEGIN_MASTER(myThid)
      bomRaftDiagnostics=.TRUE.
      bomNeighborCutoff=cutoff
      _END_MASTER(myThid)
      _BARRIER
      nOwner=0
      DO point=1,nPoint
        CALL BOM_LOCATE_OWNER(
     I       pointX(point),pointY(point),1,1,
     O       xOwner,yOwner,rank,bi,bj,hop,valid,myThid)
        CALL BOM_P34_ASSERT(valid,nFail)
        IF ( valid .AND. rank.EQ.myProcId ) THEN
          nOwner=nOwner+1
          ownerId(nOwner)=pointId(point)
          ownerStatus(nOwner)=BOM_ALIVE
          ownerX(nOwner)=xOwner
          ownerY(nOwner)=yOwner
          ownerBi(nOwner)=bi
          ownerBj(nOwner)=bj
        ENDIF
      ENDDO
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_FINAL,epoch,1,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P34_ASSERT(valid .AND. failCode.EQ.BOM_FAIL_NONE,
     &     nFail)
      IF ( .NOT.valid ) RETURN
      CALL BOM_SPRING_STAGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     BOM_STAGE_FINAL,epoch,1,0. _d 0,
     O     springEast,springNorth,ownerNeighbor,
     O     ownerRecords,ghostRecords,nonEmptyCells,
     O     comparisons,directed,edges,maxNeighbors,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P34_ASSERT(valid .AND. failCode.EQ.BOM_FAIL_NONE
     &     .AND. failPhase.EQ.BOM_P3_PHASE_NONE,nFail)
      IF ( .NOT.valid ) RETURN
      CALL BOM_COMPONENT_FETCH(
     I     nOwner,ownerId,BOM_STAGE_FINAL,epoch,1,
     O     ownerRaftId,ownerRaftSize,
     O     failCode,valid,myThid)
      CALL BOM_P34_ASSERT(valid .AND. failCode.EQ.BOM_FAIL_NONE,
     &     nFail)
      DO owner=1,nOwner
        found=.FALSE.
        expectedSlot=0
        DO point=1,nPoint
          IF ( pointId(point).EQ.ownerId(owner) ) THEN
            found=.TRUE.
            expectedSlot=point
          ENDIF
        ENDDO
        CALL BOM_P34_ASSERT(found,nFail)
        IF ( found ) THEN
          CALL BOM_P34_ASSERT(
     I         ownerRaftId(owner).EQ.expectedRaft(expectedSlot)
     &         .AND.
     &         ownerRaftSize(owner).EQ.expectedSize(expectedSlot)
     &         .AND.
     &         ownerNeighbor(owner).EQ.
     &         expectedNeighbor(expectedSlot),nFail)
          IF ( emitCanonical )
     &      WRITE(standardMessageUnit,'(A,2I21,2I9)')
     &        'P34CANON ',ownerId(owner),ownerRaftId(owner),
     &        ownerRaftSize(owner),ownerNeighbor(owner)
        ENDIF
      ENDDO
      CALL BOM_GHOST_INVALIDATE
      CALL BOM_COMPONENT_INVALIDATE
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P34_SET_CONFIG( myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
      _BEGIN_MASTER(myThid)
      bomMode='BOM'
      bomEquationMode='PAPER2024'
      bomIntegrator='RK4'
      bomCurrentPolicy='EULERIAN'
      bomStokesSource='NONE'
      bomWindSource='NONE'
      bomSpringLaw='HOOKE'
      bomNeighborPolicy='CUTOFF'
      bomAlpha=0. _d 0
      bomTau=oneRL
      bomR=0.823 _d 0
      bomSigma=0. _d 0
      bomLeewayWindCoeff=0. _d 0
      bomSpringL=100. _d 0
      bomHookeK=0.001 _d 0
      bomSpringA=0. _d 0
      bomSpringDelta=0. _d 0
      bomNeighborCutoff=300. _d 0
      bomPairDistanceMin=1. _d -6
      bomSpringCFL=oneRL
      bomAdvCFL=0.9 _d 0
      bomRaftDiagnostics=.TRUE.
      bomOutputScheduleReady=.TRUE.
      bomNextOutputTime=777. _d 0
      _END_MASTER(myThid)
      _BARRIER
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P34_ASSERT( condition, nFail )
      IMPLICIT NONE
      LOGICAL condition
      INTEGER nFail
      IF ( .NOT.condition ) nFail=nFail+1
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P34_SWAP_POINT(
     U                 pointX, pointY, pointId, expectedRaft,
     U                 expectedSize, expectedNeighbor,
     I                 slotA, slotB )
      IMPLICIT NONE
      _RL pointX(*),pointY(*),swapReal
      INTEGER*8 pointId(*),expectedRaft(*),swapI8
      INTEGER expectedSize(*),expectedNeighbor(*),slotA,slotB,swapI
      swapReal=pointX(slotA)
      pointX(slotA)=pointX(slotB)
      pointX(slotB)=swapReal
      swapReal=pointY(slotA)
      pointY(slotA)=pointY(slotB)
      pointY(slotB)=swapReal
      swapI8=pointId(slotA)
      pointId(slotA)=pointId(slotB)
      pointId(slotB)=swapI8
      swapI8=expectedRaft(slotA)
      expectedRaft(slotA)=expectedRaft(slotB)
      expectedRaft(slotB)=swapI8
      swapI=expectedSize(slotA)
      expectedSize(slotA)=expectedSize(slotB)
      expectedSize(slotB)=swapI
      swapI=expectedNeighbor(slotA)
      expectedNeighbor(slotA)=expectedNeighbor(slotB)
      expectedNeighbor(slotB)=swapI
      RETURN
      END
