#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C     !ROUTINE: BOM_MAIN
C     !INTERFACE:
      SUBROUTINE BOM_MAIN( myTime, myIter, myThid )

C     !DESCRIPTION:
C     Advance the compact owner state over one ocean step with equal
C     substeps, exact release splitting, mode-specific halo-aware RK trials,
C     and an owner tile/rank migration transaction after every substep.

C     !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE

C     !INCLUDES:
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C     !INPUT PARAMETERS:
      _RL myTime
      INTEGER myIter
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
C     !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, ip, iSub, nSub, iDiag
      INTEGER errCount, globalErrCount
      INTEGER statusCandidate
      INTEGER failStage, failCode, releaseFailCode
      INTEGER rhsFailCode
      _RL stepStart, dtSub, tSub0, tSub1, dtActive, stageTime0
      _RL x0, y0, xCandidate, yCandidate, ageCandidate
      _RL ix, jy, oceanEast, oceanNorth
      _RL windEast, windNorth, driftEast, driftNorth
      _RL wetWeight, stageCFL, rhsX, rhsY
      _RL rhsDiagCandidate(BOM_RHS_NDIAG)
      LOGICAL setupValid, boundsValid, releaseValid
      LOGICAL doAdvance, doRefresh, trialValid
      LOGICAL rhsOwner, rhsValid

C--   Phase-2 environment publication is independent of particle count.
      IF ( bomMode.EQ.'BOM' ) THEN
        CALL BOM_BUILD_ENDPOINTS(
     I       myTime, myIter, .FALSE., myThid )
      ENDIF
      IF ( bomMaxParticles.LE.0 ) RETURN

C--   Runtime time/substep preflight precedes field construction and any
C     particle write.
      CALL BOM_SUBSTEP_SETUP(
     I     myTime,
     O     stepStart, nSub, dtSub,
     O     failCode, setupValid )
      IF ( myIter.LE.-HUGE(myIter) ) setupValid = .FALSE.
      IF ( .NOT.setupValid ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,2(1X,1PE24.16),A,2I12,A,I5)')
     &         'BOM_MAIN: invalid step setup time/deltaT=',
     &         myTime, deltaTClock, ' iter/nSub=', myIter, nSub,
     &         ' failCode=', failCode
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_MAIN'
      ENDIF

      CALL BOM_BUILD_FIELDS( myTime, myIter, myThid )
      errCount = 0
      IF ( .NOT.bomFieldsReady ) errCount = errCount + 1
      IF ( .NOT.IEEE_IS_FINITE(bomFieldTime) .OR.
     &     bomFieldTime.NE.myTime .OR.
     &     bomFieldIter.NE.myIter ) errCount = errCount + 1
      IF ( .NOT.IEEE_IS_FINITE(bomWindFieldTime) .OR.
     &     bomWindFieldTime.NE.stepStart .OR.
     &     bomWindFieldIter.NE.myIter-1 ) errCount = errCount + 1
      globalErrCount = errCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8,A,2(1X,1PE24.16),A,2I12)')
     &         'BOM_MAIN: invalid frozen field metadata errors=',
     &         globalErrCount, ' ocean/wind time=',
     &         bomFieldTime, bomWindFieldTime,
     &         ' ocean/wind iter=',
     &         bomFieldIter, bomWindFieldIter
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_MAIN'
      ENDIF

C--   Reject damaged compact state before the first transactional write.
      CALL BOM_CHECK_STATE(
     I     stepStart, myIter-1, 'STEP-START', myThid )

      DO iSub=0,nSub-1
        CALL BOM_SUBSTEP_BOUNDS(
     I       stepStart, myTime, dtSub, iSub, nSub,
     O       tSub0, tSub1, boundsValid )
        IF ( .NOT.boundsValid ) THEN
          _BEGIN_MASTER(myThid)
          IF ( myProcId.EQ.0 ) THEN
            WRITE(msgBuf,'(A,2I12,A,4(1X,1PE24.16))')
     &           'BOM_MAIN: invalid substep bounds iSub/nSub=',
     &           iSub, nSub, ' start/end/dt/stepEnd=',
     &           tSub0, tSub1, dtSub, myTime
            CALL PRINT_ERROR( msgBuf, myThid )
          ENDIF
          _END_MASTER(myThid)
          CALL ALL_PROC_DIE( 0 )
          STOP 'ABNORMAL END: S/R BOM_MAIN'
        ENDIF

        errCount = 0
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          DO ip=1,bomNPartTile(bi,bj)
C--         Deterministic rollback diagnostics before any trial.
            x0 = bomX(ip,bi,bj)
            y0 = bomY(ip,bi,bj)
            xCandidate = x0
            yCandidate = y0
            ix = -1. _d 0
            jy = -1. _d 0
            oceanEast = 0. _d 0
            oceanNorth = 0. _d 0
            windEast = 0. _d 0
            windNorth = 0. _d 0
            driftEast = 0. _d 0
            driftNorth = 0. _d 0
            wetWeight = 0. _d 0
            stageCFL = 0. _d 0
            failStage = BOM_STAGE_NONE
            failCode = BOM_FAIL_NONE
            trialValid = .FALSE.
            DO iDiag=1,BOM_RHS_NDIAG
              rhsDiagCandidate(iDiag) = 0. _d 0
            ENDDO

            CALL BOM_RELEASE_STEP(
     I           bomStatus(ip,bi,bj),
     I           bomReleaseTime(ip,bi,bj),
     I           bomAge(ip,bi,bj), tSub0, tSub1,
     O           statusCandidate, dtActive, ageCandidate,
     O           doAdvance, doRefresh,
     O           releaseFailCode, releaseValid )
            IF ( .NOT.releaseValid ) THEN
              failCode = releaseFailCode
            ELSEIF ( .NOT.doRefresh ) THEN
