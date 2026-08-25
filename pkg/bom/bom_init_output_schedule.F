#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_OUTPUT_SCHEDULE
C !INTERFACE:
      SUBROUTINE BOM_INIT_OUTPUT_SCHEDULE( initialTime, myThid )

C !DESCRIPTION:
C     Initialise the P1.5 trajectory schedule for a fresh integration.
C     A restart restores this state from the BOM pickup instead.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL initialTime
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      _RL nextTime
      INTEGER errCount

      _BEGIN_MASTER(myThid)
      errCount = 0
      nextTime = 0. _d 0
      bomOutputScheduleReady = .FALSE.
      bomNextOutputTime = 0. _d 0

      IF ( .NOT.IEEE_IS_FINITE(initialTime) .OR.
     &     .NOT.IEEE_IS_FINITE(bomOutputFreq) ) THEN
        WRITE(msgBuf,'(A,2(1X,1PE24.16))')
     &       'BOM_INIT_OUTPUT_SCHEDULE: non-finite time/frequency=',
     &       initialTime, bomOutputFreq
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( bomOutputFreq.LT.0. _d 0 ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_INIT_OUTPUT_SCHEDULE: negative frequency=',
     &       bomOutputFreq
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( bomOutputFreq.GT.0. _d 0 ) THEN
        nextTime = initialTime + bomOutputFreq
        IF ( .NOT.IEEE_IS_FINITE(nextTime) .OR.
     &       nextTime.LE.initialTime ) THEN
          WRITE(msgBuf,'(A,3(1X,1PE24.16))')
     &         'BOM_INIT_OUTPUT_SCHEDULE: invalid initial/next/freq=',
     &         initialTime, nextTime, bomOutputFreq
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
      ENDIF

      IF ( errCount.GT.0 ) THEN
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_INIT_OUTPUT_SCHEDULE'
      ENDIF

      bomNextOutputTime = nextTime
      bomOutputScheduleReady = .TRUE.
      _END_MASTER(myThid)
      _BARRIER
#endif

      RETURN
      END
