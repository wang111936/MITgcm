#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_VARIA
C !INTERFACE:
      SUBROUTINE BOM_INIT_VARIA( myThid )

C !DESCRIPTION:
C     Test-only P4.1 direct-gate dispatcher.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
      CALL BOM_INIT_STATE( myThid )
      IF ( the_run_name.EQ.'P41-PTRACER' ) THEN
        CALL BOM_VERIFY_P41_CODES_CONFIG( myThid )
        CALL BOM_VERIFY_P41_ENDPOINTS( .FALSE., myThid )
        CALL BOM_VERIFY_P41_INTERP( myThid )
        CALL BOM_VERIFY_P41_BROOKS( myThid )
      ELSEIF ( the_run_name.EQ.'P41-FILES' ) THEN
        CALL BOM_VERIFY_P41_ENDPOINTS( .TRUE., myThid )
      ENDIF
#endif

      RETURN
      END
