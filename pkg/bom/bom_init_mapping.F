#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_MAPPING

C !INTERFACE:
      SUBROUTINE BOM_INIT_MAPPING( myThid )

C !DESCRIPTION:
C     Initialize the supported regular-grid domain and verify that the
C     local tile geometry is consistent with the global spacing vectors.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#ifdef ALLOW_EXCH2
#include "W2_EXCH2_SIZE.h"
#endif
#include "SET_GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, i, j, iG0, jG0
      INTEGER errCount
      _RL xSpan, ySpan, scale, xExpected, yExpected

      _BEGIN_MASTER(myThid)

C--   A failed initialization must never leave apparently usable state.
      bomMapXLo       = 0. _d 0
      bomMapXHi       = 0. _d 0
      bomMapYLo       = 0. _d 0
      bomMapYHi       = 0. _d 0
      bomMapXPeriod   = 0. _d 0
      bomMapTol       = 0. _d 0
      bomMapPeriodicX = .FALSE.
      bomFieldsReady  = .FALSE.
      bomFieldTime    = 0. _d 0
      bomFieldIter    = 0
      errCount        = 0

      IF ( usingCartesianGrid .EQV. usingSphericalPolarGrid ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_INIT_MAPPING: require exactly one supported grid'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
      IF ( usingCurvilinearGrid .OR. usingCylindricalGrid ) THEN
        WRITE(msgBuf,'(2A)')
     &       'BOM_INIT_MAPPING: curvilinear/cylindrical ',
     &       'grid unsupported'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
      IF ( rotateGrid ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_INIT_MAPPING: rotateGrid unsupported in Phase 1'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
      IF ( usingPCoords ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_INIT_MAPPING: usingPCoords unsupported in Phase 1'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
      IF ( nTx*nTy.NE.1 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_INIT_MAPPING: Phase-1 mapping is MPI-only'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
#ifdef ALLOW_EXCH2
      WRITE(msgBuf,'(A)')
     &     'BOM_INIT_MAPPING: EXCH2 unsupported in Phase 1'
      CALL PRINT_ERROR( msgBuf, myThid )
      errCount = errCount + 1
#endif
      IF ( OLx.LT.1 .OR. OLy.LT.1 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_INIT_MAPPING: mapping requires positive overlap'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( xgOrigin.NE.xgOrigin .OR.
     &     ABS(xgOrigin).GT.HUGE(xgOrigin) .OR.
     &     ygOrigin.NE.ygOrigin .OR.
     &     ABS(ygOrigin).GT.HUGE(ygOrigin) ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_INIT_MAPPING: non-finite horizontal origin'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      xSpan = 0. _d 0
      DO i=1,Nx
        IF ( delX(i).NE.delX(i) .OR.
     &       ABS(delX(i)).GT.HUGE(delX(i)) .OR.
     &       delX(i).LE.0. _d 0 ) THEN
          WRITE(msgBuf,'(A,I8,A,1PE24.16)')
     &         'BOM_INIT_MAPPING: invalid delX(', i, ')=', delX(i)
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ELSE
          xSpan = xSpan + delX(i)
        ENDIF
      ENDDO
      ySpan = 0. _d 0
      DO j=1,Ny
        IF ( delY(j).NE.delY(j) .OR.
     &       ABS(delY(j)).GT.HUGE(delY(j)) .OR.
     &       delY(j).LE.0. _d 0 ) THEN
          WRITE(msgBuf,'(A,I8,A,1PE24.16)')
     &         'BOM_INIT_MAPPING: invalid delY(', j, ')=', delY(j)
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ELSE
          ySpan = ySpan + delY(j)
        ENDIF
      ENDDO

      IF ( errCount.EQ.0 ) THEN
        bomMapXLo = xgOrigin
        bomMapXHi = xgOrigin + xSpan
        bomMapYLo = ygOrigin
        bomMapYHi = ygOrigin + ySpan
        scale = MAX( oneRL, ABS(bomMapXLo), ABS(bomMapXHi) )
        scale = MAX( scale, ABS(bomMapYLo), ABS(bomMapYHi) )
        scale = MAX( scale, ABS(xSpan), ABS(ySpan), 360. _d 0 )
        bomMapTol = 64. _d 0*EPSILON(oneRL)*scale
        IF ( usingSphericalPolarGrid .AND.
     &       ABS(xSpan-360. _d 0).LE.bomMapTol ) THEN
          bomMapPeriodicX = .TRUE.
          bomMapXPeriod = 360. _d 0
        ENDIF

C--     Check every local tile, including all stored face intervals.
        DO bj=1,nSy
         DO bi=1,nSx
          DO i=1-OLx,sNx+OLx-1
            IF ( xG(i,1,bi,bj).NE.xG(i,1,bi,bj) .OR.
     &           xG(i+1,1,bi,bj).LE.xG(i,1,bi,bj) ) THEN
              WRITE(msgBuf,'(A,4I6)')
     &             'BOM_INIT_MAPPING: non-monotone tile xG:',
     &             i, 1, bi, bj
              CALL PRINT_ERROR( msgBuf, myThid )
              errCount = errCount + 1
            ENDIF
          ENDDO
          DO j=1-OLy,sNy+OLy-1
            IF ( yG(1,j,bi,bj).NE.yG(1,j,bi,bj) .OR.
     &           yG(1,j+1,bi,bj).LE.yG(1,j,bi,bj) ) THEN
              WRITE(msgBuf,'(A,4I6)')
     &             'BOM_INIT_MAPPING: non-monotone tile yG:',
     &             1, j, bi, bj
              CALL PRINT_ERROR( msgBuf, myThid )
              errCount = errCount + 1
            ENDIF
          ENDDO

          iG0 = myXGlobalLo - 1 + (bi-1)*sNx
          xExpected = bomMapXLo
          DO i=1,iG0
            xExpected = xExpected + delX(i)
          ENDDO
          IF ( ABS(xG(1,1,bi,bj)-xExpected).GT.bomMapTol ) THEN
            WRITE(msgBuf,'(A,2I5,2(1X,1PE24.16))')
     &           'BOM_INIT_MAPPING: inconsistent tile west bound',
     &           bi, bj, xG(1,1,bi,bj), xExpected
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
          DO i=iG0+1,iG0+sNx
            xExpected = xExpected + delX(i)
          ENDDO
          IF ( ABS(xG(sNx+1,1,bi,bj)-xExpected)
     &         .GT.bomMapTol ) THEN
            WRITE(msgBuf,'(A,2I5,2(1X,1PE24.16))')
     &           'BOM_INIT_MAPPING: inconsistent tile east bound',
     &           bi, bj, xG(sNx+1,1,bi,bj), xExpected
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF

          jG0 = myYGlobalLo - 1 + (bj-1)*sNy
          yExpected = bomMapYLo
          DO j=1,jG0
            yExpected = yExpected + delY(j)
          ENDDO
          IF ( ABS(yG(1,1,bi,bj)-yExpected).GT.bomMapTol ) THEN
            WRITE(msgBuf,'(A,2I5,2(1X,1PE24.16))')
     &           'BOM_INIT_MAPPING: inconsistent tile south bound',
     &           bi, bj, yG(1,1,bi,bj), yExpected
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
          DO j=jG0+1,jG0+sNy
            yExpected = yExpected + delY(j)
          ENDDO
          IF ( ABS(yG(1,sNy+1,bi,bj)-yExpected)
     &         .GT.bomMapTol ) THEN
            WRITE(msgBuf,'(A,2I5,2(1X,1PE24.16))')
     &           'BOM_INIT_MAPPING: inconsistent tile north bound',
     &           bi, bj, yG(1,sNy+1,bi,bj), yExpected
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
         ENDDO
        ENDDO
      ENDIF

      IF ( errCount.GE.1 ) THEN
        WRITE(msgBuf,'(A,I4,A)')
     &       'BOM_INIT_MAPPING: detected', errCount,
     &       ' fatal error(s); mapping state is unavailable'
        CALL PRINT_ERROR( msgBuf, myThid )
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_INIT_MAPPING'
      ENDIF

      WRITE(msgBuf,'(A,4(1X,1PE16.8),A,L1)')
     &     'BOM_INIT_MAPPING: xLo/xHi/yLo/yHi =',
     &     bomMapXLo, bomMapXHi, bomMapYLo, bomMapYHi,
     &     ' periodicX=', bomMapPeriodicX
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A,1PE24.16)')
     &     'BOM_INIT_MAPPING: scaled tolerance = ', bomMapTol
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )

      _END_MASTER(myThid)
      _BARRIER
#endif /* ALLOW_BOM */

      RETURN
      END
