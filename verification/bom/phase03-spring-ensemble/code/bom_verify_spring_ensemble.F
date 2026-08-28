#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_SPRING_ENSEMBLE( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      INTEGER myThid
      INTEGER failG01, failG02, failI01, failI02, failI03
      INTEGER failB09, failM01
      INTEGER globalG01, globalG02, globalI01, globalI02
      INTEGER globalI03
      INTEGER globalB09, globalM01

      failG01 = 0
      failG02 = 0
      failI01 = 0
      failI02 = 0
      failI03 = 0
      failB09 = 0
      failM01 = 0
      CALL BOM_P33_TEST_GHOST(failG01,failG02,myThid)
      CALL BOM_P33_TEST_SPRING(failI03,myThid)
      CALL BOM_P33_TEST_ENSEMBLE(failI01,failI02,myThid)
      CALL BOM_P33_TEST_CROSS_RANK(failB09,myThid)
      CALL BOM_P33_TEST_MIGRATION(failM01,myThid)

      globalG01 = failG01
      globalG02 = failG02
      globalI01 = failI01
      globalI02 = failI02
      globalI03 = failI03
      globalB09 = failB09
      globalM01 = failM01
      CALL GLOBAL_SUM_INT(globalG01,myThid)
      CALL GLOBAL_SUM_INT(globalG02,myThid)
      CALL GLOBAL_SUM_INT(globalI01,myThid)
      CALL GLOBAL_SUM_INT(globalI02,myThid)
      CALL GLOBAL_SUM_INT(globalI03,myThid)
      CALL GLOBAL_SUM_INT(globalB09,myThid)
      CALL GLOBAL_SUM_INT(globalM01,myThid)
      IF ( globalG01+globalG02+globalI01+globalI02
     &     +globalI03+globalB09+globalM01.NE.0 ) THEN
        IF ( myProcId.EQ.0 )
     &    WRITE(errorMessageUnit,'(A,7I8)')
     &      'P3.3 SPRING ENSEMBLE FAIL:',globalG01,globalG02,
     &      globalI01,globalI02,globalI03,globalB09,globalM01
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P3.3 SPRING ENSEMBLE'
      ENDIF
      IF ( myProcId.EQ.0 ) THEN
        WRITE(standardMessageUnit,'(A)')
     &    'P3-G01 PASS: versioned sorted one-stage ghosts'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-G02 PASS: ghost source/capacity rollback'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-I01 PASS: synchronized RK2/RK4 convergence'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-I02 PASS: global spring-stage rollback'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-I03 PASS: spring and CFL boundary guards'
        WRITE(standardMessageUnit,'(A)')
     &    'B09 PASS: cross-tile/cross-rank RK4 dynamics'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-M01 PASS: version-2 owner migration fields'
        WRITE(standardMessageUnit,'(A)')
     &    'B17 PASS: canonical decomposition records emitted'
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P33_TEST_GHOST( failG01, failG02, myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_VALUE, IEEE_QUIET_NAN
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER failG01, failG02, myThid
      INTEGER nOwner, sourceRank, sourceBi, sourceBj, hop
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord)
      INTEGER ownerBj(bomMaxOwnerRecord)
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord), ownerY(bomMaxOwnerRecord)
      _RL xOwner, yOwner, nanValue
      INTEGER failCode, failPhase, bi, bj, expected
      INTEGER tileX, tileY, totalSent, totalReceived, nBad
      LOGICAL valid, relevant, routeValid, readyClear

      CALL BOM_INIT_STATE(myThid)
      CALL BOM_P33_SET_CONFIG(myThid)
      CALL BOM_P33_BUILD_INPUT(
     I     1,2050. _d 0,550. _d 0,4294967298_8,
     I     0. _d 0,0. _d 0,0_8,
     O     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     O     ownerBi,ownerBj,myThid)
      CALL BOM_LOCATE_OWNER(
     I     2050. _d 0,550. _d 0,1,1,
     O     xOwner,yOwner,sourceRank,sourceBi,sourceBj,
     O     hop,valid,myThid)
      CALL BOM_P33_ASSERT(valid,failG01)
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_K2,17,3,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P33_ASSERT(valid .AND. failCode.EQ.BOM_FAIL_NONE,
     &     failG01)
      DO bj=1,nSy
       DO bi=1,nSx
        tileX = (myXGlobalLo-1)/sNx+bi-1
        tileY = (myYGlobalLo-1)/sNy+bj-1
        CALL BOM_GHOST_TILE_RELEVANT(
     I       2050. _d 0,550. _d 0,tileX,tileY,
     O       relevant,routeValid,myThid)
        expected = 0
        IF ( routeValid .AND. relevant ) expected=1
        IF ( myProcId.EQ.sourceRank .AND.
     &       bi.EQ.sourceBi .AND. bj.EQ.sourceBj ) expected=0
        CALL BOM_P33_ASSERT(bomGhostReady(bi,bj),failG01)
        CALL BOM_P33_ASSERT(bomNGhostTile(bi,bj).EQ.expected,
     &       failG01)
        IF ( expected.EQ.1 ) THEN
          CALL BOM_P33_ASSERT(
     I         bomGhostId(1,bi,bj).EQ.4294967298_8 .AND.
     &         bomGhostStatus(1,bi,bj).EQ.BOM_ALIVE .AND.
     &         bomGhostSourceRank(1,bi,bj).EQ.sourceRank .AND.
     &         bomGhostSourceBi(1,bi,bj).EQ.sourceBi .AND.
     &         bomGhostSourceBj(1,bi,bj).EQ.sourceBj .AND.
     &         bomGhostX(1,bi,bj).EQ.2050. _d 0 .AND.
     &         bomGhostY(1,bi,bj).EQ.550. _d 0,failG01)
        ENDIF
       ENDDO
      ENDDO
      CALL BOM_P33_ASSERT(bomGhostStage.EQ.BOM_STAGE_K2
     &     .AND. bomGhostEpoch.EQ.17
     &     .AND. bomGhostSubstep.EQ.3,failG01)
      totalSent = INT(bomGhostRecordsSent)
      totalReceived = INT(bomGhostRecordsReceived)
      CALL GLOBAL_SUM_INT(totalSent,myThid)
      CALL GLOBAL_SUM_INT(totalReceived,myThid)
      CALL BOM_P33_ASSERT(totalSent.EQ.totalReceived,failG01)
      CALL BOM_P33_ASSERT(
     I     bomGhostBytesSent.EQ.bomGhostRecordsSent
     &       *INT(bomGhostPacketBytes,8) .AND.
     &     bomGhostBytesReceived.EQ.bomGhostRecordsReceived
     &       *INT(bomGhostPacketBytes,8),failG01)
      CALL BOM_GHOST_INVALIDATE
      readyClear = .TRUE.
      DO bj=1,nSy
       DO bi=1,nSx
        readyClear = readyClear .AND.
     &       .NOT.bomGhostReady(bi,bj)
     &       .AND. bomNGhostTile(bi,bj).EQ.0
       ENDDO
      ENDDO
      CALL BOM_P33_ASSERT(readyClear .AND.
     &     bomGhostStage.EQ.BOM_STAGE_NONE,failG01)

