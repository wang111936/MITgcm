#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VERIFY_STAGE_RK
C !INTERFACE:
      SUBROUTINE BOM_VERIFY_STAGE_RK( myThid )

C !DESCRIPTION:
C     P2-I01--I04 production stage-time/RK gate for B04 and B05.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
      INTEGER failI01, failI02, failI03, failI04
      INTEGER globalI01, globalI02, globalI03, globalI04
      CHARACTER*(MAX_LEN_MBUF) msgBuf
CEOP

      failI01 = 0
      failI02 = 0
      failI03 = 0
      failI04 = 0
      CALL BOM_P24_VERIFY_B04( failI01, failI02, myThid )
      CALL BOM_P24_VERIFY_B05( failI03, failI04, myThid )

      globalI01 = failI01
      globalI02 = failI02
      globalI03 = failI03
      globalI04 = failI04
      CALL GLOBAL_SUM_INT( globalI01, myThid )
      CALL GLOBAL_SUM_INT( globalI02, myThid )
      CALL GLOBAL_SUM_INT( globalI03, myThid )
      CALL GLOBAL_SUM_INT( globalI04, myThid )
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        IF ( globalI01.EQ.0 ) THEN
          WRITE(msgBuf,'(A)')
     &         'P2-I01 PASS: B04 components and signs'
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                        SQUEEZE_RIGHT, myThid )
        ENDIF
        IF ( globalI02.EQ.0 ) THEN
          WRITE(msgBuf,'(A)')
     &         'P2-I02 PASS: B04 RK2/RK4 convergence'
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                        SQUEEZE_RIGHT, myThid )
        ENDIF
        IF ( globalI03.EQ.0 ) THEN
          WRITE(msgBuf,'(A)')
     &         'P2-I03 PASS: B05 exact affine-time stages'
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                        SQUEEZE_RIGHT, myThid )
        ENDIF
        IF ( globalI04.EQ.0 ) THEN
          WRITE(msgBuf,'(A)')
     &         'P2-I04 PASS: endpoint order and rollback'
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                        SQUEEZE_RIGHT, myThid )
        ENDIF
      ENDIF
      _END_MASTER(myThid)
      IF ( globalI01+globalI02+globalI03+globalI04.GT.0 ) THEN
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: P2.4 STAGE/RK GATE'
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P24_VERIFY_B04( failI01, failI02, myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER failI01, failI02, myThid
      _RL offsetE(BOM_ENV_NSOURCE), offsetN(BOM_ENV_NSOURCE)
      _RL rateE(BOM_ENV_NSOURCE), rateN(BOM_ENV_NSOURCE)
      _RL gradEE(BOM_ENV_NSOURCE), gradNE(BOM_ENV_NSOURCE)
      _RL gradEN(BOM_ENV_NSOURCE), gradNN(BOM_ENV_NSOURCE)
      _RL diag(BOM_RHS_NDIAG)
      _RL rotationRate, fValue, tEnd, x0, y0, rhsX, rhsY, ix, jy
      _RL wetWeight, stageCFL, tolerance, expected
      _RL cV, cU, inertScale, radialRate, growth, angle
      _RL xExact, yExact, xTrial, yTrial, dt
      _RL errors2(4), errors4(4), orderValue
      INTEGER iSource, iCase, iStep, nStep
      INTEGER failCode, failStage
      INTEGER bi, bj, iPoint, jPoint
      LOGICAL isOwner, rhsValid, stepValid

      rotationRate = 2.0 _d -4
      fValue = 1.0 _d -4
      tEnd = 200. _d 0
      DO iSource=1,BOM_ENV_NSOURCE
        offsetE(iSource) = 0. _d 0
        offsetN(iSource) = 0. _d 0
        rateE(iSource) = 0. _d 0
        rateN(iSource) = 0. _d 0
        gradEE(iSource) = 0. _d 0
        gradNE(iSource) = 0. _d 0
        gradEN(iSource) = 0. _d 0
        gradNN(iSource) = 0. _d 0
      ENDDO
      gradNE(BOM_ENV_EULERIAN) = -rotationRate
      gradEN(BOM_ENV_EULERIAN) = rotationRate
      _BEGIN_MASTER(myThid)
      bomEquationMode = 'PAPER2024'
      bomCurrentPolicy = 'EULERIAN'
      bomStokesSource = 'NONE'
      bomWindSource = 'NONE'
      bomAlpha = 0. _d 0
      bomTau = 8. _d 0
      bomR = 0.823 _d 0
      bomSigma = 0. _d 0
      bomAdvCFL = 0.9 _d 0
      deltaTClock = tEnd
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_P24_PUBLISH_AFFINE(
     I     0. _d 0, tEnd, 0,
     I     offsetE, offsetN, rateE, rateN,
     I     gradEE, gradNE, gradEN, gradNN,
     I     fValue, myThid )

      IF ( myProcId.EQ.0 ) THEN
        bi = myBxLo(myThid)
        bj = myByLo(myThid)
        iPoint = MIN(4,sNx)
        jPoint = MIN(3,sNy)
        x0 = xC(iPoint,jPoint,bi,bj)
        y0 = yC(iPoint,jPoint,bi,bj)
        CALL BOM_RHS_SLOW_MANIFOLD(
     I       x0, y0, 0.25 _d 0*tEnd, tEnd,
     I       bi, bj, BOM_STAGE_K1,
     O       rhsX, rhsY, ix, jy, diag,
     O       wetWeight, stageCFL,
     O       isOwner, rhsValid, failCode, failStage,
     I       myThid )
        CALL BOM_P24_ASSERT(
     I       rhsValid .AND. isOwner .AND.
     &       failCode.EQ.BOM_FAIL_NONE,
     U       failI01 )
        tolerance = 4096. _d 0*EPSILON(oneRL)
        CALL BOM_P24_ASSERT(
     I       ABS(diag(BOM_RHS_VBASE_E)+rotationRate*y0)
     &         .LE.tolerance*MAX(oneRL,ABS(rotationRate*y0)),
     U       failI01 )
        CALL BOM_P24_ASSERT(
     I       ABS(diag(BOM_RHS_VBASE_N)-rotationRate*x0)
     &         .LE.tolerance*MAX(oneRL,ABS(rotationRate*x0)),
     U       failI01 )
        CALL BOM_P24_ASSERT(
     I       ABS(diag(BOM_RHS_DV_E)
     &         +rotationRate*rotationRate*x0)
     &         .LE.tolerance*MAX(oneRL,
     &              ABS(rotationRate*rotationRate*x0)),
     U       failI01 )
        CALL BOM_P24_ASSERT(
     I       ABS(diag(BOM_RHS_DV_N)
     &         +rotationRate*rotationRate*y0)
     &         .LE.tolerance*MAX(oneRL,
     &              ABS(rotationRate*rotationRate*y0)),
     U       failI01 )
        CALL BOM_P24_ASSERT(
     I       ABS(diag(BOM_RHS_OMEGA)-2. _d 0*rotationRate)
     &         .LE.tolerance,
     U       failI01 )
        cV = fValue + 2. _d 0*rotationRate/3. _d 0
        cU = fValue + 2. _d 0*bomR*rotationRate/3. _d 0
        inertScale = (oneRL-bomR)*rotationRate*rotationRate
     &             + (cU-bomR*cV)*rotationRate
        expected = inertScale*x0
        CALL BOM_P24_ASSERT(
     I       ABS(diag(BOM_RHS_INERT_E)-expected)
     &         .LE.tolerance*MAX(oneRL,ABS(expected)),
     U       failI01 )
        expected = inertScale*y0
        CALL BOM_P24_ASSERT(
     I       ABS(diag(BOM_RHS_INERT_N)-expected)
     &         .LE.tolerance*MAX(oneRL,ABS(expected)),
     U       failI01 )
        CALL BOM_P24_ASSERT(
     I       diag(BOM_RHS_ROT_VE)*diag(BOM_RHS_V_N).LE.0. _d 0
     &       .AND. diag(BOM_RHS_ROT_VN)*diag(BOM_RHS_V_E)
     &             .GE.0. _d 0,
     U       failI01 )

C--     Four exact-endpoint step sizes against the analytic linear system.
        radialRate = bomTau*inertScale
        growth = EXP(radialRate*tEnd)
        angle = rotationRate*tEnd
        xExact = growth*(COS(angle)*x0-SIN(angle)*y0)
        yExact = growth*(SIN(angle)*x0+COS(angle)*y0)
        DO iCase=1,4
          nStep = 2**(iCase-1)
          dt = tEnd/DFLOAT(nStep)
          xTrial = x0
          yTrial = y0
          DO iStep=1,nStep
            CALL BOM_RK2_SLOW_MIGRATE(
     I           xTrial, yTrial, DFLOAT(iStep-1)*dt,
     I           dt, bi, bj,
     O           rhsX, rhsY, ix, jy, diag,
     O           wetWeight, stageCFL,
     O           failStage, failCode, stepValid,
     I           myThid )
            CALL BOM_P24_ASSERT(stepValid,failI02)
            IF ( stepValid ) THEN
              xTrial = rhsX
              yTrial = rhsY
            ENDIF
          ENDDO
          errors2(iCase) = SQRT((xTrial-xExact)**2
     &                         +(yTrial-yExact)**2)

          xTrial = x0
          yTrial = y0
          DO iStep=1,nStep
            CALL BOM_RK4_SLOW_MIGRATE(
     I           xTrial, yTrial, DFLOAT(iStep-1)*dt,
     I           dt, bi, bj,
     O           rhsX, rhsY, ix, jy, diag,
     O           wetWeight, stageCFL,
     O           failStage, failCode, stepValid,
     I           myThid )
            CALL BOM_P24_ASSERT(stepValid,failI02)
            IF ( stepValid ) THEN
              xTrial = rhsX
              yTrial = rhsY
            ENDIF
          ENDDO
          errors4(iCase) = SQRT((xTrial-xExact)**2
     &                         +(yTrial-yExact)**2)
        ENDDO
        DO iCase=1,3
          orderValue = LOG(errors2(iCase)/errors2(iCase+1))
     &               /LOG(2. _d 0)
          CALL BOM_P24_ASSERT(
     I         IEEE_IS_FINITE(orderValue) .AND.
     &         orderValue.GE.1.8 _d 0 .AND.
     &         orderValue.LE.2.2 _d 0,
     U         failI02 )
          orderValue = LOG(errors4(iCase)/errors4(iCase+1))
     &               /LOG(2. _d 0)
          CALL BOM_P24_ASSERT(
     I         IEEE_IS_FINITE(orderValue) .AND.
     &         orderValue.GE.3.5 _d 0 .AND.
     &         orderValue.LE.4.5 _d 0,
     U         failI02 )
        ENDDO
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P24_VERIFY_B05( failI03, failI04, myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER failI03, failI04, myThid
      _RL oldE(BOM_ENV_NSOURCE), oldN(BOM_ENV_NSOURCE)
      _RL newE(BOM_ENV_NSOURCE), newN(BOM_ENV_NSOURCE)
      _RL slopeE(BOM_ENV_NSOURCE), slopeN(BOM_ENV_NSOURCE)
      _RL diag(BOM_RHS_NDIAG), savedDiag(BOM_RHS_NDIAG)
      _RL tEnd, fValue, x0, y0, rhsX, rhsY, ix, jy
      _RL wetWeight, stageCFL, stageTime, theta, tolerance
      _RL v0E, v0N, vRateE, vRateN
      _RL u0E, u0N, uRateE, uRateN
      _RL inert0E, inert0N, inertRateE, inertRateN
      _RL drift0E, drift0N, driftRateE, driftRateN
      _RL xExact, yExact, xTrial, yTrial
      _RL errors2(4), errors4(4), orderValue, coeff, dt
      _RL sentinelX, sentinelY, sentinelAge
      INTEGER bi, bj, iPoint, jPoint, iSource, iCase
      INTEGER iStep, nStep, failCode, failStage, iDiag
      INTEGER sentinelStatus
      LOGICAL isOwner, rhsValid, stepValid

      tEnd = 200. _d 0
      fValue = 1.0 _d -4
      oldE(BOM_ENV_EULERIAN) = 0.020 _d 0
      oldN(BOM_ENV_EULERIAN) = -0.010 _d 0
      slopeE(BOM_ENV_EULERIAN) = 1.0 _d -5
      slopeN(BOM_ENV_EULERIAN) = 0.5 _d -5
      oldE(BOM_ENV_STOKES) = 0.004 _d 0
      oldN(BOM_ENV_STOKES) = 0.006 _d 0
      slopeE(BOM_ENV_STOKES) = -0.2 _d -5
      slopeN(BOM_ENV_STOKES) = 0.3 _d -5
      oldE(BOM_ENV_WIND) = -0.030 _d 0
      oldN(BOM_ENV_WIND) = 0.040 _d 0
      slopeE(BOM_ENV_WIND) = 0.4 _d -5
      slopeN(BOM_ENV_WIND) = -0.6 _d -5
      DO iSource=1,BOM_ENV_NSOURCE
        newE(iSource) = oldE(iSource)+tEnd*slopeE(iSource)
        newN(iSource) = oldN(iSource)+tEnd*slopeN(iSource)
      ENDDO
      _BEGIN_MASTER(myThid)
      bomEquationMode = 'PAPER2024'
      bomCurrentPolicy = 'EULERIAN'
      bomStokesSource = 'FILES'
      bomWindSource = 'EXF'
      bomAlpha = 0.2 _d 0
      bomTau = 8. _d 0
      bomR = 0.823 _d 0
      bomSigma = 0.7 _d 0
      bomAdvCFL = 0.9 _d 0
      deltaTClock = tEnd
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_P24_PUBLISH_UNIFORM(
     I     0. _d 0, tEnd, 0, oldE, oldN, newE, newN,
     I     fValue, myThid )

      IF ( myProcId.EQ.0 ) THEN
        bi = myBxLo(myThid)
        bj = myByLo(myThid)
        iPoint = MIN(4,sNx)
        jPoint = MIN(3,sNy)
        x0 = xC(iPoint,jPoint,bi,bj)
        y0 = yC(iPoint,jPoint,bi,bj)
        stageTime = 0.37 _d 0*tEnd
        theta = stageTime/tEnd
        CALL BOM_RHS_SLOW_MANIFOLD(
     I       x0, y0, stageTime, tEnd, bi, bj, BOM_STAGE_K1,
     O       rhsX, rhsY, ix, jy, diag,
     O       wetWeight, stageCFL,
     O       isOwner, rhsValid, failCode, failStage,
     I       myThid )
        CALL BOM_P24_ASSERT(rhsValid .AND. isOwner,failI03)
        tolerance = 4096. _d 0*EPSILON(oneRL)
        DO iSource=1,BOM_ENV_NSOURCE
          CALL BOM_P24_ASSERT(
     I         ABS(diag(2*iSource-1)
     &          -((oneRL-theta)*oldE(iSource)
     &                         +theta*newE(iSource)))
     &          .LE.tolerance,
     U         failI03 )
          CALL BOM_P24_ASSERT(
     I         ABS(diag(2*iSource)
     &          -((oneRL-theta)*oldN(iSource)
     &                         +theta*newN(iSource)))
     &          .LE.tolerance,
     U         failI03 )
        ENDDO

        v0E = oldE(BOM_ENV_EULERIAN)
     &       +bomSigma*oldE(BOM_ENV_STOKES)
        v0N = oldN(BOM_ENV_EULERIAN)
     &       +bomSigma*oldN(BOM_ENV_STOKES)
        vRateE = slopeE(BOM_ENV_EULERIAN)
     &          +bomSigma*slopeE(BOM_ENV_STOKES)
        vRateN = slopeN(BOM_ENV_EULERIAN)
     &          +bomSigma*slopeN(BOM_ENV_STOKES)
        u0E = (oneRL-bomAlpha)*v0E
     &       +bomAlpha*oldE(BOM_ENV_WIND)
        u0N = (oneRL-bomAlpha)*v0N
     &       +bomAlpha*oldN(BOM_ENV_WIND)
        uRateE = (oneRL-bomAlpha)*vRateE
     &          +bomAlpha*slopeE(BOM_ENV_WIND)
        uRateN = (oneRL-bomAlpha)*vRateN
     &          +bomAlpha*slopeN(BOM_ENV_WIND)
        inert0E = bomR*vRateE-bomR*fValue*v0N
     &          -uRateE+fValue*u0N
        inert0N = bomR*vRateN+bomR*fValue*v0E
     &          -uRateN-fValue*u0E
        inertRateE = -bomR*fValue*vRateN+fValue*uRateN
        inertRateN = bomR*fValue*vRateE-fValue*uRateE
        drift0E = u0E+bomTau*inert0E
        drift0N = u0N+bomTau*inert0N
        driftRateE = uRateE+bomTau*inertRateE
        driftRateN = uRateN+bomTau*inertRateN
        CALL BOM_P24_ASSERT(
     I       ABS(diag(BOM_RHS_DRIFT_E)
     &       -(drift0E+stageTime*driftRateE))
     &       .LE.tolerance,
     U       failI03 )
        CALL BOM_P24_ASSERT(
     I       ABS(diag(BOM_RHS_DRIFT_N)
     &       -(drift0N+stageTime*driftRateN))
     &       .LE.tolerance,
     U       failI03 )
        xExact = x0+tEnd*drift0E
     &         +0.5 _d 0*tEnd*tEnd*driftRateE
        yExact = y0+tEnd*drift0N
     &         +0.5 _d 0*tEnd*tEnd*driftRateN
        CALL BOM_RK2_SLOW_MIGRATE(
     I       x0, y0, 0. _d 0, tEnd, bi, bj,
     O       xTrial, yTrial, ix, jy, diag,
     O       wetWeight, stageCFL,
     O       failStage, failCode, stepValid,
     I       myThid )
        CALL BOM_P24_ASSERT(stepValid .AND.
     &       ABS(xTrial-xExact).LE.2. _d -11 .AND.
     &       ABS(yTrial-yExact).LE.2. _d -11,failI03)
        CALL BOM_RK4_SLOW_MIGRATE(
     I       x0, y0, 0. _d 0, tEnd, bi, bj,
     O       xTrial, yTrial, ix, jy, diag,
     O       wetWeight, stageCFL,
     O       failStage, failCode, stepValid,
     I       myThid )
        CALL BOM_P24_ASSERT(stepValid .AND.
     &       ABS(xTrial-xExact).LE.2. _d -11 .AND.
     &       ABS(yTrial-yExact).LE.2. _d -11,failI03)
      ENDIF

C--   Quadratic forcing sampled only at endpoints: both schemes retain
C     second-order representation convergence when the bracket is refined.
      _BEGIN_MASTER(myThid)
      bomStokesSource = 'NONE'
      bomWindSource = 'NONE'
      bomAlpha = 0. _d 0
      bomTau = 0. _d 0
      bomSigma = 0. _d 0
      _END_MASTER(myThid)
      _BARRIER
      coeff = 1.0 _d -6
      tEnd = 100. _d 0
      DO iCase=1,4
        nStep = 2**iCase
        dt = tEnd/DFLOAT(nStep)
        IF ( myProcId.EQ.0 ) THEN
          bi = myBxLo(myThid)
          bj = myByLo(myThid)
          x0 = xC(MIN(4,sNx),MIN(3,sNy),bi,bj)
          y0 = yC(MIN(4,sNx),MIN(3,sNy),bi,bj)
          xTrial = x0
          yTrial = y0
        ENDIF
        DO iStep=1,nStep
          DO iSource=1,BOM_ENV_NSOURCE
            oldE(iSource) = 0. _d 0
            oldN(iSource) = 0. _d 0
            newE(iSource) = 0. _d 0
            newN(iSource) = 0. _d 0
          ENDDO
          oldE(BOM_ENV_EULERIAN) =
     &         coeff*(DFLOAT(iStep-1)*dt)**2
          newE(BOM_ENV_EULERIAN) =
     &         coeff*(DFLOAT(iStep)*dt)**2
          _BEGIN_MASTER(myThid)
          deltaTClock = dt
          _END_MASTER(myThid)
          _BARRIER
          CALL BOM_P24_PUBLISH_UNIFORM(
     I         DFLOAT(iStep-1)*dt, DFLOAT(iStep)*dt, iStep-1,
     I         oldE, oldN, newE, newN, 0. _d 0, myThid )
          IF ( myProcId.EQ.0 ) THEN
            CALL BOM_RK2_SLOW_MIGRATE(
     I           xTrial, yTrial, DFLOAT(iStep-1)*dt,
     I           dt, bi, bj,
     O           rhsX, rhsY, ix, jy, diag,
     O           wetWeight, stageCFL,
     O           failStage, failCode, stepValid,
     I           myThid )
            CALL BOM_P24_ASSERT(stepValid,failI04)
            IF ( stepValid ) THEN
              xTrial = rhsX
              yTrial = rhsY
            ENDIF
          ENDIF
        ENDDO
        IF ( myProcId.EQ.0 ) THEN
          xExact = x0+coeff*tEnd**3/3. _d 0
          errors2(iCase) = ABS(xTrial-xExact)
          xTrial = x0
          yTrial = y0
        ENDIF
        DO iStep=1,nStep
          DO iSource=1,BOM_ENV_NSOURCE
            oldE(iSource) = 0. _d 0
            oldN(iSource) = 0. _d 0
            newE(iSource) = 0. _d 0
            newN(iSource) = 0. _d 0
          ENDDO
          oldE(BOM_ENV_EULERIAN) =
     &         coeff*(DFLOAT(iStep-1)*dt)**2
          newE(BOM_ENV_EULERIAN) =
     &         coeff*(DFLOAT(iStep)*dt)**2
          CALL BOM_P24_PUBLISH_UNIFORM(
     I         DFLOAT(iStep-1)*dt, DFLOAT(iStep)*dt, iStep-1,
     I         oldE, oldN, newE, newN, 0. _d 0, myThid )
          IF ( myProcId.EQ.0 ) THEN
            CALL BOM_RK4_SLOW_MIGRATE(
     I           xTrial, yTrial, DFLOAT(iStep-1)*dt,
     I           dt, bi, bj,
     O           rhsX, rhsY, ix, jy, diag,
     O           wetWeight, stageCFL,
     O           failStage, failCode, stepValid,
     I           myThid )
            CALL BOM_P24_ASSERT(stepValid,failI04)
            IF ( stepValid ) THEN
              xTrial = rhsX
              yTrial = rhsY
            ENDIF
          ENDIF
        ENDDO
        IF ( myProcId.EQ.0 ) errors4(iCase) = ABS(xTrial-xExact)
      ENDDO
      IF ( myProcId.EQ.0 ) THEN
        DO iCase=1,3
          orderValue = LOG(errors2(iCase)/errors2(iCase+1))
     &               /LOG(2. _d 0)
          CALL BOM_P24_ASSERT(
     I         IEEE_IS_FINITE(orderValue) .AND.
     &         orderValue.GE.1.8 _d 0 .AND.
     &         orderValue.LE.2.2 _d 0,failI04)
          orderValue = LOG(errors4(iCase)/errors4(iCase+1))
     &               /LOG(2. _d 0)
          CALL BOM_P24_ASSERT(
     I         IEEE_IS_FINITE(orderValue) .AND.
     &         orderValue.GE.1.8 _d 0 .AND.
     &         orderValue.LE.2.2 _d 0,failI04)
        ENDDO
      ENDIF

C--   K2 source failure must not touch any authoritative particle field.
      DO iSource=1,BOM_ENV_NSOURCE
        oldE(iSource) = 0. _d 0
        oldN(iSource) = 0. _d 0
        newE(iSource) = 0. _d 0
        newN(iSource) = 0. _d 0
      ENDDO
      oldE(BOM_ENV_EULERIAN) = 0.01 _d 0
      newE(BOM_ENV_EULERIAN) = 0.02 _d 0
      _BEGIN_MASTER(myThid)
      deltaTClock = tEnd
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_P24_PUBLISH_UNIFORM(
     I     0. _d 0, tEnd, 0, oldE, oldN, newE, newN,
     I     0. _d 0, myThid )
      IF ( myProcId.EQ.0 ) THEN
        DO jPoint=1-OLy,sNy+OLy
         DO iPoint=1-OLx,sNx+OLx
          bomEnvValid(iPoint,jPoint,BOM_ENV_NEW,
     &         BOM_ENV_EULERIAN,bi,bj) = .FALSE.
         ENDDO
        ENDDO
        sentinelX = 123.25 _d 0
        sentinelY = -456.5 _d 0
        sentinelAge = 17. _d 0
        sentinelStatus = BOM_ALIVE
        bomX(1,bi,bj) = sentinelX
        bomY(1,bi,bj) = sentinelY
        bomAge(1,bi,bj) = sentinelAge
        bomStatus(1,bi,bj) = sentinelStatus
        DO iDiag=1,BOM_RHS_NDIAG
          bomRhsDiag(iDiag,1,bi,bj) = DFLOAT(1000+iDiag)
          savedDiag(iDiag) = bomRhsDiag(iDiag,1,bi,bj)
        ENDDO
        CALL BOM_RK2_SLOW_MIGRATE(
     I       x0, y0, 0. _d 0, tEnd, bi, bj,
     O       xTrial, yTrial, ix, jy, diag,
     O       wetWeight, stageCFL,
     O       failStage, failCode, stepValid,
     I       myThid )
        CALL BOM_P24_ASSERT(.NOT.stepValid .AND.
     &       failStage.EQ.BOM_STAGE_K2 .AND.
     &       failCode.EQ.BOM_FAIL_FIELD_SOURCE .AND.
     &       xTrial.EQ.x0 .AND. yTrial.EQ.y0,failI04)
        CALL BOM_P24_ASSERT(
     I       bomX(1,bi,bj).EQ.sentinelX .AND.
     &       bomY(1,bi,bj).EQ.sentinelY .AND.
     &       bomAge(1,bi,bj).EQ.sentinelAge .AND.
     &       bomStatus(1,bi,bj).EQ.sentinelStatus,
     U       failI04 )
        DO iDiag=1,BOM_RHS_NDIAG
          CALL BOM_P24_ASSERT(
     I         bomRhsDiag(iDiag,1,bi,bj).EQ.savedDiag(iDiag),
     U         failI04 )
        ENDDO
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P24_PUBLISH_AFFINE(
     I                 time0, time1, iter0,
     I                 offsetE, offsetN, rateE, rateN,
     I                 gradEE, gradNE, gradEN, gradNN,
     I                 fValue, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL time0, time1, fValue
      _RL offsetE(BOM_ENV_NSOURCE), offsetN(BOM_ENV_NSOURCE)
      _RL rateE(BOM_ENV_NSOURCE), rateN(BOM_ENV_NSOURCE)
      _RL gradEE(BOM_ENV_NSOURCE), gradNE(BOM_ENV_NSOURCE)
      _RL gradEN(BOM_ENV_NSOURCE), gradNN(BOM_ENV_NSOURCE)
      INTEGER iter0, myThid
      INTEGER bi, bj, i, j, iEnd, iSource
      _RL xValue, yValue, pointTime

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          xValue = xC(i,j,bi,bj)
          yValue = yC(i,j,bi,bj)
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            IF ( iEnd.EQ.BOM_ENV_OLD ) THEN
              pointTime = time0
            ELSE
              pointTime = time1
            ENDIF
            bomEnvEast(i,j,iEnd,iSource,bi,bj) =
     &           offsetE(iSource)+rateE(iSource)*pointTime
     &          +gradEE(iSource)*xValue+gradNE(iSource)*yValue
            bomEnvNorth(i,j,iEnd,iSource,bi,bj) =
     &           offsetN(iSource)+rateN(iSource)*pointTime
     &          +gradEN(iSource)*xValue+gradNN(iSource)*yValue
            bomEnvValid(i,j,iEnd,iSource,bi,bj) =
     &           maskC(i,j,1,bi,bj).GT.0.
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BEGIN_MASTER(myThid)
      bomEnvTime(BOM_ENV_OLD) = time0
      bomEnvTime(BOM_ENV_NEW) = time1
      bomEnvIter(BOM_ENV_OLD) = iter0
      bomEnvIter(BOM_ENV_NEW) = iter0+1
      bomEnvReady = .TRUE.
      _END_MASTER(myThid)
      _BARRIER
      CALL BOM_BUILD_DERIVATIVES( myThid )
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          IF ( bomMetricValid(i,j,bi,bj) )
     &         bomFCori(i,j,bi,bj) = fValue
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BARRIER
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P24_PUBLISH_UNIFORM(
     I                 time0, time1, iter0,
     I                 oldE, oldN, newE, newN,
     I                 fValue, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL time0, time1, fValue
      _RL oldE(BOM_ENV_NSOURCE), oldN(BOM_ENV_NSOURCE)
      _RL newE(BOM_ENV_NSOURCE), newN(BOM_ENV_NSOURCE)
      INTEGER iter0, myThid
      INTEGER bi, bj, i, j, iSource
      LOGICAL wetPoint

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          bomTauSphere(i,j,bi,bj) = 0. _d 0
          bomFCori(i,j,bi,bj) = fValue
          bomMetricValid(i,j,bi,bj) = wetPoint
          DO iSource=1,BOM_ENV_NSOURCE
            bomEnvEast(i,j,BOM_ENV_OLD,iSource,bi,bj) =
     &           oldE(iSource)
            bomEnvNorth(i,j,BOM_ENV_OLD,iSource,bi,bj) =
     &           oldN(iSource)
            bomEnvEast(i,j,BOM_ENV_NEW,iSource,bi,bj) =
     &           newE(iSource)
            bomEnvNorth(i,j,BOM_ENV_NEW,iSource,bi,bj) =
     &           newN(iSource)
            bomEnvValid(i,j,BOM_ENV_OLD,iSource,bi,bj) = wetPoint
            bomEnvValid(i,j,BOM_ENV_NEW,iSource,bi,bj) = wetPoint
            bomGradEastEast(i,j,BOM_ENV_OLD,iSource,bi,bj) = 0. _d 0
            bomGradEastEast(i,j,BOM_ENV_NEW,iSource,bi,bj) = 0. _d 0
            bomGradNorthEast(i,j,BOM_ENV_OLD,iSource,bi,bj) = 0. _d 0
            bomGradNorthEast(i,j,BOM_ENV_NEW,iSource,bi,bj) = 0. _d 0
            bomGradEastNorth(i,j,BOM_ENV_OLD,iSource,bi,bj) = 0. _d 0
            bomGradEastNorth(i,j,BOM_ENV_NEW,iSource,bi,bj) = 0. _d 0
            bomGradNorthNorth(i,j,BOM_ENV_OLD,iSource,bi,bj) = 0. _d 0
            bomGradNorthNorth(i,j,BOM_ENV_NEW,iSource,bi,bj) = 0. _d 0
            bomGradValid(i,j,BOM_ENV_OLD,iSource,bi,bj) = wetPoint
            bomGradValid(i,j,BOM_ENV_NEW,iSource,bi,bj) = wetPoint
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BEGIN_MASTER(myThid)
      bomEnvTime(BOM_ENV_OLD) = time0
      bomEnvTime(BOM_ENV_NEW) = time1
      bomEnvIter(BOM_ENV_OLD) = iter0
      bomEnvIter(BOM_ENV_NEW) = iter0+1
      bomEnvReady = .TRUE.
      bomGradReady = .TRUE.
      bomMetricReady = .TRUE.
      _END_MASTER(myThid)
      _BARRIER
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P24_ASSERT( condition, nFail )
      IMPLICIT NONE
      LOGICAL condition
      INTEGER nFail
      IF ( .NOT.condition ) nFail = nFail+1
      RETURN
      END
