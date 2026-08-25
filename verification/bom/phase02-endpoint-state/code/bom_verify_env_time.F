#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VERIFY_ENV_TIME
C !INTERFACE:
      SUBROUTINE BOM_VERIFY_ENV_TIME( myThid )

C !DESCRIPTION:
C     Component gate for accepted environmental endpoint interpolation.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_VALUE, IEEE_QUIET_NAN
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
      INTEGER bi, bj, iSource, nFail, globalFail
      INTEGER iter0, iter1, savedInt
      _RL time0, time1, midTime, splitTime, snapOffset
      _RL nanValue, savedReal
      _RL oldEast, newEast, oldNorth, newNorth
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
      midTime = time0 + 0.5 _d 0*deltaTClock
      splitTime = time0 + 0.25 _d 0*deltaTClock
      iter0 = nIter0
      iter1 = iter0 + 1
      snapOffset = 4. _d 0*EPSILON(oneRL)
     &     *MAX(oneRL,ABS(time0),ABS(time1),ABS(deltaTClock))
      nanValue = IEEE_VALUE(0. _d 0,IEEE_QUIET_NAN)

      CALL BOM_SET_ENV_TIME_FIXTURE(
     I     time0, time1, iter0, iter1, .FALSE., myThid )
      CALL BOM_CAPTURE_EXF_ACCEPTED(
     O     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     I     myThid )

C--   Each local tile and source exercises exact snaps and two interior
C     stage times.  Exact endpoint values must be copied bitwise.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO iSource=1,BOM_ENV_NSOURCE
          oldEast = 10. _d 0*DFLOAT(iSource)
          newEast = 14. _d 0*DFLOAT(iSource)
          oldNorth = -8. _d 0*DFLOAT(iSource)
          newNorth = -2. _d 0*DFLOAT(iSource)
          CALL BOM_EXPECT_ENV_TIME_SUCCESS(
     I         1, 1, bi, bj, iSource, time0,
     I         oldEast, oldNorth,
     I         (newEast-oldEast)/deltaTClock,
     I         (newNorth-oldNorth)/deltaTClock,
     I         .TRUE., .TRUE.,
     U         nFail,
     I         myThid )
          CALL BOM_EXPECT_ENV_TIME_SUCCESS(
     I         1, 1, bi, bj, iSource, time1,
     I         newEast, newNorth,
     I         (newEast-oldEast)/deltaTClock,
     I         (newNorth-oldNorth)/deltaTClock,
     I         .TRUE., .TRUE.,
     U         nFail,
     I         myThid )
          CALL BOM_EXPECT_ENV_TIME_SUCCESS(
     I         1, 1, bi, bj, iSource, midTime,
     I         0.5 _d 0*(oldEast+newEast),
     I         0.5 _d 0*(oldNorth+newNorth),
     I         (newEast-oldEast)/deltaTClock,
     I         (newNorth-oldNorth)/deltaTClock,
     I         .TRUE., .FALSE.,
     U         nFail,
     I         myThid )
          CALL BOM_EXPECT_ENV_TIME_SUCCESS(
     I         1, 1, bi, bj, iSource, splitTime,
     I         0.75 _d 0*oldEast+0.25 _d 0*newEast,
     I         0.75 _d 0*oldNorth+0.25 _d 0*newNorth,
     I         (newEast-oldEast)/deltaTClock,
     I         (newNorth-oldNorth)/deltaTClock,
     I         .TRUE., .FALSE.,
     U         nFail,
     I         myThid )
          CALL BOM_EXPECT_ENV_TIME_SUCCESS(
     I         1, 1, bi, bj, iSource, time0-snapOffset,
     I         oldEast, oldNorth,
     I         (newEast-oldEast)/deltaTClock,
     I         (newNorth-oldNorth)/deltaTClock,
     I         .TRUE., .TRUE.,
     U         nFail,
     I         myThid )
          CALL BOM_EXPECT_ENV_TIME_SUCCESS(
     I         1, 1, bi, bj, iSource, time1+snapOffset,
     I         newEast, newNorth,
     I         (newEast-oldEast)/deltaTClock,
     I         (newNorth-oldNorth)/deltaTClock,
     I         .TRUE., .TRUE.,
     U         nFail,
     I         myThid )
        ENDDO
        CALL BOM_EXPECT_ENV_TIME_SUCCESS(
     I       2, 2, bi, bj, BOM_ENV_EULERIAN, midTime,
     I       0. _d 0, 0. _d 0, 0. _d 0, 0. _d 0,
     I       .FALSE., .TRUE.,
     U       nFail,
     I       myThid )
       ENDDO
      ENDDO

      bi = myBxLo(myThid)
      bj = myByLo(myThid)
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, BOM_ENV_EULERIAN, time0-1. _d 0,
     I     BOM_FAIL_FIELD_TIME, BOM_STAGE_FIELD_OLD,
     U     nFail,
     I     myThid )
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, BOM_ENV_EULERIAN, time1+1. _d 0,
     I     BOM_FAIL_FIELD_TIME, BOM_STAGE_FIELD_NEW,
     U     nFail,
     I     myThid )
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, BOM_ENV_EULERIAN, nanValue,
     I     BOM_FAIL_FIELD_TIME, BOM_STAGE_FIELD_OLD,
     U     nFail,
     I     myThid )
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, 0, midTime,
     I     BOM_FAIL_FIELD_SOURCE, BOM_STAGE_FIELD_OLD,
     U     nFail,
     I     myThid )

