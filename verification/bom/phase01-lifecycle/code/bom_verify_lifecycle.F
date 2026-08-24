#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_LIFECYCLE( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      INTEGER myThid

#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, ip
      INTEGER nFail, globalFail, caseCount, globalCaseCount
      INTEGER statusCandidate, failCode, nSub
      INTEGER*8 testId
      _RL stepStart, dtSub, tSub0, tSub1
      _RL dtActive, ageCandidate
      _RL xSeed(5), ySeed(5), tol
      LOGICAL isRK2, isRK4, isMPI4
      LOGICAL isAge, isDuplicate, isCount
      LOGICAL isTail, isStatus, isOwner
      LOGICAL doAdvance, doRefresh, isValid
      LOGICAL boundsValid

      nFail = 0
      caseCount = 0
      tol = 65536. _d 0*EPSILON(oneRL)
      isRK2 = the_run_name.EQ.'P1-S04B-RK2'
      isRK4 = the_run_name.EQ.'P1-S04B-RK4'
      isMPI4 = the_run_name.EQ.'P1-LIFE-MPI4'
      isAge = the_run_name.EQ.'P1-N08-AGE'
      isDuplicate = the_run_name.EQ.'P1-N08-DUPID'
      isCount = the_run_name.EQ.'P1-N08-COUNT'
      isTail = the_run_name.EQ.'P1-N08-TAIL'
      isStatus = the_run_name.EQ.'P1-N08-STATUS'
      isOwner = the_run_name.EQ.'P1-N08-OWNER'
      CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &     isRK2 .OR. isRK4 .OR. isMPI4 .OR. isAge
     &     .OR. isDuplicate .OR. isCount .OR. isTail
     &     .OR. isStatus .OR. isOwner,
     &     'recognized lifecycle scenario', nFail, myThid )

      bomMaxParticles = 5
      bomDeltaTTarget = 300. _d 0
      bomWetWeightMin = 0.5 _d 0
      bomAdvCFL = 0.5 _d 0
      bomLeewayWindCoeff = 0. _d 0
      bomWindSource = 'NONE'
      bomStokesSource = 'NONE'
      bomCheckEverySubstep = .TRUE.
      IF ( isRK2 ) THEN
        bomIntegrator = 'RK2'
      ELSE
        bomIntegrator = 'RK4'
      ENDIF

C--   The positive serial runs exercise the stateless release helper and
C     deterministic equal-substep construction before the caller test.
      IF ( isRK2 .OR. isRK4 ) THEN
        CALL BOM_SUBSTEP_SETUP(
     I       1200. _d 0,
     O       stepStart, nSub, dtSub, failCode, isValid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       isValid .AND. failCode.EQ.BOM_FAIL_NONE
     &       .AND. stepStart.EQ.0. _d 0
     &       .AND. nSub.EQ.4 .AND. dtSub.EQ.300. _d 0,
     &       'equal substep setup', nFail, myThid )
        CALL BOM_SUBSTEP_BOUNDS(
     I       stepStart, 1200. _d 0, dtSub, 3, nSub,
     O       tSub0, tSub1, boundsValid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       boundsValid .AND. tSub0.EQ.900. _d 0
     &       .AND. tSub1.EQ.1200. _d 0,
     &       'forced final endpoint', nFail, myThid )

        CALL BOM_RELEASE_STEP(
     I       BOM_WAITING, 0. _d 0, 0. _d 0,
     I       0. _d 0, 300. _d 0,
     O       statusCandidate, dtActive, ageCandidate,
     O       doAdvance, doRefresh, failCode, isValid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       isValid .AND. statusCandidate.EQ.BOM_ALIVE
     &       .AND. dtActive.EQ.300. _d 0
     &       .AND. ageCandidate.EQ.300. _d 0
     &       .AND. doAdvance .AND. doRefresh,
     &       'release at substep start', nFail, myThid )

        CALL BOM_RELEASE_STEP(
     I       BOM_WAITING, 150. _d 0, 0. _d 0,
     I       0. _d 0, 300. _d 0,
     O       statusCandidate, dtActive, ageCandidate,
     O       doAdvance, doRefresh, failCode, isValid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       isValid .AND. statusCandidate.EQ.BOM_ALIVE
     &       .AND. dtActive.EQ.150. _d 0
     &       .AND. ageCandidate.EQ.150. _d 0
     &       .AND. doAdvance .AND. doRefresh,
     &       'release inside substep', nFail, myThid )

        CALL BOM_RELEASE_STEP(
     I       BOM_WAITING, 300. _d 0, 0. _d 0,
     I       0. _d 0, 300. _d 0,
     O       statusCandidate, dtActive, ageCandidate,
     O       doAdvance, doRefresh, failCode, isValid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       isValid .AND. statusCandidate.EQ.BOM_ALIVE
     &       .AND. dtActive.EQ.0. _d 0
     &       .AND. ageCandidate.EQ.0. _d 0
     &       .AND. .NOT.doAdvance .AND. doRefresh,
     &       'release at substep end', nFail, myThid )

        CALL BOM_RELEASE_STEP(
     I       BOM_WAITING, 600. _d 0, 0. _d 0,
     I       0. _d 0, 300. _d 0,
     O       statusCandidate, dtActive, ageCandidate,
     O       doAdvance, doRefresh, failCode, isValid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       isValid .AND. statusCandidate.EQ.BOM_WAITING
     &       .AND. dtActive.EQ.0. _d 0
     &       .AND. ageCandidate.EQ.0. _d 0
     &       .AND. .NOT.doAdvance .AND. .NOT.doRefresh,
     &       'future release is a no-op', nFail, myThid )

        CALL BOM_RELEASE_STEP(
     I       BOM_ALIVE, 0. _d 0, 0.75 _d 0*HUGE(oneRL),
     I       0. _d 0, 0.5 _d 0*HUGE(oneRL),
     O       statusCandidate, dtActive, ageCandidate,
     O       doAdvance, doRefresh, failCode, isValid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       .NOT.isValid .AND. failCode.EQ.BOM_FAIL_NONFINITE,
     &       'age overflow rejected before commit', nFail, myThid )
        caseCount = caseCount + 6
      ENDIF

      IF ( isRK2 .OR. isRK4 ) THEN
