#include "BOM_OPTIONS.h"

C---+----1----2----3----4----5----6----7-|--+----|
CBOP
C !ROUTINE: BOM_NORMALIZE_X

C !INTERFACE:
      SUBROUTINE BOM_NORMALIZE_X(
     I                 xx,
     O                 xMap, isInsideX,
     I                 myThid )

C !DESCRIPTION:
C     Return the canonical longitude on a complete 360-degree spherical
C     domain.  Non-periodic native coordinates are never wrapped or clipped.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL xx
      INTEGER myThid

C !OUTPUT PARAMETERS:
      _RL xMap
      LOGICAL isInsideX
CEOP

      xMap = xx
      isInsideX = .FALSE.
#ifdef ALLOW_BOM
      IF ( xx.NE.xx .OR. ABS(xx).GT.HUGE(xx) ) RETURN

      IF ( bomMapPeriodicX ) THEN
        xMap = bomMapXLo + MOD(xx-bomMapXLo,bomMapXPeriod)
        IF ( xMap.LT.bomMapXLo ) xMap = xMap + bomMapXPeriod
        IF ( xMap.GE.bomMapXHi ) xMap = bomMapXLo
        isInsideX = xMap.GE.bomMapXLo .AND. xMap.LT.bomMapXHi
      ELSE
        isInsideX = xMap.GE.bomMapXLo .AND. xMap.LT.bomMapXHi
      ENDIF
#endif

      RETURN
      END
