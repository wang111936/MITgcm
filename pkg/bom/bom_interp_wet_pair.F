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
      IF ( ix.NE.ix .OR. ABS(ix).GT.HUGE(ix)
     &     .OR. jy.NE.jy .OR. ABS(jy).GT.HUGE(jy) ) RETURN
      IF ( bomWetWeightMin.NE.bomWetWeightMin
     &     .OR. ABS(bomWetWeightMin).GT.HUGE(bomWetWeightMin)
     &     .OR. bomWetWeightMin.LE.0. _d 0
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
      DO jj=0,1
       DO ii=0,1
        eastPoint = fieldEast(i1+ii,j1+jj,1,bi,bj)
        northPoint = fieldNorth(i1+ii,j1+jj,1,bi,bj)
        invalidField = invalidField
     &       .OR. eastPoint.NE.eastPoint
     &       .OR. ABS(eastPoint).GT.HUGE(eastPoint)
     &       .OR. northPoint.NE.northPoint
     &       .OR. ABS(northPoint).GT.HUGE(northPoint)
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
      IF ( wetWeight.NE.wetWeight
     &     .OR. ABS(wetWeight).GT.HUGE(wetWeight)
     &     .OR. wetWeight.LT.bomWetWeightMin ) RETURN

      DO jj=0,1
       DO ii=0,1
        IF ( maskC(i1+ii,j1+jj,1,bi,bj).GT.0. ) THEN
          weight = weights(ii,jj)/wetWeight
          valueEast = valueEast
     &              + weight*fieldEast(i1+ii,j1+jj,1,bi,bj)
          valueNorth = valueNorth
     &               + weight*fieldNorth(i1+ii,j1+jj,1,bi,bj)
        ENDIF
       ENDDO
      ENDDO
      IF ( valueEast.NE.valueEast
     &     .OR. ABS(valueEast).GT.HUGE(valueEast)
     &     .OR. valueNorth.NE.valueNorth
     &     .OR. ABS(valueNorth).GT.HUGE(valueNorth) ) THEN
        valueEast = 0. _d 0
        valueNorth = 0. _d 0
        RETURN
      ENDIF
      isValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END