C--     Five serial records freeze every release relation to the four
C     nominal intervals [0,300],...,[900,1200].
        CALL BOM_VERIFY_LIFECYCLE_FILL_MODEL(
     &       0.02 _d 0, -0.01 _d 0, myThid )
        bi = 1
        bj = 1
        bomNPartTile(bi,bj) = 5
        bomNPartExpected = 5
        bomMaxParticles = 5
        CALL BOM_VERIFY_LIFECYCLE_PUT(
     I       1, bi, bj, 101_8, BOM_ALIVE,
     I       1.7 _d 0, 1.7 _d 0, 0. _d 0, 10. _d 0,
     O       isValid, myThid )
        CALL BOM_VERIFY_LIFECYCLE_PUT(
     I       2, bi, bj, 102_8, BOM_WAITING,
     I       2.0 _d 0, 1.9 _d 0, 1500. _d 0, 0. _d 0,
     O       isValid, myThid )
        CALL BOM_VERIFY_LIFECYCLE_PUT(
     I       3, bi, bj, 103_8, BOM_WAITING,
     I       2.3 _d 0, 2.1 _d 0, 300. _d 0, 0. _d 0,
     O       isValid, myThid )
        CALL BOM_VERIFY_LIFECYCLE_PUT(
     I       4, bi, bj, 104_8, BOM_WAITING,
     I       2.6 _d 0, 2.3 _d 0, 450. _d 0, 0. _d 0,
     O       isValid, myThid )
        CALL BOM_VERIFY_LIFECYCLE_PUT(
     I       5, bi, bj, 105_8, BOM_WAITING,
     I       2.9 _d 0, 2.5 _d 0, 1200. _d 0, 0. _d 0,
     O       isValid, myThid )
        DO ip=1,5
          xSeed(ip) = bomX(ip,bi,bj)
          ySeed(ip) = bomY(ip,bi,bj)
        ENDDO

        CALL BOM_MAIN( 1200. _d 0, 1, myThid )

        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       bomStatus(1,bi,bj).EQ.BOM_ALIVE
     &       .AND. ABS(bomX(1,bi,bj)-xSeed(1)-24. _d 0).LE.tol
     &       .AND. ABS(bomY(1,bi,bj)-ySeed(1)+12. _d 0).LE.tol
     &       .AND. bomAge(1,bi,bj).EQ.1210. _d 0,
     &       'already alive full-step transaction', nFail, myThid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       bomStatus(2,bi,bj).EQ.BOM_WAITING
     &       .AND. bomX(2,bi,bj).EQ.xSeed(2)
     &       .AND. bomY(2,bi,bj).EQ.ySeed(2)
     &       .AND. bomAge(2,bi,bj).EQ.0. _d 0
     &       .AND. bomDriftEast(2,bi,bj).EQ.0. _d 0
     &       .AND. bomDriftNorth(2,bi,bj).EQ.0. _d 0,
     &       'future waiting record unchanged', nFail, myThid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       bomStatus(3,bi,bj).EQ.BOM_ALIVE
     &       .AND. ABS(bomX(3,bi,bj)-xSeed(3)-18. _d 0).LE.tol
     &       .AND. ABS(bomY(3,bi,bj)-ySeed(3)+9. _d 0).LE.tol
     &       .AND. bomAge(3,bi,bj).EQ.900. _d 0,
     &       'endpoint release transaction', nFail, myThid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       bomStatus(4,bi,bj).EQ.BOM_ALIVE
     &       .AND. ABS(bomX(4,bi,bj)-xSeed(4)-15. _d 0).LE.tol
     &       .AND. ABS(bomY(4,bi,bj)-ySeed(4)+7.5 _d 0).LE.tol
     &       .AND. bomAge(4,bi,bj).EQ.750. _d 0,
     &       'interior release transaction', nFail, myThid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       bomStatus(5,bi,bj).EQ.BOM_ALIVE
     &       .AND. bomX(5,bi,bj).EQ.xSeed(5)
     &       .AND. bomY(5,bi,bj).EQ.ySeed(5)
     &       .AND. bomAge(5,bi,bj).EQ.0. _d 0
     &       .AND. ABS(bomDriftEast(5,bi,bj)-0.02 _d 0).LE.tol
     &       .AND. ABS(bomDriftNorth(5,bi,bj)+0.01 _d 0).LE.tol,
     &       'step-end release refresh without motion',
     &       nFail, myThid )
        DO ip=1,5
          CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &         bomId(ip,bi,bj).EQ.INT(100+ip,8),
     &         'authoritative ID unchanged', nFail, myThid )
          IF ( ip.NE.2 ) THEN
            CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &           ABS(bomVEast(ip,bi,bj)-0.02 _d 0).LE.tol
     &           .AND. ABS(bomVNorth(ip,bi,bj)+0.01 _d 0).LE.tol,
     &           'released final ocean diagnostics', nFail, myThid )
          ENDIF
        ENDDO
        caseCount = caseCount + 10

      ELSEIF ( isMPI4 ) THEN
