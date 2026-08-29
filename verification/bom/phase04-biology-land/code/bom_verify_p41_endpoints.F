#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P41_ENDPOINTS( useFiles, myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_VALUE, IEEE_QUIET_NAN
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "DYNVARS.h"
#include "GRID.h"
#ifdef ALLOW_PTRACERS
# include "PTRACERS_SIZE.h"
# include "PTRACERS_FIELDS.h"
#endif
#include "BOM_SIZE.h"
#include "BOM.h"
      LOGICAL useFiles
      INTEGER myThid
#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER nFail, globalFail, failCode, failStage
      INTEGER iter1, iter2
      _RL time1, time2, expectedN0, expectedN1, expectedN2
      LOGICAL buildValid

      nFail = 0
      expectedN0 = 2. _d 0
      expectedN1 = 4. _d 0
      expectedN2 = 6. _d 0
      IF ( useFiles ) THEN
        expectedN0 = 1. _d 0
        expectedN1 = 2. _d 0
        expectedN2 = 1. _d 0
      ENDIF

C--   Fresh OLD=NEW publication and one-level surface shape.
      CALL BOM_SET_P41_FIELDS(
     I     10. _d 0, 100. _d 0, 2. _d 0, myThid )
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     startTime, nIter0, .TRUE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE .AND. bomBioReady,
     &     'fresh biology endpoint publication', nFail, myThid )
      CALL BOM_CHECK_P41_ENDPOINT_VALUES(
     I     startTime, nIter0, 10. _d 0, expectedN0,
     I     startTime, nIter0, 10. _d 0, expectedN0,
     U     nFail,
     I     myThid )

C--   Normal advance moves accepted NEW to OLD in the same transaction.
      time1 = startTime+deltaTClock
      iter1 = nIter0+1
      CALL BOM_SET_P41_FIELDS(
     I     14. _d 0, -200. _d 0, 4. _d 0, myThid )
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time1, iter1, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE,
     &     'normal biology endpoint advance', nFail, myThid )
      CALL BOM_CHECK_P41_ENDPOINT_VALUES(
     I     startTime, nIter0, 10. _d 0, expectedN0,
     I     time1, iter1, 14. _d 0, expectedN1,
     U     nFail,
     I     myThid )

C--   A collective non-finite source failure preserves both accepted states.
      time2 = time1+deltaTClock
      iter2 = iter1+1
      CALL BOM_SET_P41_FIELDS(
     I     16. _d 0, 300. _d 0, 6. _d 0, myThid )
      IF ( myProcId.EQ.0 ) THEN
        theta(1,1,1,myBxLo(myThid),myByLo(myThid)) =
     &       IEEE_VALUE(theta(1,1,1,myBxLo(myThid),
     &                  myByLo(myThid)),IEEE_QUIET_NAN)
      ENDIF
      _BARRIER
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time2, iter2, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     .NOT.buildValid .AND.
     &     failCode.EQ.BOM_FAIL_BIOLOGY_FIELD .AND.
     &     failStage.EQ.BOM_STAGE_FIELD_NEW,
     &     'nonfinite biology source fails collectively',
     &     nFail, myThid )
      CALL BOM_CHECK_P41_ENDPOINT_VALUES(
     I     startTime, nIter0, 10. _d 0, expectedN0,
     I     time1, iter1, 14. _d 0, expectedN1,
     U     nFail,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     bomEnvTime(BOM_ENV_NEW).EQ.time1 .AND.
     &     bomEnvIter(BOM_ENV_NEW).EQ.iter1,
     &     'biology failure preserves physical accepted labels',
     &     nFail, myThid )

