#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_CELL_GEOMETRY
C !INTERFACE:
      SUBROUTINE BOM_INIT_CELL_GEOMETRY(
     I                 cartesianGrid, sphericalGrid, periodicX,
     I                 xMin, xMax, yMin, yMax, xPeriod,
     I                 sphereRadius, neighborCutoff, cellCapacity,
     O                 nCellX, nCellY, nCell,
     O                 cellWidthX, cellWidthY, cellReachY,
     O                 rowReachX, failureNeed, failureCapacity,
     O                 failCode, p3FailPhase, geometryValid )

C !DESCRIPTION:
C     Build one bounded half-open regular cell plan.  Cell dimensions are no
C     smaller than the cutoff at the Cartesian/equatorial metric unless the
C     model-grid dimension is the tighter compile-time bound.  Spherical rows
C     receive a conservative X reach from the most poleward latitude that a
C     within-cutoff candidate row can contain.  Plan outputs publish only
C     after the complete plan validates.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"

      LOGICAL cartesianGrid, sphericalGrid, periodicX
      _RL xMin, xMax, yMin, yMax, xPeriod
      _RL sphereRadius, neighborCutoff
      INTEGER cellCapacity
      INTEGER nCellX, nCellY, nCell, cellReachY
      _RL cellWidthX, cellWidthY
      INTEGER rowReachX(bomMaxCell)
      INTEGER*8 failureNeed, failureCapacity
      INTEGER failCode, p3FailPhase
      LOGICAL geometryValid

      INTEGER nXWork, nYWork, nWork, reachYWork
      INTEGER row, rowLo, rowHi, reachWork
      INTEGER rowReachWork(bomMaxCell)
      INTEGER*8 cellNeed8
      _RL xSpan, ySpan, xPhysicalSpan, yPhysicalSpan
      _RL xWidthWork, yWidthWork, metricScale
      _RL rowSouth, rowNorth, maxAbsLatitude, minCosine
      _RL rowOffset, xMetricScale, xMetricWidth
      _RL periodDifference, periodTolerance
      LOGICAL calcValid, termValid, reachValid
