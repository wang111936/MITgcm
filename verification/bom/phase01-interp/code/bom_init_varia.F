#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_VARIA

C !INTERFACE:
      SUBROUTINE BOM_INIT_VARIA( myThid )

C !DESCRIPTION:
C     Test-only initialization for the P1-F03/P1-N05 gate.

C !USES:
      IMPLICIT NONE

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
      CALL BOM_INIT_STATE( myThid )
      CALL BOM_VERIFY_INTERP( myThid )
#endif

      RETURN
      END
