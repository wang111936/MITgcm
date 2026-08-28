#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_INIT_VARIA( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid

#ifdef ALLOW_BOM
      CALL BOM_INIT_STATE( myThid )
      IF ( bomMaxParticles.EQ.0 ) THEN
        CALL BOM_VERIFY_COMPONENTS_SCHEMA3( myThid )
      ELSE
        CALL BOM_VERIFY_SCHEMA3_IO( myThid )
      ENDIF
#endif

      RETURN
      END
