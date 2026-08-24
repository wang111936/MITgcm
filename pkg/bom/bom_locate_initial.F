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
C     Preserve the P1.1 initial-owner interface while delegating
C     regular-grid coordinates to the Phase-1.2 mapping implementation.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
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
      INTEGER ic, jc
      _RL xMap
      LOGICAL hasStencil

      ix = -1. _d 0
      jy = -1. _d 0
      isLocal = .FALSE.
      isWet = .FALSE.

      CALL BOM_MAP_XY2IJLOCAL(
     I     xx, yy, bi, bj,
     O     xMap, ix, jy, isLocal, hasStencil,
     I     myThid )

C--   Initial acceptance remains the P1.1 owner-center wet test.
C     The four-point stage stencil is not an initial-file requirement.
      IF ( isLocal ) THEN
        ic = NINT(ix)
        jc = NINT(jy)
        isWet = maskC(ic,jc,1,bi,bj).GT.0.
      ENDIF
#endif

      RETURN
      END
