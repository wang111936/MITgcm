#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BUILD_NEIGHBORS
C !INTERFACE:
      SUBROUTINE BOM_BUILD_NEIGHBORS(
     I                 nRecord, nOwner,
     I                 candidateCapacity, neighborCapacity,
     I                 recordId, recordStatus, recordX, recordY,
     I                 recordOwner, cellHead, cellNext, recordCell,
     I                 cartesianGrid, sphericalGrid, periodicX,
     I                 xMin, xMax, yMin, yMax, xPeriod,
     I                 sphereRadius, pairDistanceMin, neighborCutoff,
     I                 nCellX, nCellY, nCell,
     I                 cellReachY, rowReachX,
     O                 neighborCount, neighborId, neighborRecord,
     O                 ownerRecords, ghostRecords, nonEmptyCells,
     O                 candidateComparisons, directedNeighbors,
     O                 undirectedEdges, maximumNeighbors,
     O                 failureNeed, failureCapacity,
     O                 failCode, p3FailPhase, neighborsValid )

C !DESCRIPTION:
C     Enumerate only conservative cell-stencil candidates, then apply the
C     canonical P3.1 pair geometry and exact inclusive cutoff.  Candidate IDs
C     are sorted before duplicate suppression, and each published owner list
C     is strictly increasing.  The complete graph and counters are scratch
C     until every owner and local reverse edge validates.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"

      INTEGER nRecord, nOwner, candidateCapacity, neighborCapacity
      INTEGER*8 recordId(bomMaxCellRecord)
      INTEGER recordStatus(bomMaxCellRecord)
      _RL recordX(bomMaxCellRecord), recordY(bomMaxCellRecord)
      INTEGER recordOwner(bomMaxCellRecord)
      INTEGER cellHead(bomMaxCell)
      INTEGER cellNext(bomMaxCellRecord)
      INTEGER recordCell(bomMaxCellRecord)
      LOGICAL cartesianGrid, sphericalGrid, periodicX
      _RL xMin, xMax, yMin, yMax, xPeriod
      _RL sphereRadius, pairDistanceMin, neighborCutoff
      INTEGER nCellX, nCellY, nCell, cellReachY
      INTEGER rowReachX(bomMaxCell)
      INTEGER neighborCount(bomMaxOwnerRecord)
      INTEGER*8 neighborId(bomMaxNeighbor,bomMaxOwnerRecord)
      INTEGER neighborRecord(bomMaxNeighbor,bomMaxOwnerRecord)
      INTEGER*8 ownerRecords, ghostRecords, nonEmptyCells
      INTEGER*8 candidateComparisons, directedNeighbors
      INTEGER*8 undirectedEdges, maximumNeighbors
      INTEGER*8 failureNeed, failureCapacity
      INTEGER failCode, p3FailPhase
      LOGICAL neighborsValid

      INTEGER countWork(bomMaxOwnerRecord)
      INTEGER*8 idWork(bomMaxNeighbor,bomMaxOwnerRecord)
      INTEGER recordWork(bomMaxNeighbor,bomMaxOwnerRecord)
      INTEGER ownerRecordMap(bomMaxOwnerRecord)
      INTEGER candidateRecord(bomMaxCandidate)
      INTEGER owner, rec, candidate, keyRecord, scan, groupEnd
      INTEGER ownerRec, candidateRec
      INTEGER cellIndex, cellX, cellY, xIndex, yIndex
      INTEGER xLo, xHi, yLo, yHi, xOffset, xReach
      INTEGER nCandidate, neighborNeed, geometryFail
      INTEGER reverseOwner
      INTEGER*8 ownerWork, ghostWork, nonEmptyWork
      INTEGER*8 compareWork, directedWork, undirectedWork, maxWork
      INTEGER*8 needWork, capacityWork
      _RL dEast, dNorth, distance
      LOGICAL appendValid, pairValid, counterValid, reverseFound
      LOGICAL BOM_CANDIDATE_AFTER
      SAVE idWork, recordWork
