#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P42_BOUNDARY( myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_VALUE, IEEE_QUIET_NAN, IEEE_POSITIVE_INF
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, i, j, iCell, jCell
      INTEGER boundaryClass, ownerRank, ownerBi, ownerBj
      INTEGER failCode, p4Phase, nFail, globalFail
      _RL xWet, yWet, xMap, ix, jy, dx, dy
      _RL savedXFace, savedPeriod
      _RS savedMask(0:1,0:1)
      LOGICAL isValid, savedPeriodic, savedMetric(0:1,0:1)
      LOGICAL savedCurvilinear
#ifdef ALLOW_USE_MPI
      INTEGER savedXLo2,savedYLo2
#endif

      nFail = 0
      bi = myBxLo(myThid)
      bj = myByLo(myThid)
      xWet = DBLE(xC(2,2,bi,bj))
      yWet = DBLE(yC(2,2,bi,bj))
      dx = DBLE(dxF(2,2,bi,bj))
      dy = DBLE(dyF(2,2,bi,bj))
      bomMetricReady = .TRUE.
      DO j=1-OLy,sNy+OLy
       DO i=1-OLx,sNx+OLx
        bomMetricValid(i,j,bi,bj) =
     &       maskC(i,j,1,bi,bj).GT.0.
       ENDDO
      ENDDO

      CALL BOM_CLASSIFY_BOUNDARY(
     I     xWet,yWet,bi,bj,
     O     boundaryClass,xMap,ix,jy,
     O     ownerRank,ownerBi,ownerBj,
     O     failCode,p4Phase,isValid,
     I     myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. boundaryClass.EQ.BOM_BOUNDARY_WET .AND.
     &     failCode.EQ.BOM_FAIL_NONE .AND.
     &     p4Phase.EQ.BOM_P4_PHASE_NONE,
     &     'P4-L01 interior wet',nFail,myThid)
      iCell = NINT(ix)
      jCell = NINT(jy)

      savedMask(0,0) = maskC(iCell,jCell,1,bi,bj)
      maskC(iCell,jCell,1,bi,bj) = 0.
      CALL BOM_CLASSIFY_BOUNDARY(
     I     xWet,yWet,bi,bj,
     O     boundaryClass,xMap,ix,jy,
     O     ownerRank,ownerBi,ownerBj,
     O     failCode,p4Phase,isValid,
     I     myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND.
     &     boundaryClass.EQ.BOM_BOUNDARY_BEACHED .AND.
     &     failCode.EQ.BOM_FAIL_NONE,
     &     'P4-L01 containing-cell dry',nFail,myThid)
      maskC(iCell,jCell,1,bi,bj) = savedMask(0,0)

C--   The global domain is half-open at the high faces.
      CALL BOM_VERIFY_P42_CLASS(
     I     bomMapXLo-bomMapTol,bomMapYLo,bi,bj,
     I     BOM_BOUNDARY_OUTSIDE,BOM_FAIL_NONE,.TRUE.,
     U     nFail,
     I     myThid)
      CALL BOM_VERIFY_P42_CLASS(
     I     bomMapXHi,bomMapYLo,bi,bj,
     I     BOM_BOUNDARY_OUTSIDE,BOM_FAIL_NONE,.TRUE.,
     U     nFail,
     I     myThid)
      CALL BOM_VERIFY_P42_CLASS(
     I     bomMapXLo,bomMapYLo-bomMapTol,bi,bj,
     I     BOM_BOUNDARY_OUTSIDE,BOM_FAIL_NONE,.TRUE.,
     U     nFail,
     I     myThid)
      CALL BOM_VERIFY_P42_CLASS(
     I     bomMapXLo,bomMapYHi,bi,bj,
     I     BOM_BOUNDARY_OUTSIDE,BOM_FAIL_NONE,.TRUE.,
     U     nFail,
     I     myThid)
      CALL BOM_VERIFY_P42_CLASS(
     I     bomMapXLo,bomMapYLo,bi,bj,
     I     BOM_BOUNDARY_WET,BOM_FAIL_NONE,.TRUE.,
     U     nFail,
     I     myThid)

C--   A complete period maps to the same wet point and exact owner.
      savedPeriodic = bomMapPeriodicX
      savedPeriod = bomMapXPeriod
      bomMapPeriodicX = .TRUE.
      bomMapXPeriod = bomMapXHi-bomMapXLo
      CALL BOM_CLASSIFY_BOUNDARY(
     I     xWet+bomMapXPeriod,yWet,bi,bj,
     O     boundaryClass,xMap,ix,jy,
     O     ownerRank,ownerBi,ownerBj,
     O     failCode,p4Phase,isValid,
     I     myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. boundaryClass.EQ.BOM_BOUNDARY_WET .AND.
     &     xMap.EQ.xWet,
     &     'P4-L01 periodic-X normalization',nFail,myThid)
      iCell=INT(ix+halfRL)
      IF ( DFLOAT(iCell).GT.ix+halfRL ) iCell=iCell-1
      jCell=INT(jy+halfRL)
      IF ( DFLOAT(jCell).GT.jy+halfRL ) jCell=jCell-1
      savedMask(0,0)=maskC(iCell,jCell,1,bi,bj)
      maskC(iCell,jCell,1,bi,bj)=0.
      CALL BOM_VERIFY_P42_CLASS(
     I     xWet+bomMapXPeriod,yWet,bi,bj,
     I     BOM_BOUNDARY_BEACHED,BOM_FAIL_NONE,.TRUE.,
     U     nFail,
     I     myThid)
      maskC(iCell,jCell,1,bi,bj)=savedMask(0,0)
      bomMapPeriodicX = savedPeriodic
      bomMapXPeriod = savedPeriod

C--   Mixed support remains wet; insufficient support is fatal, not beach.
      xWet = DBLE(xC(1,1,bi,bj))+0.49 _d 0*dx
      yWet = DBLE(yC(1,1,bi,bj))+0.49 _d 0*dy
      DO j=0,1
       DO i=0,1
        savedMask(i,j) = maskC(1+i,1+j,1,bi,bj)
        savedMetric(i,j) = bomMetricValid(1+i,1+j,bi,bj)
        maskC(1+i,1+j,1,bi,bj) = 1.
        bomMetricValid(1+i,1+j,bi,bj) = .TRUE.
       ENDDO
      ENDDO
      maskC(2,2,1,bi,bj) = 0.
      CALL BOM_VERIFY_P42_CLASS(
     I     xWet,yWet,bi,bj,
     I     BOM_BOUNDARY_WET,BOM_FAIL_NONE,.TRUE.,
     U     nFail,
     I     myThid)
      maskC(2,1,1,bi,bj) = 0.
      maskC(1,2,1,bi,bj) = 0.
      CALL BOM_VERIFY_P42_CLASS(
     I     xWet,yWet,bi,bj,
     I     BOM_BOUNDARY_FATAL,BOM_FAIL_INTERP,.FALSE.,
     U     nFail,
     I     myThid)
      DO j=0,1
       DO i=0,1
        maskC(1+i,1+j,1,bi,bj) = savedMask(i,j)
        bomMetricValid(1+i,1+j,bi,bj) = savedMetric(i,j)
       ENDDO
      ENDDO

