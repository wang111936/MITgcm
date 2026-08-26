#include "BOM_OPTIONS.h"
#include "FCORI_MACROS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VERIFY_SPHERICAL_DERIVATIVES
C !INTERFACE:
      SUBROUTINE BOM_VERIFY_SPHERICAL_DERIVATIVES( myThid )

C !DESCRIPTION:
C     Test-only P2-D04/D05 and spherical P2-N05 production gate.

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
      _RL latitude, latRad, cosLat, xArc, yArc
      _RL slopeEE, slopeEN, slopeNE, slopeNN, solidOmega
      _RL tauExpected, coriExpected, gradTol, metricTol
      _RL wEast, wNorth, dSelfEast, dSelfNorth, vorticity
      _RL expectedNorth, expectedVort, expectedEast
      _RL expectedBaseVort, expectedStokesVort
      _RL savedRadius, savedTau, savedCori
      _RL hugeValue
      _RS savedLatitude, savedGridCori
      LOGICAL evalValid, tryValid, savedReady, pointMetricValid
      LOGICAL savedMetricValid

      nFail = 0
      slopeEE = 2.0 _d -7
      slopeEN = -3.0 _d -7
      slopeNE = 1.1 _d -7
      slopeNN = 2.5 _d -7
      solidOmega = 2.0 _d -6
      gradTol = 5.0 _d -11

C--   Publish analytic zonal, meridional and solid-body fields.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          latitude = DBLE(yC(i,j,bi,bj))
          latRad = deg2rad*latitude
          cosLat = COS(latRad)
          xArc = rSphere*deg2rad*DBLE(xC(i,j,bi,bj))*cosLat
          yArc = rSphere*deg2rad*latitude
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            bomEnvEast(i,j,iEnd,iSource,bi,bj) = 0. _d 0
            bomEnvNorth(i,j,iEnd,iSource,bi,bj) = 0. _d 0
            bomEnvValid(i,j,iEnd,iSource,bi,bj) =
     &           maskC(i,j,1,bi,bj).GT.0.
           ENDDO
          ENDDO
          IF ( maskC(i,j,1,bi,bj).GT.0. ) THEN
           DO iEnd=1,BOM_ENV_NEND
C--          Zonal physical-coordinate field for east gradients.
            bomEnvEast(i,j,iEnd,BOM_ENV_EULERIAN,bi,bj) =
     &           slopeEE*xArc
            bomEnvNorth(i,j,iEnd,BOM_ENV_EULERIAN,bi,bj) =
     &           slopeEN*xArc
C--          Meridional physical-coordinate field for north gradients.
            bomEnvEast(i,j,iEnd,BOM_ENV_STOKES,bi,bj) =
     &           slopeNE*yArc
            bomEnvNorth(i,j,iEnd,BOM_ENV_STOKES,bi,bj) =
     &           slopeNN*yArc
C--          Spherical zonal solid-body field for covariant/vorticity.
            bomEnvEast(i,j,iEnd,BOM_ENV_WIND,bi,bj) =
     &           solidOmega*rSphere*cosLat
            bomEnvNorth(i,j,iEnd,BOM_ENV_WIND,bi,bj) = 0. _d 0
           ENDDO
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BEGIN_MASTER(myThid)
      bomEnvTime(BOM_ENV_OLD) = startTime
      bomEnvTime(BOM_ENV_NEW) = startTime
      bomEnvIter(BOM_ENV_OLD) = nIter0
      bomEnvIter(BOM_ENV_NEW) = nIter0
      bomEnvReady = .TRUE.
      _END_MASTER(myThid)
      _BARRIER

      CALL BOM_BUILD_DERIVATIVES( myThid )
      CALL BOM_VERIFY_SPHERE_ASSERT(
     &     bomGradReady .AND. bomMetricReady,
     &     'gradient and metric publication ready', nFail, myThid )