CEOP

      neighborsValid = .FALSE.
      failCode = BOM_FAIL_NEIGHBOR_CONFIG
      p3FailPhase = BOM_P3_PHASE_CELL
      failureNeed = 0_8
      failureCapacity = 0_8
      ownerWork = 0_8
      ghostWork = 0_8
      nonEmptyWork = 0_8
      compareWork = 0_8
      directedWork = 0_8
      undirectedWork = 0_8
      maxWork = 0_8
      DO owner=1,bomMaxOwnerRecord
        countWork(owner) = 0
        ownerRecordMap(owner) = 0
        DO candidate=1,bomMaxNeighbor
          idWork(candidate,owner) = 0_8
          recordWork(candidate,owner) = 0
        ENDDO
      ENDDO

      IF ( nRecord.LT.0 .OR. nRecord.GT.bomMaxCellRecord .OR.
     &     nOwner.LT.0 .OR. nOwner.GT.bomMaxOwnerRecord ) RETURN
      IF ( candidateCapacity.LT.1 .OR.
     &     candidateCapacity.GT.bomMaxCandidate ) THEN
        failCode = BOM_FAIL_CELL_CAPACITY
        failureNeed = MAX(1,candidateCapacity)
        failureCapacity = bomMaxCandidate
        RETURN
      ENDIF
      IF ( neighborCapacity.LT.0 .OR.
     &     neighborCapacity.GT.bomMaxNeighbor ) THEN
        failCode = BOM_FAIL_NEIGHBOR_CAPACITY
        failureNeed = MAX(0,neighborCapacity)
        failureCapacity = bomMaxNeighbor
        RETURN
      ENDIF
      IF ( nCellX.LT.1 .OR. nCellY.LT.1 .OR.
     &     nCell.LT.1 .OR. nCell.GT.bomMaxCell .OR.
     &     nCell.NE.nCellX*nCellY .OR.
     &     cellReachY.LT.1 ) RETURN
      IF ( cartesianGrid.EQV.sphericalGrid ) RETURN

C--   Validate the explicit owner map and expose bounded record counters.
      DO rec=1,nRecord
        IF ( recordOwner(rec).LT.0 .OR.
     &       recordOwner(rec).GT.nOwner ) RETURN
        IF ( recordOwner(rec).GT.0 ) THEN
          owner = recordOwner(rec)
          IF ( ownerRecordMap(owner).NE.0 ) RETURN
          ownerRecordMap(owner) = rec
        ENDIF
        IF ( recordStatus(rec).EQ.BOM_ALIVE ) THEN
          IF ( recordOwner(rec).GT.0 ) THEN
            ownerWork = ownerWork+1_8
          ELSE
            ghostWork = ghostWork+1_8
          ENDIF
          IF ( recordCell(rec).LT.1 .OR.
     &         recordCell(rec).GT.nCell ) RETURN
        ELSEIF ( recordStatus(rec).LT.BOM_UNUSED .OR.
     &           recordStatus(rec).GT.BOM_WAITING ) THEN
          RETURN
        ENDIF
      ENDDO
      DO owner=1,nOwner
        IF ( ownerRecordMap(owner).EQ.0 ) RETURN
      ENDDO
      DO cellIndex=1,nCell
        IF ( cellHead(cellIndex).NE.0 )
     &       nonEmptyWork = nonEmptyWork+1_8
      ENDDO
      p3FailPhase = BOM_P3_PHASE_NEIGHBOR

      DO owner=1,nOwner
        ownerRec = ownerRecordMap(owner)
        IF ( recordStatus(ownerRec).EQ.BOM_ALIVE ) THEN
          cellIndex = recordCell(ownerRec)
          cellY = (cellIndex-1)/nCellX+1
          cellX = cellIndex-(cellY-1)*nCellX
          IF ( rowReachX(cellY).LT.1 ) RETURN
          xReach = rowReachX(cellY)
          yLo = MAX(1,cellY-cellReachY)
          yHi = MIN(nCellY,cellY+cellReachY)
          nCandidate = 0

          DO yIndex=yLo,yHi
            IF ( periodicX .AND.
     &           2*xReach+1.LT.nCellX ) THEN
              DO xOffset=-xReach,xReach
                xIndex = MODULO(cellX-1+xOffset,nCellX)+1
                cellIndex = (yIndex-1)*nCellX+xIndex
                CALL BOM_APPEND_CELL_CANDIDATES(
     I               cellIndex,nRecord,cellHead,cellNext,
     I               candidateCapacity,
     U               nCandidate,candidateRecord,compareWork,
     O               needWork,capacityWork,appendValid)
                IF ( .NOT.appendValid ) THEN
                  failCode = BOM_FAIL_CELL_CAPACITY
                  p3FailPhase = BOM_P3_PHASE_CELL
                  failureNeed = needWork
                  failureCapacity = capacityWork
                  RETURN
                ENDIF
              ENDDO
            ELSE
              IF ( periodicX ) THEN
                xLo = 1
                xHi = nCellX
              ELSE
                xLo = MAX(1,cellX-xReach)
                xHi = MIN(nCellX,cellX+xReach)
              ENDIF
              DO xIndex=xLo,xHi
                cellIndex = (yIndex-1)*nCellX+xIndex
                CALL BOM_APPEND_CELL_CANDIDATES(
     I               cellIndex,nRecord,cellHead,cellNext,
     I               candidateCapacity,
     U               nCandidate,candidateRecord,compareWork,
     O               needWork,capacityWork,appendValid)
                IF ( .NOT.appendValid ) THEN
                  failCode = BOM_FAIL_CELL_CAPACITY
                  p3FailPhase = BOM_P3_PHASE_CELL
                  failureNeed = needWork
                  failureCapacity = capacityWork
                  RETURN
                ENDIF
              ENDDO
            ENDIF
          ENDDO

