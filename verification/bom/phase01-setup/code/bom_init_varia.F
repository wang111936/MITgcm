#include "BOM_OPTIONS.h"
#ifdef ALLOW_EXF
# include "EXF_OPTIONS.h"
#endif

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_VARIA

C !INTERFACE:
      SUBROUTINE BOM_INIT_VARIA( myThid )

C !DESCRIPTION:
C     Test-only setup gate entered after EXF variable initialization.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
      CALL BOM_INIT_STATE( myThid )
      IF ( bomMaxParticles.GT.0 ) THEN
        CALL BOM_READ_INITIAL( myThid )
      ENDIF
      IF ( the_run_name.EQ.'P13-SETUP-NONE' .OR.
     &     the_run_name.EQ.'P13-SETUP-EXF' .OR.
     &     the_run_name.EQ.'P13-TIME-OVERFLOW' ) THEN
        CALL BOM_VERIFY_SETUP( myThid )
      ENDIF
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_SETUP( myThid )

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

      INTEGER myThid

#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, i, j, nFail, globalFail
      _RL expectedEast, expectedNorth, expectedWindTime
      _RL testTime, tol
      LOGICAL isNone, isExf

      nFail = 0
      testTime = 123.5 _d 0
      tol = 4096. _d 0*EPSILON(oneRL)
      isNone = the_run_name.EQ.'P13-SETUP-NONE'
      isExf = the_run_name.EQ.'P13-SETUP-EXF'

      CALL BOM_VERIFY_SETUP_ASSERT(
     &     bomNPartExpected.EQ.0,
     &     'initial expected owner budget is zero',
     &     nFail, myThid )
      CALL BOM_VERIFY_SETUP_ASSERT(
     &     .NOT.bomFieldsReady .AND.
     &     bomFieldTime.EQ.0. _d 0 .AND.
     &     bomWindFieldTime.EQ.0. _d 0 .AND.
     &     bomFieldIter.EQ.0 .AND. bomWindFieldIter.EQ.0,
     &     'deterministic metadata initialization',
     &     nFail, myThid )

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          CALL BOM_VERIFY_SETUP_ASSERT(
     &         bomGridWindEast(i,j,1,bi,bj).EQ.0. _d 0 .AND.
     &         bomGridWindNorth(i,j,1,bi,bj).EQ.0. _d 0,
     &         'deterministic wind field initialization',
     &         nFail, myThid )
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      IF ( the_run_name.EQ.'P13-TIME-OVERFLOW' ) THEN
        CALL BOM_BUILD_FIELDS( -HUGE(oneRL), 7, myThid )
        CALL BOM_VERIFY_SETUP_ASSERT( .FALSE.,
     &       'overflow case returned from BOM_BUILD_FIELDS',
     &       nFail, myThid )
      ELSE
        CALL BOM_VERIFY_SETUP_ASSERT( isNone .OR. isExf,
     &       'recognized positive setup scenario',
     &       nFail, myThid )
        CALL BOM_BUILD_FIELDS( testTime, 7, myThid )
      ENDIF

      expectedWindTime = testTime-deltaTClock
      CALL BOM_VERIFY_SETUP_ASSERT(
     &     bomFieldsReady .AND.
     &     bomFieldTime.EQ.testTime .AND. bomFieldIter.EQ.7 .AND.
     &     bomWindFieldTime.EQ.expectedWindTime .AND.
     &     bomWindFieldIter.EQ.6,
     &     'ocean and wind metadata published last',
     &     nFail, myThid )

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          expectedEast = 0. _d 0
          expectedNorth = 0. _d 0
          IF ( isExf .AND. maskC(i,j,1,bi,bj).GT.0. ) THEN
            expectedEast = 2.5 _d 0
            expectedNorth = -1.25 _d 0
          ENDIF
          CALL BOM_VERIFY_SETUP_ASSERT(
     &         ABS(bomGridWindEast(i,j,1,bi,bj)
     &             -expectedEast).LE.tol,
     &         'frozen east wind value/mask/halo',
     &         nFail, myThid )
          CALL BOM_VERIFY_SETUP_ASSERT(
     &         ABS(bomGridWindNorth(i,j,1,bi,bj)
     &             -expectedNorth).LE.tol,
     &         'frozen north wind value/mask/halo',
     &         nFail, myThid )
#ifdef ALLOW_EXF
          IF ( isExf .AND. i.GE.1 .AND. i.LE.sNx .AND.
     &         j.GE.1 .AND. j.LE.sNy ) THEN
            CALL BOM_VERIFY_SETUP_ASSERT(
     &           ABS(uwind(i,j,bi,bj)-2.5 _d 0).LE.tol .AND.
     &           ABS(vwind(i,j,bi,bj)+1.25 _d 0).LE.tol,
     &           'EXF source wind remains unchanged',
     &           nFail, myThid )
          ENDIF
#else
          IF ( isExf ) THEN
            CALL BOM_VERIFY_SETUP_ASSERT( .FALSE.,
     &           'EXF scenario requires ALLOW_EXF',
     &           nFail, myThid )
          ENDIF
#endif
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_VERIFY_SETUP: failed assertions=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_SETUP'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        IF ( isExf ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-SETUP PASS: EXF frozen wind snapshot'
        ELSE
          WRITE(msgBuf,'(A)')
     &         'P1-SETUP PASS: NONE zero wind snapshot'
        ENDIF
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_SETUP_ASSERT(
     I                 condition, label,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "EEPARAMS.h"
      LOGICAL condition
      CHARACTER*(*) label
      INTEGER nFail, myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf

      IF ( .NOT.condition ) THEN
        IF ( nFail.LT.12 ) THEN
          WRITE(msgBuf,'(2A)') 'BOM_VERIFY_SETUP: FAIL: ', label
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        nFail = nFail + 1
      ENDIF

      RETURN
      END
