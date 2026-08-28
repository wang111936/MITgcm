#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_INIT_VARIA( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid

#ifdef ALLOW_BOM
      CALL BOM_INIT_STATE( myThid )
      IF ( bomSpringLaw.EQ.'NONE' .AND.
     &     bomNeighborPolicy.EQ.'NONE' )
     &  CALL BOM_VERIFY_CUTOFF_GRAPH( myThid )
#endif

      RETURN
      END