C--   Invalid bracket metadata is classified without changing it.
      savedReal = bomEnvTime(BOM_ENV_OLD)
      bomEnvTime(BOM_ENV_OLD) = time1 + deltaTClock
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, BOM_ENV_EULERIAN, midTime,
     I     BOM_FAIL_FIELD_TIME, BOM_STAGE_FIELD_NEW,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     bomEnvTime(BOM_ENV_OLD).EQ.time1+deltaTClock,
     &     'reversed bracket metadata unchanged', nFail, myThid )
      bomEnvTime(BOM_ENV_OLD) = savedReal

      savedReal = bomEnvTime(BOM_ENV_NEW)
      bomEnvTime(BOM_ENV_NEW) = time0 + 0.5 _d 0*deltaTClock
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, BOM_ENV_EULERIAN, midTime,
     I     BOM_FAIL_FIELD_TIME, BOM_STAGE_FIELD_NEW,
     U     nFail,
     I     myThid )
      bomEnvTime(BOM_ENV_NEW) = savedReal

      savedInt = bomEnvIter(BOM_ENV_NEW)
      bomEnvIter(BOM_ENV_NEW) = iter0 + 2
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, BOM_ENV_EULERIAN, midTime,
     I     BOM_FAIL_FIELD_TIME, BOM_STAGE_FIELD_NEW,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     bomEnvIter(BOM_ENV_NEW).EQ.iter0+2,
     &     'broken iteration metadata unchanged', nFail, myThid )
      bomEnvIter(BOM_ENV_NEW) = savedInt

      savedReal = bomEnvTime(BOM_ENV_OLD)
      bomEnvTime(BOM_ENV_OLD) = nanValue
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, BOM_ENV_EULERIAN, midTime,
     I     BOM_FAIL_FIELD_TIME, BOM_STAGE_FIELD_OLD,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     TRANSFER(bomEnvTime(BOM_ENV_OLD),0_8).EQ.
     &     TRANSFER(nanValue,0_8),
     &     'non-finite OLD metadata unchanged', nFail, myThid )
      bomEnvTime(BOM_ENV_OLD) = savedReal

      savedReal = bomEnvTime(BOM_ENV_NEW)
      bomEnvTime(BOM_ENV_NEW) = nanValue
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, BOM_ENV_EULERIAN, midTime,
     I     BOM_FAIL_FIELD_TIME, BOM_STAGE_FIELD_NEW,
     U     nFail,
     I     myThid )
      bomEnvTime(BOM_ENV_NEW) = savedReal

      bomEnvReady = .FALSE.
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, BOM_ENV_EULERIAN, midTime,
     I     BOM_FAIL_FIELD_TIME, BOM_STAGE_FIELD_OLD,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     .NOT.bomEnvReady, 'unpublished state remains unpublished',
     &     nFail, myThid )
      bomEnvReady = .TRUE.

      CALL BOM_VERIFY_EXF_ACCEPTED_SNAPSHOT(
     I     savedEast, savedNorth, savedValid,
     I     savedTime, savedIter,
     U     nFail,
     I     myThid )

