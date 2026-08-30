#include "BOM_OPTIONS.h"
#ifdef ALLOW_EXF
# include "EXF_OPTIONS.h"
#endif

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BUILD_FIELDS

C !INTERFACE:
      SUBROUTINE BOM_BUILD_FIELDS( myTime, myIter, myThid )

C !DESCRIPTION:
C     Build frozen step-end ocean velocity and request-time EXF wind
C     fields at C points in geographic east/north directions.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "DYNVARS.h"
#include "GRID.h"
#ifdef ALLOW_EXF
# include "EXF_FIELDS.h"
#endif
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
      INTEGER windIter
      _RL eastValue, northValue, windEast, windNorth, windTime
      LOGICAL invalidValue, timeFinite, deltaTFinite

C--   A partial or failed rebuild must never remain published.
      _BEGIN_MASTER(myThid)
      bomFieldsReady = .FALSE.
      _END_MASTER(myThid)
      _BARRIER

      errCount = 0
      windTime = 0. _d 0
      windIter = 0
      timeFinite = IEEE_IS_FINITE(myTime)
      deltaTFinite = IEEE_IS_FINITE(deltaTClock)
      IF ( .NOT.timeFinite ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_BUILD_FIELDS: non-finite field time=', myTime
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( .NOT.deltaTFinite ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_BUILD_FIELDS: invalid deltaTClock=', deltaTClock
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( deltaTClock.LE.0. _d 0 ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_BUILD_FIELDS: invalid deltaTClock=', deltaTClock
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( myTime.LE.-HUGE(myTime)+deltaTClock ) THEN
        WRITE(msgBuf,'(A,2(1X,1PE24.16))')
     &       'BOM_BUILD_FIELDS: wind time overflow: myTime/deltaT=',
     &       myTime, deltaTClock
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSE
        windTime = myTime-deltaTClock
        IF ( .NOT.IEEE_IS_FINITE(windTime) ) THEN
          WRITE(msgBuf,'(A,1PE24.16)')
     &         'BOM_BUILD_FIELDS: non-finite wind time=', windTime
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
      ENDIF
      IF ( myIter.LE.-HUGE(myIter) ) THEN
        WRITE(msgBuf,'(A,I12)')
     &       'BOM_BUILD_FIELDS: wind iteration overflow: myIter=',
     &       myIter
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSE
        windIter = myIter-1
      ENDIF

      IF ( bomWindSource.NE.'NONE' .AND.
     &     bomWindSource.NE.'EXF' ) THEN
        WRITE(msgBuf,'(A,A)')
     &       'BOM_BUILD_FIELDS: unsupported wind source=',
     &       bomWindSource
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
#ifndef ALLOW_EXF
      IF ( bomWindSource.EQ.'EXF' ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_BUILD_FIELDS: EXF wind is not compiled'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
#endif

C--   Preserve the complete surface C-grid inputs, including halos.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomGridUWork(i,j,1,bi,bj) = uVel(i,j,1,bi,bj)
          bomGridVWork(i,j,1,bi,bj) = vVel(i,j,1,bi,bj)
          bomGridVEast(i,j,1,bi,bj) = 0. _d 0
          bomGridVNorth(i,j,1,bi,bj) = 0. _d 0
          bomGridWindEast(i,j,1,bi,bj) = 0. _d 0
          bomGridWindNorth(i,j,1,bi,bj) = 0. _d 0
#ifdef ALLOW_EXF
          IF ( bomWindSource.EQ.'EXF' .AND.
     &         maskC(i,j,1,bi,bj).GT.0. ) THEN
            bomGridWindEast(i,j,1,bi,bj) = uwind(i,j,bi,bj)
            bomGridWindNorth(i,j,1,bi,bj) = vwind(i,j,bi,bj)
          ENDIF
#endif
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Native Nx-by-Ny C-grid records omit only the positive physical U/V
C     faces.  Complete those faces in BOM work storage before colocation.
      CALL BOM_FILL_CGRID_BOUNDARY(
     U     bomGridUWork, bomGridVWork,
     I     myThid )

C--   Collocate C-grid faces, rotate, and mask.  Exchange each
C     component as a scalar so vector exchange cannot rotate it again.
      CALL ROTATE_UV2EN_RL(
     U     bomGridUWork, bomGridVWork,
     U     bomGridVEast, bomGridVNorth,
     I     .TRUE., .TRUE., .TRUE., 1, myThid )
      CALL EXCH_3D_RL( bomGridVEast, 1, myThid )
      CALL EXCH_3D_RL( bomGridVNorth, 1, myThid )
      CALL EXCH_3D_RL( bomGridWindEast, 1, myThid )
      CALL EXCH_3D_RL( bomGridWindNorth, 1, myThid )

C--   All published wet values must be finite; dry values must be zero.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          eastValue = bomGridVEast(i,j,1,bi,bj)
          northValue = bomGridVNorth(i,j,1,bi,bj)
          windEast = bomGridWindEast(i,j,1,bi,bj)
          windNorth = bomGridWindNorth(i,j,1,bi,bj)
          invalidValue = .NOT.IEEE_IS_FINITE(eastValue)
     &          .OR. .NOT.IEEE_IS_FINITE(northValue)
     &          .OR. .NOT.IEEE_IS_FINITE(windEast)
     &          .OR. .NOT.IEEE_IS_FINITE(windNorth)
          IF ( invalidValue ) THEN
            IF ( errCount.LT.8 ) THEN
              WRITE(msgBuf,'(A,4I5,4(1X,1PE24.16))')
     &             'BOM_BUILD_FIELDS: non-finite ocean/wind at',
     &             i, j, bi, bj,
     &             eastValue, northValue, windEast, windNorth
              CALL PRINT_ERROR( msgBuf, myThid )
            ENDIF
            errCount = errCount + 1
          ELSEIF ( maskC(i,j,1,bi,bj).LE.0. .AND.
     &             ( eastValue.NE.0. _d 0 .OR.
     &               northValue.NE.0. _d 0 .OR.
     &               windEast.NE.0. _d 0 .OR.
     &               windNorth.NE.0. _d 0 ) ) THEN
            IF ( errCount.LT.8 ) THEN
              WRITE(msgBuf,'(A,4I5,4(1X,1PE24.16))')
     &             'BOM_BUILD_FIELDS: nonzero dry ocean/wind at',
     &             i, j, bi, bj,
     &             eastValue, northValue, windEast, windNorth
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
      bomWindFieldTime = windTime
      bomWindFieldIter = windIter
      bomFieldsReady = .TRUE.
      _END_MASTER(myThid)
      _BARRIER
#endif /* ALLOW_BOM */

      RETURN
      END
