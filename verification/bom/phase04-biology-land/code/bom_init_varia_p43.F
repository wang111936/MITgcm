#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_VARIA
C !INTERFACE:
      SUBROUTINE BOM_INIT_VARIA( myThid )

C !DESCRIPTION:
C     Test-only P4.3 direct-gate dispatcher.  Predecessor dispatchers remain
C     byte-for-byte unchanged and never link the P4.3 verification routines.

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
      IF ( the_run_name.EQ.'P43-RNG' ) THEN
        CALL BOM_VERIFY_P43_RNG( myThid )
      ELSEIF ( the_run_name.EQ.'P43-BIRTH' ) THEN
        CALL BOM_VERIFY_P43_BIRTH( myThid )
      ELSEIF ( the_run_name.EQ.'P43-EVENT' .OR.
     &         the_run_name.EQ.'P43-EVENT-PERM' ) THEN
        CALL BOM_VERIFY_P43_EVENT( myThid )
      ENDIF
#endif

      RETURN
      END