C--     One record per rank; low words cross the signed 32-bit boundary.
        CALL BOM_VERIFY_LIFECYCLE_FILL_MODEL(
     &       0. _d 0, 0. _d 0, myThid )
        bi = myBxLo(myThid)
        bj = myByLo(myThid)
        bomNPartTile(bi,bj) = 1
        bomNPartExpected = nPx*nPy
        bomMaxParticles = bomNPartExpected
        IF ( myProcId.EQ.0 ) THEN
          testId = 4294967295_8
        ELSEIF ( myProcId.EQ.1 ) THEN
          testId = 4294967296_8
        ELSEIF ( myProcId.EQ.2 ) THEN
          testId = 8589934591_8
        ELSE
          testId = 8589934592_8
        ENDIF
        CALL BOM_VERIFY_LIFECYCLE_PUT(
     I       1, bi, bj, testId, BOM_ALIVE,
     I       2.0 _d 0, 1.5 _d 0, 0. _d 0,
     I       DFLOAT(myProcId),
     O       isValid, myThid )
        xSeed(1) = bomX(1,bi,bj)
        ySeed(1) = bomY(1,bi,bj)
        CALL BOM_MAIN( 1200. _d 0, 1, myThid )
        CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &       bomId(1,bi,bj).EQ.testId
     &       .AND. bomX(1,bi,bj).EQ.xSeed(1)
     &       .AND. bomY(1,bi,bj).EQ.ySeed(1)
     &       .AND. bomAge(1,bi,bj)
     &       .EQ.1200. _d 0+DFLOAT(myProcId),
     &       'MPI4 ID and state budget', nFail, myThid )
        caseCount = caseCount + 1

      ELSE