C--   Fresh initialization is a legal single-time bracket only at its
C     duplicated endpoint and has an exactly zero time derivative.
      CALL BOM_SET_ENV_TIME_FIXTURE(
     I     time0, time0, iter0, iter0, .TRUE., myThid )
      CALL BOM_CAPTURE_EXF_ACCEPTED(
     O     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     I     myThid )
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO iSource=1,BOM_ENV_NSOURCE
          oldEast = 10. _d 0*DFLOAT(iSource)
          oldNorth = -8. _d 0*DFLOAT(iSource)
          CALL BOM_EXPECT_ENV_TIME_SUCCESS(
     I         1, 1, bi, bj, iSource, time0,
     I         oldEast, oldNorth, 0. _d 0, 0. _d 0,
     I         .TRUE., .TRUE.,
     U         nFail,
     I         myThid )
        ENDDO
       ENDDO
      ENDDO
      bi = myBxLo(myThid)
      bj = myByLo(myThid)
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, BOM_ENV_EULERIAN, time0-1. _d 0,
     I     BOM_FAIL_FIELD_TIME, BOM_STAGE_FIELD_OLD,
     U     nFail,
     I     myThid )
      CALL BOM_EXPECT_ENV_TIME_FAILURE(
     I     1, 1, bi, bj, BOM_ENV_EULERIAN, time0+1. _d 0,
     I     BOM_FAIL_FIELD_TIME, BOM_STAGE_FIELD_NEW,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_EXF_ACCEPTED_SNAPSHOT(
     I     savedEast, savedNorth, savedValid,
     I     savedTime, savedIter,
     U     nFail,
     I     myThid )

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_VERIFY_ENV_TIME: failed assertions=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_ENV_TIME'
      ENDIF
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P2.1 ENV TIME PASS: snap, linear, secant, '//
     &       'no extrapolation'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SET_ENV_TIME_FIXTURE(
     I                 time0, time1, iter0, iter1, fresh,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL time0, time1, east0, east1, north0, north1
      INTEGER iter0, iter1, myThid
      INTEGER bi, bj, i, j, iSource
      LOGICAL fresh, wetPoint

      _BEGIN_MASTER(myThid)
      bomEnvReady = .FALSE.
      bomEnvTime(BOM_ENV_OLD) = time0
      bomEnvTime(BOM_ENV_NEW) = time1
      bomEnvIter(BOM_ENV_OLD) = iter0
      bomEnvIter(BOM_ENV_NEW) = iter1
      _END_MASTER(myThid)
      _BARRIER
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          wetPoint = .NOT.(i.EQ.2 .AND. j.EQ.2)
          DO iSource=1,BOM_ENV_NSOURCE
            east0 = 10. _d 0*DFLOAT(iSource)
            east1 = 14. _d 0*DFLOAT(iSource)
            north0 = -8. _d 0*DFLOAT(iSource)
            north1 = -2. _d 0*DFLOAT(iSource)
            IF ( fresh ) THEN
              east1 = east0
              north1 = north0
            ENDIF
            IF ( .NOT.wetPoint ) THEN
              east0 = 0. _d 0
              east1 = 0. _d 0
              north0 = 0. _d 0
              north1 = 0. _d 0
            ENDIF
            bomEnvEast(i,j,BOM_ENV_OLD,iSource,bi,bj) = east0
            bomEnvEast(i,j,BOM_ENV_NEW,iSource,bi,bj) = east1
            bomEnvNorth(i,j,BOM_ENV_OLD,iSource,bi,bj) = north0
            bomEnvNorth(i,j,BOM_ENV_NEW,iSource,bi,bj) = north1
            bomEnvValid(i,j,BOM_ENV_OLD,iSource,bi,bj) = wetPoint
            bomEnvValid(i,j,BOM_ENV_NEW,iSource,bi,bj) = wetPoint
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BARRIER
      _BEGIN_MASTER(myThid)
      bomEnvReady = .TRUE.
      _END_MASTER(myThid)
      _BARRIER

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_EXPECT_ENV_TIME_SUCCESS(
     I                 i, j, bi, bj, iSource, stageTime,
     I                 expectedEast, expectedNorth,
     I                 expectedDtEast, expectedDtNorth,
     I                 expectedPointValid, exactValue,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER i, j, bi, bj, iSource, nFail, myThid
      INTEGER failCode, failStage
      _RL stageTime, expectedEast, expectedNorth
      _RL expectedDtEast, expectedDtNorth
      _RL stageEast, stageNorth, dtEast, dtNorth, tol
      LOGICAL expectedPointValid, exactValue
      LOGICAL pointValid, interpValid, valuesGood

      CALL BOM_INTERP_ENV_TIME(
     I     i, j, bi, bj, iSource, stageTime,
     O     stageEast, stageNorth, dtEast, dtNorth, pointValid,
     O     failCode, failStage, interpValid,
     I     myThid )
      tol = 8192. _d 0*EPSILON(oneRL)
     &     *MAX(oneRL,ABS(expectedEast),ABS(expectedNorth),
     &                  ABS(expectedDtEast),ABS(expectedDtNorth))
      IF ( exactValue ) THEN
        valuesGood = TRANSFER(stageEast,0_8).EQ.
     &               TRANSFER(expectedEast,0_8) .AND.
     &               TRANSFER(stageNorth,0_8).EQ.
     &               TRANSFER(expectedNorth,0_8)
      ELSE
        valuesGood = ABS(stageEast-expectedEast).LE.tol .AND.
     &               ABS(stageNorth-expectedNorth).LE.tol
      ENDIF
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     interpValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'environment time interpolation succeeds', nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     pointValid.EQV.expectedPointValid,
     &     'environment stage validity mask', nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     valuesGood .AND.
     &     ABS(dtEast-expectedDtEast).LE.tol .AND.
     &     ABS(dtNorth-expectedDtNorth).LE.tol,
     &     'environment stage values and secant', nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_EXPECT_ENV_TIME_FAILURE(
     I                 i, j, bi, bj, iSource, stageTime,
     I                 expectedCode, expectedStage,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER i, j, bi, bj, iSource, expectedCode, expectedStage
      INTEGER failCode, failStage, nFail, myThid
      _RL stageTime, stageEast, stageNorth, dtEast, dtNorth
      LOGICAL pointValid, interpValid

      CALL BOM_INTERP_ENV_TIME(
     I     i, j, bi, bj, iSource, stageTime,
     O     stageEast, stageNorth, dtEast, dtNorth, pointValid,
     O     failCode, failStage, interpValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     .NOT.interpValid .AND. .NOT.pointValid .AND.
     &     failCode.EQ.expectedCode .AND.
     &     failStage.EQ.expectedStage,
     &     'environment time failure classification', nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     stageEast.EQ.0. _d 0 .AND. stageNorth.EQ.0. _d 0
     &     .AND. dtEast.EQ.0. _d 0 .AND. dtNorth.EQ.0. _d 0,
     &     'environment time failure outputs remain zero',
     &     nFail, myThid )

      RETURN
      END