C--   D04/D05 at multiple owned interior latitudes and tile seams.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          iGlobal = myXGlobalLo + (bi-1)*sNx + i - 1
          jGlobal = myYGlobalLo + (bj-1)*sNy + j - 1
          IF ( iGlobal.GE.3 .AND. iGlobal.LE.Nx-2 .AND.
     &         jGlobal.GE.3 .AND. jGlobal.LE.Ny-2 ) THEN
            latitude = DBLE(yC(i,j,bi,bj))
            latRad = deg2rad*latitude
            cosLat = COS(latRad)
            tauExpected = TAN(latRad)/rSphere
            coriExpected = DBLE(_fCori(i,j,bi,bj))
            metricTol = 1024. _d 0*EPSILON(oneRL)
     &           *MAX(1. _d 0,ABS(tauExpected),ABS(coriExpected))
            CALL BOM_VERIFY_SPHERE_ASSERT(
     &           bomMetricValid(i,j,bi,bj),
     &           'spherical metric valid', nFail, myThid )
            CALL BOM_VERIFY_SPHERE_ASSERT(
     &           ABS(bomTauSphere(i,j,bi,bj)-tauExpected)
     &             .LE.metricTol .AND.
     &           bomFCori(i,j,bi,bj).EQ.coriExpected,
     &           'tauSphere and MITgcm fCori', nFail, myThid )

C--         Physical east/north gradients use dxC/dyC exactly once.
            CALL BOM_VERIFY_SPHERE_ASSERT(
     &           bomGradValid(i,j,BOM_ENV_OLD,
     &                        BOM_ENV_EULERIAN,bi,bj) .AND.
     &           ABS(bomGradEastEast(i,j,BOM_ENV_OLD,
     &                BOM_ENV_EULERIAN,bi,bj)-slopeEE)
     &             .LE.gradTol .AND.
     &           ABS(bomGradEastNorth(i,j,BOM_ENV_OLD,
     &                BOM_ENV_EULERIAN,bi,bj)-slopeEN)
     &             .LE.gradTol,
     &           'zonal physical gradients', nFail, myThid )
            CALL BOM_VERIFY_SPHERE_ASSERT(
     &           bomGradValid(i,j,BOM_ENV_OLD,
     &                        BOM_ENV_STOKES,bi,bj) .AND.
     &           ABS(bomGradNorthEast(i,j,BOM_ENV_OLD,
     &                BOM_ENV_STOKES,bi,bj)-slopeNE)
     &             .LE.gradTol .AND.
     &           ABS(bomGradNorthNorth(i,j,BOM_ENV_OLD,
     &                BOM_ENV_STOKES,bi,bj)-slopeNN)
     &             .LE.gradTol,
     &           'meridional physical gradients', nFail, myThid )

C--         JULIA base-only candidate: solid-body zonal field has
C           vort=2*Omega*sin(latitude).
            wEast = bomEnvEast(i,j,BOM_ENV_OLD,
     &                 BOM_ENV_WIND,bi,bj)
            wNorth = 0. _d 0
            CALL BOM_EVAL_COVARIANT(
     I           wEast, wNorth, 0. _d 0, 0. _d 0,
     I           bomGradEastEast(i,j,BOM_ENV_OLD,
     &                BOM_ENV_WIND,bi,bj),
     I           bomGradNorthEast(i,j,BOM_ENV_OLD,
     &                BOM_ENV_WIND,bi,bj),
     I           bomGradEastNorth(i,j,BOM_ENV_OLD,
     &                BOM_ENV_WIND,bi,bj),
     I           bomGradNorthNorth(i,j,BOM_ENV_OLD,
     &                BOM_ENV_WIND,bi,bj),
     I           bomTauSphere(i,j,bi,bj),
     O           dSelfEast, dSelfNorth, vorticity,
     O           failCode, evalValid )
            expectedBaseVort = 2. _d 0*solidOmega*SIN(latRad)
            expectedNorth = tauExpected*wEast*wEast
            CALL BOM_VERIFY_SPHERE_ASSERT(
     &           evalValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &           ABS(dSelfEast).LE.1. _d -12 .AND.
     &           ABS(dSelfNorth-expectedNorth).LE.1. _d -12 .AND.
     &           ABS(vorticity-expectedBaseVort).LE.2. _d -10,
     &           'JULIA base-only vorticity candidate',
     &           nFail, myThid )

