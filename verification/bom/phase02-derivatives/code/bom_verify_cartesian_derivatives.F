#include "BOM_OPTIONS.h"
#include "FCORI_MACROS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VERIFY_CARTESIAN_DERIVATIVES
C !INTERFACE:
      SUBROUTINE BOM_VERIFY_CARTESIAN_DERIVATIVES( myThid )

C !DESCRIPTION:
C     Test-only P2-D01--D03 and Cartesian P2-N05 production gate.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_VALUE, IEEE_QUIET_NAN
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, i, j, iEnd, iSource
      INTEGER iGlobal, jGlobal, nFail, globalFail
      INTEGER failCode, validInt
      INTEGER iTest, jTest, biTest, bjTest
      _RL xValue, yValue, oldEast, oldNorth
      _RL aEE, aNE, aEN, aNN, rateEast, rateNorth
      _RL expected, tolerance, fieldScale, metricScale
      _RL stageEast, stageNorth, dtEast, dtNorth
      _RL h, errCoarse, errFine, orderCentral, orderForward
      _RL a0, a1, a2, deriv, savedGrad, savedTau, savedFCori
      _RL dEast, dNorth
      _RL stageDEE, stageDNE, stageDEN, stageDNN
      LOGICAL gradInterpValid
      _RS savedMetric
      LOGICAL pointValid, interpValid, coeffValid, applyValid
      LOGICAL tryValid, gradValid, metricValid, valueValid
      LOGICAL savedReady, savedMetricReady, savedMetricValid
      LOGICAL savedValidM2, savedValidM1
      LOGICAL savedValidP1, savedValidP2

      nFail = 0
      aEE = 2.0 _d -4
      aNE = -3.0 _d -4
      aEN = -4.0 _d -4
      aNN = 5.0 _d -4
      rateEast = 7.0 _d -6
      rateNorth = -9.0 _d -6

C--   Publish two affine endpoint fields on the actual nonuniform grid.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          xValue = xC(i,j,bi,bj)
          yValue = yC(i,j,bi,bj)
          oldEast = aEE*xValue + aNE*yValue + 1.25 _d 0
          oldNorth = aEN*xValue + aNN*yValue - 0.75 _d 0
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            bomEnvEast(i,j,iEnd,iSource,bi,bj) = 0. _d 0
            bomEnvNorth(i,j,iEnd,iSource,bi,bj) = 0. _d 0
            bomEnvValid(i,j,iEnd,iSource,bi,bj) =
     &           maskC(i,j,1,bi,bj).GT.0.
           ENDDO
          ENDDO
          IF ( maskC(i,j,1,bi,bj).GT.0. ) THEN
            bomEnvEast(i,j,BOM_ENV_OLD,
     &           BOM_ENV_EULERIAN,bi,bj) = oldEast
            bomEnvNorth(i,j,BOM_ENV_OLD,
     &           BOM_ENV_EULERIAN,bi,bj) = oldNorth
            bomEnvEast(i,j,BOM_ENV_NEW,
     &           BOM_ENV_EULERIAN,bi,bj) =
     &           oldEast + rateEast*deltaTClock
            bomEnvNorth(i,j,BOM_ENV_NEW,
     &           BOM_ENV_EULERIAN,bi,bj) =
     &           oldNorth + rateNorth*deltaTClock
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BEGIN_MASTER(myThid)
      bomEnvTime(BOM_ENV_OLD) = startTime
      bomEnvTime(BOM_ENV_NEW) = startTime + deltaTClock
      bomEnvIter(BOM_ENV_OLD) = nIter0
      bomEnvIter(BOM_ENV_NEW) = nIter0 + 1
      bomEnvReady = .TRUE.
      _END_MASTER(myThid)
      _BARRIER

      CALL BOM_BUILD_DERIVATIVES( myThid )
      CALL BOM_VERIFY_DERIV_ASSERT(
     &     bomGradReady .AND. bomMetricReady,
     &     'gradient and metric publication ready',
     &     nFail, myThid )