C--   Numerical and metadata damage remains fatal.
      CALL BOM_VERIFY_P42_CLASS(
     I     IEEE_VALUE(xWet,IEEE_QUIET_NAN),yWet,bi,bj,
     I     BOM_BOUNDARY_FATAL,BOM_FAIL_NONFINITE,.FALSE.,
     U     nFail,
     I     myThid)
      CALL BOM_VERIFY_P42_CLASS(
     I     IEEE_VALUE(xWet,IEEE_POSITIVE_INF),yWet,bi,bj,
     I     BOM_BOUNDARY_FATAL,BOM_FAIL_NONFINITE,.FALSE.,
     U     nFail,
     I     myThid)
      savedXFace = bomMapXFace(Nx)
      bomMapXFace(Nx) = bomMapXHi-oneRL
      CALL BOM_VERIFY_P42_CLASS(
     I     xWet,yWet,bi,bj,
     I     BOM_BOUNDARY_FATAL,BOM_FAIL_MAP,.FALSE.,
     U     nFail,
     I     myThid)
      bomMapXFace(Nx) = savedXFace
      bomMetricValid(1,1,bi,bj) = .FALSE.
      xWet = DBLE(xC(1,1,bi,bj))
      yWet = DBLE(yC(1,1,bi,bj))
      CALL BOM_VERIFY_P42_CLASS(
     I     xWet,yWet,bi,bj,
     I     BOM_BOUNDARY_FATAL,BOM_FAIL_METRIC,.FALSE.,
     U     nFail,
     I     myThid)
      bomMetricValid(1,1,bi,bj) = maskC(1,1,1,bi,bj).GT.0.

C--   Invalid source ownership and unsupported grid metadata stay fatal.
      CALL BOM_VERIFY_P42_CLASS(
     I     xWet,yWet,0,bj,
     I     BOM_BOUNDARY_FATAL,BOM_FAIL_OWNER,.FALSE.,
     U     nFail,
     I     myThid)
      savedCurvilinear=usingCurvilinearGrid
      usingCurvilinearGrid=.TRUE.
      CALL BOM_VERIFY_P42_CLASS(
     I     xWet,yWet,bi,bj,
     I     BOM_BOUNDARY_FATAL,BOM_FAIL_MAP,.FALSE.,
     U     nFail,
     I     myThid)
      usingCurvilinearGrid=savedCurvilinear
#ifdef ALLOW_USE_MPI
      IF ( usingMPI .AND. nPx*nPy.GE.2 ) THEN
        savedXLo2=mpi_myXGlobalLo(2)
        savedYLo2=mpi_myYGlobalLo(2)
        mpi_myXGlobalLo(2)=mpi_myXGlobalLo(1)
        mpi_myYGlobalLo(2)=mpi_myYGlobalLo(1)
        xWet=halfRL*(bomMapXFace(0)+bomMapXFace(1))
        yWet=halfRL*(bomMapYFace(0)+bomMapYFace(1))
        CALL BOM_VERIFY_P42_CLASS(
     I       xWet,yWet,bi,bj,
     I       BOM_BOUNDARY_FATAL,BOM_FAIL_OWNER,.FALSE.,
     U       nFail,
     I       myThid)
        mpi_myXGlobalLo(2)=savedXLo2
        mpi_myYGlobalLo(2)=savedYLo2
      ENDIF