C--         PAPER total-field candidate includes explicit Stokes before
C           nonlinear covariant products; its vorticity remains linear.
            wEast = bomEnvEast(i,j,BOM_ENV_OLD,BOM_ENV_WIND,bi,bj)
     &           + bomEnvEast(i,j,BOM_ENV_OLD,
     &                 BOM_ENV_STOKES,bi,bj)
            wNorth = bomEnvNorth(i,j,BOM_ENV_OLD,
     &                 BOM_ENV_STOKES,bi,bj)
            CALL BOM_EVAL_COVARIANT(
     I           wEast, wNorth, 0. _d 0, 0. _d 0,
     I           bomGradEastEast(i,j,BOM_ENV_OLD,
     &                BOM_ENV_WIND,bi,bj)
     &           + bomGradEastEast(i,j,BOM_ENV_OLD,
     &                BOM_ENV_STOKES,bi,bj),
     I           bomGradNorthEast(i,j,BOM_ENV_OLD,
     &                BOM_ENV_WIND,bi,bj)
     &           + bomGradNorthEast(i,j,BOM_ENV_OLD,
     &                BOM_ENV_STOKES,bi,bj),
     I           bomGradEastNorth(i,j,BOM_ENV_OLD,
     &                BOM_ENV_WIND,bi,bj)
     &           + bomGradEastNorth(i,j,BOM_ENV_OLD,
     &                BOM_ENV_STOKES,bi,bj),
     I           bomGradNorthNorth(i,j,BOM_ENV_OLD,
     &                BOM_ENV_WIND,bi,bj)
     &           + bomGradNorthNorth(i,j,BOM_ENV_OLD,
     &                BOM_ENV_STOKES,bi,bj),
     I           bomTauSphere(i,j,bi,bj),
     O           dSelfEast, dSelfNorth, vorticity,
     O           failCode, evalValid )
            expectedStokesVort = -slopeNE
     &           + tauExpected*bomEnvEast(i,j,BOM_ENV_OLD,
     &                BOM_ENV_STOKES,bi,bj)
            expectedVort = expectedBaseVort + expectedStokesVort
            CALL BOM_VERIFY_SPHERE_ASSERT(
     &           evalValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &           ABS(vorticity-expectedVort).LE.2. _d -10,
     &           'PAPER total-field vorticity candidate',
     &           nFail, myThid )

            validInt = 0
            IF ( bomMetricValid(i,j,bi,bj) .AND.
     &           bomGradValid(i,j,BOM_ENV_OLD,
     &                        BOM_ENV_WIND,bi,bj) ) validInt = 1
            WRITE(standardMessageUnit,
     &           '(A,2I5,3(1X,Z16.16),1X,I1)')
     &           'P22-SPHERE-RECORD', iGlobal, jGlobal,
     &           TRANSFER(bomTauSphere(i,j,bi,bj),0_8),
     &           TRANSFER(bomFCori(i,j,bi,bj),0_8),
     &           TRANSFER(vorticity,0_8), validInt
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   N05: zero radius, near pole, NaN fCori all fail without publication.
      biTest = myBxLo(myThid)
      bjTest = myByLo(myThid)
      iTest = 2
      jTest = 2
      savedRadius = rSphere
      savedTau = bomTauSphere(iTest,jTest,biTest,bjTest)
      savedCori = bomFCori(iTest,jTest,biTest,bjTest)
      savedReady = bomMetricReady
      savedMetricValid = bomMetricValid(iTest,jTest,biTest,bjTest)
      rSphere = 0. _d 0
      CALL BOM_TRY_BUILD_DERIVATIVES(
     I     .FALSE.,
     O     failCode, tryValid,
     I     myThid )
      CALL BOM_VERIFY_SPHERE_ROLLBACK(
     I     tryValid, failCode, savedReady, savedMetricValid,
     I     savedTau, savedCori, iTest, jTest, biTest, bjTest,
     I     'zero rSphere rollback',
     U     nFail,
     I     myThid )
      rSphere = savedRadius

      savedLatitude = yC(iTest,jTest,biTest,bjTest)
      yC(iTest,jTest,biTest,bjTest) = 90.
      CALL BOM_TRY_BUILD_DERIVATIVES(
     I     .FALSE.,
     O     failCode, tryValid,
     I     myThid )
      CALL BOM_VERIFY_SPHERE_ROLLBACK(
     I     tryValid, failCode, savedReady, savedMetricValid,
     I     savedTau, savedCori, iTest, jTest, biTest, bjTest,
     I     'near-pole rollback',
     U     nFail,
     I     myThid )
      yC(iTest,jTest,biTest,bjTest) = savedLatitude

      savedGridCori = fCori(iTest,jTest,biTest,bjTest)
      fCori(iTest,jTest,biTest,bjTest) =
     &     IEEE_VALUE(fCori(iTest,jTest,biTest,bjTest),
     &                IEEE_QUIET_NAN)
      CALL BOM_TRY_BUILD_DERIVATIVES(
     I     .FALSE.,
     O     failCode, tryValid,
     I     myThid )
      CALL BOM_VERIFY_SPHERE_ROLLBACK(
     I     tryValid, failCode, savedReady, savedMetricValid,
     I     savedTau, savedCori, iTest, jTest, biTest, bjTest,
     I     'NaN fCori rollback',
     U     nFail,
     I     myThid )
      fCori(iTest,jTest,biTest,bjTest) = savedGridCori