CEOP

      geometryValid = .FALSE.
      failCode = BOM_FAIL_NEIGHBOR_CONFIG
      p3FailPhase = BOM_P3_PHASE_CELL
      failureNeed = 0_8
      failureCapacity = 0_8
      DO row=1,bomMaxCell
        rowReachWork(row) = 0
      ENDDO

      IF ( cartesianGrid.EQV.sphericalGrid ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(xMin) .OR.
     &     .NOT.IEEE_IS_FINITE(xMax) .OR.
     &     .NOT.IEEE_IS_FINITE(yMin) .OR.
     &     .NOT.IEEE_IS_FINITE(yMax) .OR.
     &     .NOT.IEEE_IS_FINITE(neighborCutoff) ) RETURN
      IF ( xMax.LE.xMin .OR. yMax.LE.yMin .OR.
     &     neighborCutoff.LE.0. _d 0 ) RETURN
      IF ( cellCapacity.LT.1 .OR.
     &     cellCapacity.GT.bomMaxCell ) THEN
        failureNeed = MAX(1,cellCapacity)
        failureCapacity = bomMaxCell
        failCode = BOM_FAIL_CELL_CAPACITY
        RETURN
      ENDIF

      CALL BOM_SAFE_ADD_RL(xMax,-xMin,xSpan,calcValid)
      IF ( .NOT.calcValid ) RETURN
      CALL BOM_SAFE_ADD_RL(yMax,-yMin,ySpan,calcValid)
      IF ( .NOT.calcValid ) RETURN
      IF ( xSpan.LE.0. _d 0 .OR. ySpan.LE.0. _d 0 ) RETURN

      IF ( periodicX ) THEN
        IF ( .NOT.IEEE_IS_FINITE(xPeriod) .OR.
     &       xPeriod.LE.0. _d 0 ) RETURN
        periodDifference = ABS(xSpan-xPeriod)
        periodTolerance = 128. _d 0*EPSILON(oneRL)
     &       *MAX(oneRL,ABS(xSpan),ABS(xPeriod))
        IF ( .NOT.IEEE_IS_FINITE(periodTolerance) .OR.
     &       periodDifference.GT.periodTolerance ) RETURN
      ENDIF

      IF ( cartesianGrid ) THEN
        xPhysicalSpan = xSpan
        yPhysicalSpan = ySpan
        metricScale = oneRL
      ELSE
        IF ( .NOT.IEEE_IS_FINITE(sphereRadius) .OR.
     &       sphereRadius.LE.0. _d 0 ) RETURN
        IF ( yMin.LT.-90. _d 0 .OR. yMax.GT.90. _d 0 ) RETURN
        CALL BOM_SAFE_MULT_RL(
     I       sphereRadius,deg2rad,
     O       metricScale,calcValid)
        IF ( .NOT.calcValid .OR. metricScale.LE.0. _d 0 ) RETURN
        CALL BOM_SAFE_MULT_RL(
     I       metricScale,xSpan,
     O       xPhysicalSpan,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_MULT_RL(
     I       metricScale,ySpan,
     O       yPhysicalSpan,calcValid)
        IF ( .NOT.calcValid ) RETURN
      ENDIF

      CALL BOM_CELL_AXIS_COUNT(
     I     xPhysicalSpan,neighborCutoff,Nx,
     O     nXWork,calcValid)
      IF ( .NOT.calcValid ) RETURN
      CALL BOM_CELL_AXIS_COUNT(
     I     yPhysicalSpan,neighborCutoff,Ny,
     O     nYWork,calcValid)
      IF ( .NOT.calcValid ) RETURN

      cellNeed8 = INT(nXWork,8)*INT(nYWork,8)
      IF ( cellNeed8.GT.INT(cellCapacity,8) ) THEN
        failureNeed = cellNeed8
        failureCapacity = INT(cellCapacity,8)
        failCode = BOM_FAIL_CELL_CAPACITY
        RETURN
      ENDIF
      nWork = nXWork*nYWork
      CALL BOM_SAFE_DIV_RL(
     I     xSpan,DFLOAT(nXWork),
     O     xWidthWork,calcValid)
      IF ( .NOT.calcValid .OR. xWidthWork.LE.0. _d 0 ) RETURN
      CALL BOM_SAFE_DIV_RL(
     I     ySpan,DFLOAT(nYWork),
     O     yWidthWork,calcValid)
      IF ( .NOT.calcValid .OR. yWidthWork.LE.0. _d 0 ) RETURN

      IF ( cartesianGrid ) THEN
        CALL BOM_CELL_REACH(
     I       neighborCutoff,yWidthWork,nYWork,
     O       reachYWork,reachValid)
        IF ( .NOT.reachValid ) RETURN
        CALL BOM_CELL_REACH(
     I       neighborCutoff,xWidthWork,nXWork,
     O       reachWork,reachValid)
        IF ( .NOT.reachValid ) RETURN
        DO row=1,nYWork
          rowReachWork(row) = reachWork
        ENDDO
      ELSE
        CALL BOM_SAFE_MULT_RL(
     I       metricScale,yWidthWork,
     O       rowSouth,calcValid)
        IF ( .NOT.calcValid .OR. rowSouth.LE.0. _d 0 ) RETURN
        CALL BOM_CELL_REACH(
     I       neighborCutoff,rowSouth,nYWork,
     O       reachYWork,reachValid)
        IF ( .NOT.reachValid ) RETURN

        DO row=1,nYWork
          rowLo = MAX(0,row-1-reachYWork)
          rowHi = MIN(nYWork,row+reachYWork)
          CALL BOM_SAFE_MULT_RL(
     I         DFLOAT(rowLo),yWidthWork,
     O         rowOffset,calcValid)
          IF ( .NOT.calcValid ) RETURN
          CALL BOM_SAFE_ADD_RL(
     I         yMin,rowOffset,
     O         rowSouth,termValid)
          IF ( .NOT.termValid ) RETURN
          CALL BOM_SAFE_MULT_RL(
     I         DFLOAT(rowHi),yWidthWork,
     O         rowOffset,calcValid)
          IF ( .NOT.calcValid ) RETURN
          CALL BOM_SAFE_ADD_RL(
     I         yMin,rowOffset,
     O         rowNorth,termValid)
          IF ( .NOT.termValid ) RETURN
          maxAbsLatitude = MAX(ABS(rowSouth),ABS(rowNorth))
          IF ( maxAbsLatitude.GT.90. _d 0 ) RETURN
          minCosine = ABS(COS(deg2rad*maxAbsLatitude))
          IF ( .NOT.IEEE_IS_FINITE(minCosine) .OR.
     &         minCosine.LT.SQRT(EPSILON(oneRL)) ) RETURN
          CALL BOM_SAFE_MULT_RL(
     I         metricScale,minCosine,
     O         xMetricScale,calcValid)
          IF ( .NOT.calcValid ) RETURN
          CALL BOM_SAFE_MULT_RL(
     I         xMetricScale,xWidthWork,
     O         xMetricWidth,calcValid)
          IF ( .NOT.calcValid .OR.
     &         xMetricWidth.LE.0. _d 0 ) RETURN
          CALL BOM_CELL_REACH(
     I         neighborCutoff,xMetricWidth,nXWork,
     O         reachWork,reachValid)
          IF ( .NOT.reachValid ) RETURN
          rowReachWork(row) = reachWork
        ENDDO
      ENDIF

C--   Publish the complete plan only after every row validates.
      nCellX = nXWork
      nCellY = nYWork
      nCell = nWork
      cellWidthX = xWidthWork
      cellWidthY = yWidthWork
      cellReachY = reachYWork
      DO row=1,bomMaxCell
        rowReachX(row) = rowReachWork(row)
      ENDDO
      failCode = BOM_FAIL_NONE
      p3FailPhase = BOM_P3_PHASE_NONE
      geometryValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_CELL_AXIS_COUNT(
     I                 physicalSpan, cutoff, maxAxis,
     O                 axisCount, countValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL physicalSpan, cutoff, perCell, ratio
      INTEGER maxAxis, axisCount
      LOGICAL countValid

      axisCount = 0
      countValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(physicalSpan) .OR.
     &     .NOT.IEEE_IS_FINITE(cutoff) ) RETURN
      IF ( physicalSpan.LE.0. _d 0 .OR. cutoff.LE.0. _d 0 .OR.
     &     maxAxis.LT.1 ) RETURN
      perCell = physicalSpan/DFLOAT(maxAxis)
      IF ( .NOT.IEEE_IS_FINITE(perCell) .OR.
     &     perCell.LE.0. _d 0 ) RETURN
      IF ( perCell.GE.cutoff ) THEN
        axisCount = maxAxis
      ELSE
        ratio = physicalSpan/cutoff
        IF ( .NOT.IEEE_IS_FINITE(ratio) .OR.
     &       ratio.LE.0. _d 0 ) RETURN
        axisCount = MAX(1,INT(ratio))
      ENDIF
      IF ( axisCount.LT.1 .OR. axisCount.GT.maxAxis ) RETURN
      countValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_CELL_REACH(
     I                 cutoff, physicalCellWidth, maxReach,
     O                 reach, reachValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL cutoff, physicalCellWidth, ratio
      INTEGER maxReach, reach
      LOGICAL reachValid

      reach = 0
      reachValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(cutoff) .OR.
     &     .NOT.IEEE_IS_FINITE(physicalCellWidth) ) RETURN
      IF ( cutoff.LE.0. _d 0 .OR. physicalCellWidth.LE.0. _d 0
     &     .OR. maxReach.LT.1 ) RETURN
      ratio = cutoff/physicalCellWidth
      IF ( .NOT.IEEE_IS_FINITE(ratio) .OR. ratio.LE.0. _d 0 ) RETURN
      IF ( ratio.GE.DFLOAT(maxReach) ) THEN
        reach = maxReach
      ELSE
        reach = MAX(1,INT(ratio))
        IF ( DFLOAT(reach)*physicalCellWidth.LT.cutoff )
     &       reach = reach + 1
        reach = MIN(reach,maxReach)
      ENDIF
      reachValid = reach.GE.1 .AND. reach.LE.maxReach

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_CELL_INDEX(
     I                 xx, yy, periodicX,
     I                 xMin, xMax, yMin, yMax, xPeriod,
     I                 nCellX, nCellY, nCell,
     I                 cellWidthX, cellWidthY,
     O                 cellX, cellY, cellIndex,
     O                 failCode, indexValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      _RL xx, yy, xMin, xMax, yMin, yMax, xPeriod
      _RL cellWidthX, cellWidthY
      INTEGER nCellX, nCellY, nCell
      INTEGER cellX, cellY, cellIndex, failCode
      LOGICAL periodicX, indexValid
      _RL xMap, xResid, xLoResid, xDelta, xRatio, yRatio
      INTEGER xWork, yWork, indexWork

      indexValid = .FALSE.
      failCode = BOM_FAIL_PAIR_GEOMETRY
      IF ( .NOT.IEEE_IS_FINITE(xx) .OR.
     &     .NOT.IEEE_IS_FINITE(yy) .OR.
     &     .NOT.IEEE_IS_FINITE(xMin) .OR.
     &     .NOT.IEEE_IS_FINITE(xMax) .OR.
     &     .NOT.IEEE_IS_FINITE(yMin) .OR.
     &     .NOT.IEEE_IS_FINITE(yMax) .OR.
     &     .NOT.IEEE_IS_FINITE(cellWidthX) .OR.
     &     .NOT.IEEE_IS_FINITE(cellWidthY) ) RETURN
      IF ( nCellX.LT.1 .OR. nCellY.LT.1 .OR.
     &     nCell.NE.nCellX*nCellY .OR.
     &     cellWidthX.LE.0. _d 0 .OR.
     &     cellWidthY.LE.0. _d 0 ) RETURN
      IF ( yy.LT.yMin .OR. yy.GE.yMax ) RETURN

      xMap = xx
      IF ( periodicX ) THEN
        IF ( .NOT.IEEE_IS_FINITE(xPeriod) .OR.
     &       xPeriod.LE.0. _d 0 ) RETURN
        xResid = MOD(xx,xPeriod)
        xLoResid = MOD(xMin,xPeriod)
        IF ( .NOT.IEEE_IS_FINITE(xResid) .OR.
     &       .NOT.IEEE_IS_FINITE(xLoResid) ) RETURN
        xDelta = xResid-xLoResid
        IF ( .NOT.IEEE_IS_FINITE(xDelta) ) RETURN
        xMap = xMin+xDelta
        IF ( .NOT.IEEE_IS_FINITE(xMap) ) RETURN
        IF ( xMap.LT.xMin ) xMap = xMap+xPeriod
        IF ( xMap.GE.xMax ) xMap = xMin
      ENDIF
      IF ( xMap.LT.xMin .OR. xMap.GE.xMax ) RETURN

      xRatio = (xMap-xMin)/cellWidthX
      yRatio = (yy-yMin)/cellWidthY
      IF ( .NOT.IEEE_IS_FINITE(xRatio) .OR.
     &     .NOT.IEEE_IS_FINITE(yRatio) ) RETURN
      xWork = INT(xRatio)+1
      yWork = INT(yRatio)+1
      IF ( xWork.LT.1 .OR. xWork.GT.nCellX .OR.
     &     yWork.LT.1 .OR. yWork.GT.nCellY ) RETURN
      indexWork = (yWork-1)*nCellX+xWork
      IF ( indexWork.LT.1 .OR. indexWork.GT.nCell ) RETURN

      cellX = xWork
      cellY = yWork
      cellIndex = indexWork
      failCode = BOM_FAIL_NONE
      indexValid = .TRUE.

      RETURN
      END