C--   Invalid label, source, duplicate, nonfinite and capacity inputs.
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_NONE,17,3,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P33_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_GHOST_PACKET,failG02)
      IF ( nOwner.EQ.1 ) ownerStatus(1)=BOM_UNUSED
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_K1,18,4,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P33_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_GHOST_PACKET,failG02)
      IF ( nOwner.EQ.1 ) ownerStatus(1)=BOM_ALIVE
      nanValue = IEEE_VALUE(nanValue,IEEE_QUIET_NAN)
      IF ( nOwner.EQ.1 ) ownerX(1)=nanValue
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_K1,19,4,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P33_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_GHOST_PACKET,failG02)

      CALL BOM_P33_BUILD_INPUT(
     I     2,2000. _d 0,0. _d 0,77_8,
     I     2050. _d 0,0. _d 0,77_8,
     O     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     O     ownerBi,ownerBj,myThid)
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_K1,20,4,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P33_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_GHOST_PACKET,failG02)
      nBad = 0
      IF ( myProcId.EQ.0 ) nBad=bomMaxOwnerRecord+1
      CALL BOM_GHOST_EXCHANGE(
     I     nBad,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_K1,21,4,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P33_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_GHOST_CAPACITY,failG02)
      readyClear = .TRUE.
      DO bj=1,nSy
       DO bi=1,nSx
        readyClear = readyClear .AND.
     &       .NOT.bomGhostReady(bi,bj)
       ENDDO
      ENDDO
      CALL BOM_P33_ASSERT(readyClear,failG02)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P33_TEST_SPRING( nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nFail, myThid, nOwner, owner, failCode, failPhase
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord)
      INTEGER ownerBj(bomMaxOwnerRecord)
      INTEGER neighborCount(bomMaxOwnerRecord)
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord), ownerY(bomMaxOwnerRecord)
      _RL springEast(bomMaxOwnerRecord)
      _RL springNorth(bomMaxOwnerRecord)
      INTEGER*8 ownerRecords, ghostRecords, nonEmptyCells
      INTEGER*8 comparisons, directed, undirected, maximum
      INTEGER globalDirected, globalUndirected, ownerRanks
      INTEGER caught, globalCaught
      LOGICAL valid, ghostValid

      CALL BOM_INIT_STATE(myThid)
      CALL BOM_P33_SET_CONFIG(myThid)
      CALL BOM_P33_BUILD_INPUT(
     I     2,2000. _d 0,0. _d 0,11_8,
     I     2200. _d 0,0. _d 0,22_8,
     O     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     O     ownerBi,ownerBj,myThid)
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_K1,1,1,
     O     failCode,failPhase,ghostValid,myThid)
      CALL BOM_P33_ASSERT(ghostValid,nFail)
      CALL BOM_SPRING_STAGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     BOM_STAGE_K1,1,1,100. _d 0,
     O     springEast,springNorth,neighborCount,
     O     ownerRecords,ghostRecords,nonEmptyCells,
     O     comparisons,directed,undirected,maximum,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P33_ASSERT(valid,nFail)
      DO owner=1,nOwner
        IF ( ownerId(owner).EQ.11_8 ) THEN
          CALL BOM_P33_ASSERT(neighborCount(owner).EQ.1 .AND.
     &         ABS(springEast(owner)-0.1 _d 0).LT.1. _d -13
     &         .AND. springNorth(owner).EQ.0. _d 0,nFail)
        ELSEIF ( ownerId(owner).EQ.22_8 ) THEN
          CALL BOM_P33_ASSERT(neighborCount(owner).EQ.1 .AND.
     &         ABS(springEast(owner)+0.1 _d 0).LT.1. _d -13
     &         .AND. springNorth(owner).EQ.0. _d 0,nFail)
        ENDIF
      ENDDO
      globalDirected = INT(directed)
      globalUndirected = INT(undirected)
      CALL GLOBAL_SUM_INT(globalDirected,myThid)
      CALL GLOBAL_SUM_INT(globalUndirected,myThid)
      CALL BOM_P33_ASSERT(globalDirected.EQ.2 .AND.
     &     globalUndirected.EQ.1,nFail)

