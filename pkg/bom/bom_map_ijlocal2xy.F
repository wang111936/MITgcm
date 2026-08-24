#include "BOM_OPTIONS.h"

C---+----1----2----3----4----5----6----7-|--+----|
CBOP
C !ROUTINE: BOM_MAP_IJLOCAL2XY

C !INTERFACE:
      SUBROUTINE BOM_MAP_IJLOCAL2XY(
     I                 ix, jy, bi, bj,
     O                 xx, yy, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Reconstruct a native coordinate from a local fractional index.  The
C     required face intervals must be fully represented in the tile overlap.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL ix, jy
      INTEGER bi, bj, myThid

C !OUTPUT PARAMETERS:
      _RL xx, yy
      LOGICAL isValid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER i, j
      _RL ddx, ddy, xNative, xCanonical
      LOGICAL isInsideX
#endif

      xx = 0. _d 0
      yy = 0. _d 0
      isValid = .FALSE.

#ifdef ALLOW_BOM
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) RETURN
      IF ( ix.NE.ix .OR. ABS(ix).GT.HUGE(ix) .OR.
     &     jy.NE.jy .OR. ABS(jy).GT.HUGE(jy) ) RETURN
      IF ( ix.LT.DFLOAT(1-OLx)-halfRL .OR.
     &     ix.GT.DFLOAT(sNx+OLx-1)+halfRL .OR.
     &     jy.LT.DFLOAT(1-OLy)-halfRL .OR.
     &     jy.GT.DFLOAT(sNy+OLy-1)+halfRL ) RETURN

      i = NINT(ix)
      j = NINT(jy)
      IF ( i.LT.1-OLx .OR. i+1.GT.sNx+OLx .OR.
     &     j.LT.1-OLy .OR. j+1.GT.sNy+OLy ) RETURN

      ddx = halfRL + ix - DFLOAT(i)
      ddy = halfRL + jy - DFLOAT(j)
      xNative = xG(i,j,bi,bj)
     &        + ddx*(xG(i+1,j,bi,bj)-xG(i,j,bi,bj))
      yy = yG(i,j,bi,bj)
     &   + ddy*(yG(i,j+1,bi,bj)-yG(i,j,bi,bj))
      IF ( xNative.NE.xNative .OR.
     &     ABS(xNative).GT.HUGE(xNative) .OR.
     &     yy.NE.yy .OR. ABS(yy).GT.HUGE(yy) ) RETURN

      IF ( bomMapPeriodicX ) THEN
        CALL BOM_NORMALIZE_X(
     &       xNative, xCanonical, isInsideX, myThid )
        IF ( .NOT.isInsideX ) RETURN
        xx = xCanonical
      ELSE
        xx = xNative
      ENDIF
      isValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END
