#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VERIFY_STOKES_FILES
C !INTERFACE:
      SUBROUTINE BOM_VERIFY_STOKES_FILES( myThid )

C !DESCRIPTION:
C     Test-only P2-E04/P2-N03 exact-time FILES Stokes transaction gate.

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
      CHARACTER*(MAX_LEN_FNAM) savedUFile, savedVFile
      INTEGER nFail, globalFail, failCode, failStage
      INTEGER iter0, iter1, iter2, iter3, iter4, iter5
      _RL time0, time1, time2, time3, time4, time5
      _RL savedStart, savedRepCycle
      LOGICAL buildValid
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
      time4 = time3 + deltaTClock
      time5 = time4 + deltaTClock
      iter0 = nIter0
      iter1 = iter0 + 1
      iter2 = iter1 + 1
      iter3 = iter2 + 1
      iter4 = iter3 + 1
      iter5 = iter4 + 1
      savedUFile = bomUStokesFile
      savedVFile = bomVStokesFile
      savedStart = bomStokesStartTime
      savedRepCycle = bomStokesRepCycle

C--   Distinct ocean fixture plus deterministic dry C points on every tile.
      CALL BOM_SET_ENDPOINT_FIXTURE(
     I     2. _d 0, -3. _d 0, myThid )
      CALL BOM_SET_STOKES_DRY_FIXTURE( myThid )

C--   Fresh endpoint is an exact record and is duplicated into OLD/NEW.
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time0, iter0, .TRUE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'P2-E04 fresh FILES transaction', nFail, myThid )
      CALL BOM_VERIFY_STOKES_ENDPOINT_VALUES(
     I     time0, iter0, 2. _d 0, -4. _d 0,
     I     time0, iter0, 2. _d 0, -4. _d 0,
     U     nFail,
     I     myThid )
      CALL BOM_CAPTURE_EXF_ACCEPTED(
     O     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     I     myThid )

C--   The 1200 s model step is not aligned with 1800 s file records.
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time1, iter1, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'P2-E04 interpolated FILES transaction', nFail, myThid )
      CALL BOM_VERIFY_EXF_OLD_FROM_SNAPSHOT(
     I     savedEast, savedNorth, savedValid,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_STOKES_ENDPOINT_VALUES(
     I     time0, iter0, 2. _d 0, -4. _d 0,
     I     time1, iter1, 6. _d 0, 0. _d 0,
     U     nFail,
     I     myThid )
      CALL BOM_CAPTURE_EXF_ACCEPTED(
     O     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     I     myThid )

C--   P2-N03 failures must leave the full accepted bracket bitwise intact.
      _BEGIN_MASTER(myThid)
      bomUStokesFile = 'ustokes-missing.bin'
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 Stokes missing file', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_STOKES_CONFIG(
     I     savedUFile, savedVFile, savedStart, savedRepCycle,
     I     myThid )

      _BEGIN_MASTER(myThid)
      bomUStokesFile = ' '
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 Stokes unpaired files', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_STOKES_CONFIG(
     I     savedUFile, savedVFile, savedStart, savedRepCycle,
     I     myThid )

      _BEGIN_MASTER(myThid)
      bomUStokesFile = 'ustokes-partial.bin'
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 Stokes partial record', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_STOKES_CONFIG(
     I     savedUFile, savedVFile, savedStart, savedRepCycle,
     I     myThid )

      _BEGIN_MASTER(myThid)
      bomStokesStartTime = 3600. _d 0
      bomStokesRepCycle = 0. _d 0
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 Stokes future time', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_STOKES_CONFIG(
     I     savedUFile, savedVFile, savedStart, savedRepCycle,
     I     myThid )

      _BEGIN_MASTER(myThid)
      bomVStokesFile = 'vstokes-short.bin'
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 Stokes stale coverage', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_STOKES_CONFIG(
     I     savedUFile, savedVFile, savedStart, savedRepCycle,
     I     myThid )

      _BEGIN_MASTER(myThid)
      bomUStokesFile = 'ustokes-nan.bin'
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 Stokes non-finite record', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_STOKES_CONFIG(
     I     savedUFile, savedVFile, savedStart, savedRepCycle,
     I     myThid )

      _BEGIN_MASTER(myThid)
      bomStokesRepCycle = 5000. _d 0
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I     'P2-N03 Stokes invalid repeat cycle', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_STOKES_CONFIG(
     I     savedUFile, savedVFile, savedStart, savedRepCycle,
     I     myThid )

