#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BUILD_FIELDS

C !INTERFACE:
      SUBROUTINE BOM_BUILD_FIELDS( myTime, myIter, myThid )

C !DESCRIPTION:
C     Build frozen step-end surface velocity fields at C points in
C     geographic east/north directions and exchange them as scalars.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "DYNVARS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL myTime
      INTEGER myIter, myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, i, j, errCount, globalErrCount
      _RL eastValue, northValue
      LOGICAL invalidValue

C--   A partial or failed rebuild must never remain published.
      _BEGIN_MASTER(myThid)
      bomFieldsReady = .FALSE.
      _END_MASTER(myThid)
      _BARRIER

      errCount = 0
      IF ( myTime.NE.myTime .OR.
     &     ABS(myTime).GT.HUGE(myTime) ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_BUILD_FIELDS: non-finite field time=', myTime
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

C--   Preserve the complete surface C-grid inputs, including halos.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomGridUWork(i,j,1,bi,bj) = uVel(i,j,1,bi,bj)
          bomGridVWork(i,j,1,bi,bj) = vVel(i,j,1,bi,bj)
          bomGridVEast(i,j,1,bi,bj) = 0. _d 0
          bomGridVNorth(i,j,1,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Collocate C-grid faces, rotate, and mask.  Exchange each
C     component as a scalar so vector exchange cannot rotate it again.
      CALL ROTATE_UV2EN_RL(
     U     bomGridUWork, bomGridVWork,
     U     bomGridVEast, bomGridVNorth,
     I     .TRUE., .TRUE., .TRUE., 1, myThid )
      CALL EXCH_3D_RL( bomGridVEast, 1, myThid )
      CALL EXCH_3D_RL( bomGridVNorth, 1, myThid )

C--   All published wet values must be finite; dry values must be zero.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          eastValue = bomGridVEast(i,j,1,bi,bj)
          northValue = bomGridVNorth(i,j,1,bi,bj)
          invalidValue = eastValue.NE.eastValue
     &          .OR. ABS(eastValue).GT.HUGE(eastValue)
     &          .OR. northValue.NE.northValue
     &          .OR. ABS(northValue).GT.HUGE(northValue)
          IF ( invalidValue ) THEN
            IF ( errCount.LT.8 ) THEN
              WRITE(msgBuf,'(A,4I5,2(1X,1PE24.16))')
     &             'BOM_BUILD_FIELDS: non-finite EN at',
     &             i, j, bi, bj, eastValue, northValue
              CALL PRINT_ERROR( msgBuf, myThid )
            ENDIF
            errCount = errCount + 1
          ELSEIF ( maskC(i,j,1,bi,bj).LE.0. .AND.
     &             ( eastValue.NE.0. _d 0 .OR.
     &               northValue.NE.0. _d 0 ) ) THEN
            IF ( errCount.LT.8 ) THEN
              WRITE(msgBuf,'(A,4I5,2(1X,1PE24.16))')
     &             'BOM_BUILD_FIELDS: nonzero dry EN at',
     &             i, j, bi, bj, eastValue, northValue
              CALL PRINT_ERROR( msgBuf, myThid )
            ENDIF
            errCount = errCount + 1
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      globalErrCount = errCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8,A)')
     &         'BOM_BUILD_FIELDS: detected ', globalErrCount,
     &         ' fatal field validation error(s)'
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_BUILD_FIELDS'
      ENDIF

C--   Publish metadata only after rotation, exchanges, and validation.
      _BEGIN_MASTER(myThid)
      bomFieldTime = myTime
      bomFieldIter = myIter
      bomFieldsReady = .TRUE.
      _END_MASTER(myThid)
      _BARRIER
#endif /* ALLOW_BOM */

      RETURN
      END