C--     Each negative run must terminate in production before returning.
        IF ( isOwner ) THEN
          CALL BOM_VERIFY_LIFECYCLE_FILL_MODEL(
     &         0.5 _d 0, 0. _d 0, myThid )
        ELSE
          CALL BOM_VERIFY_LIFECYCLE_FILL_MODEL(
     &         0. _d 0, 0. _d 0, myThid )
        ENDIF
        bi = myBxLo(myThid)
        bj = myByLo(myThid)
        bomNPartTile(bi,bj) = 1
        bomNPartExpected = 1
        bomMaxParticles = 1
        testId = INT(myProcId+1,8)
        IF ( isDuplicate ) testId = 77_8
        IF ( isOwner ) THEN
          CALL BOM_VERIFY_LIFECYCLE_PUT(
     I         1, bi, bj, testId, BOM_ALIVE,
     I         4.4 _d 0, 1.5 _d 0, 0. _d 0, 0. _d 0,
     O         isValid, myThid )
        ELSE
          CALL BOM_VERIFY_LIFECYCLE_PUT(
     I         1, bi, bj, testId, BOM_ALIVE,
     I         2.0 _d 0, 1.5 _d 0, 0. _d 0, 0. _d 0,
     O         isValid, myThid )
        ENDIF
        IF ( isAge ) THEN
          bomAge(1,bi,bj) = 0.75 _d 0*HUGE(oneRL)
          deltaTClock = 0.5 _d 0*HUGE(oneRL)
          bomDeltaTTarget = deltaTClock
        ENDIF
        IF ( isDuplicate ) THEN
          bomNPartExpected = nPx*nPy
          bomMaxParticles = bomNPartExpected
        ENDIF
        IF ( isCount ) bomNPartExpected = 2
        IF ( isTail ) THEN
          bomId(2,bi,bj) = 99_8
          bomStatus(2,bi,bj) = BOM_ALIVE
        ENDIF
        IF ( isStatus ) bomStatus(1,bi,bj) = BOM_OUTSIDE

        IF ( isAge ) THEN
          CALL BOM_MAIN( deltaTClock, 1, myThid )
        ELSE
          CALL BOM_MAIN( 1200. _d 0, 1, myThid )
        ENDIF
        CALL BOM_VERIFY_LIFECYCLE_ASSERT( .FALSE.,
     &       'negative lifecycle scenario returned', nFail, myThid )
      ENDIF

      globalCaseCount = caseCount
      CALL GLOBAL_SUM_INT( globalCaseCount, myThid )
      CALL BOM_VERIFY_LIFECYCLE_ASSERT(
     &     globalCaseCount.GT.0, 'lifecycle scenario exercised',
     &     nFail, myThid )
      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I6)')
     &         'BOM_VERIFY_LIFECYCLE: failed assertions=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_LIFECYCLE'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        IF ( isRK2 ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-S04B RK2 PASS: exact release transactions'
        ELSEIF ( isRK4 ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-S04B RK4 PASS: exact release transactions'
        ELSE
          WRITE(msgBuf,'(A)')
     &         'P1-LIFECYCLE MPI4 PASS: exact global ID budget'
        ENDIF
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_LIFECYCLE_FILL_MODEL(
     I     waterEast, waterNorth, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "DYNVARS.h"
#include "GRID.h"

      _RL waterEast, waterNorth
      INTEGER myThid

#ifdef ALLOW_BOM
      INTEGER bi, bj, i, j, k
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          maskC(i,j,1,bi,bj) = 1.
          angleCosC(i,j,bi,bj) = 1.
          angleSinC(i,j,bi,bj) = 0.
          DO k=1,Nr
            uVel(i,j,k,bi,bj) = 0. _d 0
            vVel(i,j,k,bi,bj) = 0. _d 0
          ENDDO
          uVel(i,j,1,bi,bj) = waterEast
          vVel(i,j,1,bi,bj) = waterNorth
         ENDDO
        ENDDO
       ENDDO
      ENDDO
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_LIFECYCLE_PUT(
     I     ip, bi, bj, particleId, particleStatus,
     I     ixSeed, jySeed, releaseTime, ageValue,
     O     isValid,
     I     myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      INTEGER ip, bi, bj, particleStatus, myThid
      INTEGER*8 particleId
      _RL ixSeed, jySeed, releaseTime, ageValue
      LOGICAL isValid
      _RL xx, yy, xMap, ix, jy
      LOGICAL coordValid, isOwner, hasStencil

      isValid = .FALSE.
      CALL BOM_MAP_IJLOCAL2XY(
     I     ixSeed, jySeed, bi, bj,
     O     xx, yy, coordValid,
     I     myThid )
      IF ( .NOT.coordValid ) RETURN
      CALL BOM_MAP_XY2IJLOCAL(
     I     xx, yy, bi, bj,
     O     xMap, ix, jy, isOwner, hasStencil,
     I     myThid )
      IF ( .NOT.isOwner .OR. .NOT.hasStencil ) RETURN
      bomId(ip,bi,bj) = particleId
      bomStatus(ip,bi,bj) = particleStatus
      bomX(ip,bi,bj) = xx
      bomY(ip,bi,bj) = yy
      bomReleaseTime(ip,bi,bj) = releaseTime
      bomAge(ip,bi,bj) = ageValue
      bomI(ip,bi,bj) = ix
      bomJ(ip,bi,bj) = jy
      bomVEast(ip,bi,bj) = 0. _d 0
      bomVNorth(ip,bi,bj) = 0. _d 0
      bomWindEast(ip,bi,bj) = 0. _d 0
      bomWindNorth(ip,bi,bj) = 0. _d 0
      bomDriftEast(ip,bi,bj) = 0. _d 0
      bomDriftNorth(ip,bi,bj) = 0. _d 0
      isValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_LIFECYCLE_ASSERT(
     I     condition, label,
     U     nFail,
     I     myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"

      LOGICAL condition
      CHARACTER*(*) label
      INTEGER nFail, myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf

      IF ( .NOT.condition ) THEN
        nFail = nFail + 1
        WRITE(msgBuf,'(A,A)')
     &       'BOM_VERIFY_LIFECYCLE assertion: ', label
        CALL PRINT_ERROR( msgBuf, myThid )
      ENDIF

      RETURN
      END
