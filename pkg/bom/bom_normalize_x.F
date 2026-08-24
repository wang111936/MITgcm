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

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      _RL xResid, xLoResid, xDelta
#endif

      xMap = xx
      isInsideX = .FALSE.
#ifdef ALLOW_BOM
      IF ( xx.NE.xx .OR. ABS(xx).GT.HUGE(xx) ) RETURN

      IF ( bomMapPeriodicX ) THEN
        IF ( bomMapXPeriod.NE.bomMapXPeriod .OR.
     &       ABS(bomMapXPeriod).GT.HUGE(bomMapXPeriod) .OR.
     &       bomMapXPeriod.LE.0. _d 0 ) RETURN
C--     Reduce the input and origin separately so their difference cannot
C       overflow when xx is a very large but finite equivalent longitude.
        xResid = MOD(xx,bomMapXPeriod)
        xLoResid = MOD(bomMapXLo,bomMapXPeriod)
        IF ( xResid.NE.xResid .OR.
     &       ABS(xResid).GT.HUGE(xResid) .OR.
     &       xLoResid.NE.xLoResid .OR.
     &       ABS(xLoResid).GT.HUGE(xLoResid) ) RETURN
        xDelta = xResid - xLoResid
        IF ( xDelta.NE.xDelta .OR.
     &       ABS(xDelta).GT.HUGE(xDelta) ) RETURN
        xMap = bomMapXLo + xDelta
        IF ( xMap.NE.xMap .OR. ABS(xMap).GT.HUGE(xMap) ) THEN
          xMap = xx
          RETURN
        ENDIF
        IF ( xMap.LT.bomMapXLo ) xMap = xMap + bomMapXPeriod
        IF ( xMap.GE.bomMapXHi ) xMap = bomMapXLo
        IF ( xMap.NE.xMap .OR. ABS(xMap).GT.HUGE(xMap) ) THEN
          xMap = xx
          RETURN
        ENDIF
        isInsideX = xMap.GE.bomMapXLo .AND. xMap.LT.bomMapXHi
      ELSE
        isInsideX = xMap.GE.bomMapXLo .AND. xMap.LT.bomMapXHi
      ENDIF
#endif

      RETURN
      END
