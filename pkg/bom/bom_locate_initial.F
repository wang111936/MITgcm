#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_LOCATE_INITIAL

C !INTERFACE:
      SUBROUTINE BOM_LOCATE_INITIAL(
     I                 xx, yy, bi, bj,
     O                 ix, jy, isLocal, isWet,
     I                 myThid )

C !DESCRIPTION:
C     Locate a MODEL_NATIVE initial coordinate on one local regular tile.
C     This bounded initial-owner locator is not the stage-time mapping
C     interface planned for Phase 1.2.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"

C !INPUT PARAMETERS:
      _RL xx, yy
      INTEGER bi, bj, myThid

C !OUTPUT PARAMETERS:
      _RL ix, jy
      LOGICAL isLocal, isWet
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER i, j, ic, jc
      _RL dist, frac

      ix = -1. _d 0
      jy = -1. _d 0
      isLocal = .FALSE.
      isWet = .FALSE.

      IF ( usingCartesianGrid .OR.
     &     usingSphericalPolarGrid .AND. .NOT.rotateGrid ) THEN
        j = 1
        DO i=1,sNx
          IF ( ix.EQ.-1. _d 0 ) THEN
            IF ( xG(i,j,bi,bj).LE.xx .AND.
     &           xx.LT.xG(i+1,j,bi,bj) ) THEN
              dist = xG(i+1,j,bi,bj) - xG(i,j,bi,bj)
              IF ( dist.GT.0. _d 0 ) THEN
                frac = (xx-xG(i,j,bi,bj))/dist
                ix = DFLOAT(i) + frac - 0.5 _d 0
              ENDIF
            ENDIF
          ENDIF
        ENDDO

        i = 1
        DO j=1,sNy
          IF ( jy.EQ.-1. _d 0 ) THEN
            IF ( yG(i,j,bi,bj).LE.yy .AND.
     &           yy.LT.yG(i,j+1,bi,bj) ) THEN
              dist = yG(i,j+1,bi,bj) - yG(i,j,bi,bj)
              IF ( dist.GT.0. _d 0 ) THEN
                frac = (yy-yG(i,j,bi,bj))/dist
                jy = DFLOAT(j) + frac - 0.5 _d 0
              ENDIF
            ENDIF
          ENDIF
        ENDDO

        isLocal = ix.GE.0.5 _d 0
     &        .AND. ix.LT.0.5 _d 0+DFLOAT(sNx)
     &        .AND. jy.GE.0.5 _d 0
     &        .AND. jy.LT.0.5 _d 0+DFLOAT(sNy)
        IF ( isLocal ) THEN
          ic = NINT(ix)
          jc = NINT(jy)
          isWet = maskC(ic,jc,1,bi,bj).GT.0.
        ENDIF
      ENDIF
#endif

      RETURN
      END