C--   D01: affine derivatives on interior points, including tile seams.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          iGlobal = myXGlobalLo + (bi-1)*sNx + i - 1
          jGlobal = myYGlobalLo + (bj-1)*sNy + j - 1
          IF ( iGlobal.GE.3 .AND. iGlobal.LE.Nx-2 .AND.
     &         jGlobal.GE.3 .AND. jGlobal.LE.Ny-2 ) THEN
            fieldScale = MAX(1. _d 0,
     &           ABS(bomEnvEast(i,j,BOM_ENV_OLD,
     &                          BOM_ENV_EULERIAN,bi,bj)),
     &           ABS(bomEnvNorth(i,j,BOM_ENV_OLD,
     &                           BOM_ENV_EULERIAN,bi,bj)))
            metricScale = MIN(DBLE(dxC(i,j,bi,bj)),
     &                        DBLE(dxC(i+1,j,bi,bj)),
     &                        DBLE(dyC(i,j,bi,bj)),
     &                        DBLE(dyC(i,j+1,bi,bj)))
            tolerance = 512. _d 0*EPSILON(oneRL)
     &           *MAX(1. _d 0,fieldScale/metricScale,
     &                ABS(aEE),ABS(aNE),ABS(aEN),ABS(aNN))
            CALL BOM_VERIFY_DERIV_ASSERT(
     &           bomGradValid(i,j,BOM_ENV_OLD,
     &                        BOM_ENV_EULERIAN,bi,bj),
     &           'affine OLD gradient valid', nFail, myThid )
            CALL BOM_VERIFY_DERIV_ASSERT(
     &           bomGradValid(i,j,BOM_ENV_NEW,
     &                        BOM_ENV_EULERIAN,bi,bj),
     &           'affine NEW gradient valid', nFail, myThid )
            CALL BOM_VERIFY_DERIV_ASSERT(
     &           ABS(bomGradEastEast(i,j,BOM_ENV_OLD,
     &                 BOM_ENV_EULERIAN,bi,bj)-aEE).LE.tolerance,
     &           'affine dE(east)', nFail, myThid )
            CALL BOM_VERIFY_DERIV_ASSERT(
     &           ABS(bomGradNorthEast(i,j,BOM_ENV_OLD,
     &                 BOM_ENV_EULERIAN,bi,bj)-aNE).LE.tolerance,
     &           'affine dN(east)', nFail, myThid )
            CALL BOM_VERIFY_DERIV_ASSERT(
     &           bomMetricValid(i,j,bi,bj) .AND.
     &           bomTauSphere(i,j,bi,bj).EQ.0. _d 0 .AND.
     &           bomFCori(i,j,bi,bj).EQ.
     &                DBLE(_fCori(i,j,bi,bj)),
     &           'Cartesian tauSphere zero and MITgcm fCori',
     &           nFail, myThid )
            CALL BOM_VERIFY_DERIV_ASSERT(
     &           ABS(bomGradEastNorth(i,j,BOM_ENV_OLD,
     &                 BOM_ENV_EULERIAN,bi,bj)-aEN).LE.tolerance,
     &           'affine dE(north)', nFail, myThid )
            CALL BOM_VERIFY_DERIV_ASSERT(
     &           ABS(bomGradNorthNorth(i,j,BOM_ENV_OLD,
     &                 BOM_ENV_EULERIAN,bi,bj)-aNN).LE.tolerance,
     &           'affine dN(north)', nFail, myThid )
            CALL BOM_VERIFY_DERIV_ASSERT(
     &           bomGradEastEast(i,j,BOM_ENV_OLD,
     &                 BOM_ENV_STOKES,bi,bj).EQ.0. _d 0 .AND.
     &           bomGradNorthEast(i,j,BOM_ENV_OLD,
     &                 BOM_ENV_STOKES,bi,bj).EQ.0. _d 0 .AND.
     &           bomGradEastNorth(i,j,BOM_ENV_OLD,
     &                 BOM_ENV_STOKES,bi,bj).EQ.0. _d 0 .AND.
     &           bomGradNorthNorth(i,j,BOM_ENV_OLD,
     &                 BOM_ENV_STOKES,bi,bj).EQ.0. _d 0,
     &           'constant derivative exact zero', nFail, myThid )
            validInt = 0
            IF ( bomGradValid(i,j,BOM_ENV_OLD,
     &                        BOM_ENV_EULERIAN,bi,bj) )
     &           validInt = 1
            WRITE(standardMessageUnit,
     &           '(A,2I5,4(1X,Z16.16),1X,I1)')
     &           'P22-GRAD-RECORD', iGlobal, jGlobal,
     &           TRANSFER(bomGradEastEast(i,j,BOM_ENV_OLD,
     &                    BOM_ENV_EULERIAN,bi,bj),0_8),
     &           TRANSFER(bomGradNorthEast(i,j,BOM_ENV_OLD,
     &                    BOM_ENV_EULERIAN,bi,bj),0_8),
     &           TRANSFER(bomGradEastNorth(i,j,BOM_ENV_OLD,
     &                    BOM_ENV_EULERIAN,bi,bj),0_8),
     &           TRANSFER(bomGradNorthNorth(i,j,BOM_ENV_OLD,
     &                    BOM_ENV_EULERIAN,bi,bj),0_8),
     &           validInt
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   The primary endpoint bracket supplies the exact time secant.
      biTest = myBxLo(myThid)
      bjTest = myByLo(myThid)
      iTest = 2
      jTest = 2
      CALL BOM_INTERP_ENV_TIME(
     I     iTest, jTest, biTest, bjTest, BOM_ENV_EULERIAN,
     I     startTime+0.5 _d 0*deltaTClock,
     O     stageEast, stageNorth, dtEast, dtNorth, pointValid,
     O     failCode, iEnd, interpValid,
     I     myThid )
      expected = 0.5 _d 0*(
     &     bomEnvEast(iTest,jTest,BOM_ENV_OLD,
     &                BOM_ENV_EULERIAN,biTest,bjTest)
     &    +bomEnvEast(iTest,jTest,BOM_ENV_NEW,
     &                BOM_ENV_EULERIAN,biTest,bjTest))
      tolerance = 512. _d 0*EPSILON(oneRL)
      CALL BOM_VERIFY_DERIV_ASSERT(
     &     interpValid .AND. pointValid .AND.
     &     failCode.EQ.BOM_FAIL_NONE,
     &     'time midpoint interpolation valid', nFail, myThid )
      CALL BOM_VERIFY_DERIV_ASSERT(
     &     ABS(stageEast-expected).LE.tolerance
     &       *MAX(1. _d 0,ABS(expected)) .AND.
     &     ABS(dtEast-rateEast).LE.tolerance .AND.
     &     ABS(dtNorth-rateNorth).LE.tolerance,
     &     'exact field time secant', nFail, myThid )
      CALL BOM_INTERP_ENV_DERIVATIVES(
     I     iTest, jTest, biTest, bjTest, BOM_ENV_EULERIAN,
     I     startTime+0.5 _d 0*deltaTClock,
     O     stageDEE, stageDNE, stageDEN, stageDNN,
     O     pointValid,
     O     failCode, iEnd, gradInterpValid,
     I     myThid )
      CALL BOM_VERIFY_DERIV_ASSERT(
     &     gradInterpValid .AND. pointValid .AND.
     &     failCode.EQ.BOM_FAIL_NONE .AND.
     &     ABS(stageDEE-aEE).LE.tolerance .AND.
     &     ABS(stageDNE-aNE).LE.tolerance .AND.
     &     ABS(stageDEN-aEN).LE.tolerance .AND.
     &     ABS(stageDNN-aNN).LE.tolerance,
     &     'gradient midpoint interpolation', nFail, myThid )


