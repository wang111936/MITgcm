#include "BOM_OPTIONS.h"

C---+----1----2----3----4----5----6----7-|--+----|
C     Verification override of the production fixed-init hook.  It only
C     injects named invalid states after MITgcm grid initialization.
      SUBROUTINE BOM_INIT_FIXED( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#ifdef ALLOW_EXCH2
#include "W2_EXCH2_SIZE.h"
#endif
#include "SET_GRID.h"

      INTEGER myThid

#ifdef ALLOW_BOM
      _BEGIN_MASTER(myThid)
      IF ( the_run_name.EQ.'P1-N04-ROTATE' ) THEN
        rotateGrid = .TRUE.
      ELSEIF ( the_run_name.EQ.'P1-N04-CURVILINEAR' ) THEN
        usingCartesianGrid = .FALSE.
        usingCurvilinearGrid = .TRUE.
      ELSEIF ( the_run_name.EQ.'P1-N04-PCOORDS' ) THEN
        usingPCoords = .TRUE.
      ELSEIF ( the_run_name.EQ.'P1-N04-DELX' ) THEN
        delX(1) = 0. _d 0
      ELSEIF ( the_run_name.EQ.'P1-N04-TILE-BOUND' ) THEN
        xG(1,1,1,1) = xG(1,1,1,1) + 1. _d 0
      ENDIF
      _END_MASTER(myThid)
      _BARRIER

      CALL BOM_INIT_MAPPING( myThid )
      IF ( the_run_name.EQ.'P1-M01-CARTESIAN' .OR.
     &     the_run_name.EQ.'P1-M02-GLOBAL' .OR.
     &     the_run_name.EQ.'P1-M02-REGIONAL' ) THEN
        CALL BOM_VERIFY_MAPPING( myThid )
      ENDIF
#endif

      RETURN
      END