C--       Sort by (ID, owner-before-ghost, record index).
          DO candidate=2,nCandidate
            keyRecord = candidateRecord(candidate)
            scan = candidate-1
            DO WHILE ( scan.GE.1 )
              IF ( .NOT.BOM_CANDIDATE_AFTER(
     &             candidateRecord(scan),keyRecord,
     &             recordId,recordOwner) ) GOTO 110
              candidateRecord(scan+1) = candidateRecord(scan)
              scan = scan-1
            ENDDO
  110       CONTINUE
            candidateRecord(scan+1) = keyRecord
          ENDDO

          candidate = 1
          DO WHILE ( candidate.LE.nCandidate )
            candidateRec = candidateRecord(candidate)
            groupEnd = candidate
            DO WHILE ( groupEnd.LT.nCandidate )
              rec = candidateRecord(groupEnd+1)
              IF ( recordId(rec).NE.recordId(candidateRec) ) GOTO 120
              groupEnd = groupEnd+1
              IF ( recordStatus(rec).NE.recordStatus(candidateRec)
     &             .OR. recordX(rec).NE.recordX(candidateRec)
     &             .OR. recordY(rec).NE.recordY(candidateRec) ) THEN
                failCode = BOM_FAIL_PAIR_GEOMETRY
                RETURN
              ENDIF
            ENDDO
  120       CONTINUE

            IF ( recordId(candidateRec).NE.recordId(ownerRec) ) THEN
              dEast = 0. _d 0
              dNorth = 0. _d 0
              distance = 0. _d 0
              CALL BOM_PAIR_GEOMETRY(
     I             recordId(ownerRec),recordX(ownerRec),
     I             recordY(ownerRec),
     I             recordId(candidateRec),recordX(candidateRec),
     I             recordY(candidateRec),
     I             cartesianGrid,sphericalGrid,periodicX,
     I             xMin,xMax,yMin,yMax,xPeriod,
     I             sphereRadius,pairDistanceMin,
     O             dEast,dNorth,distance,geometryFail,pairValid)
              IF ( .NOT.pairValid ) THEN
                failCode = geometryFail
                RETURN
              ENDIF
              IF ( distance.LE.neighborCutoff ) THEN
                neighborNeed = countWork(owner)+1
                IF ( neighborNeed.GT.neighborCapacity ) THEN
                  failCode = BOM_FAIL_NEIGHBOR_CAPACITY
                  failureNeed = neighborNeed
                  failureCapacity = neighborCapacity
                  RETURN
                ENDIF
                countWork(owner) = neighborNeed
                idWork(neighborNeed,owner) = recordId(candidateRec)
                recordWork(neighborNeed,owner) = candidateRec
                CALL BOM_INCREMENT_I8(directedWork,counterValid)
                IF ( .NOT.counterValid ) THEN
                  failCode = BOM_FAIL_CELL_CAPACITY
                  failureNeed = HUGE(directedWork)
                  failureCapacity = HUGE(directedWork)
                  RETURN
                ENDIF
                IF ( recordId(ownerRec).LT.recordId(candidateRec) ) THEN
                  CALL BOM_INCREMENT_I8(undirectedWork,counterValid)
                  IF ( .NOT.counterValid ) THEN
                    failCode = BOM_FAIL_CELL_CAPACITY
                    failureNeed = HUGE(undirectedWork)
                    failureCapacity = HUGE(undirectedWork)
                    RETURN
                  ENDIF
                ENDIF
              ENDIF
            ENDIF
            candidate = groupEnd+1
          ENDDO
          maxWork = MAX(maxWork,INT(countWork(owner),8))
        ENDIF
      ENDDO

C--   Every local-owner edge must have its reverse directed representation.
      DO owner=1,nOwner
        ownerRec = ownerRecordMap(owner)
        DO candidate=1,countWork(owner)
          candidateRec = recordWork(candidate,owner)
          reverseOwner = recordOwner(candidateRec)
          IF ( reverseOwner.GT.0 ) THEN
            CALL BOM_FIND_NEIGHBOR_ID(
     I           recordId(ownerRec),countWork(reverseOwner),
     I           idWork(1,reverseOwner),
     O           reverseFound)
            IF ( .NOT.reverseFound ) THEN
              failCode = BOM_FAIL_PAIR_GEOMETRY
              RETURN
            ENDIF
          ENDIF
        ENDDO
      ENDDO

