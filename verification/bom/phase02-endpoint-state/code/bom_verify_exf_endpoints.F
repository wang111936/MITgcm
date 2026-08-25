#include "BOM_OPTIONS.h"

#ifdef ALLOW_EXF
# include "EXF_OPTIONS.h"
#endif

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VERIFY_EXF_ENDPOINTS
C !INTERFACE:
      SUBROUTINE BOM_VERIFY_EXF_ENDPOINTS( myThid )

C !DESCRIPTION:
C     Test-only P2-E03/P2-N03 exact-time EXF endpoint transaction gate.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
#ifdef ALLOW_EXF
# include "EXF_PARAM.h"
# include "EXF_FIELDS.h"
#endif

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#if defined(ALLOW_BOM) && defined(ALLOW_EXF)
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*128 savedUFile, savedVFile
      INTEGER nFail, globalFail, failCode, failStage
      INTEGER iter0, iter1, iter2
      _RL time0, time1, time2
      _RL savedUStart, savedVStart
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
      iter0 = nIter0
      iter1 = iter0 + 1
      iter2 = iter1 + 1
      savedUFile = uwindfile
      savedVFile = vwindfile
      savedUStart = uwindStartTime
      savedVStart = vwindStartTime

C--   EXF globals become sentinels before any BOM-owned provider request.
      CALL BOM_SET_ENDPOINT_FIXTURE(
     I     2. _d 0, -3. _d 0, myThid )
      CALL BOM_SET_EXF_GLOBAL_SENTINELS( myThid )

