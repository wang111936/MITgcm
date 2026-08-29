#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_FREE_INIT
C !INTERFACE:
      SUBROUTINE BOM_FREE_INIT(
     I                 bi, bj,
     O                 failCode, isValid )

C !DESCRIPTION:
C     Validate one compact owner prefix and transactionally rebuild the
C     deterministic free tail.  The top entry always names NPART+1.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER bi, bj, failCode
      LOGICAL isValid
      INTEGER ip, nPart, nFree, validateFail
      INTEGER stackWork(bomMaxPartTile)
      LOGICAL prefixValid

      failCode = BOM_FAIL_EVENT_TRANSACTION
      isValid = .FALSE.
      CALL BOM_FREE_VALIDATE(bi,bj,validateFail,prefixValid)
      IF ( .NOT.prefixValid ) THEN
        failCode=validateFail
        RETURN
      ENDIF
      nPart = bomNPartTile(bi,bj)
      nFree = bomMaxPartTile-nPart
      DO ip=1,nFree
        stackWork(ip) = bomMaxPartTile-ip+1
      ENDDO
      DO ip=nFree+1,bomMaxPartTile
        stackWork(ip) = 0
      ENDDO
      DO ip=1,bomMaxPartTile
        bomFreeStack(ip,bi,bj) = stackWork(ip)
      ENDDO
      bomFreeCount(bi,bj) = nFree
      bomFreeRebuildOps = bomFreeRebuildOps+1_8
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_FREE_VALIDATE(bi,bj,failCode,isValid)
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER bi,bj,failCode
      LOGICAL isValid
      INTEGER ip,iDiag,nPart
      LOGICAL slotClear

      failCode=BOM_FAIL_EVENT_TRANSACTION
      isValid=.FALSE.
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) RETURN
      nPart=bomNPartTile(bi,bj)
      IF ( nPart.LT.0 .OR. nPart.GT.bomMaxPartTile ) RETURN
      IF ( bomFreeRebuildOps.LT.0_8 .OR.
     &     bomFreeRebuildOps.EQ.HUGE(bomFreeRebuildOps) ) RETURN
      DO ip=1,nPart
        IF ( bomStatus(ip,bi,bj).NE.BOM_ALIVE .AND.
     &       bomStatus(ip,bi,bj).NE.BOM_WAITING ) RETURN
        IF ( bomId(ip,bi,bj).LE.0_8 ) RETURN
        IF ( bomParentId(ip,bi,bj).LT.0_8 .OR.
     &       bomParentId(ip,bi,bj).EQ.bomId(ip,bi,bj) ) RETURN
        IF ( bomBirthCount(ip,bi,bj).LT.0 ) RETURN
        IF ( .NOT.IEEE_IS_FINITE(bomX(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomY(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomReleaseTime(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomAge(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomI(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomJ(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomVEast(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomVNorth(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomWindEast(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomWindNorth(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomDriftEast(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomDriftNorth(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomS(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomSpringEast(ip,bi,bj)) .OR.
     &       .NOT.IEEE_IS_FINITE(bomSpringNorth(ip,bi,bj)) ) RETURN
        IF ( bomNeighborCount(ip,bi,bj).LT.0 .OR.
     &       bomRaftSize(ip,bi,bj).LT.0 .OR.
     &       bomRaftId(ip,bi,bj).LT.0_8 ) RETURN
        DO iDiag=1,BOM_RHS_NDIAG
          IF ( .NOT.IEEE_IS_FINITE(
     &         bomRhsDiag(iDiag,ip,bi,bj)) ) RETURN
        ENDDO
      ENDDO
      DO ip=nPart+1,bomMaxPartTile
        CALL BOM_OWNER_SLOT_IS_CLEAR(ip,bi,bj,slotClear)
        IF ( .NOT.slotClear ) RETURN
      ENDDO
      failCode=BOM_FAIL_NONE
      isValid=.TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_FREE_REMOVE
C !INTERFACE:
      SUBROUTINE BOM_FREE_REMOVE(
     I                 removeSlot, bi, bj, expectedId,
     O                 movedId, failCode, isValid )

C !DESCRIPTION:
C     Remove one exact owner in O(1), swap the compact tail when needed,
C     zero the old tail, and push that tail onto the deterministic stack.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER removeSlot, bi, bj, failCode
      INTEGER*8 expectedId, movedId
      LOGICAL isValid, slotClear
      INTEGER nPart, nFree, expectedTail

      movedId = 0_8
      failCode = BOM_FAIL_EVENT_TRANSACTION
      isValid = .FALSE.
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) RETURN
      nPart = bomNPartTile(bi,bj)
      nFree = bomFreeCount(bi,bj)
      IF ( nPart.LT.1 .OR. nPart.GT.bomMaxPartTile ) RETURN
      IF ( removeSlot.LT.1 .OR. removeSlot.GT.nPart ) RETURN
      IF ( expectedId.LE.0_8 .OR.
     &     bomId(removeSlot,bi,bj).NE.expectedId ) RETURN
      IF ( nFree.NE.bomMaxPartTile-nPart ) RETURN
      IF ( nFree.GT.0 ) THEN
        expectedTail = nPart+1
        IF ( bomFreeStack(nFree,bi,bj).NE.expectedTail ) RETURN
      ENDIF
      IF ( bomFreeRemoveOps.EQ.HUGE(bomFreeRemoveOps) ) RETURN

      IF ( removeSlot.NE.nPart ) THEN
        movedId = bomId(nPart,bi,bj)
        CALL BOM_OWNER_COPY_SLOT(nPart,removeSlot,bi,bj)
      ENDIF
      CALL BOM_OWNER_CLEAR_SLOT(nPart,bi,bj)
      CALL BOM_OWNER_SLOT_IS_CLEAR(nPart,bi,bj,slotClear)
      IF ( .NOT.slotClear ) RETURN
      bomNPartTile(bi,bj) = nPart-1
      bomFreeCount(bi,bj) = nFree+1
      bomFreeStack(nFree+1,bi,bj) = nPart
      bomFreeRemoveOps = bomFreeRemoveOps+1_8
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_FREE_ALLOC
C !INTERFACE:
      SUBROUTINE BOM_FREE_ALLOC(
     I                 bi, bj, candidateId, candidateParent,
     I                 candidateStatus, candidateBirthCount,
     I                 candidateX, candidateY, candidateRelease,
     I                 candidateAge, candidateI, candidateJ,
     I                 candidateVEast, candidateVNorth,
     I                 candidateWindEast, candidateWindNorth,
     I                 candidateDriftEast, candidateDriftNorth,
     I                 candidateS,
     I                 candidateSpringEast, candidateSpringNorth,
     I                 candidateNeighbor, candidateRaftId,
     I                 candidateRaftSize, candidateDiag,
     O                 newSlot, failCode, isValid )

C !DESCRIPTION:
C     Pop exactly NPART+1 and publish one complete finite owner record.  All
C     validation precedes the first authoritative write.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER bi, bj, candidateStatus, candidateBirthCount
      INTEGER candidateNeighbor, candidateRaftSize
      INTEGER newSlot, failCode
      INTEGER*8 candidateId, candidateParent, candidateRaftId
      _RL candidateX, candidateY, candidateRelease, candidateAge
      _RL candidateI, candidateJ, candidateVEast, candidateVNorth
      _RL candidateWindEast, candidateWindNorth
      _RL candidateDriftEast, candidateDriftNorth, candidateS
      _RL candidateSpringEast, candidateSpringNorth
      _RL candidateDiag(BOM_RHS_NDIAG)
      LOGICAL isValid, slotClear
      INTEGER nPart, nFree, iDiag

      newSlot = 0
      failCode = BOM_FAIL_EVENT_TRANSACTION
      isValid = .FALSE.
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) RETURN
      nPart = bomNPartTile(bi,bj)
      nFree = bomFreeCount(bi,bj)
      IF ( nPart.LT.0 .OR. nPart.GE.bomMaxPartTile ) RETURN
      IF ( nFree.NE.bomMaxPartTile-nPart .OR. nFree.LT.1 ) RETURN
      IF ( bomFreeStack(nFree,bi,bj).NE.nPart+1 ) RETURN
      IF ( candidateId.LE.0_8 .OR. candidateParent.LT.0_8 .OR.
     &     candidateParent.EQ.candidateId ) RETURN
      IF ( candidateStatus.NE.BOM_ALIVE .AND.
     &     candidateStatus.NE.BOM_WAITING ) RETURN
      IF ( candidateBirthCount.LT.0 .OR. candidateNeighbor.LT.0 .OR.
     &     candidateRaftId.LT.0_8 .OR. candidateRaftSize.LT.0 ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(candidateX) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateY) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateRelease) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateAge) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateI) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateJ) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateVEast) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateVNorth) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateWindEast) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateWindNorth) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateDriftEast) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateDriftNorth) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateS) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateSpringEast) .OR.
     &     .NOT.IEEE_IS_FINITE(candidateSpringNorth) ) RETURN
      DO iDiag=1,BOM_RHS_NDIAG
        IF ( .NOT.IEEE_IS_FINITE(candidateDiag(iDiag)) ) RETURN
      ENDDO
      IF ( bomFreeAllocOps.EQ.HUGE(bomFreeAllocOps) ) RETURN
      newSlot = nPart+1
      CALL BOM_OWNER_SLOT_IS_CLEAR(newSlot,bi,bj,slotClear)
      IF ( .NOT.slotClear ) THEN
        newSlot = 0
        RETURN
      ENDIF

      bomId(newSlot,bi,bj) = candidateId
      bomParentId(newSlot,bi,bj) = candidateParent
      bomStatus(newSlot,bi,bj) = candidateStatus
      bomBirthCount(newSlot,bi,bj) = candidateBirthCount
      bomX(newSlot,bi,bj) = candidateX
      bomY(newSlot,bi,bj) = candidateY
      bomReleaseTime(newSlot,bi,bj) = candidateRelease
      bomAge(newSlot,bi,bj) = candidateAge
      bomI(newSlot,bi,bj) = candidateI
      bomJ(newSlot,bi,bj) = candidateJ
      bomVEast(newSlot,bi,bj) = candidateVEast
      bomVNorth(newSlot,bi,bj) = candidateVNorth
      bomWindEast(newSlot,bi,bj) = candidateWindEast
      bomWindNorth(newSlot,bi,bj) = candidateWindNorth
      bomDriftEast(newSlot,bi,bj) = candidateDriftEast
      bomDriftNorth(newSlot,bi,bj) = candidateDriftNorth
      bomS(newSlot,bi,bj) = candidateS
      bomSpringEast(newSlot,bi,bj) = candidateSpringEast
      bomSpringNorth(newSlot,bi,bj) = candidateSpringNorth
      bomNeighborCount(newSlot,bi,bj) = candidateNeighbor
      bomRaftId(newSlot,bi,bj) = candidateRaftId
      bomRaftSize(newSlot,bi,bj) = candidateRaftSize
      DO iDiag=1,BOM_RHS_NDIAG
        bomRhsDiag(iDiag,newSlot,bi,bj) = candidateDiag(iDiag)
      ENDDO
      bomTerminalType(newSlot,bi,bj) = BOM_EVENT_NONE
      bomTerminalStage(newSlot,bi,bj) = BOM_STAGE_NONE
      bomTerminalId(newSlot,bi,bj) = 0_8
      bomTerminalAcceptedX(newSlot,bi,bj) = 0. _d 0
      bomTerminalAcceptedY(newSlot,bi,bj) = 0. _d 0
      bomTerminalAttemptX(newSlot,bi,bj) = 0. _d 0
      bomTerminalAttemptY(newSlot,bi,bj) = 0. _d 0
      bomTerminalReady(newSlot,bi,bj) = .FALSE.
      bomNPartTile(bi,bj) = nPart+1
      bomFreeStack(nFree,bi,bj) = 0
      bomFreeCount(bi,bj) = nFree-1
      bomFreeAllocOps = bomFreeAllocOps+1_8
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_OWNER_COPY_SLOT(sourceSlot,destSlot,bi,bj)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER sourceSlot, destSlot, bi, bj, iDiag
      bomId(destSlot,bi,bj) = bomId(sourceSlot,bi,bj)
      bomParentId(destSlot,bi,bj) = bomParentId(sourceSlot,bi,bj)
      bomStatus(destSlot,bi,bj) = bomStatus(sourceSlot,bi,bj)
      bomBirthCount(destSlot,bi,bj) = bomBirthCount(sourceSlot,bi,bj)
      bomX(destSlot,bi,bj) = bomX(sourceSlot,bi,bj)
      bomY(destSlot,bi,bj) = bomY(sourceSlot,bi,bj)
      bomReleaseTime(destSlot,bi,bj) =
     &     bomReleaseTime(sourceSlot,bi,bj)
      bomAge(destSlot,bi,bj) = bomAge(sourceSlot,bi,bj)
      bomI(destSlot,bi,bj) = bomI(sourceSlot,bi,bj)
      bomJ(destSlot,bi,bj) = bomJ(sourceSlot,bi,bj)
      bomVEast(destSlot,bi,bj) = bomVEast(sourceSlot,bi,bj)
      bomVNorth(destSlot,bi,bj) = bomVNorth(sourceSlot,bi,bj)
      bomWindEast(destSlot,bi,bj) = bomWindEast(sourceSlot,bi,bj)
      bomWindNorth(destSlot,bi,bj) = bomWindNorth(sourceSlot,bi,bj)
      bomDriftEast(destSlot,bi,bj) = bomDriftEast(sourceSlot,bi,bj)
      bomDriftNorth(destSlot,bi,bj) = bomDriftNorth(sourceSlot,bi,bj)
      bomS(destSlot,bi,bj) = bomS(sourceSlot,bi,bj)
      bomSpringEast(destSlot,bi,bj) =
     &     bomSpringEast(sourceSlot,bi,bj)
      bomSpringNorth(destSlot,bi,bj) =
     &     bomSpringNorth(sourceSlot,bi,bj)
      bomNeighborCount(destSlot,bi,bj) =
     &     bomNeighborCount(sourceSlot,bi,bj)
      bomRaftId(destSlot,bi,bj) = bomRaftId(sourceSlot,bi,bj)
      bomRaftSize(destSlot,bi,bj) = bomRaftSize(sourceSlot,bi,bj)
      DO iDiag=1,BOM_RHS_NDIAG
        bomRhsDiag(iDiag,destSlot,bi,bj) =
     &       bomRhsDiag(iDiag,sourceSlot,bi,bj)
      ENDDO
      bomTerminalType(destSlot,bi,bj) =
     &     bomTerminalType(sourceSlot,bi,bj)
      bomTerminalStage(destSlot,bi,bj) =
     &     bomTerminalStage(sourceSlot,bi,bj)
      bomTerminalId(destSlot,bi,bj) =
     &     bomTerminalId(sourceSlot,bi,bj)
      bomTerminalAcceptedX(destSlot,bi,bj) =
     &     bomTerminalAcceptedX(sourceSlot,bi,bj)
      bomTerminalAcceptedY(destSlot,bi,bj) =
     &     bomTerminalAcceptedY(sourceSlot,bi,bj)
      bomTerminalAttemptX(destSlot,bi,bj) =
     &     bomTerminalAttemptX(sourceSlot,bi,bj)
      bomTerminalAttemptY(destSlot,bi,bj) =
     &     bomTerminalAttemptY(sourceSlot,bi,bj)
      bomTerminalReady(destSlot,bi,bj) =
     &     bomTerminalReady(sourceSlot,bi,bj)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_OWNER_CLEAR_SLOT(slot,bi,bj)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER slot, bi, bj, iDiag
      bomId(slot,bi,bj) = 0_8
      bomParentId(slot,bi,bj) = 0_8
      bomStatus(slot,bi,bj) = BOM_UNUSED
      bomBirthCount(slot,bi,bj) = 0
      bomX(slot,bi,bj) = 0. _d 0
      bomY(slot,bi,bj) = 0. _d 0
      bomReleaseTime(slot,bi,bj) = 0. _d 0
      bomAge(slot,bi,bj) = 0. _d 0
      bomI(slot,bi,bj) = 0. _d 0
      bomJ(slot,bi,bj) = 0. _d 0
      bomVEast(slot,bi,bj) = 0. _d 0
      bomVNorth(slot,bi,bj) = 0. _d 0
      bomWindEast(slot,bi,bj) = 0. _d 0
      bomWindNorth(slot,bi,bj) = 0. _d 0
      bomDriftEast(slot,bi,bj) = 0. _d 0
      bomDriftNorth(slot,bi,bj) = 0. _d 0
      bomS(slot,bi,bj) = 0. _d 0
      bomSpringEast(slot,bi,bj) = 0. _d 0
      bomSpringNorth(slot,bi,bj) = 0. _d 0
      bomNeighborCount(slot,bi,bj) = 0
      bomRaftId(slot,bi,bj) = 0_8
      bomRaftSize(slot,bi,bj) = 0
      DO iDiag=1,BOM_RHS_NDIAG
        bomRhsDiag(iDiag,slot,bi,bj) = 0. _d 0
      ENDDO
      bomTerminalType(slot,bi,bj) = BOM_EVENT_NONE
      bomTerminalStage(slot,bi,bj) = BOM_STAGE_NONE
      bomTerminalId(slot,bi,bj) = 0_8
      bomTerminalAcceptedX(slot,bi,bj) = 0. _d 0
      bomTerminalAcceptedY(slot,bi,bj) = 0. _d 0
      bomTerminalAttemptX(slot,bi,bj) = 0. _d 0
      bomTerminalAttemptY(slot,bi,bj) = 0. _d 0
      bomTerminalReady(slot,bi,bj) = .FALSE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_OWNER_SLOT_IS_CLEAR(slot,bi,bj,isClear)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER slot, bi, bj, iDiag
      LOGICAL isClear
      isClear = .FALSE.
      IF ( slot.LT.1 .OR. slot.GT.bomMaxPartTile .OR.
     &     bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) RETURN
      IF ( bomId(slot,bi,bj).NE.0_8 .OR.
     &     bomParentId(slot,bi,bj).NE.0_8 .OR.
     &     bomStatus(slot,bi,bj).NE.BOM_UNUSED .OR.
     &     bomBirthCount(slot,bi,bj).NE.0 .OR.
     &     bomX(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomY(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomReleaseTime(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomAge(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomI(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomJ(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomVEast(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomVNorth(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomWindEast(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomWindNorth(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomDriftEast(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomDriftNorth(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomS(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomSpringEast(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomSpringNorth(slot,bi,bj).NE.0. _d 0 .OR.
     &     bomNeighborCount(slot,bi,bj).NE.0 .OR.
     &     bomRaftId(slot,bi,bj).NE.0_8 .OR.
     &     bomRaftSize(slot,bi,bj).NE.0 ) RETURN
C--   Terminal scratch is not owner state and may temporarily remain at a
C     pre-migration slot until exact-ID binding in the event transaction.
      DO iDiag=1,BOM_RHS_NDIAG
        IF ( bomRhsDiag(iDiag,slot,bi,bj).NE.0. _d 0 ) RETURN
      ENDDO
      isClear = .TRUE.
      RETURN
      END
