#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_MAIN

C !INTERFACE:
      SUBROUTINE BOM_MAIN( myTime, myIter, myThid )

C !DESCRIPTION:
C     Publish frozen step-end surface velocity fields when particles
C     exist.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
      IF ( bomMaxParticles.LE.0 ) RETURN
      CALL BOM_BUILD_FIELDS( myTime, myIter, myThid )
#endif

      RETURN
      END
