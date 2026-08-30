#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_INIT_VARIA(myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
      INTEGER myThid
#ifdef ALLOW_BOM
      CALL BOM_INIT_STATE(myThid)
      IF ( the_run_name.EQ.'P45-CAPACITY' ) THEN
        CALL BOM_VERIFY_P45_CAPACITY(myThid)
      ELSEIF ( the_run_name.EQ.'P45-TRANSACTION' ) THEN
        CALL BOM_VERIFY_P45_TRANSACTION(myThid)
      ELSEIF ( the_run_name.EQ.'P45-GRAPH' ) THEN
        CALL BOM_VERIFY_P45_GRAPH(myThid)
      ENDIF
#endif
      RETURN
      END