C--   Clean retry proves failed scratch data was not published.
      CALL BOM_SET_P41_FIELDS(
     I     16. _d 0, 300. _d 0, 6. _d 0, myThid )
      CALL BOM_TRY_BUILD_ENDPOINTS(
     I     time2, iter2, .FALSE.,
     O     failCode, failStage, buildValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     buildValid .AND. failCode.EQ.BOM_FAIL_NONE,
     &     'biology endpoint clean retry', nFail, myThid )
      CALL BOM_CHECK_P41_ENDPOINT_VALUES(
     I     time1, iter1, 14. _d 0, expectedN1,
     I     time2, iter2, 16. _d 0, expectedN2,
     U     nFail,
     I     myThid )

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) CALL BOM_VERIFY_P41_ABORT(
     &     'BOM_VERIFY_P41_ENDPOINTS', globalFail, myThid )
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        IF ( useFiles ) THEN
          WRITE(msgBuf,'(A)')
     &         'P4-E01 FILES PASS: scale, cycle, rollback, retry'
        ELSE
          WRITE(msgBuf,'(A)')
     &         'P4-E01 PTRACER PASS: k=1, clamp, rollback, retry'
        ENDIF
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SET_P41_FIELDS(
     I                 tempSurface, tempDeep, nutrient, myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "DYNVARS.h"
#ifdef ALLOW_PTRACERS
# include "PTRACERS_SIZE.h"
# include "PTRACERS_FIELDS.h"
#endif
      _RL tempSurface, tempDeep, nutrient
      INTEGER myThid, bi, bj, i, j
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          uVel(i,j,1,bi,bj) = 0. _d 0
          vVel(i,j,1,bi,bj) = 0. _d 0
          theta(i,j,1,bi,bj) = tempSurface
          theta(i,j,2,bi,bj) = tempDeep
#ifdef ALLOW_PTRACERS
          pTracer(i,j,1,bi,bj,1) = nutrient
          pTracer(i,j,2,bi,bj,1) = nutrient+999. _d 0
#endif
         ENDDO
        ENDDO
       ENDDO
      ENDDO
#ifdef ALLOW_PTRACERS
C--   One finite negative surface value proves Nsafe clamping in endpoints.
      IF ( nutrient.EQ.2. _d 0 )
     &     pTracer(2,2,1,myBxLo(myThid),myByLo(myThid),1) =
     &       -nutrient
#endif
      _BARRIER
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_CHECK_P41_ENDPOINT_VALUES(
     I                 oldTime, oldIter, oldTemp, oldN,
     I                 newTime, newIter, newTemp, newN,
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
      _RL oldTime, oldTemp, oldN, newTime, newTemp, newN
      _RL expectedTemp, expectedN
      INTEGER oldIter, newIter, nFail, myThid
      INTEGER bi, bj, i, j, iEnd, expectedTempCode, expectedNCode
      LOGICAL wetPoint
      expectedTempCode = BOM_BIO_TEMP_THETA
      expectedNCode = BOM_BIO_N_PTRACER
      IF ( bomNSource.EQ.'FILES' ) expectedNCode = BOM_BIO_N_FILES
      CALL BOM_VERIFY_P41_ASSERT(
     &     bomBioReady .AND.
     &     bomBioTime(BOM_ENV_OLD).EQ.oldTime .AND.
     &     bomBioTime(BOM_ENV_NEW).EQ.newTime .AND.
     &     bomBioIter(BOM_ENV_OLD).EQ.oldIter .AND.
     &     bomBioIter(BOM_ENV_NEW).EQ.newIter,
     &     'accepted biology endpoint labels', nFail, myThid )
      DO iEnd=1,BOM_ENV_NEND
        CALL BOM_VERIFY_P41_ASSERT(
     &       bomBioTempSource(iEnd).EQ.expectedTempCode .AND.
     &       bomBioNSource(iEnd).EQ.expectedNCode,
     &       'accepted biology source metadata', nFail, myThid )
      ENDDO
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          DO iEnd=1,BOM_ENV_NEND
            IF ( iEnd.EQ.BOM_ENV_OLD ) THEN
              expectedTemp = oldTemp
              expectedN = oldN
            ELSE
              expectedTemp = newTemp
              expectedN = newN
            ENDIF
            IF ( wetPoint ) THEN
              IF ( bomNSource.EQ.'PTRACER' .AND.
     &             i.EQ.2 .AND. j.EQ.2 .AND.
     &             bi.EQ.myBxLo(myThid) .AND.
     &             bj.EQ.myByLo(myThid) .AND.
     &             expectedN.EQ.2. _d 0 ) expectedN = 0. _d 0
              CALL BOM_VERIFY_P41_ASSERT(
     &             bomBioValid(i,j,iEnd,bi,bj) .AND.
     &             IEEE_IS_FINITE(bomBioTemp(i,j,iEnd,bi,bj))
     &             .AND. IEEE_IS_FINITE(bomBioN(i,j,iEnd,bi,bj))
     &             .AND. bomBioTemp(i,j,iEnd,bi,bj)
     &               .EQ.expectedTemp
     &             .AND. bomBioN(i,j,iEnd,bi,bj).EQ.expectedN,
     &             'finite wet T/N accepted value', nFail, myThid )
            ELSE
              CALL BOM_VERIFY_P41_ASSERT(
     &             .NOT.bomBioValid(i,j,iEnd,bi,bj) .AND.
     &             bomBioTemp(i,j,iEnd,bi,bj).EQ.0. _d 0
     &             .AND. bomBioN(i,j,iEnd,bi,bj).EQ.0. _d 0,
     &             'dry T/N exact zero and invalid', nFail, myThid )
            ENDIF
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      RETURN
      END