C--   D02: three-point formulas are quadratic-exact; cubic error is O(h^2).
      h = 400. _d 0
      CALL BOM_DERIV_COEFF_CENTRAL(
     I     h, h,
     O     a0, a1, a2, coeffValid )
      CALL BOM_DERIV_APPLY3(
     I     h*h, 0. _d 0, h*h, a0, a1, a2,
     O     deriv, applyValid )
      CALL BOM_VERIFY_DERIV_ASSERT(
     &     coeffValid .AND. applyValid .AND.
     &     deriv.EQ.0. _d 0,
     &     'quadratic represented derivative exact', nFail, myThid )

      CALL BOM_DERIV_COEFF_CENTRAL(
     I     h, h,
     O     a0, a1, a2, coeffValid )
      CALL BOM_DERIV_APPLY3(
     I     -h*h*h, 0. _d 0, h*h*h, a0, a1, a2,
     O     deriv, applyValid )
      errCoarse = ABS(deriv)
      CALL BOM_DERIV_COEFF_CENTRAL(
     I     0.5 _d 0*h, 0.5 _d 0*h,
     O     a0, a1, a2, coeffValid )
      CALL BOM_DERIV_APPLY3(
     I     -(0.5 _d 0*h)**3, 0. _d 0, (0.5 _d 0*h)**3,
     I     a0, a1, a2,
     O     deriv, applyValid )
      errFine = ABS(deriv)
      orderCentral = LOG(errCoarse/errFine)/LOG(2. _d 0)

      CALL BOM_DERIV_COEFF_FORWARD(
     I     h, h,
     O     a0, a1, a2, coeffValid )
      CALL BOM_DERIV_APPLY3(
     I     0. _d 0, h*h*h, (2. _d 0*h)**3,
     I     a0, a1, a2,
     O     deriv, applyValid )
      errCoarse = ABS(deriv)
      CALL BOM_DERIV_COEFF_FORWARD(
     I     0.5 _d 0*h, 0.5 _d 0*h,
     O     a0, a1, a2, coeffValid )
      CALL BOM_DERIV_APPLY3(
     I     0. _d 0, (0.5 _d 0*h)**3, h*h*h,
     I     a0, a1, a2,
     O     deriv, applyValid )
      errFine = ABS(deriv)
      orderForward = LOG(errCoarse/errFine)/LOG(2. _d 0)
      CALL BOM_VERIFY_DERIV_ASSERT(
     &     orderCentral.GE.1.8 _d 0 .AND.
     &     orderCentral.LE.2.2 _d 0 .AND.
     &     orderForward.GE.1.8 _d 0 .AND.
     &     orderForward.LE.2.2 _d 0,
     &     'centered and one-sided second order', nFail, myThid )

