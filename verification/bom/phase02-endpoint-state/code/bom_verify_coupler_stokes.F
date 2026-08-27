#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VERIFY_COUPLER_STOKES
C !INTERFACE:
      SUBROUTINE BOM_VERIFY_COUPLER_STOKES( myThid )

C !DESCRIPTION:
C     Test-only P2-E05/P2-N03 compiled COUPLER Stokes transaction gate.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_VALUE, IEEE_QUIET_NAN
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#if defined(ALLOW_BOM) && defined(ALLOW_BOM_STOKES_COUPLER)
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, i, j
      INTEGER nFail, globalFail, failCode, failStage
      INTEGER iter0, iter1, iter2, iter3
      _RL time0, time1, time2, time3
      _RL nanValue
      LOGICAL buildValid, eastValid, northValid
      _RL eastField(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL northField(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL savedEast(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL savedNorth(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL savedTime(BOM_ENV_NEND)
      INTEGER savedIter(BOM_ENV_NEND)
      LOGICAL savedValid(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)

      nFail = 0
      time0 = startTime
      time1 = time0 + deltaTClock
      time2 = time1 + deltaTClock
      time3 = time2 + deltaTClock
      iter0 = nIter0
      iter1 = iter0 + 1
      iter2 = iter1 + 1
      iter3 = iter2 + 1
      nanValue = IEEE_VALUE(0. _d 0, IEEE_QUIET_NAN)

C--   Distinct ocean values and a deterministic dry point on every tile.
      CALL BOM_SET_ENDPOINT_FIXTURE(
     I     2. _d 0, -3. _d 0, myThid )
      CALL BOM_SET_STOKES_DRY_FIXTURE( myThid )
      CALL BOM_CLEAR_COUPLER_STOKES( myThid )

C--   Fresh paired publication is copied; producer mutation cannot alias it.
      CALL BOM_FILL_COUPLER_FIELD(
     O     eastField,
     I     1. _d 0, myThid )
      CALL BOM_FILL_COUPLER_FIELD(
     O     northField,
     I     -2. _d 0, myThid )
      CALL BOM_SET_COUPLER_STOKES(
     I     BOM_COUPLER_EAST, eastField, time0, iter0,
     O     eastValid,
     I     myThid )
      CALL BOM_SET_COUPLER_STOKES(
     I     BOM_COUPLER_NORTH, northField, time0, iter0,
     O     northValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     eastValid .AND. northValid,
     &     'P2-E05 fresh paired publication', nFail, myThid )
      CALL BOM_FILL_COUPLER_FIELD(
     O     eastField,
     I     91. _d 0, myThid )
      CALL BOM_FILL_COUPLER_FIELD(
     O     northField,
     I     -92. _d 0, myThid )
      CALL BOM_VERIFY_COUPLER_STAGING(
     I     time0, iter0, 1. _d 0, -2. _d 0,
     U     nFail,
     I     myThid )
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time0, iter0, .TRUE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'P2-E05 fresh COUPLER transaction', nFail, myThid )
      CALL BOM_VERIFY_COUPLER_ENDPOINT_VALUES(
     I     time0, iter0, 1. _d 0, -2. _d 0,
     I     time0, iter0, 1. _d 0, -2. _d 0,
     U     nFail,
     I     myThid )
      CALL BOM_CAPTURE_EXF_ACCEPTED(
     O     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     I     myThid )

C--   Normal advance shifts accepted NEW to OLD and publishes exact NEW.
      CALL BOM_TEST_PUBLISH_COUPLER_PAIR(
     I     time1, iter1, 3. _d 0, 4. _d 0,
     O     eastField, northField,
     U     nFail,
     I     myThid )
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time1, iter1, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'P2-E05 normal COUPLER transaction', nFail, myThid )
      CALL BOM_VERIFY_EXF_OLD_FROM_SNAPSHOT(
     I     savedEast, savedNorth, savedValid,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_COUPLER_ENDPOINT_VALUES(
     I     time0, iter0, 1. _d 0, -2. _d 0,
     I     time1, iter1, 3. _d 0, 4. _d 0,
     U     nFail,
     I     myThid )
      CALL BOM_CAPTURE_EXF_ACCEPTED(
     O     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     I     myThid )

C--   Missing and partial publications fail with the accepted bracket intact.
      CALL BOM_CLEAR_COUPLER_STOKES( myThid )
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 COUPLER missing pair', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )

      CALL BOM_CLEAR_COUPLER_STOKES( myThid )
      CALL BOM_FILL_COUPLER_FIELD(
     O     eastField,
     I     5. _d 0, myThid )
      CALL BOM_SET_COUPLER_STOKES(
     I     BOM_COUPLER_EAST, eastField, time2, iter2,
     O     eastValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     eastValid,
     &     'P2-N03 COUPLER partial east accepted', nFail, myThid )
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 COUPLER partial pair', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )

C--   Both temporal directions, mixed labels and wrong iteration are fatal.
      CALL BOM_CLEAR_COUPLER_STOKES( myThid )
      CALL BOM_TEST_PUBLISH_COUPLER_PAIR(
     I     time1, iter1, 5. _d 0, 6. _d 0,
     O     eastField, northField,
     U     nFail,
     I     myThid )
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 COUPLER stale labels', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )

      CALL BOM_CLEAR_COUPLER_STOKES( myThid )
      CALL BOM_TEST_PUBLISH_COUPLER_PAIR(
     I     time3, iter3, 5. _d 0, 6. _d 0,
     O     eastField, northField,
     U     nFail,
     I     myThid )
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 COUPLER future labels', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )

      CALL BOM_CLEAR_COUPLER_STOKES( myThid )
      CALL BOM_FILL_COUPLER_FIELD(
     O     eastField,
     I     5. _d 0, myThid )
      CALL BOM_FILL_COUPLER_FIELD(
     O     northField,
     I     6. _d 0, myThid )
      CALL BOM_SET_COUPLER_STOKES(
     I     BOM_COUPLER_EAST, eastField, time2, iter2,
     O     eastValid,
     I     myThid )
      CALL BOM_SET_COUPLER_STOKES(
     I     BOM_COUPLER_NORTH, northField, time3, iter3,
     O     northValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     eastValid .AND. northValid,
     &     'P2-N03 COUPLER mixed labels staged', nFail, myThid )
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 COUPLER mixed labels', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )

      CALL BOM_CLEAR_COUPLER_STOKES( myThid )
      CALL BOM_TEST_PUBLISH_COUPLER_PAIR(
     I     time2, iter1, 5. _d 0, 6. _d 0,
     O     eastField, northField,
     U     nFail,
     I     myThid )
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 COUPLER wrong iteration', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )

C--   Setter rejects non-finite wet data and nonzero dry-point data.
      CALL BOM_CLEAR_COUPLER_STOKES( myThid )
      CALL BOM_FILL_COUPLER_FIELD(
     O     eastField,
     I     5. _d 0, myThid )
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        eastField(1,1,1,bi,bj) = nanValue
       ENDDO
      ENDDO
      CALL BOM_SET_COUPLER_STOKES(
     I     BOM_COUPLER_EAST, eastField, time2, iter2,
     O     eastValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     .NOT.eastValid,
     &     'P2-N03 COUPLER non-finite rejected', nFail, myThid )
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 COUPLER non-finite transaction', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )

      CALL BOM_CLEAR_COUPLER_STOKES( myThid )
      CALL BOM_FILL_COUPLER_FIELD(
     O     eastField,
     I     5. _d 0, myThid )
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        eastField(2,2,1,bi,bj) = 1. _d 0
       ENDDO
      ENDDO
      CALL BOM_SET_COUPLER_STOKES(
     I     BOM_COUPLER_EAST, eastField, time2, iter2,
     O     eastValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     .NOT.eastValid,
     &     'P2-N03 COUPLER dry value rejected', nFail, myThid )
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 COUPLER dry-value transaction', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )

C--   A clean exact pair retries successfully after every failed attempt.
      CALL BOM_CLEAR_COUPLER_STOKES( myThid )
      CALL BOM_TEST_PUBLISH_COUPLER_PAIR(
     I     time2, iter2, 5. _d 0, 6. _d 0,
     O     eastField, northField,
     U     nFail,
     I     myThid )
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time2, iter2, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'P2-E05 clean retry', nFail, myThid )
      CALL BOM_VERIFY_EXF_OLD_FROM_SNAPSHOT(
     I     savedEast, savedNorth, savedValid,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_COUPLER_ENDPOINT_VALUES(
     I     time1, iter1, 3. _d 0, 4. _d 0,
     I     time2, iter2, 5. _d 0, 6. _d 0,
     U     nFail,
     I     myThid )

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_VERIFY_COUPLER_STOKES: failures=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_COUPLER_STOKES'
      ENDIF
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(2A)')
     &       'P2.1 COUPLER STOKES PASS: copied exact pair, ',
     &       'labels, mask, rollback'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_FILL_COUPLER_FIELD(
     O                 componentField,
     I                 wetValue, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
      _RL componentField(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL wetValue
      INTEGER myThid

#ifdef ALLOW_BOM
      INTEGER bi, bj, i, j
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          componentField(i,j,1,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
        DO j=1,sNy
         DO i=1,sNx
          IF ( maskC(i,j,1,bi,bj).GT.0. )
     &         componentField(i,j,1,bi,bj) = wetValue
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BARRIER
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_TEST_PUBLISH_COUPLER_PAIR(
     I                 fieldTime, fieldIter, eastValue, northValue,
     O                 eastField, northField,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL fieldTime, eastValue, northValue
      INTEGER fieldIter, nFail, myThid
      _RL eastField(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL northField(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      LOGICAL eastValid, northValid

      CALL BOM_FILL_COUPLER_FIELD(
     O     eastField,
     I     eastValue, myThid )
      CALL BOM_FILL_COUPLER_FIELD(
     O     northField,
     I     northValue, myThid )
      CALL BOM_SET_COUPLER_STOKES(
     I     BOM_COUPLER_EAST, eastField, fieldTime, fieldIter,
     O     eastValid,
     I     myThid )
      CALL BOM_SET_COUPLER_STOKES(
     I     BOM_COUPLER_NORTH, northField, fieldTime, fieldIter,
     O     northValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     eastValid .AND. northValid,
     &     'COUPLER pair staged', nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_COUPLER_STAGING(
     I                 fieldTime, fieldIter, eastExpected,
     I                 northExpected,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL fieldTime, eastExpected, northExpected
      INTEGER fieldIter, nFail, myThid
      INTEGER bi, bj, i, j
      LOGICAL condition

      condition = bomCouplerStokesReady(BOM_COUPLER_EAST) .AND.
     &            bomCouplerStokesReady(BOM_COUPLER_NORTH) .AND.
     &            bomCouplerStokesTime(BOM_COUPLER_EAST)
     &              .EQ.fieldTime .AND.
     &            bomCouplerStokesTime(BOM_COUPLER_NORTH)
     &              .EQ.fieldTime .AND.
     &            bomCouplerStokesIter(BOM_COUPLER_EAST)
     &              .EQ.fieldIter .AND.
     &            bomCouplerStokesIter(BOM_COUPLER_NORTH)
     &              .EQ.fieldIter
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          IF ( maskC(i,j,1,bi,bj).GT.0. ) THEN
            condition = condition .AND.
     &           bomCouplerStokesEast(i,j,1,bi,bj)
     &             .EQ.eastExpected .AND.
     &           bomCouplerStokesNorth(i,j,1,bi,bj)
     &             .EQ.northExpected
          ELSE
            condition = condition .AND.
     &           bomCouplerStokesEast(i,j,1,bi,bj).EQ.0. _d 0
     &           .AND.
     &           bomCouplerStokesNorth(i,j,1,bi,bj).EQ.0. _d 0
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     condition, 'P2-E05 copied staging is immutable',
     &     nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_COUPLER_ENDPOINT_VALUES(
     I                 oldTime, oldIter, oldEast, oldNorth,
     I                 newTime, newIter, newEast, newNorth,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL oldTime, oldEast, oldNorth
      _RL newTime, newEast, newNorth
      INTEGER oldIter, newIter, nFail, myThid
      INTEGER bi, bj, i, j, iEnd
      _RL expectedEast, expectedNorth
      LOGICAL condition

      condition = bomEnvReady .AND.
     &            bomEnvTime(BOM_ENV_OLD).EQ.oldTime .AND.
     &            bomEnvTime(BOM_ENV_NEW).EQ.newTime .AND.
     &            bomEnvIter(BOM_ENV_OLD).EQ.oldIter .AND.
     &            bomEnvIter(BOM_ENV_NEW).EQ.newIter
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          DO iEnd=1,BOM_ENV_NEND
            IF ( iEnd.EQ.BOM_ENV_OLD ) THEN
              expectedEast = oldEast
              expectedNorth = oldNorth
            ELSE
              expectedEast = newEast
              expectedNorth = newNorth
            ENDIF
            IF ( maskC(i,j,1,bi,bj).LE.0. ) THEN
              expectedEast = 0. _d 0
              expectedNorth = 0. _d 0
            ENDIF
            condition = condition .AND.
     &           bomEnvValid(i,j,iEnd,BOM_ENV_STOKES,bi,bj)
     &           .EQV.(maskC(i,j,1,bi,bj).GT.0.)
            condition = condition .AND.
     &           bomEnvEast(i,j,iEnd,BOM_ENV_STOKES,bi,bj)
     &             .EQ.expectedEast .AND.
     &           bomEnvNorth(i,j,iEnd,BOM_ENV_STOKES,bi,bj)
     &             .EQ.expectedNorth
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     condition, 'P2-E05 exact accepted COUPLER endpoints',
     &     nFail, myThid )

      RETURN
      END
