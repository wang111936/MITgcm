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
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
      CALL BOM_INIT_MAPPING( myThid )
#ifdef ALLOW_DIAGNOSTICS
      IF ( useDiagnostics ) CALL BOM_DIAGNOSTICS_INIT(myThid)
#endif
#endif

      RETURN
      END
