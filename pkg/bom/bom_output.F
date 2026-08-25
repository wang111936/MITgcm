#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_OUTPUT
C !INTERFACE:
      SUBROUTINE BOM_OUTPUT( myTime, myIter, myThid )

C !DESCRIPTION:
C     Schedule one P1.5 trajectory frame from the completed P1.4 owner
C     state.  Non-integral frequencies sample at the first ocean-step end
C     that reaches or crosses the scheduled time.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL myTime
      INTEGER myIter, myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      _RL timeScale, timeTol, scheduledTime, nextTime
      INTEGER localErrCount, globalErrCount
      INTEGER localOwnerCount, globalOwnerCount, bi, bj

      IF ( bomOutputFreq.EQ.0. _d 0 ) RETURN

      localErrCount = 0
      scheduledTime = bomNextOutputTime
      nextTime = scheduledTime + bomOutputFreq
      IF ( .NOT.bomOutputScheduleReady .OR.
     &     .NOT.IEEE_IS_FINITE(myTime) .OR.
     &     .NOT.IEEE_IS_FINITE(scheduledTime) .OR.
     &     .NOT.IEEE_IS_FINITE(bomOutputFreq) .OR.
     &     .NOT.IEEE_IS_FINITE(nextTime) .OR.
     &     bomOutputFreq.LE.0. _d 0 .OR.
     &     nextTime.LE.scheduledTime ) THEN
        localErrCount = localErrCount + 1
      ENDIF

      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,L3,A,I12,A,4(1X,1PE24.16))')
     &         'BOM_OUTPUT: invalid schedule ready=',
     &         bomOutputScheduleReady, ' iter=', myIter,
     &         ' time/scheduled/next/freq=',
     &         myTime, scheduledTime, nextTime, bomOutputFreq
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_OUTPUT'
      ENDIF

      timeScale = MAX( oneRL, ABS(myTime), ABS(scheduledTime),
     &                 ABS(nextTime), ABS(bomOutputFreq) )
      timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
      IF ( myTime.LT.scheduledTime-timeTol ) RETURN

C--   The frozen frequency bound permits at most one scheduled event.
      IF ( myTime.GE.nextTime-timeTol ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I12,A,4(1X,1PE24.16))')
     &         'BOM_OUTPUT: multiple schedule crossing iter=', myIter,
     &         ' time/scheduled/next/freq=',
     &         myTime, scheduledTime, nextTime, bomOutputFreq
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_OUTPUT'
      ENDIF

      IF ( bomNPartExpected.GT.0 ) THEN
        CALL BOM_CHECK_STATE(
     I       myTime, myIter, 'OUTPUT', myThid )
      ELSE
C--     Explicitly enabled zero-particle output still writes tiled headers.
        localErrCount = 0
        localOwnerCount = 0
        IF ( bomNPartExpected.NE.0 ) localErrCount = 1
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          IF ( bomNPartTile(bi,bj).LT.0 .OR.
     &         bomNPartTile(bi,bj).GT.bomMaxPartTile ) THEN
            localErrCount = localErrCount + 1
          ELSE
            localOwnerCount = localOwnerCount + bomNPartTile(bi,bj)
          ENDIF
         ENDDO
        ENDDO
        globalErrCount = localErrCount
        globalOwnerCount = localOwnerCount
        CALL GLOBAL_SUM_INT( globalErrCount, myThid )
        CALL GLOBAL_SUM_INT( globalOwnerCount, myThid )
        IF ( globalOwnerCount.NE.0 ) globalErrCount = globalErrCount + 1
        IF ( globalErrCount.GT.0 ) THEN
          _BEGIN_MASTER(myThid)
          IF ( myProcId.EQ.0 ) THEN
            WRITE(msgBuf,'(A,I12,A,2I12)')
     &           'BOM_OUTPUT: empty-state budget iter=', myIter,
     &           ' owner/errors=', globalOwnerCount, globalErrCount
            CALL PRINT_ERROR( msgBuf, myThid )
          ENDIF
          _END_MASTER(myThid)
          CALL ALL_PROC_DIE( 0 )
          STOP 'ABNORMAL END: S/R BOM_OUTPUT'
        ENDIF
      ENDIF
      CALL BOM_WRITE_TRAJECTORY(
     I     myTime, scheduledTime, myIter, myThid )

      _BEGIN_MASTER(myThid)
      bomNextOutputTime = nextTime
      _END_MASTER(myThid)
      _BARRIER
#endif

      RETURN
      END