C--   Fresh publication evaluates t=0 and duplicates the exact endpoint.
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time0, iter0, .TRUE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'P2-E03 fresh EXF transaction', nFail, myThid )
      CALL BOM_VERIFY_EXF_ENDPOINT_VALUES(
     I     time0, iter0, 1. _d 0, -2. _d 0,
     I     time0, iter0, 1. _d 0, -2. _d 0,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_EXF_GLOBAL_SENTINELS( nFail, myThid )
      CALL BOM_CAPTURE_EXF_ACCEPTED(
     O     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     I     myThid )

C--   Ocean step is 1200 s while EXF records are spaced by 1800 s.
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time1, iter1, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'P2-E03 normal EXF transaction', nFail, myThid )
      CALL BOM_VERIFY_EXF_OLD_FROM_SNAPSHOT(
     I     savedEast, savedNorth, savedValid,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_EXF_ENDPOINT_VALUES(
     I     time0, iter0, 1. _d 0, -2. _d 0,
     I     time1, iter1, 3. _d 0, 0. _d 0,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_EXF_GLOBAL_SENTINELS( nFail, myThid )
      CALL BOM_CAPTURE_EXF_ACCEPTED(
     O     savedEast, savedNorth, savedValid,
     O     savedTime, savedIter,
     I     myThid )

C--   P2-N03: every provider failure must preserve the accepted bracket.
      _BEGIN_MASTER(myThid)
      uwindfile = 'uwind-missing.bin'
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_EXF_SOURCE_FAILURE(
     I     'P2-N03 missing file', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_EXF_CONFIG(
     I     savedUFile, savedVFile, savedUStart, savedVStart, myThid )

      _BEGIN_MASTER(myThid)
      uwindfile = ' '
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_EXF_SOURCE_FAILURE(
     I     'P2-N03 unpaired files', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_EXF_CONFIG(
     I     savedUFile, savedVFile, savedUStart, savedVStart, myThid )

      _BEGIN_MASTER(myThid)
      uwindfile = 'uwind-partial.bin'
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_EXF_SOURCE_FAILURE(
     I     'P2-N03 partial record', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_EXF_CONFIG(
     I     savedUFile, savedVFile, savedUStart, savedVStart, myThid )

      _BEGIN_MASTER(myThid)
      uwindStartTime = 3600. _d 0
      vwindStartTime = 3600. _d 0
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_EXF_SOURCE_FAILURE(
     I     'P2-N03 future uncovered time', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_EXF_CONFIG(
     I     savedUFile, savedVFile, savedUStart, savedVStart, myThid )

      _BEGIN_MASTER(myThid)
      vwindfile = 'vwind-short.bin'
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_EXF_SOURCE_FAILURE(
     I     'P2-N03 stale coverage', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_EXF_CONFIG(
     I     savedUFile, savedVFile, savedUStart, savedVStart, myThid )

      _BEGIN_MASTER(myThid)
      uwindfile = 'uwind-nan.bin'
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_EXPECT_EXF_SOURCE_FAILURE(
     I     'P2-N03 non-finite record', time2, iter2,
     I     savedEast, savedNorth, savedValid, savedTime, savedIter,
     U     nFail,
     I     myThid )
      CALL BOM_RESTORE_EXF_CONFIG(
     I     savedUFile, savedVFile, savedUStart, savedVStart, myThid )

C--   A clean retry proves failed work arrays were never published.
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time2, iter2, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE,
     &     'P2-E03 retry after rollback', nFail, myThid )
      CALL BOM_VERIFY_EXF_OLD_FROM_SNAPSHOT(
     I     savedEast, savedNorth, savedValid,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_EXF_ENDPOINT_VALUES(
     I     time1, iter1, 3. _d 0, 0. _d 0,
     I     time2, iter2, 5. _d 0, 2. _d 0,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_EXF_GLOBAL_SENTINELS( nFail, myThid )

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_VERIFY_EXF_ENDPOINTS: failures=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_EXF_ENDPOINTS'
      ENDIF
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(2A)')
     &       'P2.1 EXF ENDPOINT PASS: exact values, ',
     &       'immutable globals, rollback'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SET_EXF_GLOBAL_SENTINELS( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#ifdef ALLOW_EXF
# include "EXF_FIELDS.h"
#endif
      INTEGER myThid

#ifdef ALLOW_EXF
      INTEGER bi, bj, i, j
      _RL BOM_EXF_SENTINEL_VALUE
      EXTERNAL BOM_EXF_SENTINEL_VALUE

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          uwind(i,j,bi,bj) =
     &         BOM_EXF_SENTINEL_VALUE(1,i,j,bi,bj)
          vwind(i,j,bi,bj) =
     &         BOM_EXF_SENTINEL_VALUE(2,i,j,bi,bj)
          uwind0(i,j,bi,bj) =
     &         BOM_EXF_SENTINEL_VALUE(3,i,j,bi,bj)
          uwind1(i,j,bi,bj) =
     &         BOM_EXF_SENTINEL_VALUE(4,i,j,bi,bj)
          vwind0(i,j,bi,bj) =
     &         BOM_EXF_SENTINEL_VALUE(5,i,j,bi,bj)
          vwind1(i,j,bi,bj) =
     &         BOM_EXF_SENTINEL_VALUE(6,i,j,bi,bj)
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BARRIER
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_EXF_GLOBAL_SENTINELS(
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#ifdef ALLOW_EXF
# include "EXF_FIELDS.h"
#endif
      INTEGER nFail, myThid

#ifdef ALLOW_EXF
      INTEGER bi, bj, i, j
      _RL BOM_EXF_SENTINEL_VALUE
      LOGICAL unchanged
      EXTERNAL BOM_EXF_SENTINEL_VALUE

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          unchanged =
     &      TRANSFER(uwind(i,j,bi,bj),0_8).EQ.TRANSFER(
     &        BOM_EXF_SENTINEL_VALUE(1,i,j,bi,bj),0_8) .AND.
     &      TRANSFER(vwind(i,j,bi,bj),0_8).EQ.TRANSFER(
     &        BOM_EXF_SENTINEL_VALUE(2,i,j,bi,bj),0_8) .AND.
     &      TRANSFER(uwind0(i,j,bi,bj),0_8).EQ.TRANSFER(
     &        BOM_EXF_SENTINEL_VALUE(3,i,j,bi,bj),0_8) .AND.
     &      TRANSFER(uwind1(i,j,bi,bj),0_8).EQ.TRANSFER(
     &        BOM_EXF_SENTINEL_VALUE(4,i,j,bi,bj),0_8) .AND.
     &      TRANSFER(vwind0(i,j,bi,bj),0_8).EQ.TRANSFER(
     &        BOM_EXF_SENTINEL_VALUE(5,i,j,bi,bj),0_8) .AND.
     &      TRANSFER(vwind1(i,j,bi,bj),0_8).EQ.TRANSFER(
     &        BOM_EXF_SENTINEL_VALUE(6,i,j,bi,bj),0_8)
          CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &         unchanged, 'EXF globals bitwise unchanged',
     &         nFail, myThid )
         ENDDO
        ENDDO
       ENDDO
      ENDDO
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      _RL FUNCTION BOM_EXF_SENTINEL_VALUE(
     I                 selector, i, j, bi, bj )

      IMPLICIT NONE
      INTEGER selector, i, j, bi, bj

      BOM_EXF_SENTINEL_VALUE = 100000. _d 0*selector
     &     + 1000. _d 0*bj + 100. _d 0*bi
     &     + 10. _d 0*j + i

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_CAPTURE_EXF_ACCEPTED(
     O                 savedEast, savedNorth, savedValid,
     O                 savedTime, savedIter,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL savedEast(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL savedNorth(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL savedTime(BOM_ENV_NEND)
      INTEGER savedIter(BOM_ENV_NEND), myThid
      LOGICAL savedValid(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      INTEGER bi, bj, i, j, iEnd, iSource

      DO iEnd=1,BOM_ENV_NEND
        savedTime(iEnd) = bomEnvTime(iEnd)
        savedIter(iEnd) = bomEnvIter(iEnd)
      ENDDO
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            savedEast(i,j,iEnd,iSource,bi,bj) =
     &           bomEnvEast(i,j,iEnd,iSource,bi,bj)
            savedNorth(i,j,iEnd,iSource,bi,bj) =
     &           bomEnvNorth(i,j,iEnd,iSource,bi,bj)
            savedValid(i,j,iEnd,iSource,bi,bj) =
     &           bomEnvValid(i,j,iEnd,iSource,bi,bj)
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_EXF_ACCEPTED_SNAPSHOT(
     I                 savedEast, savedNorth, savedValid,
     I                 savedTime, savedIter,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL savedEast(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL savedNorth(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL savedTime(BOM_ENV_NEND)
      INTEGER savedIter(BOM_ENV_NEND), nFail, myThid
      LOGICAL savedValid(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      INTEGER bi, bj, i, j, iEnd, iSource
      LOGICAL unchanged

      unchanged = bomEnvReady
      DO iEnd=1,BOM_ENV_NEND
        unchanged = unchanged .AND.
     &       TRANSFER(bomEnvTime(iEnd),0_8).EQ.
     &       TRANSFER(savedTime(iEnd),0_8) .AND.
     &       bomEnvIter(iEnd).EQ.savedIter(iEnd)
      ENDDO
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     unchanged, 'rollback metadata bitwise unchanged',
     &     nFail, myThid )
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            unchanged =
     &        TRANSFER(bomEnvEast(
     &          i,j,iEnd,iSource,bi,bj),0_8).EQ.
     &        TRANSFER(savedEast(
     &          i,j,iEnd,iSource,bi,bj),0_8) .AND.
     &        TRANSFER(bomEnvNorth(
     &          i,j,iEnd,iSource,bi,bj),0_8).EQ.
     &        TRANSFER(savedNorth(
     &          i,j,iEnd,iSource,bi,bj),0_8) .AND.
     &        (bomEnvValid(i,j,iEnd,iSource,bi,bj)
     &          .EQV.savedValid(i,j,iEnd,iSource,bi,bj))
            CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &           unchanged, 'rollback fields bitwise unchanged',
     &           nFail, myThid )
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_EXF_OLD_FROM_SNAPSHOT(
     I                 savedEast, savedNorth, savedValid,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL savedEast(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      _RL savedNorth(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      LOGICAL savedValid(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      INTEGER nFail, myThid
      INTEGER bi, bj, i, j, iSource
      LOGICAL unchanged

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          DO iSource=1,BOM_ENV_NSOURCE
            unchanged =
     &        TRANSFER(bomEnvEast(i,j,BOM_ENV_OLD,
     &          iSource,bi,bj),0_8).EQ.
     &        TRANSFER(savedEast(i,j,BOM_ENV_NEW,
     &          iSource,bi,bj),0_8) .AND.
     &        TRANSFER(bomEnvNorth(i,j,BOM_ENV_OLD,
     &          iSource,bi,bj),0_8).EQ.
     &        TRANSFER(savedNorth(i,j,BOM_ENV_NEW,
     &          iSource,bi,bj),0_8) .AND.
     &        (bomEnvValid(i,j,BOM_ENV_OLD,iSource,bi,bj)
     &          .EQV.savedValid(i,j,BOM_ENV_NEW,iSource,bi,bj))
            CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &           unchanged, 'accepted NEW copied bitwise to OLD',
     &           nFail, myThid )
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_EXPECT_EXF_SOURCE_FAILURE(
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
      CALL BOM_VERIFY_EXF_GLOBAL_SENTINELS( nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_RESTORE_EXF_CONFIG(
     I                 savedUFile, savedVFile,
     I                 savedUStart, savedVStart, myThid )

      IMPLICIT NONE
#include "EEPARAMS.h"
#ifdef ALLOW_EXF
# include "EXF_PARAM.h"
#endif
      CHARACTER*128 savedUFile, savedVFile
      _RL savedUStart, savedVStart
      INTEGER myThid

#ifdef ALLOW_EXF
      _BEGIN_MASTER(myThid)
      uwindfile = savedUFile
      vwindfile = savedVFile
      uwindStartTime = savedUStart
      vwindStartTime = savedVStart
      _END_MASTER(myThid)
      _BARRIER
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_EXF_ENDPOINT_VALUES(
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
      _RL windU, windV, expectedEast, expectedNorth, tolerance
      LOGICAL wetPoint, validState

      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     bomEnvReady .AND.
     &     bomEnvTime(BOM_ENV_OLD).EQ.oldTime .AND.
     &     bomEnvTime(BOM_ENV_NEW).EQ.newTime .AND.
     &     bomEnvIter(BOM_ENV_OLD).EQ.oldIter .AND.
     &     bomEnvIter(BOM_ENV_NEW).EQ.newIter,
     &     'EXF accepted endpoint labels', nFail, myThid )
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
     &             'EXF wet endpoint finite and valid',
     &             nFail, myThid )
            ELSE
              CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &             .NOT.validState .AND.
     &             bomEnvEast(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0 .AND.
     &             bomEnvNorth(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0,
     &             'EXF dry endpoint exact zero and invalid',
     &             nFail, myThid )
            ENDIF
            IF ( iSource.EQ.BOM_ENV_STOKES ) THEN
              CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &             bomEnvEast(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0 .AND.
     &             bomEnvNorth(i,j,iEnd,iSource,bi,bj)
     &               .EQ.0. _d 0,
     &             'Stokes NONE endpoint exact zero',
     &             nFail, myThid )
            ENDIF
           ENDDO
          ENDDO

          IF ( wetPoint .AND. i.GE.1 .AND. i.LE.sNx .AND.
     &         j.GE.1 .AND. j.LE.sNy ) THEN
           DO iEnd=1,BOM_ENV_NEND
            IF ( iEnd.EQ.BOM_ENV_OLD ) THEN
              windU = oldU
              windV = oldV
            ELSE
              windU = newU
              windV = newV
            ENDIF
            expectedEast = angleCosC(i,j,bi,bj)*windU
     &                   - angleSinC(i,j,bi,bj)*windV
            expectedNorth = angleSinC(i,j,bi,bj)*windU
     &                    + angleCosC(i,j,bi,bj)*windV
            tolerance = 8192. _d 0*EPSILON(oneRL)*
     &           MAX(oneRL,ABS(expectedEast),ABS(expectedNorth))
            CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &           ABS(bomEnvEast(i,j,iEnd,BOM_ENV_WIND,bi,bj)
     &             -expectedEast).LE.tolerance .AND.
     &           ABS(bomEnvNorth(i,j,iEnd,BOM_ENV_WIND,bi,bj)
     &             -expectedNorth).LE.tolerance,
     &           'exact-time EXF wind matches independent oracle',
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
     &           'ocean exact-time provider remains independent',
     &           nFail, myThid )
           ENDDO
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END