C--           A still-WAITING record is a successful no-op.
              trialValid = .TRUE.
            ELSEIF ( doAdvance ) THEN
              stageTime0 = tSub1-dtActive
              IF ( bomMode.EQ.'BOM' ) THEN
                IF ( bomIntegrator.EQ.'RK2' ) THEN
                  CALL BOM_RK2_SLOW_MIGRATE(
     I                 x0, y0, stageTime0, dtActive, bi, bj,
     O                 xCandidate, yCandidate, ix, jy,
     O                 rhsDiagCandidate, wetWeight, stageCFL,
     O                 failStage, failCode, trialValid,
     I                 myThid )
                ELSEIF ( bomIntegrator.EQ.'RK4' ) THEN
                  CALL BOM_RK4_SLOW_MIGRATE(
     I                 x0, y0, stageTime0, dtActive, bi, bj,
     O                 xCandidate, yCandidate, ix, jy,
     O                 rhsDiagCandidate, wetWeight, stageCFL,
     O                 failStage, failCode, trialValid,
     I                 myThid )
                ELSE
                  failCode = BOM_FAIL_STATE
                ENDIF
                IF ( trialValid ) THEN
                  oceanEast = rhsDiagCandidate(BOM_RHS_VBASE_E)
                  oceanNorth = rhsDiagCandidate(BOM_RHS_VBASE_N)
                  windEast = rhsDiagCandidate(BOM_RHS_VW_E)
                  windNorth = rhsDiagCandidate(BOM_RHS_VW_N)
                  driftEast = rhsDiagCandidate(BOM_RHS_DRIFT_E)
                  driftNorth = rhsDiagCandidate(BOM_RHS_DRIFT_N)
                ENDIF
              ELSE
                IF ( bomIntegrator.EQ.'RK2' ) THEN
                  CALL BOM_RK2_MIGRATE(
     I                 x0, y0, dtActive, bi, bj,
     O                 xCandidate, yCandidate, ix, jy,
     O                 oceanEast, oceanNorth,
     O                 windEast, windNorth,
     O                 driftEast, driftNorth,
     O                 wetWeight, stageCFL,
     O                 failStage, failCode, trialValid,
     I                 myThid )
                ELSEIF ( bomIntegrator.EQ.'RK4' ) THEN
                  CALL BOM_RK4_MIGRATE(
     I                 x0, y0, dtActive, bi, bj,
     O                 xCandidate, yCandidate, ix, jy,
     O                 oceanEast, oceanNorth,
     O                 windEast, windNorth,
     O                 driftEast, driftNorth,
     O                 wetWeight, stageCFL,
     O                 failStage, failCode, trialValid,
     I                 myThid )
                ELSE
                  failCode = BOM_FAIL_STATE
                ENDIF
              ENDIF
            ELSE
C--           Release at tSub1: refresh FINAL diagnostics at zero time.
              failStage = BOM_STAGE_FINAL
              IF ( bomMode.EQ.'BOM' ) THEN
                CALL BOM_RHS_SLOW_MANIFOLD(
     I               x0, y0, tSub1, 0. _d 0,
     I               bi, bj, BOM_STAGE_FINAL,
     O               rhsX, rhsY, ix, jy, rhsDiagCandidate,
     O               wetWeight, stageCFL,
     O               rhsOwner, rhsValid, rhsFailCode, failStage,
     I               myThid )
                IF ( rhsValid ) THEN
                  oceanEast = rhsDiagCandidate(BOM_RHS_VBASE_E)
                  oceanNorth = rhsDiagCandidate(BOM_RHS_VBASE_N)
                  windEast = rhsDiagCandidate(BOM_RHS_VW_E)
                  windNorth = rhsDiagCandidate(BOM_RHS_VW_N)
                  driftEast = rhsDiagCandidate(BOM_RHS_DRIFT_E)
                  driftNorth = rhsDiagCandidate(BOM_RHS_DRIFT_N)
                ENDIF
              ELSE
                CALL BOM_RHS_LEEWAY(
     I               x0, y0, 0. _d 0, bi, bj,
     O               rhsX, rhsY, ix, jy,
     O               oceanEast, oceanNorth,
     O               windEast, windNorth,
     O               driftEast, driftNorth,
     O               wetWeight, stageCFL,
     O               rhsOwner, rhsValid, rhsFailCode,
     I               myThid )
              ENDIF
              IF ( .NOT.rhsValid ) THEN
                failCode = rhsFailCode
              ELSEIF ( .NOT.rhsOwner ) THEN
                failCode = BOM_FAIL_OWNER
              ELSE
                failStage = BOM_STAGE_NONE
                failCode = BOM_FAIL_NONE
                trialValid = .TRUE.
              ENDIF
            ENDIF

            IF ( trialValid ) THEN
              IF ( doRefresh ) THEN
