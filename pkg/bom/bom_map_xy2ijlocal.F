#include "BOM_OPTIONS.h"

C---+----1----2----3----4----5----6----7-|--+----|
CBOP
C !ROUTINE: BOM_MAP_XY2IJLOCAL

C !INTERFACE:
      SUBROUTINE BOM_MAP_XY2IJLOCAL(
     I                 xx, yy, bi, bj,
     O                 xMap, ix, jy, isOwner, hasStencil,
     I                 myThid )

C !DESCRIPTION:
C     Map one native horizontal coordinate onto a specified regular tile.
C     Owner and four-C-point stencil availability are independent results.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL xx, yy
      INTEGER bi, bj, myThid

C !OUTPUT PARAMETERS:
      _RL xMap, ix, jy
      LOGICAL isOwner, hasStencil
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER i, j, i1, j1, xShift
      _RL xTile, tileMid, dist, frac
      LOGICAL isInsideX, foundX, foundY
#endif

      xMap = xx
      ix = -1. _d 0
      jy = -1. _d 0
      isOwner = .FALSE.
      hasStencil = .FALSE.

#ifdef ALLOW_BOM
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) RETURN
      IF ( yy.NE.yy .OR. ABS(yy).GT.HUGE(yy) ) RETURN

      CALL BOM_NORMALIZE_X( xx, xMap, isInsideX, myThid )
      IF ( .NOT.isInsideX ) RETURN
      IF ( yy.LT.bomMapYLo .OR. yy.GE.bomMapYHi ) RETURN

C--   Select the periodic image nearest this tile before searching halos.
      xTile = xMap
      IF ( bomMapPeriodicX ) THEN
        tileMid = halfRL*( xG(1,1,bi,bj)
     &                   + xG(sNx+1,1,bi,bj) )
        xShift = NINT((tileMid-xMap)/bomMapXPeriod)
        xTile = xMap + DFLOAT(xShift)*bomMapXPeriod
      ENDIF

      foundX = .FALSE.
      DO i=1-OLx,sNx+OLx-1
        IF ( .NOT.foundX ) THEN
          IF ( xG(i,1,bi,bj).LE.xTile .AND.
     &         xTile.LT.xG(i+1,1,bi,bj) ) THEN
            dist = xG(i+1,1,bi,bj) - xG(i,1,bi,bj)
            IF ( dist.GT.0. _d 0 ) THEN
              frac = (xTile-xG(i,1,bi,bj))/dist
              ix = DFLOAT(i) + frac - halfRL
              foundX = .TRUE.
            ENDIF
          ENDIF
        ENDIF
      ENDDO

      foundY = .FALSE.
      DO j=1-OLy,sNy+OLy-1
        IF ( .NOT.foundY ) THEN
          IF ( yG(1,j,bi,bj).LE.yy .AND.
     &         yy.LT.yG(1,j+1,bi,bj) ) THEN
            dist = yG(1,j+1,bi,bj) - yG(1,j,bi,bj)
            IF ( dist.GT.0. _d 0 ) THEN
              frac = (yy-yG(1,j,bi,bj))/dist
              jy = DFLOAT(j) + frac - halfRL
              foundY = .TRUE.
            ENDIF
          ENDIF
        ENDIF
      ENDDO
      IF ( .NOT.foundX .OR. .NOT.foundY ) RETURN

      isOwner = ix.GE.halfRL
     &      .AND. ix.LT.halfRL+DFLOAT(sNx)
     &      .AND. jy.GE.halfRL
     &      .AND. jy.LT.halfRL+DFLOAT(sNy)

C--   Fortran INT truncates toward zero; correct it to mathematical floor.
      i1 = INT(ix)
      IF ( DFLOAT(i1).GT.ix ) i1 = i1 - 1
      j1 = INT(jy)
      IF ( DFLOAT(j1).GT.jy ) j1 = j1 - 1
      hasStencil = i1.GE.1-OLx .AND. i1+1.LE.sNx+OLx
     &         .AND. j1.GE.1-OLy .AND. j1+1.LE.sNy+OLy
#endif /* ALLOW_BOM */

      RETURN
      END