C--   N05: an unavailable all-wet stencil returns invalid, never valid zero.
      savedValidM2 = bomEnvValid(iTest-2,jTest,BOM_ENV_OLD,
     &                 BOM_ENV_EULERIAN,biTest,bjTest)
      savedValidM1 = bomEnvValid(iTest-1,jTest,BOM_ENV_OLD,
     &                 BOM_ENV_EULERIAN,biTest,bjTest)
      savedValidP1 = bomEnvValid(iTest+1,jTest,BOM_ENV_OLD,
     &                 BOM_ENV_EULERIAN,biTest,bjTest)
      savedValidP2 = bomEnvValid(iTest+2,jTest,BOM_ENV_OLD,
     &                 BOM_ENV_EULERIAN,biTest,bjTest)
      bomEnvValid(iTest-2,jTest,BOM_ENV_OLD,
     &     BOM_ENV_EULERIAN,biTest,bjTest) = .FALSE.
      bomEnvValid(iTest-1,jTest,BOM_ENV_OLD,
     &     BOM_ENV_EULERIAN,biTest,bjTest) = .FALSE.
      bomEnvValid(iTest+1,jTest,BOM_ENV_OLD,
     &     BOM_ENV_EULERIAN,biTest,bjTest) = .FALSE.
      bomEnvValid(iTest+2,jTest,BOM_ENV_OLD,
     &     BOM_ENV_EULERIAN,biTest,bjTest) = .FALSE.
      CALL BOM_DERIVATIVE_X_PAIR(
     I     iTest,jTest,biTest,bjTest,BOM_ENV_OLD,
     I     BOM_ENV_EULERIAN,.FALSE.,
     O     dEast,dNorth,gradValid,metricValid,valueValid )
      CALL BOM_VERIFY_DERIV_ASSERT(
     &     .NOT.gradValid .AND. metricValid .AND. valueValid
     &     .AND. dEast.EQ.0. _d 0 .AND. dNorth.EQ.0. _d 0,
     &     'insufficient stencil explicit invalidity',
     &     nFail, myThid )
      bomEnvValid(iTest-2,jTest,BOM_ENV_OLD,
     &     BOM_ENV_EULERIAN,biTest,bjTest) = savedValidM2
      bomEnvValid(iTest-1,jTest,BOM_ENV_OLD,
     &     BOM_ENV_EULERIAN,biTest,bjTest) = savedValidM1
      bomEnvValid(iTest+1,jTest,BOM_ENV_OLD,
     &     BOM_ENV_EULERIAN,biTest,bjTest) = savedValidP1
      bomEnvValid(iTest+2,jTest,BOM_ENV_OLD,
     &     BOM_ENV_EULERIAN,biTest,bjTest) = savedValidP2

