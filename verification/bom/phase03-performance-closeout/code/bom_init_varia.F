#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_INIT_VARIA( myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      INTEGER myThid
#ifdef ALLOW_BOM
      CALL BOM_INIT_STATE( myThid )
      CALL BOM_VERIFY_PERFORMANCE_CLOSEOUT( myThid )
#endif
      RETURN
      END
