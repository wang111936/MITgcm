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
      IF ( the_run_name.EQ.'P44-IO' ) THEN
        CALL BOM_VERIFY_P44_IO(myThid)
      ELSEIF ( the_run_name.EQ.'P44-WRITE-N' ) THEN
        CALL BOM_VERIFY_P44_WRITE(.FALSE.,myThid)
      ELSEIF ( the_run_name.EQ.'P44-READ-N' ) THEN
        CALL BOM_VERIFY_P44_READ(.FALSE.,myThid)
      ELSEIF ( the_run_name.EQ.'P44-WRITE-E' ) THEN
        CALL BOM_VERIFY_P44_WRITE(.TRUE.,myThid)
      ELSEIF ( the_run_name.EQ.'P44-READ-E' ) THEN
        CALL BOM_VERIFY_P44_READ(.TRUE.,myThid)
      ENDIF
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