C--   Equality is accepted; the first value above the guard is rejected.
      _BEGIN_MASTER(myThid)
      bomSpringCFL = 0.1 _d 0
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_K2,2,1,
     O     failCode,failPhase,ghostValid,myThid)
      CALL BOM_SPRING_STAGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     BOM_STAGE_K2,2,1,100. _d 0,
     O     springEast,springNorth,neighborCount,
     O     ownerRecords,ghostRecords,nonEmptyCells,
     O     comparisons,directed,undirected,maximum,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P33_ASSERT(valid,nFail)
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_K3,3,1,
     O     failCode,failPhase,ghostValid,myThid)
      CALL BOM_SPRING_STAGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     BOM_STAGE_K3,3,1,100.0001 _d 0,
     O     springEast,springNorth,neighborCount,
     O     ownerRecords,ghostRecords,nonEmptyCells,
     O     comparisons,directed,undirected,maximum,
     O     failCode,failPhase,valid,myThid)
      caught = 0
      IF ( nOwner.GT.0 .AND. .NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_SPRING_CFL ) caught=1
      globalCaught = caught
      ownerRanks = 0
      IF ( nOwner.GT.0 ) ownerRanks=1
      CALL GLOBAL_SUM_INT(globalCaught,myThid)
      CALL GLOBAL_SUM_INT(ownerRanks,myThid)
      CALL BOM_P33_ASSERT(globalCaught.EQ.ownerRanks,nFail)
      _BEGIN_MASTER(myThid)
      bomSpringCFL = oneRL
      _END_MASTER(myThid)
      _BARRIER
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P33_TEST_ENSEMBLE(
     U                 failI01, failI02,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER failI01, failI02, myThid
      INTEGER order, iCase, iStep, nStep, failStage
      INTEGER failPhase, failCode, bi, bj, ip, iDiag
      INTEGER nCases(3)
      _RL errors2(3), errors4(3), errors(3)
      _RL totalTime, dt, t0, t1, xLow, xHigh
      _RL separation, centre, exactSeparation, tolerance
      _RL savedOutput, savedX, savedY, savedAge
      _RL savedSpringE, savedSpringN, savedDiag
      INTEGER savedStatus, savedNeighbor
      LOGICAL valid, unchanged, ghostsClear

      nCases(1)=1
      nCases(2)=2
      nCases(3)=4
      totalTime = 100. _d 0
      exactSeparation = 100. _d 0
     &     +100. _d 0*EXP(-0.2 _d 0)
      tolerance = 2. _d -10
      DO order=2,4,2
        DO iCase=1,3
          nStep = nCases(iCase)
          CALL BOM_P33_PREPARE_PAIR(
     I         -900. _d 0,-700. _d 0,0. _d 0,
     I         totalTime,myThid)
          dt = totalTime/DFLOAT(nStep)
          DO iStep=1,nStep
            t0 = DFLOAT(iStep-1)*dt
            t1 = DFLOAT(iStep)*dt
            IF ( order.EQ.2 ) THEN
              CALL BOM_RK2_SPRING_ENSEMBLE(
     I             t0,t1,iStep,iStep,
     O             failStage,failPhase,failCode,valid,myThid)
            ELSE
              CALL BOM_RK4_SPRING_ENSEMBLE(
     I             t0,t1,iStep,iStep,
     O             failStage,failPhase,failCode,valid,myThid)
            ENDIF
            CALL BOM_P33_ASSERT(valid,failI01)
          ENDDO
          CALL BOM_P33_GET_PAIR(
     O         xLow,xHigh,separation,centre,myThid)
          errors(iCase) = ABS(separation-exactSeparation)
          CALL BOM_P33_ASSERT(ABS(centre+800. _d 0).LT.tolerance,
     &         failI01)
          IF ( order.EQ.2 ) errors2(iCase)=errors(iCase)
          IF ( order.EQ.4 ) errors4(iCase)=errors(iCase)
        ENDDO
      ENDDO
      IF ( myProcId.EQ.0 ) THEN
        CALL BOM_P33_ASSERT(errors2(1).GT.3.5 _d 0*errors2(2)
     &       .AND. errors2(2).GT.3.5 _d 0*errors2(3),failI01)
        CALL BOM_P33_ASSERT(errors4(1).GT.12. _d 0*errors4(2)
     &       .AND. errors4(2).GT.12. _d 0*errors4(3),failI01)
      ENDIF

C--   A K1 spring-CFL failure leaves every authoritative byte sampled here.
      CALL BOM_P33_PREPARE_PAIR(
     I     -900. _d 0,-700. _d 0,0. _d 0,totalTime,myThid)
      savedOutput = bomNextOutputTime
      savedX = 0. _d 0
      savedY = 0. _d 0
      savedAge = 0. _d 0
      savedSpringE = 0. _d 0
      savedSpringN = 0. _d 0
      savedDiag = 0. _d 0
      savedStatus = 0
      savedNeighbor = 0
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          savedX = savedX+bomX(ip,bi,bj)
          savedY = savedY+bomY(ip,bi,bj)
          savedAge = savedAge+bomAge(ip,bi,bj)
          savedSpringE = savedSpringE+bomSpringEast(ip,bi,bj)
          savedSpringN = savedSpringN+bomSpringNorth(ip,bi,bj)
          savedStatus = savedStatus+bomStatus(ip,bi,bj)
          savedNeighbor = savedNeighbor+bomNeighborCount(ip,bi,bj)
          DO iDiag=1,BOM_RHS_NDIAG
            savedDiag = savedDiag+bomRhsDiag(iDiag,ip,bi,bj)
          ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BEGIN_MASTER(myThid)
      bomSpringCFL = 0.05 _d 0
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_RK2_SPRING_ENSEMBLE(
     I     0. _d 0,totalTime,1,1,
     O     failStage,failPhase,failCode,valid,myThid)
      CALL BOM_P33_ASSERT(.NOT.valid .AND.
     &     failStage.EQ.BOM_STAGE_K1 .AND.
     &     failPhase.EQ.BOM_P3_PHASE_SPRING .AND.
     &     failCode.EQ.BOM_FAIL_SPRING_CFL,failI02)
      unchanged = bomNextOutputTime.EQ.savedOutput
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          unchanged = unchanged .AND.
     &         savedX.GE.bomX(ip,bi,bj)-2000. _d 0
C         Exact aggregate equality is checked below after rebuilding sums.
        ENDDO
       ENDDO
      ENDDO
      xLow = 0. _d 0
      xHigh = 0. _d 0
      t0 = 0. _d 0
      t1 = 0. _d 0
      centre = 0. _d 0
      separation = 0. _d 0
      failCode = 0
      failPhase = 0
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          xLow = xLow+bomX(ip,bi,bj)
          xHigh = xHigh+bomY(ip,bi,bj)
          t0 = t0+bomAge(ip,bi,bj)
          t1 = t1+bomSpringEast(ip,bi,bj)
          centre = centre+bomSpringNorth(ip,bi,bj)
          failCode = failCode+bomStatus(ip,bi,bj)
          failPhase = failPhase+bomNeighborCount(ip,bi,bj)
          DO iDiag=1,BOM_RHS_NDIAG
            separation = separation+bomRhsDiag(iDiag,ip,bi,bj)
          ENDDO
        ENDDO
       ENDDO
      ENDDO
      unchanged = unchanged .AND. xLow.EQ.savedX
     &     .AND. xHigh.EQ.savedY .AND. t0.EQ.savedAge
     &     .AND. t1.EQ.savedSpringE
     &     .AND. centre.EQ.savedSpringN
     &     .AND. separation.EQ.savedDiag
     &     .AND. failCode.EQ.savedStatus
     &     .AND. failPhase.EQ.savedNeighbor
      ghostsClear = .TRUE.
      DO bj=1,nSy
       DO bi=1,nSx
        ghostsClear = ghostsClear .AND.
     &       .NOT.bomGhostReady(bi,bj)
     &       .AND. bomNGhostTile(bi,bj).EQ.0
       ENDDO
      ENDDO
      CALL BOM_P33_ASSERT(unchanged .AND. ghostsClear,failI02)
      _BEGIN_MASTER(myThid)
      bomSpringCFL = oneRL
      _END_MASTER(myThid)
      _BARRIER
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P33_TEST_CROSS_RANK( nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nFail, myThid, failStage, failPhase, failCode
      INTEGER bi, bj, ip, ownerCount
      INTEGER*8 xBits, yBits, springEBits, springNBits
      INTEGER*8 driftEBits, driftNBits
      _RL xLow, xHigh, separation, centre, expected
      LOGICAL valid

      CALL BOM_P33_PREPARE_PAIR(
     I     2000. _d 0,2200. _d 0,0. _d 0,100. _d 0,myThid)
      CALL BOM_RK4_SPRING_ENSEMBLE(
     I     0. _d 0,100. _d 0,1,1,
     O     failStage,failPhase,failCode,valid,myThid)
      CALL BOM_P33_ASSERT(valid,nFail)
      CALL BOM_P33_GET_PAIR(
     O     xLow,xHigh,separation,centre,myThid)
      expected = 100. _d 0+100. _d 0*
     &     (oneRL-0.2 _d 0+0.02 _d 0
     &      -0.001333333333333333 _d 0
     &      +0.000066666666666667 _d 0)
      CALL BOM_P33_ASSERT(ABS(separation-expected).LT.2. _d -10
     &     .AND. ABS(centre-2100. _d 0).LT.2. _d -10,nFail)
      ownerCount = 0
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          ownerCount=ownerCount+1
          CALL BOM_P33_ASSERT(
     I         bomNeighborCount(ip,bi,bj).EQ.1 .AND.
     &         bomRhsDiag(BOM_RHS_DRIFT_E,ip,bi,bj).EQ.
     &           bomSpringEast(ip,bi,bj) .AND.
     &         bomRhsDiag(BOM_RHS_DRIFT_N,ip,bi,bj).EQ.
     &           bomSpringNorth(ip,bi,bj),nFail)
          xBits=TRANSFER(bomX(ip,bi,bj),xBits)
          yBits=TRANSFER(bomY(ip,bi,bj),yBits)
          springEBits=TRANSFER(bomSpringEast(ip,bi,bj),springEBits)
          springNBits=TRANSFER(bomSpringNorth(ip,bi,bj),springNBits)
          driftEBits=TRANSFER(
     &         bomRhsDiag(BOM_RHS_DRIFT_E,ip,bi,bj),driftEBits)
          driftNBits=TRANSFER(
     &         bomRhsDiag(BOM_RHS_DRIFT_N,ip,bi,bj),driftNBits)
          WRITE(standardMessageUnit,9000)
     &         'P3-B17 RECORD',bomId(ip,bi,bj),xBits,yBits,
     &         springEBits,springNBits,driftEBits,driftNBits,
     &         bomNeighborCount(ip,bi,bj)
        ENDDO
       ENDDO
      ENDDO
      CALL GLOBAL_SUM_INT(ownerCount,myThid)
      CALL BOM_P33_ASSERT(ownerCount.EQ.2,nFail)
 9000 FORMAT(A,1X,I20,6(1X,Z16.16),1X,I6)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P33_TEST_MIGRATION( nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nFail, myThid, bi, bj, ip, owner, nOwner
      INTEGER ownerCount, id101Count, id202Count
      INTEGER failCode, failPhase, globalDirected
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord), ownerBj(bomMaxOwnerRecord)
      INTEGER neighborCount(bomMaxOwnerRecord)
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord), ownerY(bomMaxOwnerRecord)
      _RL springEast(bomMaxOwnerRecord)
      _RL springNorth(bomMaxOwnerRecord)
      INTEGER*8 ownerRecords, ghostRecords, nonEmptyCells
      INTEGER*8 comparisons, directed, undirected, maximum
      LOGICAL valid, ghostValid, carried

      CALL BOM_P33_PREPARE_PAIR(
     I     2000. _d 0,2200. _d 0,0. _d 0,100. _d 0,myThid)
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          IF ( bomId(ip,bi,bj).EQ.101_8 ) THEN
            bomX(ip,bi,bj)=2200. _d 0
            bomSpringEast(ip,bi,bj)=1.25 _d 0
            bomSpringNorth(ip,bi,bj)=0.5 _d 0
          ELSE
            bomX(ip,bi,bj)=2400. _d 0
            bomSpringEast(ip,bi,bj)=-2.5 _d 0
            bomSpringNorth(ip,bi,bj)=-0.75 _d 0
          ENDIF
          bomNeighborCount(ip,bi,bj)=1
          bomRaftId(ip,bi,bj)=101_8
          bomRaftSize(ip,bi,bj)=2
        ENDDO
       ENDDO
      ENDDO
      CALL BOM_PARTICLE_EXCHANGE(0. _d 0,1,1,myThid)
      ownerCount=0
      id101Count=0
      id202Count=0
      carried=.TRUE.
      nOwner=0
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          ownerCount=ownerCount+1
          nOwner=nOwner+1
          ownerId(nOwner)=bomId(ip,bi,bj)
          ownerStatus(nOwner)=bomStatus(ip,bi,bj)
          ownerX(nOwner)=bomX(ip,bi,bj)
          ownerY(nOwner)=bomY(ip,bi,bj)
          ownerBi(nOwner)=bi
          ownerBj(nOwner)=bj
          IF ( bomId(ip,bi,bj).EQ.101_8 ) THEN
            id101Count=id101Count+1
            carried=carried .AND.
     &           bomX(ip,bi,bj).EQ.2200. _d 0 .AND.
     &           bomSpringEast(ip,bi,bj).EQ.1.25 _d 0 .AND.
     &           bomSpringNorth(ip,bi,bj).EQ.0.5 _d 0
          ELSEIF ( bomId(ip,bi,bj).EQ.202_8 ) THEN
            id202Count=id202Count+1
            carried=carried .AND.
     &           bomX(ip,bi,bj).EQ.2400. _d 0 .AND.
     &           bomSpringEast(ip,bi,bj).EQ.-2.5 _d 0 .AND.
     &           bomSpringNorth(ip,bi,bj).EQ.-0.75 _d 0
          ELSE
            carried=.FALSE.
          ENDIF
          carried=carried .AND.
     &         bomNeighborCount(ip,bi,bj).EQ.1 .AND.
     &         bomRaftId(ip,bi,bj).EQ.101_8 .AND.
     &         bomRaftSize(ip,bi,bj).EQ.2
        ENDDO
       ENDDO
      ENDDO
      CALL GLOBAL_SUM_INT(ownerCount,myThid)
      CALL GLOBAL_SUM_INT(id101Count,myThid)
      CALL GLOBAL_SUM_INT(id202Count,myThid)
      CALL BOM_P33_ASSERT(ownerCount.EQ.2 .AND.
     &     id101Count.EQ.1 .AND. id202Count.EQ.1 .AND.
     &     carried,nFail)

C--   A migration packet cannot become a ghost owner; rebuild the next graph.
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_FINAL,91,9,
     O     failCode,failPhase,ghostValid,myThid)
      CALL BOM_P33_ASSERT(ghostValid,nFail)
      CALL BOM_SPRING_STAGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     BOM_STAGE_FINAL,91,9,0. _d 0,
     O     springEast,springNorth,neighborCount,
     O     ownerRecords,ghostRecords,nonEmptyCells,
     O     comparisons,directed,undirected,maximum,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P33_ASSERT(valid,nFail)
      DO owner=1,nOwner
        CALL BOM_P33_ASSERT(neighborCount(owner).EQ.1,nFail)
      ENDDO
      globalDirected=INT(directed)
      CALL GLOBAL_SUM_INT(globalDirected,myThid)
      CALL BOM_P33_ASSERT(globalDirected.EQ.2,nFail)
      CALL BOM_GHOST_INVALIDATE
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P33_SET_CONFIG( myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
      _BEGIN_MASTER(myThid)
      bomMode = 'BOM'
      bomEquationMode = 'PAPER2024'
      bomIntegrator = 'RK4'
      bomCurrentPolicy = 'EULERIAN'
      bomStokesSource = 'NONE'
      bomWindSource = 'NONE'
      bomSpringLaw = 'HOOKE'
      bomNeighborPolicy = 'CUTOFF'
      bomAlpha = 0. _d 0
      bomTau = oneRL
      bomR = 0.823 _d 0
      bomSigma = 0. _d 0
      bomLeewayWindCoeff = 0. _d 0
      bomSpringL = 100. _d 0
      bomHookeK = 0.001 _d 0
      bomSpringA = 0. _d 0
      bomSpringDelta = 0. _d 0
      bomNeighborCutoff = 300. _d 0
      bomPairDistanceMin = 1. _d -6
      bomSpringCFL = oneRL
      bomAdvCFL = 0.9 _d 0
      bomRaftDiagnostics = .FALSE.
      bomOutputScheduleReady = .TRUE.
      bomNextOutputTime = 777. _d 0
      _END_MASTER(myThid)
      _BARRIER
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P33_PREPARE_PAIR(
     I                 xLow, xHigh, yy, totalTime, myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      _RL xLow, xHigh, yy, totalTime
      INTEGER myThid, nOwner, owner, ip, bi, bj
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord), ownerBj(bomMaxOwnerRecord)
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord), ownerY(bomMaxOwnerRecord)

      CALL BOM_INIT_STATE(myThid)
      CALL BOM_P33_SET_CONFIG(myThid)
      CALL BOM_P33_PUBLISH_ZERO(0. _d 0,totalTime,myThid)
      CALL BOM_P33_BUILD_INPUT(
     I     2,xLow,yy,101_8,xHigh,yy,202_8,
     O     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     O     ownerBi,ownerBj,myThid)
      DO owner=1,nOwner
        bi = ownerBi(owner)
        bj = ownerBj(owner)
        ip = bomNPartTile(bi,bj)+1
        bomNPartTile(bi,bj) = ip
        bomId(ip,bi,bj) = ownerId(owner)
        bomStatus(ip,bi,bj) = BOM_ALIVE
        bomX(ip,bi,bj) = ownerX(owner)
        bomY(ip,bi,bj) = ownerY(owner)
        bomReleaseTime(ip,bi,bj) = 0. _d 0
        bomAge(ip,bi,bj) = 0. _d 0
      ENDDO
      _BARRIER
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P33_BUILD_INPUT(
     I                 nPoint, x1, y1, id1, x2, y2, id2,
     O                 nOwner, ownerId, ownerStatus,
     O                 ownerX, ownerY, ownerBi, ownerBj,
     I                 myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nPoint, nOwner, myThid, point, rank, bi, bj, hop
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord), ownerBj(bomMaxOwnerRecord)
      INTEGER*8 id1, id2, ownerId(bomMaxOwnerRecord), pointId
      _RL x1, y1, x2, y2, pointX, pointY, xOwner, yOwner
      _RL ownerX(bomMaxOwnerRecord), ownerY(bomMaxOwnerRecord)
      _RL pointsX(2), pointsY(2)
      INTEGER*8 pointsId(2)
      LOGICAL valid
      pointsX(1)=x1
      pointsY(1)=y1
      pointsId(1)=id1
      pointsX(2)=x2
      pointsY(2)=y2
      pointsId(2)=id2
      nOwner=0
      DO point=1,nPoint
        pointX=pointsX(point)
        pointY=pointsY(point)
        pointId=pointsId(point)
        CALL BOM_LOCATE_OWNER(
     I       pointX,pointY,1,1,
     O       xOwner,yOwner,rank,bi,bj,hop,valid,myThid)
        IF ( valid .AND. rank.EQ.myProcId ) THEN
          nOwner=nOwner+1
          ownerId(nOwner)=pointId
          ownerStatus(nOwner)=BOM_ALIVE
          ownerX(nOwner)=xOwner
          ownerY(nOwner)=yOwner
          ownerBi(nOwner)=bi
          ownerBj(nOwner)=bj
        ENDIF
      ENDDO
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P33_PUBLISH_ZERO( time0, time1, myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL time0, time1
      INTEGER myThid, bi, bj, i, j, iSource, iEnd
      LOGICAL wetPoint
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          bomTauSphere(i,j,bi,bj)=0. _d 0
          bomFCori(i,j,bi,bj)=0. _d 0
          bomMetricValid(i,j,bi,bj)=wetPoint
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            bomEnvEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomEnvNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomEnvValid(i,j,iEnd,iSource,bi,bj)=wetPoint
            bomGradEastEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradNorthEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradEastNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradNorthNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradValid(i,j,iEnd,iSource,bi,bj)=wetPoint
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BEGIN_MASTER(myThid)
      bomEnvTime(BOM_ENV_OLD)=time0
      bomEnvTime(BOM_ENV_NEW)=time1
      bomEnvIter(BOM_ENV_OLD)=0
      bomEnvIter(BOM_ENV_NEW)=1
      bomEnvReady=.TRUE.
      bomGradReady=.TRUE.
      bomMetricReady=.TRUE.
      _END_MASTER(myThid)
      _BARRIER
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P33_GET_PAIR(
     O                 xLow, xHigh, separation, centre,
     I                 myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL xLow, xHigh, separation, centre
      INTEGER myThid, bi, bj, ip
      xLow=0. _d 0
      xHigh=0. _d 0
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          IF ( bomId(ip,bi,bj).EQ.101_8 ) xLow=bomX(ip,bi,bj)
          IF ( bomId(ip,bi,bj).EQ.202_8 ) xHigh=bomX(ip,bi,bj)
        ENDDO
       ENDDO
      ENDDO
      CALL GLOBAL_SUM_R8(xLow,myThid)
      CALL GLOBAL_SUM_R8(xHigh,myThid)
      separation=xHigh-xLow
      centre=halfRL*(xHigh+xLow)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P33_ASSERT( condition, nFail )
      IMPLICIT NONE
      LOGICAL condition
      INTEGER nFail
      IF ( .NOT.condition ) nFail=nFail+1
      RETURN
      END