#endif

      globalFail = nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.GT.0 ) CALL BOM_VERIFY_P42_ABORT(
     &     'BOM_VERIFY_P42_BOUNDARY',globalFail,myThid)
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P4-L01 PASS: wet/dry/outside/periodic/fatal classes'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
      ENDIF
      _END_MASTER(myThid)
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P42_CLASS(
     I     x,y,bi,bj,expectedClass,expectedFail,expectedValid,
     U     nFail,
     I     myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL x,y,xMap,ix,jy
      INTEGER bi,bj,expectedClass,expectedFail,nFail,myThid
      INTEGER boundaryClass,ownerRank,ownerBi,ownerBj
      INTEGER failCode,p4Phase
      LOGICAL expectedValid,isValid
      CALL BOM_CLASSIFY_BOUNDARY(
     I     x,y,bi,bj,
     O     boundaryClass,xMap,ix,jy,
     O     ownerRank,ownerBi,ownerBj,
     O     failCode,p4Phase,isValid,
     I     myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid.EQV.expectedValid .AND.
     &     boundaryClass.EQ.expectedClass .AND.
     &     failCode.EQ.expectedFail,
     &     'P4-L01 classified fixture',nFail,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P42_FREE_STACK( myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi,bj,ip,newSlot,failCode,nFail,globalFail
      INTEGER*8 movedId,baseRebuild,baseRemove,baseAlloc
      INTEGER*8 expectedId
      _RL diag(BOM_RHS_NDIAG)
      LOGICAL isValid,slotClear

      nFail = 0
      bi = myBxLo(myThid)
      bj = myByLo(myThid)
      CALL BOM_FREE_INIT(bi,bj,failCode,isValid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. bomFreeCount(bi,bj).EQ.bomMaxPartTile
     &     .AND. bomFreeStack(bomMaxPartTile,bi,bj).EQ.1,
     &     'P4-F01 empty reconstruction',nFail,myThid)
      baseRebuild = bomFreeRebuildOps
      baseRemove = bomFreeRemoveOps
      baseAlloc = bomFreeAllocOps

      DO ip=1,5
        expectedId = 100_8+INT(ip,8)
        CALL BOM_VERIFY_P42_ALLOC(
     I       bi,bj,expectedId,
     O       newSlot,failCode,isValid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       isValid .AND. newSlot.EQ.ip .AND.
     &       bomId(ip,bi,bj).EQ.expectedId,
     &       'P4-F01 deterministic prefix allocation',nFail,myThid)
      ENDDO
      CALL BOM_VERIFY_P42_ASSERT(
     &     bomFreeAllocOps-baseAlloc.EQ.5_8,
     &     'P4-F01 one allocation operation per owner',nFail,myThid)

      CALL BOM_FREE_REMOVE(1,bi,bj,101_8,
     O     movedId,failCode,isValid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. movedId.EQ.105_8 .AND.
     &     bomId(1,bi,bj).EQ.105_8,
     &     'P4-F01 remove first swaps exact tail',nFail,myThid)
      CALL BOM_FREE_REMOVE(2,bi,bj,102_8,
     O     movedId,failCode,isValid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. movedId.EQ.104_8 .AND.
     &     bomId(2,bi,bj).EQ.104_8,
     &     'P4-F01 remove middle swaps exact tail',nFail,myThid)
      CALL BOM_FREE_REMOVE(3,bi,bj,103_8,
     O     movedId,failCode,isValid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. movedId.EQ.0_8 .AND.
     &     bomNPartTile(bi,bj).EQ.2,
     &     'P4-F01 remove last',nFail,myThid)
      CALL BOM_OWNER_SLOT_IS_CLEAR(3,bi,bj,slotClear)
      CALL BOM_VERIFY_P42_ASSERT(
     &     slotClear .AND. bomFreeStack(
     &       bomFreeCount(bi,bj),bi,bj).EQ.3,
     &     'P4-F01 zero tail and next-prefix top',nFail,myThid)

      CALL BOM_VERIFY_P42_ALLOC(
     I     bi,bj,201_8,
     O     newSlot,failCode,isValid)
      CALL BOM_VERIFY_P42_ALLOC(
     I     bi,bj,202_8,
     O     newSlot,failCode,isValid)
      CALL BOM_FREE_REMOVE(4,bi,bj,202_8,
     O     movedId,failCode,isValid)
      CALL BOM_FREE_REMOVE(2,bi,bj,104_8,
     O     movedId,failCode,isValid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. movedId.EQ.201_8 .AND.
     &     bomId(1,bi,bj).EQ.105_8 .AND.
     &     bomId(2,bi,bj).EQ.201_8,
     &     'P4-F01 descending multiple removal',nFail,myThid)

C--   Reorder logical records, clear the scratch tail, then reconstruct.
      CALL BOM_OWNER_COPY_SLOT(1,3,bi,bj)
      CALL BOM_OWNER_COPY_SLOT(2,1,bi,bj)
      CALL BOM_OWNER_COPY_SLOT(3,2,bi,bj)
      CALL BOM_OWNER_CLEAR_SLOT(3,bi,bj)
      CALL BOM_FREE_INIT(bi,bj,failCode,isValid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. bomId(1,bi,bj).EQ.201_8 .AND.
     &     bomId(2,bi,bj).EQ.105_8 .AND.
     &     bomFreeStack(bomFreeCount(bi,bj),bi,bj).EQ.3,
     &     'P4-F01 permutation/restart reconstruction',nFail,myThid)

C--   Fill the tile, reject over-allocation without mutation, then reuse.
      DO ip=3,bomMaxPartTile
        expectedId = 1000_8+INT(ip,8)
        CALL BOM_VERIFY_P42_ALLOC(
     I       bi,bj,expectedId,
     O       newSlot,failCode,isValid)
      ENDDO
      CALL BOM_VERIFY_P42_ASSERT(
     &     bomNPartTile(bi,bj).EQ.bomMaxPartTile .AND.
     &     bomFreeCount(bi,bj).EQ.0,
     &     'P4-F01 full compact prefix',nFail,myThid)
      CALL BOM_VERIFY_P42_ALLOC(
     I     bi,bj,99999_8,
     O     newSlot,failCode,isValid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     .NOT.isValid .AND. newSlot.EQ.0 .AND.
     &     bomNPartTile(bi,bj).EQ.bomMaxPartTile,
     &     'P4-F01 full allocation rollback',nFail,myThid)
      expectedId = bomId(bomMaxPartTile/2,bi,bj)
      CALL BOM_FREE_REMOVE(bomMaxPartTile/2,bi,bj,expectedId,
     O     movedId,failCode,isValid)
      CALL BOM_VERIFY_P42_ALLOC(
     I     bi,bj,88888_8,
     O     newSlot,failCode,isValid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. newSlot.EQ.bomMaxPartTile .AND.
     &     bomId(newSlot,bi,bj).EQ.88888_8,
     &     'P4-F01 immediate deterministic reuse',nFail,myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     bomFreeRebuildOps-baseRebuild.EQ.1_8 .AND.
     &     bomFreeRemoveOps-baseRemove.EQ.6_8 .AND.
     &     bomFreeAllocOps-baseAlloc.EQ.INT(bomMaxPartTile+6,8),
     &     'P4-F01 exact O(1) operation counters',nFail,myThid)

      globalFail = nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.GT.0 ) CALL BOM_VERIFY_P42_ABORT(
     &     'BOM_VERIFY_P42_FREE_STACK',globalFail,myThid)
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P4-F01 PASS: compact tail, O(1) remove/alloc/rebuild'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
      ENDIF
      _END_MASTER(myThid)
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P42_ALLOC(
     I     bi,bj,candidateId,
     O     newSlot,failCode,isValid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER bi,bj,newSlot,failCode,iDiag
      INTEGER*8 candidateId
      _RL diag(BOM_RHS_NDIAG)
      LOGICAL isValid
      DO iDiag=1,BOM_RHS_NDIAG
        diag(iDiag) = DBLE(candidateId)+DFLOAT(iDiag)/100. _d 0
      ENDDO
      CALL BOM_FREE_ALLOC(
     I     bi,bj,candidateId,0_8,BOM_ALIVE,0,
     I     DBLE(candidateId),-DBLE(candidateId),0. _d 0,
     I     oneRL,oneRL,oneRL,
     I     2. _d 0,3. _d 0,4. _d 0,5. _d 0,
     I     6. _d 0,7. _d 0,8. _d 0,9. _d 0,10. _d 0,
     I     11,12_8,13,diag,
     O     newSlot,failCode,isValid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P42_TRANSACTION( myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi,bj,i,j,iEnd,ip,newSlot,seedFail,iStack
      INTEGER failCode,p4Phase,failRank,failBi,failBj,failSlot
      INTEGER nFail,globalFail,nBefore,eventBefore,freeBefore
      INTEGER eventTypeBefore,componentBefore,bioIterBefore
      INTEGER inject(6),expectedCode(6),expectedPhase(6)
      INTEGER*8 failId,id1,id2,id3,id4,timeBefore
      INTEGER*8 beachBefore,outsideBefore,rebuildBefore,removeBefore
      INTEGER*8 allocBefore,nextBefore,birthBefore,deathBefore
      INTEGER*8 cancelBefore
      INTEGER*8 componentIdBefore,p3GraphBefore,eventIdBefore
      INTEGER freeStackBefore(bomMaxPartTile)
      _RL acceptedX,acceptedY,nextOutputBefore,bioTimeBefore
      LOGICAL isValid,readyBefore,rollbackSame
      LOGICAL componentReadyBefore,bioReadyBefore,scheduleReadyBefore

      nFail=0
      bi=myBxLo(myThid)
      bj=myByLo(myThid)
      CALL BOM_INIT_STATE(myThid)
      bomMaxParticles=4*nPx*nPy
      bomUseBiology=.FALSE.
      bomUseLand=.TRUE.
      bomTempSource='NONE'
      bomNSource='NONE'
      DO ip=1,4
        CALL BOM_VERIFY_P42_ALLOC(
     I       bi,bj,INT(myProcId,8)*10000_8+INT(ip,8),
     O       newSlot,seedFail,isValid)
      ENDDO
      id1=bomId(1,bi,bj)
      id2=bomId(2,bi,bj)
      id3=bomId(3,bi,bj)
      id4=bomId(4,bi,bj)
      bomNPartExpected=4*nPx*nPy
      bomNPartLiveExpected=bomNPartExpected
      acceptedX=DBLE(xC(1,1,bi,bj))
      acceptedY=DBLE(yC(1,1,bi,bj))
      bomX(1,bi,bj)=acceptedX
      bomY(1,bi,bj)=acceptedY
      bomX(2,bi,bj)=acceptedX
      bomY(2,bi,bj)=acceptedY
      bomTerminalType(1,bi,bj)=BOM_EVENT_BEACHED
      bomTerminalStage(1,bi,bj)=BOM_STAGE_K2
      bomTerminalId(1,bi,bj)=id1
      bomTerminalAcceptedX(1,bi,bj)=acceptedX
      bomTerminalAcceptedY(1,bi,bj)=acceptedY
      bomTerminalAttemptX(1,bi,bj)=acceptedX+10. _d 0
      bomTerminalAttemptY(1,bi,bj)=acceptedY+20. _d 0
      bomTerminalReady(1,bi,bj)=.TRUE.
      bomTerminalType(2,bi,bj)=BOM_EVENT_OUTSIDE
      bomTerminalStage(2,bi,bj)=BOM_STAGE_FINAL
      bomTerminalId(2,bi,bj)=id2
      bomTerminalAcceptedX(2,bi,bj)=acceptedX
      bomTerminalAcceptedY(2,bi,bj)=acceptedY
      bomTerminalAttemptX(2,bi,bj)=bomMapXHi
      bomTerminalAttemptY(2,bi,bj)=acceptedY
      bomTerminalReady(2,bi,bj)=.TRUE.
      bomNextId=987654321_8
      bomComponentReady=.TRUE.
      bomComponentNOwner=1
      bomComponentOwnerId(1)=id4
      bomComponentRaftId(1)=id3
      bomP3DirectedNeighbors=17_8
      bomBioReady=.TRUE.
      bomBioTime(BOM_ENV_OLD)=-3. _d 0
      bomBioIter(BOM_ENV_OLD)=-7
      bomNextOutputTime=123.5 _d 0
      bomOutputScheduleReady=.TRUE.
      bomEventTypeBuffer(1)=BOM_EVENT_BIRTH_CANCEL
      bomEventSubjectIdBuffer(1)=777777_8

      inject(1)=BOM_P4_PHASE_BOUNDARY
      inject(2)=BOM_P4_PHASE_BIOLOGY
      inject(3)=BOM_P4_PHASE_TERMINAL
      inject(4)=BOM_P4_PHASE_CAPACITY
      inject(5)=BOM_P4_PHASE_GRAPH
      inject(6)=BOM_P4_PHASE_BUDGET
      expectedPhase(1)=BOM_P4_PHASE_BOUNDARY
      expectedPhase(2)=BOM_P4_PHASE_BIOLOGY
      expectedPhase(3)=BOM_P4_PHASE_TERMINAL
      expectedPhase(4)=BOM_P4_PHASE_CAPACITY
      expectedPhase(5)=BOM_P4_PHASE_GRAPH
      expectedPhase(6)=BOM_P4_PHASE_BUDGET
      expectedCode(1)=BOM_FAIL_BOUNDARY_EVENT
      expectedCode(2)=BOM_FAIL_BROOKS
      expectedCode(3)=BOM_FAIL_EVENT_TRANSACTION
      expectedCode(4)=BOM_FAIL_EVENT_CAPACITY
      expectedCode(5)=BOM_FAIL_COMPONENT
      expectedCode(6)=BOM_FAIL_EVENT_BUDGET

      DO ip=1,6
        nBefore=bomNPartTile(bi,bj)
        eventBefore=bomEventBufferCount
        freeBefore=bomFreeCount(bi,bj)
        timeBefore=bomEventTimeIndex
        beachBefore=bomBeachEvents
        outsideBefore=bomOutsideEvents
        rebuildBefore=bomFreeRebuildOps
        removeBefore=bomFreeRemoveOps
        allocBefore=bomFreeAllocOps
        nextBefore=bomNextId
        birthBefore=bomBirthEvents
        deathBefore=bomDeathEvents
        cancelBefore=bomCancelEvents
        readyBefore=bomTerminalReady(1,bi,bj)
        eventTypeBefore=bomEventTypeBuffer(1)
        eventIdBefore=bomEventSubjectIdBuffer(1)
        componentReadyBefore=bomComponentReady
        componentBefore=bomComponentNOwner
        componentIdBefore=bomComponentOwnerId(1)
        p3GraphBefore=bomP3DirectedNeighbors
        bioReadyBefore=bomBioReady
        bioTimeBefore=bomBioTime(BOM_ENV_OLD)
        bioIterBefore=bomBioIter(BOM_ENV_OLD)
        nextOutputBefore=bomNextOutputTime
        scheduleReadyBefore=bomOutputScheduleReady
        DO iStack=1,bomMaxPartTile
          freeStackBefore(iStack)=bomFreeStack(iStack,bi,bj)
        ENDDO
        CALL BOM_EVENT_TRANSACTION(
     I       0. _d 0,10. _d 0,1,1,inject(ip),
     O       failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O       failId,isValid,
     I       myThid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       .NOT.isValid .AND. p4Phase.EQ.expectedPhase(ip)
     &       .AND. failCode.EQ.expectedCode(ip)
     &       .AND. failRank.EQ.0,
     &       'P4-T01 canonical injected failure',nFail,myThid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       bomNPartTile(bi,bj).EQ.nBefore .AND.
     &       bomId(1,bi,bj).EQ.id1 .AND.
     &       bomId(2,bi,bj).EQ.id2 .AND.
     &       bomId(3,bi,bj).EQ.id3 .AND.
     &       bomId(4,bi,bj).EQ.id4 .AND.
     &       bomEventBufferCount.EQ.eventBefore .AND.
     &       bomFreeCount(bi,bj).EQ.freeBefore .AND.
     &       bomEventTimeIndex.EQ.timeBefore .AND.
     &       bomBeachEvents.EQ.beachBefore .AND.
     &       bomOutsideEvents.EQ.outsideBefore .AND.
     &       bomFreeRebuildOps.EQ.rebuildBefore .AND.
     &       (bomTerminalReady(1,bi,bj).EQV.readyBefore),
     &       'P4-T01 bitwise authoritative rollback',nFail,myThid)
        rollbackSame=.TRUE.
        DO iStack=1,bomMaxPartTile
          rollbackSame=rollbackSame .AND.
     &         bomFreeStack(iStack,bi,bj).EQ.freeStackBefore(iStack)
        ENDDO
        rollbackSame=rollbackSame .AND.
     &       bomFreeRemoveOps.EQ.removeBefore .AND.
     &       bomFreeAllocOps.EQ.allocBefore .AND.
     &       bomNextId.EQ.nextBefore .AND.
     &       bomBirthEvents.EQ.birthBefore .AND.
     &       bomDeathEvents.EQ.deathBefore .AND.
     &       bomCancelEvents.EQ.cancelBefore .AND.
     &       bomEventTypeBuffer(1).EQ.eventTypeBefore .AND.
     &       bomEventSubjectIdBuffer(1).EQ.eventIdBefore .AND.
     &       (bomComponentReady.EQV.componentReadyBefore) .AND.
     &       bomComponentNOwner.EQ.componentBefore .AND.
     &       bomComponentOwnerId(1).EQ.componentIdBefore .AND.
     &       bomP3DirectedNeighbors.EQ.p3GraphBefore .AND.
     &       (bomBioReady.EQV.bioReadyBefore) .AND.
     &       bomBioTime(BOM_ENV_OLD).EQ.bioTimeBefore .AND.
     &       bomBioIter(BOM_ENV_OLD).EQ.bioIterBefore .AND.
     &       bomNextOutputTime.EQ.nextOutputBefore .AND.
     &       (bomOutputScheduleReady.EQV.scheduleReadyBefore) .AND.
     &       bomTerminalAttemptX(1,bi,bj).EQ.acceptedX+10. _d 0
        CALL BOM_VERIFY_P42_ASSERT(
     &       rollbackSame,'P4-T01 extended rollback state',nFail,myThid)
      ENDDO

      CALL BOM_EVENT_TRANSACTION(
     I     0. _d 0,10. _d 0,1,1,BOM_P4_PHASE_NONE,
     O     failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O     failId,isValid,
     I     myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. bomNPartTile(bi,bj).EQ.2 .AND.
     &     bomId(1,bi,bj).EQ.id3 .AND.
     &     bomId(2,bi,bj).EQ.id4 .AND.
     &     bomEventBufferCount.EQ.2 .AND.
     &     bomEventTypeBuffer(1).EQ.BOM_EVENT_BEACHED .AND.
     &     bomEventTypeBuffer(2).EQ.BOM_EVENT_OUTSIDE .AND.
     &     bomEventStageBuffer(1).EQ.BOM_STAGE_K2 .AND.
     &     bomEventAttemptXBuffer(1).EQ.acceptedX+10. _d 0
     &     .AND. bomEventAcceptedXBuffer(1).EQ.acceptedX,
     &     'P4-T01/B11 distinct terminal commit',nFail,myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     bomBeachEvents.EQ.INT(nPx*nPy,8) .AND.
     &     bomOutsideEvents.EQ.INT(nPx*nPy,8) .AND.
     &     bomNPartLiveExpected.EQ.2*nPx*nPy .AND.
     &     bomEventTimeIndex.EQ.1_8 .AND.
     &     .NOT.bomTerminalReady(1,bi,bj) .AND.
     &     bomFreeStack(bomFreeCount(bi,bj),bi,bj).EQ.3,
     &     'P4-T01 global budget and consumed scratch',nFail,myThid)
      CALL BOM_VERIFY_P42_ALLOC(
     I     bi,bj,INT(myProcId,8)*10000_8+99_8,
     O     newSlot,seedFail,isValid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. newSlot.EQ.3 .AND.
     &     bomId(newSlot,bi,bj).NE.id1 .AND.
     &     bomId(newSlot,bi,bj).NE.id2,
     &     'B11/B13 immediate slot reuse without ID reuse',nFail,myThid)

C--   A second isolated transaction covers interleaved Brooks deaths and S.
      CALL BOM_INIT_STATE(myThid)
      bomMaxParticles=4*nPx*nPy
      bomUseBiology=.TRUE.
      bomUseLand=.TRUE.
      bomTempSource='THETA'
      bomNSource='PTRACER'
      bomBiologyMissingPolicy='STOP'
      bomMuMax=0. _d 0
      bomMort=0.1 _d 0
      bomS0=oneRL
      bomSMin=0.2 _d 0
      bomSMax=3. _d 0
      DO ip=1,4
        CALL BOM_VERIFY_P42_ALLOC(
     I       bi,bj,INT(myProcId,8)*10000_8+100_8+INT(ip,8),
     O       newSlot,seedFail,isValid)
        bomX(ip,bi,bj)=acceptedX
        bomY(ip,bi,bj)=acceptedY
        bomI(ip,bi,bj)=1.25 _d 0
        bomJ(ip,bi,bj)=1.25 _d 0
        bomReleaseTime(ip,bi,bj)=0. _d 0
      ENDDO
      id1=bomId(1,bi,bj)
      id2=bomId(2,bi,bj)
      id3=bomId(3,bi,bj)
      id4=bomId(4,bi,bj)
      bomS(1,bi,bj)=0.25 _d 0
      bomS(2,bi,bj)=2. _d 0
      bomS(3,bi,bj)=0.21 _d 0
      bomS(4,bi,bj)=1.5 _d 0
      bomStatus(4,bi,bj)=BOM_WAITING
      bomReleaseTime(4,bi,bj)=2. _d 0*deltaTClock
      bomNPartExpected=4*nPx*nPy
      bomNPartLiveExpected=bomNPartExpected
      bomBioReady=.TRUE.
      bomBioTime(BOM_ENV_OLD)=0. _d 0
      bomBioTime(BOM_ENV_NEW)=deltaTClock
      bomBioIter(BOM_ENV_OLD)=0
      bomBioIter(BOM_ENV_NEW)=1
      DO iEnd=1,BOM_ENV_NEND
        bomBioTempSource(iEnd)=BOM_BIO_TEMP_THETA
        bomBioNSource(iEnd)=BOM_BIO_N_PTRACER
      ENDDO
      DO j=1-OLy,sNy+OLy
       DO i=1-OLx,sNx+OLx
        DO iEnd=1,BOM_ENV_NEND
          bomBioTemp(i,j,iEnd,bi,bj)=20. _d 0
          bomBioN(i,j,iEnd,bi,bj)=0. _d 0
          bomBioValid(i,j,iEnd,bi,bj)=
     &         maskC(i,j,1,bi,bj).GT.0.
        ENDDO
       ENDDO
      ENDDO
      CALL BOM_EVENT_TRANSACTION(
     I     deltaTClock-oneRL,deltaTClock,2,1,BOM_P4_PHASE_NONE,
     O     failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O     failId,isValid,
     I     myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. bomNPartTile(bi,bj).EQ.2 .AND.
     &     bomId(1,bi,bj).EQ.id4 .AND.
     &     bomId(2,bi,bj).EQ.id2 .AND.
     &     bomStatus(1,bi,bj).EQ.BOM_WAITING .AND.
     &     bomS(1,bi,bj).EQ.1.5 _d 0 .AND.
     &     bomS(2,bi,bj).EQ.1.9 _d 0 .AND.
     &     bomEventTypeBuffer(1).EQ.BOM_EVENT_DEAD_BIO .AND.
     &     bomEventSubjectIdBuffer(1).EQ.id1 .AND.
     &     bomEventSubjectIdBuffer(2).EQ.id3 .AND.
     &     bomEventSBeforeBuffer(1).EQ.0.25 _d 0 .AND.
     &     bomEventSTrialBuffer(1).EQ.0.15 _d 0,
     &     'B13 deaths, ALIVE growth, WAITING freeze',nFail,myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     bomDeathEvents.EQ.INT(2*nPx*nPy,8) .AND.
     &     bomNPartLiveExpected.EQ.2*nPx*nPy .AND.
     &     bomEventTimeIndex.EQ.1_8,
     &     'B13 global death/free budget',nFail,myThid)
      CALL BOM_VERIFY_P42_ALLOC(
     I     bi,bj,INT(myProcId,8)*10000_8+999_8,
     O     newSlot,seedFail,isValid)
      bomNPartLiveExpected=bomNPartLiveExpected+nPx*nPy
      CALL BOM_VERIFY_P42_ASSERT(
     &     isValid .AND. newSlot.EQ.3 .AND.
     &     bomId(newSlot,bi,bj).NE.id1 .AND.
     &     bomId(newSlot,bi,bj).NE.id3,
     &     'B13 immediate death-slot reuse',nFail,myThid)

      globalFail=nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.GT.0 ) CALL BOM_VERIFY_P42_ABORT(
     &     'BOM_VERIFY_P42_TRANSACTION',globalFail,myThid)
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P4-T01/B11/B13 PASS: rollback, terminals, death/free'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
      ENDIF
      _END_MASTER(myThid)
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P42_RK_BOUNDARY( myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi,bj,i,j,iEnd,iSource,stage,nFail,globalFail
      INTEGER sourceRank,sourceBi,sourceBj,hop,newSlot,seedFail
      INTEGER migrateRank,migrateBi,migrateBj
      INTEGER outsideRank,outsideBi,outsideBj,rotRank,rotBi,rotBj
      INTEGER terminalType,terminalStage,failStage,failCode,p4Phase
      INTEGER failRank,failBi,failBj,failSlot,ownerCount,eventCount
      INTEGER p3Phase
      INTEGER*8 failId
      _RL xOwner,yOwner,x1,y1,ix,jy,wetWeight,stageCFL
      _RL flowOmega
      _RL rhsDiag(BOM_RHS_NDIAG),attemptX,attemptY
      LOGICAL locateValid,isTerminal,boundaryValid,trialValid
      LOGICAL ensembleValid,eventValid

      nFail=0
      CALL BOM_INIT_STATE(myThid)
      bomMode='BOM'
      bomEquationMode='PAPER2024'
      bomIntegrator='RK2'
      bomCurrentPolicy='EULERIAN'
      bomStokesSource='NONE'
      bomWindSource='NONE'
      bomSpringLaw='NONE'
      bomNeighborPolicy='NONE'
      bomUseLand=.TRUE.
      bomUseBiology=.FALSE.
      bomTempSource='NONE'
      bomNSource='NONE'
      bomAlpha=0. _d 0
      bomTau=0. _d 0
      bomR=0.823 _d 0
      bomSigma=0. _d 0
      bomLeewayWindCoeff=0. _d 0
      bomAdvCFL=10. _d 0

C--   One wet-to-dry rank-seam fixture: x<0 is wet, the +500 C cell dry.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          IF ( DBLE(xC(i,j,bi,bj)).GT.0. _d 0 .AND.
     &         DBLE(xC(i,j,bi,bj)).LT.1000. _d 0 )
     &         maskC(i,j,1,bi,bj)=0.
          bomMetricValid(i,j,bi,bj)=
     &         maskC(i,j,1,bi,bj).GT.0.
          bomTauSphere(i,j,bi,bj)=0. _d 0
          bomFCori(i,j,bi,bj)=0. _d 0
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            bomEnvEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            IF ( iSource.EQ.BOM_ENV_EULERIAN )
     &           bomEnvEast(i,j,iEnd,iSource,bi,bj)=0.01 _d 0
            bomEnvNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomEnvValid(i,j,iEnd,iSource,bi,bj)=
     &           maskC(i,j,1,bi,bj).GT.0.
            bomGradEastEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradNorthEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradEastNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradNorthNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradValid(i,j,iEnd,iSource,bi,bj)=
     &           maskC(i,j,1,bi,bj).GT.0.
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      bomEnvTime(BOM_ENV_OLD)=0. _d 0
      bomEnvTime(BOM_ENV_NEW)=deltaTClock
      bomEnvIter(BOM_ENV_OLD)=0
      bomEnvIter(BOM_ENV_NEW)=1
      bomEnvReady=.TRUE.
      bomGradReady=.TRUE.
      bomMetricReady=.TRUE.
      bomFieldsReady=.TRUE.

      CALL BOM_LOCATE_OWNER(
     I     -5. _d 0,-300. _d 0,1,1,
     O     xOwner,yOwner,sourceRank,sourceBi,sourceBj,
     O     hop,locateValid,myThid)
      IF ( myProcId.EQ.sourceRank ) THEN
        DO stage=BOM_STAGE_K1,BOM_STAGE_FINAL
          CALL BOM_TRY_STAGE_BOUNDARY(
     I         1. _d 0,-300. _d 0,sourceBi,sourceBj,stage,
     O         terminalType,attemptX,attemptY,isTerminal,
     O         failCode,p4Phase,boundaryValid,myThid)
          CALL BOM_VERIFY_P42_ASSERT(
     &         boundaryValid .AND. isTerminal .AND.
     &         terminalType.EQ.BOM_EVENT_BEACHED .AND.
     &         attemptX.EQ.1. _d 0,
     &         'B11 stage classifier K1 through FINAL',nFail,myThid)
        ENDDO

        CALL BOM_RK2_SLOW_MIGRATE_P4(
     I       1. _d 0,-300. _d 0,0. _d 0,deltaTClock,
     I       sourceBi,sourceBj,
     O       x1,y1,ix,jy,rhsDiag,wetWeight,stageCFL,
     O       terminalType,terminalStage,attemptX,attemptY,isTerminal,
     O       failStage,failCode,trialValid,myThid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       trialValid .AND. isTerminal .AND.
     &       terminalStage.EQ.BOM_STAGE_K1 .AND.
     &       x1.EQ.1. _d 0 .AND. attemptX.EQ.1. _d 0,
     &       'B11 RK2 K1 terminal',nFail,myThid)

        CALL BOM_RK4_SLOW_MIGRATE_P4(
     I       1. _d 0,-300. _d 0,0. _d 0,deltaTClock,
     I       sourceBi,sourceBj,
     O       x1,y1,ix,jy,rhsDiag,wetWeight,stageCFL,
     O       terminalType,terminalStage,attemptX,attemptY,isTerminal,
     O       failStage,failCode,trialValid,myThid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       trialValid .AND. isTerminal .AND.
     &       terminalStage.EQ.BOM_STAGE_K1 .AND.
     &       x1.EQ.1. _d 0,
     &       'B11 RK4 K1 terminal',nFail,myThid)

        CALL BOM_RK2_SLOW_MIGRATE_P4(
     I       -5. _d 0,-300. _d 0,0. _d 0,deltaTClock,
     I       sourceBi,sourceBj,
     O       x1,y1,ix,jy,rhsDiag,wetWeight,stageCFL,
     O       terminalType,terminalStage,attemptX,attemptY,isTerminal,
     O       failStage,failCode,trialValid,myThid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       trialValid .AND. isTerminal .AND.
     &       terminalStage.EQ.BOM_STAGE_K2 .AND.
     &       x1.EQ.-5. _d 0 .AND. attemptX.GT.0. _d 0,
     &       'B11 RK2 K2 freezes substep start',nFail,myThid)

        CALL BOM_RK4_SLOW_MIGRATE_P4(
     I       -5. _d 0,-300. _d 0,0. _d 0,deltaTClock,
     I       sourceBi,sourceBj,
     O       x1,y1,ix,jy,rhsDiag,wetWeight,stageCFL,
     O       terminalType,terminalStage,attemptX,attemptY,isTerminal,
     O       failStage,failCode,trialValid,myThid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       trialValid .AND. isTerminal .AND.
     &       terminalStage.EQ.BOM_STAGE_K2 .AND.
     &       x1.EQ.-5. _d 0 .AND. attemptX.GT.0. _d 0,
     &       'B11 RK4 K2 freezes substep start',nFail,myThid)

        CALL BOM_RK2_SLOW_MIGRATE_P4(
     I       -11. _d 0,-300. _d 0,0. _d 0,deltaTClock,
     I       sourceBi,sourceBj,
     O       x1,y1,ix,jy,rhsDiag,wetWeight,stageCFL,
     O       terminalType,terminalStage,attemptX,attemptY,isTerminal,
     O       failStage,failCode,trialValid,myThid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       trialValid .AND. isTerminal .AND.
     &       terminalStage.EQ.BOM_STAGE_FINAL .AND.
     &       x1.EQ.-11. _d 0 .AND. attemptX.GT.0. _d 0,
     &       'B11 RK2 FINAL freezes substep start',nFail,myThid)

        CALL BOM_RK4_SLOW_MIGRATE_P4(
     I       -11. _d 0,-300. _d 0,0. _d 0,deltaTClock,
     I       sourceBi,sourceBj,
     O       x1,y1,ix,jy,rhsDiag,wetWeight,stageCFL,
     O       terminalType,terminalStage,attemptX,attemptY,isTerminal,
     O       failStage,failCode,trialValid,myThid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       trialValid .AND. isTerminal .AND.
     &       terminalStage.EQ.BOM_STAGE_K4 .AND.
     &       x1.EQ.-11. _d 0 .AND. attemptX.GT.0. _d 0,
     &       'B11 RK4 K4 freezes substep start',nFail,myThid)
      ENDIF

C--   A linear-in-time current makes RK4 first encounter land at K3.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomEnvEast(i,j,BOM_ENV_NEW,BOM_ENV_EULERIAN,bi,bj)=
     &         0.03 _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      IF ( myProcId.EQ.sourceRank ) THEN
        CALL BOM_RK4_SLOW_MIGRATE_P4(
     I       -11. _d 0,-300. _d 0,0. _d 0,deltaTClock,
     I       sourceBi,sourceBj,
     O       x1,y1,ix,jy,rhsDiag,wetWeight,stageCFL,
     O       terminalType,terminalStage,attemptX,attemptY,isTerminal,
     O       failStage,failCode,trialValid,myThid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       trialValid .AND. isTerminal .AND.
     &       terminalStage.EQ.BOM_STAGE_K3 .AND.
     &       x1.EQ.-11. _d 0 .AND. attemptX.GT.0. _d 0,
     &       'B11 RK4 K3 time-dependent trajectory',nFail,myThid)
      ENDIF
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomEnvEast(i,j,BOM_ENV_NEW,BOM_ENV_EULERIAN,bi,bj)=
     &         0.01 _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   The same stage logic distinguishes a non-periodic exterior terminal.
      CALL BOM_LOCATE_OWNER(
     I     bomMapXHi-5. _d 0,-300. _d 0,1,1,
     O     xOwner,yOwner,outsideRank,outsideBi,outsideBj,
     O     hop,locateValid,myThid)
      IF ( myProcId.EQ.outsideRank ) THEN
        CALL BOM_RK2_SLOW_MIGRATE_P4(
     I       bomMapXHi-5. _d 0,-300. _d 0,
     I       0. _d 0,deltaTClock,outsideBi,outsideBj,
     O       x1,y1,ix,jy,rhsDiag,wetWeight,stageCFL,
     O       terminalType,terminalStage,attemptX,attemptY,isTerminal,
     O       failStage,failCode,trialValid,myThid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       trialValid .AND. isTerminal .AND.
     &       terminalType.EQ.BOM_EVENT_OUTSIDE .AND.
     &       terminalStage.EQ.BOM_STAGE_K2 .AND.
     &       x1.EQ.bomMapXHi-5. _d 0 .AND.
     &       attemptX.GE.bomMapXHi,
     &       'B11 RK2 non-periodic outside',nFail,myThid)
      ENDIF

C--   A steady rotational flow separates RK4 K4 and FINAL coordinates.
      flowOmega=1.4875 _d 0/deltaTClock
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          IF ( DBLE(xC(i,j,bi,bj)).GT.0. _d 0 .AND.
     &         DBLE(xC(i,j,bi,bj)).LT.1000. _d 0 )
     &         maskC(i,j,1,bi,bj)=1.
          IF ( ABS(DBLE(xC(i,j,bi,bj))+2500. _d 0).LT.oneRL
     &         .AND. ABS(DBLE(yC(i,j,bi,bj))+1500. _d 0)
     &         .LT.oneRL ) maskC(i,j,1,bi,bj)=0.
          bomMetricValid(i,j,bi,bj)=maskC(i,j,1,bi,bj).GT.0.
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            bomEnvEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomEnvNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradEastEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradNorthEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradEastNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradNorthNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            IF ( iSource.EQ.BOM_ENV_EULERIAN ) THEN
              bomEnvEast(i,j,iEnd,iSource,bi,bj)=
     &             -flowOmega*DBLE(yC(i,j,bi,bj))
              bomEnvNorth(i,j,iEnd,iSource,bi,bj)=
     &              flowOmega*DBLE(xC(i,j,bi,bj))
              bomGradNorthEast(i,j,iEnd,iSource,bi,bj)=-flowOmega
              bomGradEastNorth(i,j,iEnd,iSource,bi,bj)=flowOmega
            ENDIF
            bomEnvValid(i,j,iEnd,iSource,bi,bj)=
     &           maskC(i,j,1,bi,bj).GT.0.
            bomGradValid(i,j,iEnd,iSource,bi,bj)=
     &           maskC(i,j,1,bi,bj).GT.0.
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      CALL BOM_LOCATE_OWNER(
     I     -1850. _d 0,2475. _d 0,1,1,
     O     xOwner,yOwner,rotRank,rotBi,rotBj,
     O     hop,locateValid,myThid)
      IF ( myProcId.EQ.rotRank ) THEN
        CALL BOM_RK4_SLOW_MIGRATE_P4(
     I       -1850. _d 0,2475. _d 0,0. _d 0,deltaTClock,
     I       rotBi,rotBj,
     O       x1,y1,ix,jy,rhsDiag,wetWeight,stageCFL,
     O       terminalType,terminalStage,attemptX,attemptY,isTerminal,
     O       failStage,failCode,trialValid,myThid)
        CALL BOM_VERIFY_P42_ASSERT(
     &       trialValid .AND. isTerminal .AND.
     &       terminalStage.EQ.BOM_STAGE_FINAL .AND.
     &       x1.EQ.-1850. _d 0 .AND. y1.EQ.2475. _d 0 .AND.
     &       attemptX.GT.-3000. _d 0 .AND.
     &       attemptX.LT.-2000. _d 0 .AND.
     &       attemptY.GT.-2000. _d 0 .AND.
     &       attemptY.LT.-1000. _d 0,
     &       'B11 RK4 curved FINAL trajectory',nFail,myThid)
      ENDIF

C--   Restore the rank-seam constant-current fixture for spring integration.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          maskC(i,j,1,bi,bj)=1.
          IF ( DBLE(xC(i,j,bi,bj)).GT.0. _d 0 .AND.
     &         DBLE(xC(i,j,bi,bj)).LT.1000. _d 0 )
     &         maskC(i,j,1,bi,bj)=0.
          bomMetricValid(i,j,bi,bj)=maskC(i,j,1,bi,bj).GT.0.
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            bomEnvEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            IF ( iSource.EQ.BOM_ENV_EULERIAN )
     &           bomEnvEast(i,j,iEnd,iSource,bi,bj)=0.01 _d 0
            bomEnvNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomEnvValid(i,j,iEnd,iSource,bi,bj)=
     &           maskC(i,j,1,bi,bj).GT.0.
            bomGradEastEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradNorthEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradEastNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradNorthNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
            bomGradValid(i,j,iEnd,iSource,bi,bj)=
     &           maskC(i,j,1,bi,bj).GT.0.
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      CALL BOM_LOCATE_OWNER(
     I     -5. _d 0,-300. _d 0,1,1,
     O     xOwner,yOwner,sourceRank,sourceBi,sourceBj,
     O     hop,locateValid,myThid)

C--   Run the same seam encounter through the synchronized spring path.
      bomSpringLaw='HOOKE'
      bomNeighborPolicy='CUTOFF'
      bomSpringL=100. _d 0
      bomHookeK=0.001 _d 0
      bomSpringA=0. _d 0
      bomSpringDelta=0. _d 0
      bomNeighborCutoff=300. _d 0
      bomPairDistanceMin=1. _d -6
      bomSpringCFL=oneRL
      bomRaftDiagnostics=.FALSE.
      bomMaxParticles=1
      bomNPartExpected=1
      bomNPartLiveExpected=1
      IF ( myProcId.EQ.sourceRank ) THEN
        CALL BOM_VERIFY_P42_ALLOC(
     I       sourceBi,sourceBj,70001_8,
     O       newSlot,seedFail,ensembleValid)
        bomX(newSlot,sourceBi,sourceBj)=-5. _d 0
        bomY(newSlot,sourceBi,sourceBj)=-300. _d 0
        bomReleaseTime(newSlot,sourceBi,sourceBj)=0. _d 0
        bomAge(newSlot,sourceBi,sourceBj)=0. _d 0
      ENDIF
      CALL BOM_RK2_SPRING_ENSEMBLE(
     I     0. _d 0,deltaTClock,1,1,
     O     failStage,p3Phase,failCode,ensembleValid,myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     ensembleValid,'B11 spring ensemble success',nFail,myThid)
      ownerCount=0
      IF ( myProcId.EQ.sourceRank ) THEN
        ownerCount=bomNPartTile(sourceBi,sourceBj)
        CALL BOM_VERIFY_P42_ASSERT(
     &       ownerCount.EQ.1 .AND.
     &       bomX(1,sourceBi,sourceBj).EQ.-5. _d 0 .AND.
     &       bomTerminalReady(1,sourceBi,sourceBj) .AND.
     &       bomTerminalStage(1,sourceBi,sourceBj).EQ.BOM_STAGE_K2,
     &       'B11 spring scratch freezes and excludes owner',
     &       nFail,myThid)
      ENDIF
      CALL BOM_EVENT_TRANSACTION(
     I     0. _d 0,deltaTClock,1,1,BOM_P4_PHASE_GRAPH,
     O     failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O     failId,eventValid,myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     .NOT.eventValid .AND. p4Phase.EQ.BOM_P4_PHASE_GRAPH
     &     .AND. failCode.EQ.BOM_FAIL_COMPONENT .AND.
     &     failRank.EQ.0 .AND. bomEventTimeIndex.EQ.0_8 .AND.
     &     bomEventBufferCount.EQ.0,
     &     'P4-T01 spring event rollback',nFail,myThid)
      IF ( myProcId.EQ.sourceRank ) CALL BOM_VERIFY_P42_ASSERT(
     &     bomNPartTile(sourceBi,sourceBj).EQ.1 .AND.
     &     bomId(1,sourceBi,sourceBj).EQ.70001_8 .AND.
     &     bomTerminalReady(1,sourceBi,sourceBj),
     &     'P4-T01 spring owner/scratch rollback',nFail,myThid)
      CALL BOM_PARTICLE_EXCHANGE(deltaTClock,1,1,myThid)
      CALL BOM_EVENT_TRANSACTION(
     I     0. _d 0,deltaTClock,1,1,BOM_P4_PHASE_NONE,
     O     failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O     failId,eventValid,myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     eventValid .AND. bomNPartLiveExpected.EQ.0 .AND.
     &     bomBeachEvents.EQ.1_8 .AND.
     &     bomEventTimeIndex.EQ.1_8,
     &     'B11 spring terminal transaction',nFail,myThid)
      eventCount=bomEventBufferCount
      CALL GLOBAL_SUM_INT(eventCount,myThid)
      ownerCount=0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        ownerCount=ownerCount+bomNPartTile(bi,bj)
       ENDDO
      ENDDO
      CALL GLOBAL_SUM_INT(ownerCount,myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     eventCount.EQ.1 .AND. ownerCount.EQ.0,
     &     'B11 spring rank-seam owner removal',nFail,myThid)

C--   Exercise a real owner migration followed by transactional free-stack
C     reconstruction.  Schema 2 remains unchanged; this is the P4.2
C     land-only subset, while complete biology migration remains P4.3.
      CALL BOM_LOCATE_OWNER(
     I     1500. _d 0,-300. _d 0,1,1,
     O     xOwner,yOwner,migrateRank,migrateBi,migrateBj,
     O     hop,locateValid,myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     locateValid .AND. (migrateRank.NE.sourceRank .OR.
     &     migrateBi.NE.sourceBi .OR. migrateBj.NE.sourceBj),
     &     'P4-F01 owner migration fixture',nFail,myThid)
      bomMaxParticles=1
      bomNPartExpected=1
      bomNPartLiveExpected=1
      IF ( myProcId.EQ.sourceRank ) THEN
        CALL BOM_VERIFY_P42_ALLOC(
     I       sourceBi,sourceBj,80001_8,
     O       newSlot,seedFail,ensembleValid)
        bomX(newSlot,sourceBi,sourceBj)=1500. _d 0
        bomY(newSlot,sourceBi,sourceBj)=-300. _d 0
        bomReleaseTime(newSlot,sourceBi,sourceBj)=0. _d 0
        bomAge(newSlot,sourceBi,sourceBj)=0. _d 0
      ENDIF
      CALL BOM_PARTICLE_EXCHANGE(deltaTClock,2,1,myThid)
      CALL BOM_EVENT_TRANSACTION(
     I     deltaTClock,2. _d 0*deltaTClock,2,1,
     I     BOM_P4_PHASE_NONE,
     O     failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O     failId,eventValid,myThid)
      ownerCount=0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        ownerCount=ownerCount+bomNPartTile(bi,bj)
       ENDDO
      ENDDO
      CALL GLOBAL_SUM_INT(ownerCount,myThid)
      CALL BOM_VERIFY_P42_ASSERT(
     &     eventValid .AND. ownerCount.EQ.1 .AND.
     &     bomNPartLiveExpected.EQ.1 .AND.
     &     bomEventTimeIndex.EQ.2_8,
     &     'P4-F01 migration transaction succeeds',nFail,myThid)
      IF ( myProcId.EQ.migrateRank )
     &     CALL BOM_VERIFY_P42_ASSERT(
     &       bomNPartTile(migrateBi,migrateBj).EQ.1 .AND.
     &       bomId(1,migrateBi,migrateBj).EQ.80001_8 .AND.
     &       bomFreeCount(migrateBi,migrateBj).EQ.
     &       bomMaxPartTile-1 .AND.
     &       bomFreeStack(bomFreeCount(migrateBi,migrateBj),
     &                    migrateBi,migrateBj).EQ.2,
     &       'P4-F01 destination free-stack reconstruction',
     &       nFail,myThid)
      IF ( myProcId.EQ.sourceRank )
     &     CALL BOM_VERIFY_P42_ASSERT(
     &       bomNPartTile(sourceBi,sourceBj).EQ.0 .AND.
     &       bomFreeCount(sourceBi,sourceBj).EQ.bomMaxPartTile .AND.
     &       bomFreeStack(bomMaxPartTile,sourceBi,sourceBj).EQ.1,
     &       'P4-F01 source free-stack reconstruction',
     &       nFail,myThid)

      globalFail=nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.GT.0 ) CALL BOM_VERIFY_P42_ABORT(
     &     'BOM_VERIFY_P42_RK_BOUNDARY',globalFail,myThid)
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'B11-RK PASS: RK stages, spring, migration/free rebuild'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
      ENDIF
      _END_MASTER(myThid)
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----5----6----7-|--+----|
      SUBROUTINE BOM_VERIFY_P42_ASSERT(
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
        IF ( nFail.LT.16 ) THEN
          WRITE(msgBuf,'(A,A)') 'P4.2 assertion failed: ',label
          CALL PRINT_ERROR(msgBuf,myThid)
        ENDIF
        nFail = nFail+1
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P42_ABORT(routine,nFail,myThid)
      IMPLICIT NONE
#include "EEPARAMS.h"
      CHARACTER*(*) routine
      INTEGER nFail,myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A,A,A,I8)') 'P4.2 ',routine,
     &       ': failures=',nFail
        CALL PRINT_ERROR(msgBuf,myThid)
      ENDIF
      _END_MASTER(myThid)
      CALL ALL_PROC_DIE(0)
      STOP 'ABNORMAL END: P4.2 DIRECT GATE'
      END
