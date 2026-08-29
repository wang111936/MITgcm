#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_CLASSIFY_BOUNDARY
C !INTERFACE:
      SUBROUTINE BOM_CLASSIFY_BOUNDARY(
     I                 attemptedX, attemptedY, sourceBi, sourceBj,
     O                 boundaryClass, xMap, ix, jy,
     O                 ownerRank, ownerBi, ownerBj,
     O                 failCode, p4FailPhase, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Classify a finite attempted coordinate on the supported regular grid.
C     Only a dry containing C cell or a supported-domain exterior is a
C     terminal result.  Ambiguous mapping, stencil and metric states remain
C     fatal and are never relabelled as beaching.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL attemptedX, attemptedY, xMap, ix, jy
      INTEGER sourceBi, sourceBj
      INTEGER boundaryClass, ownerRank, ownerBi, ownerBj
      INTEGER failCode, p4FailPhase, myThid
      LOGICAL isValid

      INTEGER i1, j1, iCell, jCell, ii, jj, hopCount
      _RL fracI, fracJ, weight, wetWeight
      _RL weights(0:1,0:1), pointDx, pointDy, xOwner, yOwner
      LOGICAL insideX, localOwner, hasStencil, locateValid

      boundaryClass = BOM_BOUNDARY_FATAL
      xMap = attemptedX
      ix = -1. _d 0
      jy = -1. _d 0
      ownerRank = -1
      ownerBi = 0
      ownerBj = 0
      failCode = BOM_FAIL_BOUNDARY_EVENT
      p4FailPhase = BOM_P4_PHASE_BOUNDARY
      isValid = .FALSE.

      IF ( .NOT.IEEE_IS_FINITE(attemptedX) .OR.
     &     .NOT.IEEE_IS_FINITE(attemptedY) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( sourceBi.LT.1 .OR. sourceBi.GT.nSx .OR.
     &     sourceBj.LT.1 .OR. sourceBj.GT.nSy ) THEN
        failCode = BOM_FAIL_OWNER
        RETURN
      ENDIF
      IF ( usingCartesianGrid.EQV.usingSphericalPolarGrid .OR.
     &     usingCurvilinearGrid .OR. usingCylindricalGrid .OR.
     &     rotateGrid .OR. usingPCoords .OR. nTx*nTy.NE.1 ) THEN
        failCode = BOM_FAIL_MAP
        RETURN
      ENDIF
#ifdef ALLOW_EXCH2
      failCode = BOM_FAIL_MAP
      RETURN
#endif
      IF ( .NOT.IEEE_IS_FINITE(bomMapXLo) .OR.
     &     .NOT.IEEE_IS_FINITE(bomMapXHi) .OR.
     &     .NOT.IEEE_IS_FINITE(bomMapYLo) .OR.
     &     .NOT.IEEE_IS_FINITE(bomMapYHi) .OR.
     &     .NOT.IEEE_IS_FINITE(bomMapTol) .OR.
     &     bomMapXHi.LE.bomMapXLo .OR.
     &     bomMapYHi.LE.bomMapYLo .OR.
     &     bomMapTol.LE.0. _d 0 ) THEN
        failCode = BOM_FAIL_MAP
        RETURN
      ENDIF
      IF ( ABS(bomMapXFace(0)-bomMapXLo).GT.bomMapTol .OR.
     &     ABS(bomMapXFace(Nx)-bomMapXHi).GT.bomMapTol .OR.
     &     ABS(bomMapYFace(0)-bomMapYLo).GT.bomMapTol .OR.
     &     ABS(bomMapYFace(Ny)-bomMapYHi).GT.bomMapTol ) THEN
        failCode = BOM_FAIL_MAP
        RETURN
      ENDIF

      CALL BOM_NORMALIZE_X(attemptedX,xMap,insideX,myThid)
      IF ( .NOT.insideX ) THEN
        IF ( .NOT.bomMapPeriodicX .AND.
     &       (attemptedX.LT.bomMapXLo .OR.
     &        attemptedX.GE.bomMapXHi) ) THEN
          boundaryClass = BOM_BOUNDARY_OUTSIDE
          failCode = BOM_FAIL_NONE
          p4FailPhase = BOM_P4_PHASE_NONE
          isValid = .TRUE.
        ELSE
          failCode = BOM_FAIL_MAP
        ENDIF
        RETURN
      ENDIF
      IF ( attemptedY.LT.bomMapYLo .OR.
     &     attemptedY.GE.bomMapYHi ) THEN
        boundaryClass = BOM_BOUNDARY_OUTSIDE
        failCode = BOM_FAIL_NONE
        p4FailPhase = BOM_P4_PHASE_NONE
        isValid = .TRUE.
        RETURN
      ENDIF

      CALL BOM_LOCATE_OWNER(
     I     xMap,attemptedY,sourceBi,sourceBj,
     O     xOwner,yOwner,ownerRank,ownerBi,ownerBj,
     O     hopCount,locateValid,myThid)
      IF ( .NOT.locateValid .OR. ownerRank.LT.0 .OR.
     &     ownerBi.LT.1 .OR. ownerBi.GT.nSx .OR.
     &     ownerBj.LT.1 .OR. ownerBj.GT.nSy ) THEN
        failCode = BOM_FAIL_OWNER
        RETURN
      ENDIF
      IF ( xOwner.NE.xMap .OR. yOwner.NE.attemptedY ) THEN
        failCode = BOM_FAIL_BOUNDARY_EVENT
        RETURN
      ENDIF

C--   The stage source tile supplies the exchanged mask/metric overlap.
      CALL BOM_MAP_XY2IJLOCAL(
     I     xMap,attemptedY,sourceBi,sourceBj,
     O     xOwner,ix,jy,localOwner,hasStencil,myThid)
      IF ( .NOT.hasStencil .OR.
     &     .NOT.IEEE_IS_FINITE(ix) .OR.
     &     .NOT.IEEE_IS_FINITE(jy) ) THEN
        failCode = BOM_FAIL_STENCIL
        RETURN
      ENDIF
      iCell = INT(ix+halfRL)
      IF ( DFLOAT(iCell).GT.ix+halfRL ) iCell=iCell-1
      jCell = INT(jy+halfRL)
      IF ( DFLOAT(jCell).GT.jy+halfRL ) jCell=jCell-1
      IF ( iCell.LT.1-OLx .OR. iCell.GT.sNx+OLx .OR.
     &     jCell.LT.1-OLy .OR. jCell.GT.sNy+OLy ) THEN
        failCode = BOM_FAIL_STENCIL
        RETURN
      ENDIF
      IF ( maskC(iCell,jCell,1,sourceBi,sourceBj).LE.0. ) THEN
        boundaryClass = BOM_BOUNDARY_BEACHED
        failCode = BOM_FAIL_NONE
        p4FailPhase = BOM_P4_PHASE_NONE
        isValid = .TRUE.
        RETURN
      ENDIF

C--   A wet containing cell is accepted only with the same normalized wet
C     support and finite metrics required by the movement interpolation.
      IF ( .NOT.IEEE_IS_FINITE(bomWetWeightMin) .OR.
     &     bomWetWeightMin.LE.0. _d 0 .OR.
     &     bomWetWeightMin.GT.oneRL ) THEN
        failCode = BOM_FAIL_INTERP
        RETURN
      ENDIF
      i1 = INT(ix)
      IF ( DFLOAT(i1).GT.ix ) i1=i1-1
      j1 = INT(jy)
      IF ( DFLOAT(j1).GT.jy ) j1=j1-1
      IF ( i1.LT.1-OLx .OR. i1+1.GT.sNx+OLx .OR.
     &     j1.LT.1-OLy .OR. j1+1.GT.sNy+OLy ) THEN
        failCode = BOM_FAIL_STENCIL
        RETURN
      ENDIF
      fracI = ix-DFLOAT(i1)
      fracJ = jy-DFLOAT(j1)
      weights(0,0) = (oneRL-fracI)*(oneRL-fracJ)
      weights(1,0) = fracI*(oneRL-fracJ)
      weights(0,1) = (oneRL-fracI)*fracJ
      weights(1,1) = fracI*fracJ
      wetWeight = 0. _d 0
      DO jj=0,1
       DO ii=0,1
        weight = weights(ii,jj)
        IF ( maskC(i1+ii,j1+jj,1,sourceBi,sourceBj).GT.0.
     &       .AND. weight.GT.0. _d 0 )
     &       wetWeight=wetWeight+weight
       ENDDO
      ENDDO
      IF ( .NOT.IEEE_IS_FINITE(wetWeight) .OR.
     &     wetWeight.LT.bomWetWeightMin ) THEN
        failCode = BOM_FAIL_INTERP
        RETURN
      ENDIF
      IF ( .NOT.bomMetricReady ) THEN
        failCode = BOM_FAIL_METRIC
        RETURN
      ENDIF
      DO jj=0,1
       DO ii=0,1
        weight = weights(ii,jj)
        IF ( maskC(i1+ii,j1+jj,1,sourceBi,sourceBj).GT.0.
     &       .AND. weight.GT.0. _d 0 ) THEN
          IF ( .NOT.bomMetricValid(
     &         i1+ii,j1+jj,sourceBi,sourceBj) ) THEN
            failCode = BOM_FAIL_METRIC
            RETURN
          ENDIF
          pointDx = recip_dxF(i1+ii,j1+jj,sourceBi,sourceBj)
          pointDy = recip_dyF(i1+ii,j1+jj,sourceBi,sourceBj)
          IF ( .NOT.IEEE_IS_FINITE(pointDx) .OR.
     &         .NOT.IEEE_IS_FINITE(pointDy) .OR.
     &         pointDx.LE.0. _d 0 .OR. pointDy.LE.0. _d 0 ) THEN
            failCode = BOM_FAIL_METRIC
            RETURN
          ENDIF
        ENDIF
       ENDDO
      ENDDO

      boundaryClass = BOM_BOUNDARY_WET
      failCode = BOM_FAIL_NONE
      p4FailPhase = BOM_P4_PHASE_NONE
      isValid = .TRUE.
      RETURN
      END