C--   Direct near-pole and protected-overflow operator checks.
      CALL BOM_EVAL_CPOINT_METRICS(
     I     90. _d 0, 1. _d -4,
     O     expectedEast, expectedNorth, pointMetricValid )
      CALL BOM_VERIFY_SPHERE_ASSERT(
     &     .NOT.pointMetricValid .AND.
     &     expectedEast.EQ.0. _d 0 .AND.
     &     expectedNorth.EQ.0. _d 0,
     &     'direct near-pole rejection', nFail, myThid )
      hugeValue = HUGE(oneRL)
      CALL BOM_EVAL_COVARIANT(
     I     hugeValue, 0. _d 0, 0. _d 0, 0. _d 0,
     I     2. _d 0, 0. _d 0, 0. _d 0, 0. _d 0,
     I     0. _d 0,
     O     dSelfEast, dSelfNorth, vorticity,
     O     failCode, evalValid )
      CALL BOM_VERIFY_SPHERE_ASSERT(
     &     .NOT.evalValid .AND. failCode.EQ.BOM_FAIL_EQUATION .AND.
     &     dSelfEast.EQ.0. _d 0 .AND.
     &     dSelfNorth.EQ.0. _d 0 .AND. vorticity.EQ.0. _d 0,
     &     'covariant overflow rejection', nFail, myThid )

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_VERIFY_SPHERICAL_DERIVATIVES: failures=',
     &         globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_SPHERICAL_DERIVATIVES'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P2-D04 PASS: spherical gradients and tauSphere'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
        WRITE(msgBuf,'(A)')
     &       'P2-D05 PASS: fCori, PAPER-total and JULIA-base vorticity'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
        WRITE(msgBuf,'(A)')
     &       'P2-N05-SPHERE PASS: radius, pole, fCori and rollback'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_SPHERE_ROLLBACK(
     I                 tryValid, failCode, savedReady,
     I                 savedMetricValid, savedTau, savedCori,
     I                 i, j, bi, bj, label,
     U                 nFail,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      LOGICAL tryValid, savedReady, savedMetricValid
      INTEGER failCode, i, j, bi, bj, nFail, myThid
      _RL savedTau, savedCori
      CHARACTER*(*) label

      CALL BOM_VERIFY_SPHERE_ASSERT(
     &     .NOT.tryValid .AND. failCode.EQ.BOM_FAIL_METRIC .AND.
     &     (bomMetricReady.EQV.savedReady) .AND.
     &     (bomMetricValid(i,j,bi,bj).EQV.savedMetricValid) .AND.
     &     bomTauSphere(i,j,bi,bj).EQ.savedTau .AND.
     &     bomFCori(i,j,bi,bj).EQ.savedCori,
     &     label, nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_SPHERE_ASSERT(
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
        IF ( nFail.LT.24 ) THEN
          WRITE(msgBuf,'(2A)')
     &         'BOM_VERIFY_SPHERICAL_DERIVATIVES: FAIL: ', label
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        nFail = nFail + 1
      ENDIF

      RETURN
      END
