#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P56_TRAJECTORY(
     I     sampleTime,scheduledTime,myIter,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL sampleTime,scheduledTime
      INTEGER myIter,myThid
#ifdef ALLOW_BOM
C--   Test-only growth fixture: the historical P4 writer seeds two current
C     owners.  Lower only the immutable initial count so live > initial is
C     exercised without modifying the Phase-4 source fixture.
      IF ( bomTrajectoryFile.EQ.'bom_growth' ) THEN
        _BEGIN_MASTER(myThid)
        bomNPartExpected=1
        _END_MASTER(myThid)
        _BARRIER
      ENDIF
      IF ( bomTrajectoryMode.EQ.'ARCHIVE' ) THEN
        CALL BOM_WRITE_TRAJECTORY_ARCHIVE(
     I       sampleTime,scheduledTime,myIter,myThid)
      ELSE
        CALL BOM_WRITE_TRAJECTORY(
     I       sampleTime,scheduledTime,myIter,myThid)
      ENDIF
#endif
      RETURN
      END