C--   Zero and NaN metrics fail scratch construction without publication.
      savedGrad = bomGradEastEast(iTest,jTest,BOM_ENV_OLD,
     &              BOM_ENV_EULERIAN,biTest,bjTest)
      savedReady = bomGradReady
      savedMetric = dxC(iTest,jTest,biTest,bjTest)
      dxC(iTest,jTest,biTest,bjTest) = 0.
      savedTau = bomTauSphere(iTest,jTest,biTest,bjTest)
      savedFCori = bomFCori(iTest,jTest,biTest,bjTest)
      savedMetricReady = bomMetricReady
      savedMetricValid = bomMetricValid(iTest,jTest,biTest,bjTest)
      CALL BOM_TRY_BUILD_DERIVATIVES(
     I     .FALSE.,
     O     failCode, tryValid,
     I     myThid )
      CALL BOM_VERIFY_DERIV_ASSERT(
     &     .NOT.tryValid .AND. failCode.EQ.BOM_FAIL_METRIC
     &     .AND. (bomGradReady.EQV.savedReady)
     &     .AND. (bomMetricReady.EQV.savedMetricReady)
     &     .AND. (bomMetricValid(iTest,jTest,biTest,bjTest)
     &                   .EQV.savedMetricValid)
     &     .AND. bomTauSphere(iTest,jTest,biTest,bjTest)
     &                   .EQ.savedTau
     &     .AND. bomFCori(iTest,jTest,biTest,bjTest)
     &                   .EQ.savedFCori
     &     .AND. bomGradEastEast(iTest,jTest,BOM_ENV_OLD,
     &              BOM_ENV_EULERIAN,biTest,bjTest).EQ.savedGrad,
     &     'zero metric rollback', nFail, myThid )
      dxC(iTest,jTest,biTest,bjTest) = savedMetric

      dxC(iTest,jTest,biTest,bjTest) =
     &     IEEE_VALUE(dxC(iTest,jTest,biTest,bjTest),
     &                IEEE_QUIET_NAN)
      CALL BOM_TRY_BUILD_DERIVATIVES(
     I     .FALSE.,
     O     failCode, tryValid,
     I     myThid )
      CALL BOM_VERIFY_DERIV_ASSERT(
     &     .NOT.tryValid .AND. failCode.EQ.BOM_FAIL_METRIC
     &     .AND. (bomGradReady.EQV.savedReady)
     &     .AND. (bomMetricReady.EQV.savedMetricReady)
     &     .AND. (bomMetricValid(iTest,jTest,biTest,bjTest)
     &                   .EQV.savedMetricValid)
     &     .AND. bomTauSphere(iTest,jTest,biTest,bjTest)
     &                   .EQ.savedTau
     &     .AND. bomFCori(iTest,jTest,biTest,bjTest)
     &                   .EQ.savedFCori
     &     .AND. bomGradEastEast(iTest,jTest,BOM_ENV_OLD,
     &              BOM_ENV_EULERIAN,biTest,bjTest).EQ.savedGrad,
     &     'NaN metric rollback', nFail, myThid )
      dxC(iTest,jTest,biTest,bjTest) = savedMetric

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_VERIFY_CARTESIAN_DERIVATIVES: failures=',
     &         globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_CARTESIAN_DERIVATIVES'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P2-D01 PASS: Cartesian affine and constant gradients'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
        WRITE(msgBuf,'(A,2F8.3)')
     &       'P2-D02 PASS: centered/one-sided observed orders=',
     &       orderCentral, orderForward
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
        WRITE(msgBuf,'(A)')
     &       'P2-N05 PASS: stencil invalidity and metric rollback'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_DERIV_ASSERT(
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
        IF ( nFail.LT.16 ) THEN
          WRITE(msgBuf,'(2A)')
     &         'BOM_VERIFY_CARTESIAN_DERIVATIVES: FAIL: ', label
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        nFail = nFail + 1
      ENDIF

      RETURN
      END
