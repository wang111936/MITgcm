#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VERIFY_ENDPOINT_TRANSACTION
C !INTERFACE:
      SUBROUTINE BOM_VERIFY_ENDPOINT_TRANSACTION( myThid )

C !DESCRIPTION:
C     Test-only direct gate for the production endpoint transaction.

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
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*8 savedWindSource
      INTEGER nFail, globalFail, failCode, failStage
      INTEGER iter1, iter2
      _RL time1, time2
      LOGICAL buildValid

      nFail = 0

C--   Fresh publication duplicates one exact ocean/NONE/NONE endpoint.
      CALL BOM_SET_ENDPOINT_FIXTURE(
     I     2. _d 0, -3. _d 0, myThid )
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     startTime, nIter0, .TRUE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'fresh endpoint transaction succeeds', nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_VALUES(
     I     startTime, nIter0, 2. _d 0, -3. _d 0,
     I     startTime, nIter0, 2. _d 0, -3. _d 0,
     U     nFail,
     I     myThid )

C--   Save the complete accepted state in test-only Phase-1 arrays.
      CALL BOM_CAPTURE_ACCEPTED_ENDPOINTS( myThid )

C--   A normal step copies accepted NEW to OLD before building exact NEW.
      time1 = startTime + deltaTClock
      iter1 = nIter0 + 1
      CALL BOM_SET_ENDPOINT_FIXTURE(
     I     4. _d 0, -1. _d 0, myThid )
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time1, iter1, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'normal endpoint transaction succeeds', nFail, myThid )
      CALL BOM_VERIFY_OLD_FROM_NEW_SNAPSHOT( nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_VALUES(
     I     startTime, nIter0, 2. _d 0, -3. _d 0,
     I     time1, iter1, 4. _d 0, -1. _d 0,
     U     nFail,
     I     myThid )
      CALL BOM_CAPTURE_ACCEPTED_ENDPOINTS( myThid )

C--   Broken continuity must return without changing accepted state.
      time2 = time1 + 2. _d 0*deltaTClock
      iter2 = iter1 + 2
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time2, iter2, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     .NOT.buildValid .AND.
     &     failCode.EQ.BOM_FAIL_FIELD_TIME .AND.
     &     failStage.EQ.BOM_STAGE_FIELD_OLD,
     &     'continuity failure code and stage', nFail, myThid )
      CALL BOM_VERIFY_ACCEPTED_SNAPSHOT(
     I     startTime, nIter0, time1, iter1,
     U     nFail,
     I     myThid )

C--   An unavailable source is a component failure with full rollback.
      time2 = time1 + deltaTClock
      iter2 = iter1 + 1
      savedWindSource = bomWindSource
      _BEGIN_MASTER(myThid)
      bomWindSource = 'EXF'
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time2, iter2, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     .NOT.buildValid .AND.
     &     failCode.EQ.BOM_FAIL_FIELD_SOURCE .AND.
     &     failStage.EQ.BOM_STAGE_FIELD_NEW,
     &     'source failure code and stage', nFail, myThid )
      CALL BOM_VERIFY_ACCEPTED_SNAPSHOT(
     I     startTime, nIter0, time1, iter1,
     U     nFail,
     I     myThid )
      _BEGIN_MASTER(myThid)
      bomWindSource = savedWindSource
      _END_MASTER(myThid)
      _BARRIER

