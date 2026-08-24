#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_RHS_LEEWAY_HALO

C !INTERFACE:
      SUBROUTINE BOM_RHS_LEEWAY_HALO(
     I                 xx, yy, dtGuard, bi, bj,
     O                 rhsX, rhsY, ix, jy,
     O                 oceanEast, oceanNorth,
     O                 windEast, windNorth,
     O                 driftEast, driftNorth,
     O                 wetWeight, stageCFL,
     O                 isOwner, isValid, failCode,
     I                 myThid )

C !DESCRIPTION:
C     Evaluate the P1.4 Leeway right-hand side on an owner tile or its
C     exchanged overlap.  The caller separately enforces strict K1 owner
C     and post-substep migration.  This routine never commits state.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL xx, yy, dtGuard
      INTEGER bi, bj, myThid

C !OUTPUT PARAMETERS:
      _RL rhsX, rhsY, ix, jy
      _RL oceanEast, oceanNorth
      _RL windEast, windNorth
      _RL driftEast, driftNorth
      _RL wetWeight, stageCFL
      LOGICAL isOwner, isValid
      INTEGER failCode
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER iC, jC
      _RL xMap, wetOcean, wetWind
      _RL windTermEast, windTermNorth
      _RL cosLat, cosMin, denomX, denomY
      _RL metricX, metricY, cflX, cflY
      LOGICAL isInsideX, hasStencil
      LOGICAL oceanValid, windValid
#endif

C--   Deterministic diagnostics support first-failure reporting by callers.
      rhsX = 0. _d 0
      rhsY = 0. _d 0
      ix = -1. _d 0
      jy = -1. _d 0
      oceanEast = 0. _d 0
      oceanNorth = 0. _d 0
      windEast = 0. _d 0
      windNorth = 0. _d 0
      driftEast = 0. _d 0
      driftNorth = 0. _d 0
      wetWeight = 0. _d 0
      stageCFL = 0. _d 0
      isOwner = .FALSE.
      isValid = .FALSE.
      failCode = BOM_FAIL_NONE

