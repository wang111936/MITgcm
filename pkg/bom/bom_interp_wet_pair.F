#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INTERP_WET_PAIR

C !INTERFACE:
      SUBROUTINE BOM_INTERP_WET_PAIR(
     I                 ix, jy, bi, bj,
     I                 fieldEast, fieldNorth,
     O                 valueEast, valueNorth, wetWeight, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Interpolate one east/north C-point field pair with common wet
C     weights.  Invalid input returns zeros without changing state.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL ix, jy
      INTEGER bi, bj, myThid
      _RL fieldEast(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL fieldNorth(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)

C !OUTPUT PARAMETERS:
      _RL valueEast, valueNorth, wetWeight
      LOGICAL isValid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER i1, j1, ii, jj
      _RL fracI, fracJ, weight
      _RL weights(0:1,0:1)
      _RL eastPoint, northPoint
      _RL eastScale, northScale, eastScaled, northScaled
      LOGICAL invalidField
#endif

      valueEast = 0. _d 0
      valueNorth = 0. _d 0
      wetWeight = 0. _d 0
      isValid = .FALSE.

#ifdef ALLOW_BOM
      IF ( .NOT.bomFieldsReady ) RETURN
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) RETURN
      IF ( bi.LT.myBxLo(myThid) .OR. bi.GT.myBxHi(myThid)
     &     .OR. bj.LT.myByLo(myThid)
     &     .OR. bj.GT.myByHi(myThid) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(ix) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(jy) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(bomWetWeightMin) ) RETURN
      IF ( bomWetWeightMin.LE.0. _d 0
     &     .OR. bomWetWeightMin.GT.1. _d 0 ) RETURN
      IF ( ix.LT.DFLOAT(1-OLx) .OR. ix.GE.DFLOAT(sNx+OLx)
     &     .OR. jy.LT.DFLOAT(1-OLy)
     &     .OR. jy.GE.DFLOAT(sNy+OLy) ) RETURN

C--   Correct Fortran truncation to mathematical floor in low overlaps.
      i1 = INT(ix)
      IF ( DFLOAT(i1).GT.ix ) i1 = i1 - 1
      j1 = INT(jy)
      IF ( DFLOAT(j1).GT.jy ) j1 = j1 - 1
      IF ( i1.LT.1-OLx .OR. i1+1.GT.sNx+OLx
     &     .OR. j1.LT.1-OLy .OR. j1+1.GT.sNy+OLy ) RETURN

      fracI = ix - DFLOAT(i1)
      fracJ = jy - DFLOAT(j1)
      weights(0,0) = (oneRL-fracI)*(oneRL-fracJ)
      weights(1,0) = fracI*(oneRL-fracJ)
      weights(0,1) = (oneRL-fracI)*fracJ
      weights(1,1) = fracI*fracJ

C--   Reject corruption anywhere in the requested pair stencil.
      invalidField = .FALSE.
      eastScale = 0. _d 0
      northScale = 0. _d 0
      DO jj=0,1
       DO ii=0,1
        eastPoint = fieldEast(i1+ii,j1+jj,1,bi,bj)
        northPoint = fieldNorth(i1+ii,j1+jj,1,bi,bj)
        IF ( .NOT.IEEE_IS_FINITE(eastPoint) .OR.
     &       .NOT.IEEE_IS_FINITE(northPoint) ) THEN
          invalidField = .TRUE.
        ELSE
          eastScale = MAX(eastScale,ABS(eastPoint))
          northScale = MAX(northScale,ABS(northPoint))
        ENDIF
       ENDDO
      ENDDO
      IF ( invalidField ) RETURN

C--   Form one wet weight and reuse each normalized weight for the pair.
      DO jj=0,1
       DO ii=0,1
        IF ( maskC(i1+ii,j1+jj,1,bi,bj).GT.0. ) THEN
          wetWeight = wetWeight + weights(ii,jj)
        ENDIF
       ENDDO
      ENDDO
      IF ( .NOT.IEEE_IS_FINITE(wetWeight) ) RETURN
      IF ( wetWeight.LT.bomWetWeightMin ) RETURN

C--   Scale the convex sums so finite extreme inputs cannot overflow an
C     intermediate addition under floating-point exception trapping.
      eastScaled = 0. _d 0
      northScaled = 0. _d 0
      DO jj=0,1
       DO ii=0,1
        IF ( maskC(i1+ii,j1+jj,1,bi,bj).GT.0. ) THEN
          weight = weights(ii,jj)/wetWeight
          IF ( eastScale.GT.0. _d 0 ) THEN
            eastScaled = eastScaled + weight
     &           *(fieldEast(i1+ii,j1+jj,1,bi,bj)/eastScale)
          ENDIF
          IF ( northScale.GT.0. _d 0 ) THEN
            northScaled = northScaled + weight
     &           *(fieldNorth(i1+ii,j1+jj,1,bi,bj)/northScale)
          ENDIF
        ENDIF
       ENDDO
      ENDDO
      eastScaled = MAX(-oneRL,MIN(oneRL,eastScaled))
      northScaled = MAX(-oneRL,MIN(oneRL,northScaled))
      valueEast = eastScale*eastScaled
      valueNorth = northScale*northScaled
      IF ( .NOT.IEEE_IS_FINITE(valueEast) .OR.
     &     .NOT.IEEE_IS_FINITE(valueNorth) ) THEN
        valueEast = 0. _d 0
        valueNorth = 0. _d 0
        RETURN
      ENDIF
      isValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END
