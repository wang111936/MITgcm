#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BUILD_CELL_LIST
C !INTERFACE:
      SUBROUTINE BOM_BUILD_CELL_LIST(
     I                 nRecord, nOwner, linkCapacity,
     I                 recordId, recordStatus, recordX, recordY,
     I                 recordOwner,
     I                 periodicX, xMin, xMax, yMin, yMax, xPeriod,
     I                 nCellX, nCellY, nCell,
     I                 cellWidthX, cellWidthY,
     O                 cellHead, cellNext, recordCell,
     O                 ownerRecords, ghostRecords, nonEmptyCells,
     O                 failureNeed, failureCapacity,
     O                 failCode, p3FailPhase, listValid )

C !DESCRIPTION:
C     Rebuild one bounded head/next list from explicit owner and current-stage
C     ghost records.  Only ALIVE records enter cells.  recordOwner=1:nOwner
C     identifies authoritative owner slots; zero identifies a ghost.  Outputs
C     remain unchanged unless the complete list validates.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"

      INTEGER nRecord, nOwner, linkCapacity
      INTEGER*8 recordId(bomMaxCellRecord)
      INTEGER recordStatus(bomMaxCellRecord)
      _RL recordX(bomMaxCellRecord), recordY(bomMaxCellRecord)
      INTEGER recordOwner(bomMaxCellRecord)
      LOGICAL periodicX
      _RL xMin, xMax, yMin, yMax, xPeriod
      INTEGER nCellX, nCellY, nCell
      _RL cellWidthX, cellWidthY
      INTEGER cellHead(bomMaxCell)
      INTEGER cellNext(bomMaxCellRecord)
      INTEGER recordCell(bomMaxCellRecord)
      INTEGER*8 ownerRecords, ghostRecords, nonEmptyCells
      INTEGER*8 failureNeed, failureCapacity
      INTEGER failCode, p3FailPhase
      LOGICAL listValid

      INTEGER headWork(bomMaxCell)
      INTEGER nextWork(bomMaxCellRecord)
      INTEGER recordCellWork(bomMaxCellRecord)
      INTEGER ownerSeen(bomMaxOwnerRecord)
      INTEGER rec, owner, cellX, cellY, cellIndex, indexFail
      INTEGER*8 ownerWork, ghostWork, nonEmptyWork
      LOGICAL indexValid
CEOP

      listValid = .FALSE.
      failCode = BOM_FAIL_NEIGHBOR_CONFIG
      p3FailPhase = BOM_P3_PHASE_CELL
      failureNeed = 0_8
      failureCapacity = 0_8
      ownerWork = 0_8
      ghostWork = 0_8
      nonEmptyWork = 0_8
      DO cellIndex=1,bomMaxCell
        headWork(cellIndex) = 0
      ENDDO
      DO rec=1,bomMaxCellRecord
        nextWork(rec) = 0
        recordCellWork(rec) = 0
      ENDDO
      DO owner=1,bomMaxOwnerRecord
        ownerSeen(owner) = 0
      ENDDO

      IF ( nRecord.LT.0 .OR. nOwner.LT.0 .OR.
     &     nOwner.GT.bomMaxOwnerRecord ) RETURN
      IF ( linkCapacity.LT.0 .OR.
     &     linkCapacity.GT.bomMaxCellRecord ) THEN
        failCode = BOM_FAIL_CELL_CAPACITY
        failureNeed = MAX(0,linkCapacity)
        failureCapacity = bomMaxCellRecord
        RETURN
      ENDIF
      IF ( nRecord.GT.linkCapacity ) THEN
        failCode = BOM_FAIL_CELL_CAPACITY
        failureNeed = nRecord
        failureCapacity = linkCapacity
        RETURN
      ENDIF
      IF ( nCellX.LT.1 .OR. nCellY.LT.1 .OR.
     &     nCell.LT.1 .OR. nCell.GT.bomMaxCell .OR.
     &     nCell.NE.nCellX*nCellY ) RETURN

      DO rec=1,nRecord
        owner = recordOwner(rec)
        IF ( owner.LT.0 .OR. owner.GT.nOwner ) RETURN
        IF ( owner.GT.0 ) THEN
          IF ( ownerSeen(owner).NE.0 ) RETURN
          ownerSeen(owner) = rec
        ENDIF
        IF ( recordStatus(rec).LT.BOM_UNUSED .OR.
     &       recordStatus(rec).GT.BOM_WAITING ) RETURN
        IF ( recordStatus(rec).EQ.BOM_ALIVE ) THEN
          IF ( recordId(rec).LE.0_8 ) THEN
            failCode = BOM_FAIL_PAIR_GEOMETRY
            RETURN
          ENDIF
          CALL BOM_CELL_INDEX(
     I         recordX(rec),recordY(rec),periodicX,
     I         xMin,xMax,yMin,yMax,xPeriod,
     I         nCellX,nCellY,nCell,cellWidthX,cellWidthY,
     O         cellX,cellY,cellIndex,indexFail,indexValid)
          IF ( .NOT.indexValid ) THEN
            failCode = indexFail
            RETURN
          ENDIF
          IF ( headWork(cellIndex).EQ.0 )
     &         nonEmptyWork = nonEmptyWork+1_8
          nextWork(rec) = headWork(cellIndex)
          headWork(cellIndex) = rec
          recordCellWork(rec) = cellIndex
          IF ( owner.GT.0 ) THEN
            ownerWork = ownerWork+1_8
          ELSE
            ghostWork = ghostWork+1_8
          ENDIF
        ENDIF
      ENDDO
      DO owner=1,nOwner
        IF ( ownerSeen(owner).EQ.0 ) RETURN
      ENDDO

C--   Publish only after all owner slots, coordinates and links validate.
      DO cellIndex=1,bomMaxCell
        cellHead(cellIndex) = headWork(cellIndex)
      ENDDO
      DO rec=1,bomMaxCellRecord
        cellNext(rec) = nextWork(rec)
        recordCell(rec) = recordCellWork(rec)
      ENDDO
      ownerRecords = ownerWork
      ghostRecords = ghostWork
      nonEmptyCells = nonEmptyWork
      failCode = BOM_FAIL_NONE
      p3FailPhase = BOM_P3_PHASE_NONE
      listValid = .TRUE.

      RETURN
      END