C--   Clean retry and subsequent endpoints cross the periodic seam.
      CALL BOM_ADVANCE_STOKES_ENDPOINT(
     I     time2, iter2, 10. _d 0, 4. _d 0,
     I     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_ADVANCE_STOKES_ENDPOINT(
     I     time3, iter3, 14. _d 0, 8. _d 0,
     I     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_ADVANCE_STOKES_ENDPOINT(
     I     time4, iter4, 6. _d 0, 0. _d 0,
     I     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_ADVANCE_STOKES_ENDPOINT(
     I     time5, iter5, 4. _d 0, -2. _d 0,
     I     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     U     nFail,
     I     myThid )

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_VERIFY_STOKES_FILES: failures=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_STOKES_FILES'
      ENDIF
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(2A)')
     &       'P2.1 STOKES FILES PASS: exact values, ',
     &       'repeat cycle, mask, rollback'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SET_STOKES_DRY_FIXTURE( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
      INTEGER myThid

#ifdef ALLOW_BOM
      INTEGER bi, bj
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        maskC(2,2,1,bi,bj) = 0.
       ENDDO
      ENDDO
      _BARRIER
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_EXPECT_STOKES_SOURCE_FAILURE(
     I                 caseLabel, targetTime, targetIter,
     I                 savedEast, savedNorth, savedValid,
     I                 savedTime, savedIter,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) caseLabel
      _RL targetTime
      INTEGER targetIter, nFail, myThid
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
      INTEGER failCode, failStage
      LOGICAL buildValid

      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     targetTime, targetIter, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     .NOT.buildValid .AND.
     &     failCode.EQ.BOM_FAIL_FIELD_SOURCE .AND.
     &     failStage.EQ.BOM_STAGE_FIELD_NEW,
     &     caseLabel, nFail, myThid )
      CALL BOM_VERIFY_EXF_ACCEPTED_SNAPSHOT(
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_RESTORE_STOKES_CONFIG(
     I                 savedUFile, savedVFile,
     I                 savedStart, savedRepCycle, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(MAX_LEN_FNAM) savedUFile, savedVFile
      _RL savedStart, savedRepCycle
      INTEGER myThid

      _BEGIN_MASTER(myThid)
      bomUStokesFile = savedUFile
      bomVStokesFile = savedVFile
      bomStokesStartTime = savedStart
      bomStokesRepCycle = savedRepCycle
      _END_MASTER(myThid)
      _BARRIER

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_ADVANCE_STOKES_ENDPOINT(
     I                 targetTime, targetIter, expectedU, expectedV,
     U                 savedEast, savedNorth, savedValid,
     O                 savedTime, savedIter,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL targetTime, expectedU, expectedV
      INTEGER targetIter, nFail, myThid
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
      INTEGER failCode, failStage
      LOGICAL buildValid

      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     targetTime, targetIter, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'P2-E04 periodic FILES advance', nFail, myThid )
      CALL BOM_VERIFY_EXF_OLD_FROM_SNAPSHOT(
     I     savedEast, savedNorth, savedValid,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_STOKES_NEW_VALUE(
     I     targetTime, targetIter, expectedU, expectedV,
     U     nFail,
     I     myThid )
      CALL BOM_CAPTURE_EXF_ACCEPTED(
     O     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     I     myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_STOKES_ENDPOINT_VALUES(
     I                 oldTime, oldIter, oldU, oldV,
     I                 newTime, newIter, newU, newV,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL oldTime, oldU, oldV, newTime, newU, newV
      INTEGER oldIter, newIter, nFail, myThid

      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     bomEnvReady .AND.
     &     bomEnvTime(BOM_ENV_OLD).EQ.oldTime .AND.
     &     bomEnvTime(BOM_ENV_NEW).EQ.newTime .AND.
     &     bomEnvIter(BOM_ENV_OLD).EQ.oldIter .AND.
     &     bomEnvIter(BOM_ENV_NEW).EQ.newIter,
     &     'FILES Stokes accepted endpoint labels', nFail, myThid )
      CALL BOM_VERIFY_STOKES_VALUE(
     I     BOM_ENV_OLD, oldU, oldV, nFail, myThid )
      CALL BOM_VERIFY_STOKES_VALUE(
     I     BOM_ENV_NEW, newU, newV, nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_STOKES_NEW_VALUE(
     I                 targetTime, targetIter, expectedU, expectedV,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL targetTime, expectedU, expectedV
      INTEGER targetIter, nFail, myThid

      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     bomEnvReady .AND.
     &     bomEnvTime(BOM_ENV_NEW).EQ.targetTime .AND.
     &     bomEnvIter(BOM_ENV_NEW).EQ.targetIter,
     &     'periodic FILES endpoint label', nFail, myThid )
      CALL BOM_VERIFY_STOKES_VALUE(
     I     BOM_ENV_NEW, expectedU, expectedV, nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_STOKES_VALUE(
     I                 iEnd, expectedU, expectedV, nFail, myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER iEnd, nFail, myThid
      _RL expectedU, expectedV
      INTEGER bi, bj, i, j, iSource
      _RL expectedEast, expectedNorth, tolerance
      LOGICAL wetPoint, validState

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          DO iSource=1,BOM_ENV_NSOURCE
            validState = bomEnvValid(i,j,iEnd,iSource,bi,bj)
            IF ( wetPoint ) THEN
              CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &             validState .AND.
     &             IEEE_IS_FINITE(bomEnvEast(
     &               i,j,iEnd,iSource,bi,bj)) .AND.
     &             IEEE_IS_FINITE(bomEnvNorth(
     &               i,j,iEnd,iSource,bi,bj)),
     &             'FILES wet endpoint finite and valid',
     &             nFail, myThid )
            ELSE
              CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &             .NOT.validState .AND.
     &             bomEnvEast(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0 .AND.
     &             bomEnvNorth(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0,
     &             'FILES dry endpoint exact zero and invalid',
     &             nFail, myThid )
            ENDIF
          ENDDO

          CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &         bomEnvEast(i,j,iEnd,BOM_ENV_WIND,bi,bj)
     &           .EQ.0. _d 0 .AND.
     &         bomEnvNorth(i,j,iEnd,BOM_ENV_WIND,bi,bj)
     &           .EQ.0. _d 0,
     &         'wind NONE endpoint exact zero', nFail, myThid )

          IF ( wetPoint .AND. i.GE.1 .AND. i.LE.sNx .AND.
     &         j.GE.1 .AND. j.LE.sNy ) THEN
            expectedEast = angleCosC(i,j,bi,bj)*expectedU
     &                   - angleSinC(i,j,bi,bj)*expectedV
            expectedNorth = angleSinC(i,j,bi,bj)*expectedU
     &                    + angleCosC(i,j,bi,bj)*expectedV
            tolerance = 8192. _d 0*EPSILON(oneRL)*
     &           MAX(oneRL,ABS(expectedEast),ABS(expectedNorth))
            CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &           ABS(bomEnvEast(i,j,iEnd,
     &             BOM_ENV_STOKES,bi,bj)-expectedEast)
     &             .LE.tolerance .AND.
     &           ABS(bomEnvNorth(i,j,iEnd,
     &             BOM_ENV_STOKES,bi,bj)-expectedNorth)
     &             .LE.tolerance,
     &           'FILES Stokes matches independent oracle',
     &           nFail, myThid )

            expectedEast = angleCosC(i,j,bi,bj)*2. _d 0
     &                   + angleSinC(i,j,bi,bj)*3. _d 0
            expectedNorth = angleSinC(i,j,bi,bj)*2. _d 0
     &                    - angleCosC(i,j,bi,bj)*3. _d 0
            CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &           ABS(bomEnvEast(i,j,iEnd,
     &             BOM_ENV_EULERIAN,bi,bj)-expectedEast)
     &             .LE.tolerance .AND.
     &           ABS(bomEnvNorth(i,j,iEnd,
     &             BOM_ENV_EULERIAN,bi,bj)-expectedNorth)
     &             .LE.tolerance,
     &           'ocean provider remains independent of Stokes',
     &           nFail, myThid )
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END