C--   A successful retry proves failed scratch data was never accepted.
      CALL BOM_SET_ENDPOINT_FIXTURE(
     I     6. _d 0, 1. _d 0, myThid )
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time2, iter2, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'endpoint transaction recovers after rollback',
     &     nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_VALUES(
     I     time1, iter1, 4. _d 0, -1. _d 0,
     I     time2, iter2, 6. _d 0, 1. _d 0,
     U     nFail,
     I     myThid )

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_VERIFY_ENDPOINT_TRANSACTION: failures=',
     &         globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_ENDPOINT_TRANSACTION'
      ENDIF
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P2.1 ENDPOINT TRANSACTION PASS: fresh, normal, rollback'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SET_ENDPOINT_FIXTURE(
     I                 uValue, vValue, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "DYNVARS.h"
      _RL uValue, vValue
      INTEGER myThid
      INTEGER bi, bj, i, j

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          uVel(i,j,1,bi,bj) = uValue
          vVel(i,j,1,bi,bj) = vValue
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BARRIER

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_CAPTURE_ACCEPTED_ENDPOINTS( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
      INTEGER bi, bj, i, j

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomGridVEast(i,j,1,bi,bj) =
     &         bomEnvEast(i,j,BOM_ENV_OLD,
     &                    BOM_ENV_EULERIAN,bi,bj)
          bomGridVNorth(i,j,1,bi,bj) =
     &         bomEnvNorth(i,j,BOM_ENV_OLD,
     &                     BOM_ENV_EULERIAN,bi,bj)
          bomGridWindEast(i,j,1,bi,bj) =
     &         bomEnvEast(i,j,BOM_ENV_NEW,
     &                    BOM_ENV_EULERIAN,bi,bj)
          bomGridWindNorth(i,j,1,bi,bj) =
     &         bomEnvNorth(i,j,BOM_ENV_NEW,
     &                     BOM_ENV_EULERIAN,bi,bj)
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BARRIER

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_OLD_FROM_NEW_SNAPSHOT(
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nFail, myThid
      INTEGER bi, bj, i, j

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &         bomEnvEast(i,j,BOM_ENV_OLD,
     &                    BOM_ENV_EULERIAN,bi,bj)
     &           .EQ.bomGridWindEast(i,j,1,bi,bj) .AND.
     &         bomEnvNorth(i,j,BOM_ENV_OLD,
     &                     BOM_ENV_EULERIAN,bi,bj)
     &           .EQ.bomGridWindNorth(i,j,1,bi,bj),
     &         'accepted NEW copied exactly to OLD', nFail, myThid )
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_ACCEPTED_SNAPSHOT(
     I                 oldTime, oldIter, newTime, newIter,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL oldTime, newTime
      INTEGER oldIter, newIter, nFail, myThid
      INTEGER bi, bj, i, j, iEnd, iSource
      LOGICAL wetPoint

      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     bomEnvReady .AND.
     &     bomEnvTime(BOM_ENV_OLD).EQ.oldTime .AND.
     &     bomEnvTime(BOM_ENV_NEW).EQ.newTime .AND.
     &     bomEnvIter(BOM_ENV_OLD).EQ.oldIter .AND.
     &     bomEnvIter(BOM_ENV_NEW).EQ.newIter,
     &     'rollback preserves accepted metadata', nFail, myThid )
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &         bomEnvEast(i,j,BOM_ENV_OLD,
     &                    BOM_ENV_EULERIAN,bi,bj)
     &           .EQ.bomGridVEast(i,j,1,bi,bj) .AND.
     &         bomEnvNorth(i,j,BOM_ENV_OLD,
     &                     BOM_ENV_EULERIAN,bi,bj)
     &           .EQ.bomGridVNorth(i,j,1,bi,bj) .AND.
     &         bomEnvEast(i,j,BOM_ENV_NEW,
     &                    BOM_ENV_EULERIAN,bi,bj)
     &           .EQ.bomGridWindEast(i,j,1,bi,bj) .AND.
     &         bomEnvNorth(i,j,BOM_ENV_NEW,
     &                     BOM_ENV_EULERIAN,bi,bj)
     &           .EQ.bomGridWindNorth(i,j,1,bi,bj),
     &         'rollback preserves accepted fields', nFail, myThid )
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &           bomEnvValid(i,j,iEnd,iSource,bi,bj)
     &             .EQV.wetPoint,
     &           'rollback preserves source validity', nFail, myThid )
            IF ( iSource.NE.BOM_ENV_EULERIAN ) THEN
              CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &             bomEnvEast(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0 .AND.
     &             bomEnvNorth(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0,
     &             'rollback preserves NONE source zeros',
     &             nFail, myThid )
            ENDIF
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_ENDPOINT_VALUES(
     I                 oldTime, oldIter, oldU, oldV,
     I                 newTime, newIter, newU, newV,
     U                 nFail,
     I                 myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL oldTime, oldU, oldV, newTime, newU, newV
      INTEGER oldIter, newIter, nFail, myThid
      INTEGER bi, bj, i, j, iEnd, iSource
      _RL uValue, vValue, expectedEast, expectedNorth, tolerance
      LOGICAL wetPoint, validState

      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     bomEnvReady .AND.
     &     bomEnvTime(BOM_ENV_OLD).EQ.oldTime .AND.
     &     bomEnvTime(BOM_ENV_NEW).EQ.newTime .AND.
     &     bomEnvIter(BOM_ENV_OLD).EQ.oldIter .AND.
     &     bomEnvIter(BOM_ENV_NEW).EQ.newIter,
     &     'accepted endpoint labels', nFail, myThid )
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            validState = bomEnvValid(
     &           i,j,iEnd,iSource,bi,bj)
            IF ( wetPoint ) THEN
              CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &             validState .AND.
     &             IEEE_IS_FINITE(bomEnvEast(
     &               i,j,iEnd,iSource,bi,bj)) .AND.
     &             IEEE_IS_FINITE(bomEnvNorth(
     &               i,j,iEnd,iSource,bi,bj)),
     &             'wet endpoint is finite and valid', nFail, myThid )
            ELSE
              CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &             .NOT.validState .AND.
     &             bomEnvEast(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0 .AND.
     &             bomEnvNorth(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0,
     &             'dry endpoint is exact zero and invalid',
     &             nFail, myThid )
            ENDIF
            IF ( iSource.NE.BOM_ENV_EULERIAN ) THEN
              CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &             bomEnvEast(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0 .AND.
     &             bomEnvNorth(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0,
     &             'NONE source publishes exact zero', nFail, myThid )
            ENDIF
           ENDDO
          ENDDO
          IF ( wetPoint .AND. i.GE.1 .AND. i.LE.sNx .AND.
     &         j.GE.1 .AND. j.LE.sNy ) THEN
           DO iEnd=1,BOM_ENV_NEND
            IF ( iEnd.EQ.BOM_ENV_OLD ) THEN
              uValue = oldU
              vValue = oldV
            ELSE
              uValue = newU
              vValue = newV
            ENDIF
            expectedEast = angleCosC(i,j,bi,bj)*uValue
     &                   - angleSinC(i,j,bi,bj)*vValue
            expectedNorth = angleSinC(i,j,bi,bj)*uValue
     &                    + angleCosC(i,j,bi,bj)*vValue
            tolerance = 4096. _d 0*EPSILON(oneRL)*
     &           MAX(oneRL,ABS(expectedEast),ABS(expectedNorth))
            CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &           ABS(bomEnvEast(i,j,iEnd,
     &               BOM_ENV_EULERIAN,bi,bj)-expectedEast)
     &             .LE.tolerance .AND.
     &           ABS(bomEnvNorth(i,j,iEnd,
     &               BOM_ENV_EULERIAN,bi,bj)-expectedNorth)
     &             .LE.tolerance,
     &           'interior ocean endpoint matches rotation oracle',
     &           nFail, myThid )
           ENDDO
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END
