#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_MAIN

C !INTERFACE:
      SUBROUTINE BOM_MAIN( myTime, myIter, myThid )

C !DESCRIPTION:
C     Empty time-step hook for the Phase-0 zero-particle skeleton.

C !USES:
      IMPLICIT NONE

C !INPUT PARAMETERS:
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP

      RETURN
      END