C--             Publish all authoritative candidates exactly once.
                bomX(ip,bi,bj) = xCandidate
                bomY(ip,bi,bj) = yCandidate
                bomStatus(ip,bi,bj) = statusCandidate
                bomAge(ip,bi,bj) = ageCandidate
                bomI(ip,bi,bj) = ix
                bomJ(ip,bi,bj) = jy
                bomVEast(ip,bi,bj) = oceanEast
                bomVNorth(ip,bi,bj) = oceanNorth
                bomWindEast(ip,bi,bj) = windEast
                bomWindNorth(ip,bi,bj) = windNorth
                bomDriftEast(ip,bi,bj) = driftEast
                bomDriftNorth(ip,bi,bj) = driftNorth
                IF ( bomMode.EQ.'BOM' ) THEN
                  DO iDiag=1,BOM_RHS_NDIAG
                    bomRhsDiag(iDiag,ip,bi,bj) =
     &                   rhsDiagCandidate(iDiag)
                  ENDDO
                ENDIF
              ENDIF
            ELSE
              IF ( errCount.LT.8 ) THEN
                WRITE(msgBuf,1000)
     &               'BOM_MAIN: particle failure time=', myTime,
     &               ' iter/sub=', myIter, iSub+1,
     &               ' rank/tile/slot=', myProcId, bi, bj, ip,
     &               ' id=', bomId(ip,bi,bj),
     &               ' stage/code=', failStage, failCode
                CALL PRINT_ERROR( msgBuf, myThid )
                WRITE(msgBuf,'(A,6(1X,1PE24.16))')
     &               'BOM_MAIN: xy/ij/wet/CFL=',
     &               x0, y0, ix, jy, wetWeight, stageCFL
                CALL PRINT_ERROR( msgBuf, myThid )
                WRITE(msgBuf,'(A,5(1X,1PE24.16))')
     &               'BOM_MAIN: tSub0/tSub1/dtActive/age/release=',
     &               tSub0, tSub1, dtActive,
     &               bomAge(ip,bi,bj), bomReleaseTime(ip,bi,bj)
                CALL PRINT_ERROR( msgBuf, myThid )
              ENDIF
              errCount = errCount + 1
            ENDIF
          ENDDO
         ENDDO
        ENDDO

        globalErrCount = errCount
        CALL GLOBAL_SUM_INT( globalErrCount, myThid )
        IF ( globalErrCount.GT.0 ) THEN
          _BEGIN_MASTER(myThid)
          IF ( myProcId.EQ.0 ) THEN
            WRITE(msgBuf,'(A,I8,A,2I12,A,2(1X,1PE24.16))')
     &           'BOM_MAIN: fatal particle errors=', globalErrCount,
     &           ' iter/sub=', myIter, iSub+1,
     &           ' interval=', tSub0, tSub1
            CALL PRINT_ERROR( msgBuf, myThid )
          ENDIF
          _END_MASTER(myThid)
          CALL ALL_PROC_DIE( 0 )
          STOP 'ABNORMAL END: S/R BOM_MAIN'
        ENDIF

C--     No non-owner candidate may enter a state budget or next substep.
        CALL BOM_PARTICLE_EXCHANGE(
     I       tSub1, myIter, iSub+1, myThid )

        IF ( bomCheckEverySubstep ) THEN
          CALL BOM_CHECK_STATE(
     I         tSub1, myIter, 'SUBSTEP', myThid )
        ENDIF
      ENDDO

C--   The step-end budget is unconditional.  When every substep was
C     checked, the last call above already is this exact budget.
      IF ( .NOT.bomCheckEverySubstep ) THEN
        CALL BOM_CHECK_STATE(
     I       myTime, myIter, 'STEP-END', myThid )
      ENDIF
 1000 FORMAT(A,1PE24.16,A,2I12,A,4I6,A,I20,A,2I6)
#endif /* ALLOW_BOM */

      RETURN
      END