#ifdef ALLOW_BOM
C--   Inputs precede mapping in the frozen failure priority.
      IF ( .NOT.IEEE_IS_FINITE(xx) .OR.
     &     .NOT.IEEE_IS_FINITE(yy) .OR.
     &     .NOT.IEEE_IS_FINITE(dtGuard) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( dtGuard.LT.0. _d 0 ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) THEN
        failCode = BOM_FAIL_MAP
        RETURN
      ENDIF

C--   Separate global-map failure from departure from this owner tile.
      CALL BOM_NORMALIZE_X( xx, xMap, isInsideX, myThid )
      IF ( .NOT.isInsideX .OR.
     &     yy.LT.bomMapYLo .OR. yy.GE.bomMapYHi ) THEN
        failCode = BOM_FAIL_MAP
        RETURN
      ENDIF
      CALL BOM_MAP_XY2IJLOCAL(
     I     xx, yy, bi, bj,
     O     xMap, ix, jy, isOwner, hasStencil,
     I     myThid )
      IF ( .NOT.IEEE_IS_FINITE(ix) .OR.
     &     .NOT.IEEE_IS_FINITE(jy) ) THEN
        failCode = BOM_FAIL_MAP
        RETURN
      ENDIF
      IF ( .NOT.hasStencil ) THEN
        failCode = BOM_FAIL_STENCIL
        RETURN
      ENDIF

C--   Both pairs use the same C mask and wet-weight threshold.
      CALL BOM_INTERP_WET_PAIR(
     I     ix, jy, bi, bj, bomGridVEast, bomGridVNorth,
     O     oceanEast, oceanNorth, wetOcean, oceanValid,
     I     myThid )
      wetWeight = wetOcean
      IF ( .NOT.oceanValid ) THEN
        failCode = BOM_FAIL_INTERP
        RETURN
      ENDIF
      CALL BOM_INTERP_WET_PAIR(
     I     ix, jy, bi, bj, bomGridWindEast, bomGridWindNorth,
     O     windEast, windNorth, wetWind, windValid,
     I     myThid )
      IF ( .NOT.windValid .OR. wetWind.NE.wetOcean ) THEN
        failCode = BOM_FAIL_INTERP
        RETURN
      ENDIF

C--   Startup validates these controls; stages recheck before arithmetic.
      IF ( .NOT.IEEE_IS_FINITE(bomLeewayWindCoeff) .OR.
     &     .NOT.IEEE_IS_FINITE(bomAdvCFL) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( bomLeewayWindCoeff.LT.0. _d 0 .OR.
     &     bomLeewayWindCoeff.GT.0.1 _d 0 .OR.
     &     bomAdvCFL.LE.0. _d 0 ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      windTermEast = bomLeewayWindCoeff*windEast
      windTermNorth = bomLeewayWindCoeff*windNorth
      IF ( .NOT.IEEE_IS_FINITE(windTermEast) .OR.
     &     .NOT.IEEE_IS_FINITE(windTermNorth) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
C--   Guard the two additions explicitly for exception-trapping builds.
      IF ( windTermEast.GT.0. _d 0 ) THEN
        IF ( oceanEast.GT.HUGE(oceanEast)-windTermEast ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
      ELSEIF ( windTermEast.LT.0. _d 0 ) THEN
        IF ( oceanEast.LT.-HUGE(oceanEast)-windTermEast ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
      ENDIF
      IF ( windTermNorth.GT.0. _d 0 ) THEN
        IF ( oceanNorth.GT.HUGE(oceanNorth)-windTermNorth ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
      ELSEIF ( windTermNorth.LT.0. _d 0 ) THEN
        IF ( oceanNorth.LT.-HUGE(oceanNorth)-windTermNorth ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
      ENDIF
      driftEast = oceanEast + windTermEast
      driftNorth = oceanNorth + windTermNorth
      IF ( .NOT.IEEE_IS_FINITE(driftEast) .OR.
     &     .NOT.IEEE_IS_FINITE(driftNorth) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF

C--   Convert SI velocity to the model's native horizontal coordinate rate.
      IF ( usingCartesianGrid .AND.
     &     .NOT.usingSphericalPolarGrid ) THEN
        rhsX = driftEast
        rhsY = driftNorth
      ELSEIF ( usingSphericalPolarGrid .AND.
     &         .NOT.usingCartesianGrid ) THEN
        IF ( .NOT.IEEE_IS_FINITE(rSphere) ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
        IF ( rSphere.LE.0. _d 0 ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
        cosLat = COS(deg2rad*yy)
        cosMin = SQRT(EPSILON(oneRL))
        IF ( .NOT.IEEE_IS_FINITE(cosLat) ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
        IF ( ABS(cosLat).LT.cosMin ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
        denomY = rSphere*deg2rad
        denomX = denomY*cosLat
        IF ( .NOT.IEEE_IS_FINITE(denomX) .OR.
     &       .NOT.IEEE_IS_FINITE(denomY) ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
        IF ( ABS(denomX).LE.0. _d 0 .OR.
     &       denomY.LE.0. _d 0 ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
        IF ( ABS(denomX).LT.oneRL ) THEN
          IF ( ABS(driftEast).GT.HUGE(rhsX)*ABS(denomX) ) THEN
            failCode = BOM_FAIL_NONFINITE
            RETURN
          ENDIF
        ENDIF
        IF ( denomY.LT.oneRL ) THEN
          IF ( ABS(driftNorth).GT.HUGE(rhsY)*denomY ) THEN
            failCode = BOM_FAIL_NONFINITE
            RETURN
          ENDIF
        ENDIF
        rhsX = driftEast/denomX
        rhsY = driftNorth/denomY
      ELSE
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(rhsX) .OR.
     &     .NOT.IEEE_IS_FINITE(rhsY) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF

C--   Mathematical floor fixes exact half-cell ties to the east/north C point.
      iC = INT(ix+halfRL)
      IF ( DFLOAT(iC).GT.ix+halfRL ) iC = iC - 1
      jC = INT(jy+halfRL)
      IF ( DFLOAT(jC).GT.jy+halfRL ) jC = jC - 1
      IF ( iC.LT.1-OLx .OR. iC.GT.sNx+OLx .OR.
     &     jC.LT.1-OLy .OR. jC.GT.sNy+OLy ) THEN
        failCode = BOM_FAIL_STENCIL
        RETURN
      ENDIF
      metricX = recip_dxF(iC,jC,bi,bj)
      metricY = recip_dyF(iC,jC,bi,bj)
      IF ( .NOT.IEEE_IS_FINITE(metricX) .OR.
     &     .NOT.IEEE_IS_FINITE(metricY) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( metricX.LE.0. _d 0 .OR. metricY.LE.0. _d 0 ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF

C--   Avoid overflow while retaining CFL as the final failure category.
      IF ( ABS(driftEast).GT.oneRL ) THEN
        IF ( metricX.GT.HUGE(cflX)/ABS(driftEast) ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
      ENDIF
      IF ( ABS(driftNorth).GT.oneRL ) THEN
        IF ( metricY.GT.HUGE(cflY)/ABS(driftNorth) ) THEN
          failCode = BOM_FAIL_NONFINITE
          RETURN
        ENDIF
      ENDIF
      cflX = ABS(driftEast)*metricX
      cflY = ABS(driftNorth)*metricY
      IF ( .NOT.IEEE_IS_FINITE(cflX) .OR.
     &     .NOT.IEEE_IS_FINITE(cflY) ) THEN
        failCode = BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( dtGuard.GT.oneRL ) THEN
        IF ( cflX.GT.HUGE(stageCFL)/dtGuard .OR.
     &       cflY.GT.HUGE(stageCFL)/dtGuard ) THEN
          stageCFL = HUGE(stageCFL)
          failCode = BOM_FAIL_CFL
          RETURN
        ENDIF
      ENDIF
      stageCFL = dtGuard*MAX(cflX,cflY)
      IF ( .NOT.IEEE_IS_FINITE(stageCFL) ) THEN
        failCode = BOM_FAIL_CFL
        RETURN
      ENDIF
      IF ( stageCFL.GT.bomAdvCFL ) THEN
        failCode = BOM_FAIL_CFL
        RETURN
      ENDIF

      isValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END