C--   Publish graph and work counters once, after symmetry validation.
      DO owner=1,bomMaxOwnerRecord
        neighborCount(owner) = countWork(owner)
        DO candidate=1,bomMaxNeighbor
          neighborId(candidate,owner) = idWork(candidate,owner)
          neighborRecord(candidate,owner) = recordWork(candidate,owner)
        ENDDO
      ENDDO
      ownerRecords = ownerWork
      ghostRecords = ghostWork
      nonEmptyCells = nonEmptyWork
      candidateComparisons = compareWork
      directedNeighbors = directedWork
      undirectedEdges = undirectedWork
      maximumNeighbors = maxWork
      failCode = BOM_FAIL_NONE
      p3FailPhase = BOM_P3_PHASE_NONE
      neighborsValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_APPEND_CELL_CANDIDATES(
     I                 cellIndex, nRecord, cellHead, cellNext,
     I                 candidateCapacity,
     U                 nCandidate, candidateRecord, comparisons,
     O                 failureNeed, failureCapacity, appendValid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
      INTEGER cellIndex, nRecord, candidateCapacity, nCandidate
      INTEGER cellHead(bomMaxCell), cellNext(bomMaxCellRecord)
      INTEGER candidateRecord(bomMaxCandidate)
      INTEGER rec, traversed
      INTEGER*8 comparisons, failureNeed, failureCapacity
      LOGICAL appendValid, counterValid

      appendValid = .FALSE.
      failureNeed = 0_8
      failureCapacity = 0_8
      IF ( cellIndex.LT.1 .OR. cellIndex.GT.bomMaxCell ) RETURN
      rec = cellHead(cellIndex)
      traversed = 0
      DO WHILE ( rec.NE.0 )
        traversed = traversed+1
        IF ( traversed.GT.nRecord .OR.
     &       rec.LT.1 .OR. rec.GT.nRecord ) RETURN
        CALL BOM_INCREMENT_I8(comparisons,counterValid)
        IF ( .NOT.counterValid ) THEN
          failureNeed = HUGE(comparisons)
          failureCapacity = HUGE(comparisons)
          RETURN
        ENDIF
        IF ( nCandidate.GE.candidateCapacity ) THEN
          failureNeed = INT(nCandidate,8)+1_8
          failureCapacity = candidateCapacity
          RETURN
        ENDIF
        nCandidate = nCandidate+1
        candidateRecord(nCandidate) = rec
        rec = cellNext(rec)
      ENDDO
      appendValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      LOGICAL FUNCTION BOM_CANDIDATE_AFTER(
     I                 recordA, recordB, recordId, recordOwner )

      IMPLICIT NONE
#include "SIZE.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
      INTEGER recordA, recordB
      INTEGER*8 recordId(bomMaxCellRecord)
      INTEGER recordOwner(bomMaxCellRecord)
      INTEGER precedenceA, precedenceB

      BOM_CANDIDATE_AFTER = .FALSE.
      IF ( recordId(recordA).GT.recordId(recordB) ) THEN
        BOM_CANDIDATE_AFTER = .TRUE.
      ELSEIF ( recordId(recordA).EQ.recordId(recordB) ) THEN
        precedenceA = 1
        precedenceB = 1
        IF ( recordOwner(recordA).GT.0 ) precedenceA = 0
        IF ( recordOwner(recordB).GT.0 ) precedenceB = 0
        IF ( precedenceA.GT.precedenceB ) THEN
          BOM_CANDIDATE_AFTER = .TRUE.
        ELSEIF ( precedenceA.EQ.precedenceB .AND.
     &           recordA.GT.recordB ) THEN
          BOM_CANDIDATE_AFTER = .TRUE.
        ENDIF
      ENDIF

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_INCREMENT_I8( value, incrementValid )

      IMPLICIT NONE
      INTEGER*8 value
      LOGICAL incrementValid

      incrementValid = .FALSE.
      IF ( value.GE.HUGE(value) ) RETURN
      value = value+1_8
      incrementValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_FIND_NEIGHBOR_ID(
     I                 targetId, nNeighbor, sortedId,
     O                 found )

      IMPLICIT NONE
#include "SIZE.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
      INTEGER*8 targetId, sortedId(bomMaxNeighbor)
      INTEGER nNeighbor, lo, hi, middle
      LOGICAL found

      found = .FALSE.
      lo = 1
      hi = nNeighbor
      DO WHILE ( lo.LE.hi )
        middle = lo+(hi-lo)/2
        IF ( sortedId(middle).EQ.targetId ) THEN
          found = .TRUE.
          RETURN
        ELSEIF ( sortedId(middle).LT.targetId ) THEN
          lo = middle+1
        ELSE
          hi = middle-1
        ENDIF
      ENDDO

      RETURN
      END
