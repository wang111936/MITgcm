#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_FIXED

C !INTERFACE:
      SUBROUTINE BOM_INIT_FIXED( myThid )

C !DESCRIPTION:
C     Initialize the static Phase-1.2 regular-grid mapping state.

C !USES:
      IMPLICIT NONE

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
      CALL BOM_INIT_MAPPING( myThid )
#endif

      RETURN
      END
