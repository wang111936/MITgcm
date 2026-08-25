#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_RK4( myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
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
      INTEGER bi, bj, nFail, globalFail
      INTEGER caseCount, globalCaseCount
      INTEGER failStage, failCode
      INTEGER n, s
      INTEGER nStepList(4)
      INTEGER savedCount, savedStatus
      INTEGER*8 bitsBefore, bitsAfter
      _RL x0, y0, x1, y1, xMidTarget, yTarget
      _RL ix, jy, oceanEast, oceanNorth
      _RL windEast, windNorth, driftEast, driftNorth
      _RL wetWeight, stageCFL
      _RL xRef, yRef, timeScale, lengthX, lengthY
      _RL u0, v0, ax, ay, stepDt
      _RL xExact, yExact, xCurrent, yCurrent
      _RL errors(4), orders(3), tol
      _RL savedCoeff, savedCFL
      _RL savedX, savedY, savedAge, savedRelease
      _RL negZero, negZeroTrial
      LOGICAL coordValid, isValid, convValid
      LOGICAL isZero, isConstant, isSpherical
      LOGICAL isConvergence, isN08
      DATA nStepList / 4, 8, 16, 32 /

      nFail = 0
      caseCount = 0
      tol = 65536. _d 0*EPSILON(oneRL)
      isZero = the_run_name.EQ.'P1-RK4-ZERO'
      isConstant = the_run_name.EQ.'P1-RK4-CONST'
      isSpherical = the_run_name.EQ.'P1-I03-SPHERE'
      isConvergence = the_run_name.EQ.'P1-I06-RK4'
      isN08 = the_run_name.EQ.'P1-N08-RK4'
      CALL BOM_VERIFY_RK4_ASSERT(
     &     isZero .OR. isConstant .OR. isSpherical
     &     .OR. isConvergence .OR. isN08,
     &     'recognized RK4 scenario', nFail, myThid )

      savedCoeff = bomLeewayWindCoeff
      savedCFL = bomAdvCFL
      bomLeewayWindCoeff = 0. _d 0
      bomWetWeightMin = 0.5 _d 0

      IF ( isZero ) THEN
        bomAdvCFL = 0.5 _d 0
        CALL BOM_VERIFY_RK4_FILL_CONSTANT(
     &       0. _d 0, 0. _d 0, myThid )
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          CALL BOM_MAP_IJLOCAL2XY(
     &         2. _d 0, 2. _d 0, bi, bj,
     &         x0, y0, coordValid, myThid )
          CALL BOM_RK4(
     &         x0, y0, deltaTClock, bi, bj,
     &         x1, y1, ix, jy,
     &         oceanEast, oceanNorth, windEast, windNorth,
     &         driftEast, driftNorth, wetWeight, stageCFL,
     &         failStage, failCode, isValid, myThid )
          CALL BOM_VERIFY_RK4_ASSERT(
     &         coordValid .AND. isValid
     &         .AND. failStage.EQ.BOM_STAGE_NONE
     &         .AND. failCode.EQ.BOM_FAIL_NONE,
     &         'zero field valid', nFail, myThid )
          CALL BOM_VERIFY_RK4_ASSERT(
     &         x1.EQ.x0 .AND. y1.EQ.y0
     &         .AND. oceanEast.EQ.0. _d 0
     &         .AND. oceanNorth.EQ.0. _d 0
     &         .AND. windEast.EQ.0. _d 0
     &         .AND. windNorth.EQ.0. _d 0
     &         .AND. driftEast.EQ.0. _d 0
     &         .AND. driftNorth.EQ.0. _d 0
     &         .AND. stageCFL.EQ.0. _d 0,
     &         'zero field bitwise position and diagnostics',
     &         nFail, myThid )
          caseCount = caseCount + 1
         ENDDO
        ENDDO

C--     The coordinate helper must also preserve the sign bit of zero.
        negZero = -0. _d 0
        bitsBefore = TRANSFER(negZero,bitsBefore)
        CALL BOM_RK_COORD_UPDATE(
     &       negZero, 0. _d 0, deltaTClock, oneRL,
     &       negZeroTrial, coordValid )
        bitsAfter = TRANSFER(negZeroTrial,bitsAfter)
        CALL BOM_VERIFY_RK4_ASSERT(
     &       coordValid .AND. bitsAfter.EQ.bitsBefore,
     &       'signed zero bitwise preservation', nFail, myThid )
C--     Extreme weighted cancellation must not overflow before summing.
        CALL BOM_RK4_COORD_UPDATE(
     &       negZero, HUGE(oneRL), -0.5 _d 0*HUGE(oneRL),
     &       -0.5 _d 0*HUGE(oneRL), HUGE(oneRL), HUGE(oneRL),
     &       negZeroTrial, coordValid )
        bitsAfter = TRANSFER(negZeroTrial,bitsAfter)
        CALL BOM_VERIFY_RK4_ASSERT(
     &       coordValid .AND. bitsAfter.EQ.bitsBefore,
     &       'weighted extreme cancellation', nFail, myThid )

      ELSEIF ( isConstant ) THEN
        bomAdvCFL = 0.5 _d 0
        CALL BOM_VERIFY_RK4_FILL_CONSTANT(
     &       0.02 _d 0, -0.01 _d 0, myThid )
        stepDt = 300. _d 0
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          CALL BOM_MAP_IJLOCAL2XY(
     &         2. _d 0, 2. _d 0, bi, bj,
     &         x0, y0, coordValid, myThid )
          CALL BOM_RK4(
     &         x0, y0, stepDt, bi, bj,
     &         x1, y1, ix, jy,
     &         oceanEast, oceanNorth, windEast, windNorth,
     &         driftEast, driftNorth, wetWeight, stageCFL,
     &         failStage, failCode, isValid, myThid )
          CALL BOM_VERIFY_RK4_ASSERT(
     &         coordValid .AND. isValid
     &         .AND. failStage.EQ.BOM_STAGE_NONE
     &         .AND. failCode.EQ.BOM_FAIL_NONE,
     &         'constant field valid', nFail, myThid )
          CALL BOM_VERIFY_RK4_ASSERT(
     &         ABS(x1-(x0+stepDt*0.02 _d 0)).LE.tol
     &         .AND. ABS(y1-(y0-stepDt*0.01 _d 0)).LE.tol
     &         .AND. ABS(oceanEast-0.02 _d 0).LE.tol
     &         .AND. ABS(oceanNorth+0.01 _d 0).LE.tol
     &         .AND. driftEast.EQ.oceanEast
     &         .AND. driftNorth.EQ.oceanNorth
     &         .AND. wetWeight.GE.bomWetWeightMin
     &         .AND. stageCFL.EQ.0. _d 0,
     &         'constant field analytic step and final diagnostics',
     &         nFail, myThid )
          caseCount = caseCount + 1
         ENDDO
        ENDDO

      ELSEIF ( isSpherical ) THEN
C--     P1-I03 applies the production RK4 kernel to constant SI east and
C     north velocities on a nonzero-latitude spherical-polar grid.
        bomAdvCFL = 0.5 _d 0
        stepDt = 300. _d 0
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          CALL BOM_MAP_IJLOCAL2XY(
     &         2. _d 0, 2. _d 0, bi, bj,
     &         x0, y0, coordValid, myThid )

          CALL BOM_VERIFY_RK4_FILL_CONSTANT(
     &         2. _d 0, 0. _d 0, myThid )
          CALL BOM_RK4(
     &         x0, y0, stepDt, bi, bj,
     &         x1, y1, ix, jy,
     &         oceanEast, oceanNorth, windEast, windNorth,
     &         driftEast, driftNorth, wetWeight, stageCFL,
     &         failStage, failCode, isValid, myThid )
          xExact = x0 + stepDt*2. _d 0/
     &         (rSphere*deg2rad*COS(deg2rad*y0))
          CALL BOM_VERIFY_RK4_ASSERT(
     &         coordValid .AND. ABS(y0).GT.0. _d 0
     &         .AND. isValid .AND. failStage.EQ.BOM_STAGE_NONE
     &         .AND. failCode.EQ.BOM_FAIL_NONE,
     &         'P1-I03 spherical east RK4 valid', nFail, myThid )
          CALL BOM_VERIFY_RK4_ASSERT(
     &         ABS(x1-xExact).LE.tol*MAX(oneRL,ABS(xExact))
     &         .AND. y1.EQ.y0
     &         .AND. ABS(oceanEast-2. _d 0).LE.tol
     &         .AND. oceanNorth.EQ.0. _d 0
     &         .AND. stageCFL.EQ.0. _d 0,
     &         'P1-I03 east analytic longitude displacement',
     &         nFail, myThid )

          CALL BOM_VERIFY_RK4_FILL_CONSTANT(
     &         0. _d 0, 3. _d 0, myThid )
          CALL BOM_RK4(
     &         x0, y0, stepDt, bi, bj,
     &         x1, y1, ix, jy,
     &         oceanEast, oceanNorth, windEast, windNorth,
     &         driftEast, driftNorth, wetWeight, stageCFL,
     &         failStage, failCode, isValid, myThid )
          yExact = y0 + stepDt*3. _d 0/(rSphere*deg2rad)
          CALL BOM_VERIFY_RK4_ASSERT(
     &         isValid .AND. failStage.EQ.BOM_STAGE_NONE
     &         .AND. failCode.EQ.BOM_FAIL_NONE,
     &         'P1-I03 spherical north RK4 valid', nFail, myThid )
          CALL BOM_VERIFY_RK4_ASSERT(
     &         x1.EQ.x0
     &         .AND. ABS(y1-yExact).LE.tol*MAX(oneRL,ABS(yExact))
     &         .AND. oceanEast.EQ.0. _d 0
     &         .AND. ABS(oceanNorth-3. _d 0).LE.tol
     &         .AND. stageCFL.EQ.0. _d 0,
     &         'P1-I03 north analytic latitude displacement',
     &         nFail, myThid )
          caseCount = caseCount + 2
         ENDDO
        ENDDO

      ELSEIF ( isConvergence ) THEN
C--     Frozen P1-I06 affine field on a central Cartesian C point.
        bi = 1
        bj = 1
        timeScale = deltaTClock
        xRef = xC(2,2,bi,bj)
        yRef = yC(2,2,bi,bj)
        lengthX = dxF(2,2,bi,bj)
        lengthY = dyF(2,2,bi,bj)
        u0 = 0.04 _d 0*lengthX/timeScale
        ax = 0.20 _d 0/timeScale
        v0 = 0.03 _d 0*lengthY/timeScale
        ay = -0.15 _d 0/timeScale
        bomAdvCFL = 0.5 _d 0
        CALL BOM_VERIFY_RK4_FILL_AFFINE(
     &       xRef, yRef, u0, v0, ax, ay, myThid )

        xExact = xRef + u0/ax*(EXP(ax*timeScale)-oneRL)
        yExact = yRef + v0/ay*(EXP(ay*timeScale)-oneRL)
        DO s=1,4
          xCurrent = xRef
          yCurrent = yRef
          stepDt = timeScale/DFLOAT(nStepList(s))
          DO n=1,nStepList(s)
            CALL BOM_RK4(
     &           xCurrent, yCurrent, stepDt, bi, bj,
     &           x1, y1, ix, jy,
     &           oceanEast, oceanNorth, windEast, windNorth,
     &           driftEast, driftNorth, wetWeight, stageCFL,
     &           failStage, failCode, isValid, myThid )
            CALL BOM_VERIFY_RK4_ASSERT(
     &           isValid .AND. failStage.EQ.BOM_STAGE_NONE
     &           .AND. failCode.EQ.BOM_FAIL_NONE,
     &           'P1-I06 accepted affine step', nFail, myThid )
            IF ( isValid ) THEN
              xCurrent = x1
              yCurrent = y1
            ENDIF
            caseCount = caseCount + 1
          ENDDO
          errors(s) = SQRT(
     &         ((xCurrent-xExact)/lengthX)**2
     &         + ((yCurrent-yExact)/lengthY)**2 )
        ENDDO

        convValid = .TRUE.
        DO s=1,4
          IF ( .NOT.IEEE_IS_FINITE(errors(s)) ) convValid = .FALSE.
          IF ( errors(s).LE.0. _d 0 ) convValid = .FALSE.
        ENDDO
        CALL BOM_VERIFY_RK4_ASSERT(
     &       convValid, 'P1-I06 finite positive errors',
     &       nFail, myThid )
        orders(1) = 0. _d 0
        orders(2) = 0. _d 0
        orders(3) = 0. _d 0
        IF ( convValid ) THEN
          DO s=1,3
            orders(s) = LOG(errors(s)/errors(s+1))/LOG(twoRL)
          ENDDO
        ENDIF
        CALL BOM_VERIFY_RK4_ASSERT(
     &       orders(2).GE.3.5 _d 0 .AND. orders(2).LE.4.5 _d 0
     &       .AND. orders(3).GE.3.5 _d 0
     &       .AND. orders(3).LE.4.5 _d 0,
     &       'P1-I06 two finest observed orders',
     &       nFail, myThid )
        CALL BOM_VERIFY_RK4_ASSERT(
     &       ABS(driftEast-(u0+ax*(xCurrent-xRef)))
     &       .LE.tol*MAX(oneRL,ABS(driftEast))
     &       .AND. ABS(driftNorth-(v0+ay*(yCurrent-yRef)))
     &       .LE.tol*MAX(oneRL,ABS(driftNorth))
     &       .AND. wetWeight.GE.bomWetWeightMin
     &       .AND. stageCFL.EQ.0. _d 0,
     &       'P1-I06 final-position diagnostics',
     &       nFail, myThid )

      ELSEIF ( isN08 ) THEN
C--     Serial stage/final failure matrix with rollback sentinels.
        bi = 1
        bj = 1
        stepDt = deltaTClock
        CALL BOM_MAP_IJLOCAL2XY(
     &       2. _d 0, 2. _d 0, bi, bj,
     &       x0, y0, coordValid, myThid )
        CALL BOM_VERIFY_RK4_ASSERT(
     &       coordValid, 'N08 seed coordinate', nFail, myThid )

        savedCount = bomNPartTile(bi,bj)
        savedStatus = bomStatus(1,bi,bj)
        savedX = bomX(1,bi,bj)
        savedY = bomY(1,bi,bj)
        savedAge = bomAge(1,bi,bj)
        savedRelease = bomReleaseTime(1,bi,bj)
        bomNPartTile(bi,bj) = 1
        bomStatus(1,bi,bj) = BOM_ALIVE
        bomX(1,bi,bj) = 123. _d 0
        bomY(1,bi,bj) = -456. _d 0
        bomAge(1,bi,bj) = 789. _d 0
        bomReleaseTime(1,bi,bj) = 2468. _d 0

        CALL BOM_VERIFY_RK4_FILL_CONSTANT(
     &       0. _d 0, 0. _d 0, myThid )
        CALL BOM_RK4(
     &       x0, y0, -oneRL, bi, bj,
     &       x1, y1, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       failStage, failCode, isValid, myThid )
        CALL BOM_VERIFY_RK4_FAILURE(
     &       x0, y0, x1, y1, isValid, failStage, failCode,
     &       BOM_STAGE_NONE, BOM_FAIL_NONFINITE,
     &       'N08 invalid input before K1', nFail, myThid )

        bomFieldsReady = .FALSE.
        CALL BOM_RK4(
     &       x0, y0, stepDt, bi, bj,
     &       x1, y1, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       failStage, failCode, isValid, myThid )
        CALL BOM_VERIFY_RK4_FAILURE(
     &       x0, y0, x1, y1, isValid, failStage, failCode,
     &       BOM_STAGE_K1, BOM_FAIL_INTERP,
     &       'N08 K1 field failure', nFail, myThid )
        bomFieldsReady = .TRUE.

C--     K1 succeeds, but the K2 half-step leaves tile ownership.
        CALL BOM_MAP_IJLOCAL2XY(
     &       4.25 _d 0, 2. _d 0, bi, bj,
     &       x0, y0, coordValid, myThid )
        CALL BOM_MAP_IJLOCAL2XY(
     &       4.55 _d 0, 2. _d 0, bi, bj,
     &       xMidTarget, yTarget, coordValid, myThid )
        bomAdvCFL = 0.9 _d 0
        CALL BOM_VERIFY_RK4_FILL_CONSTANT(
     &       twoRL*(xMidTarget-x0)/stepDt,
     &       0. _d 0, myThid )
        CALL BOM_RK4(
     &       x0, y0, stepDt, bi, bj,
     &       x1, y1, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       failStage, failCode, isValid, myThid )
        CALL BOM_VERIFY_RK4_FAILURE(
     &       x0, y0, x1, y1, isValid, failStage, failCode,
     &       BOM_STAGE_K2, BOM_FAIL_OWNER,
     &       'N08 K2 owner departure', nFail, myThid )

C--     K1/K2 stay owned, but the K3 trial leaves tile ownership.
        CALL BOM_MAP_IJLOCAL2XY(
     &       4.25 _d 0, 2. _d 0, bi, bj,
     &       x0, y0, coordValid, myThid )
        lengthX = dxF(4,2,bi,bj)
        CALL BOM_VERIFY_RK4_FILL_AFFINE(
     &       x0, y0, 0.30 _d 0*lengthX/stepDt,
     &       0. _d 0, twoRL/stepDt, 0. _d 0, myThid )
        CALL BOM_RK4(
     &       x0, y0, stepDt, bi, bj,
     &       x1, y1, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       failStage, failCode, isValid, myThid )
        CALL BOM_VERIFY_RK4_FAILURE(
     &       x0, y0, x1, y1, isValid, failStage, failCode,
     &       BOM_STAGE_K3, BOM_FAIL_OWNER,
     &       'N08 K3 owner departure', nFail, myThid )

C--     K1-K3 stay owned, but the K4 trial leaves tile ownership.
        CALL BOM_MAP_IJLOCAL2XY(
     &       4. _d 0, 2. _d 0, bi, bj,
     &       x0, y0, coordValid, myThid )
        CALL BOM_MAP_IJLOCAL2XY(
     &       4.35 _d 0, 2. _d 0, bi, bj,
     &       xMidTarget, yTarget, coordValid, myThid )
        CALL BOM_VERIFY_RK4_FILL_CONSTANT(
     &       twoRL*(xMidTarget-x0)/stepDt,
     &       0. _d 0, myThid )
        CALL BOM_RK4(
     &       x0, y0, stepDt, bi, bj,
     &       x1, y1, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       failStage, failCode, isValid, myThid )
        CALL BOM_VERIFY_RK4_FAILURE(
     &       x0, y0, x1, y1, isValid, failStage, failCode,
     &       BOM_STAGE_K4, BOM_FAIL_OWNER,
     &       'N08 K4 owner departure', nFail, myThid )

C--     All RK stages stay owned, but the weighted final trial departs.
        CALL BOM_MAP_IJLOCAL2XY(
     &       4. _d 0, 2. _d 0, bi, bj,
     &       x0, y0, coordValid, myThid )
        lengthX = dxF(4,2,bi,bj)
        bomAdvCFL = 2.1 _d 0
        CALL BOM_VERIFY_RK4_FILL_AFFINE(
     &       x0, y0, 0.062 _d 0*lengthX/stepDt,
     &       0. _d 0, 4. _d 0/stepDt, 0. _d 0, myThid )
        CALL BOM_RK4(
     &       x0, y0, stepDt, bi, bj,
     &       x1, y1, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       failStage, failCode, isValid, myThid )
        CALL BOM_VERIFY_RK4_FAILURE(
     &       x0, y0, x1, y1, isValid, failStage, failCode,
     &       BOM_STAGE_FINAL, BOM_FAIL_OWNER,
     &       'N08 FINAL owner departure', nFail, myThid )

C--     A finite K1 rate whose midpoint product would overflow.
        CALL BOM_MAP_IJLOCAL2XY(
     &       2. _d 0, 2. _d 0, bi, bj,
     &       x0, y0, coordValid, myThid )
        bomAdvCFL = HUGE(oneRL)
        CALL BOM_VERIFY_RK4_FILL_CONSTANT(
     &       0.5 _d 0*HUGE(oneRL), 0. _d 0, myThid )
        CALL BOM_RK4(
     &       x0, y0, 8. _d 0, bi, bj,
     &       x1, y1, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       failStage, failCode, isValid, myThid )
        CALL BOM_VERIFY_RK4_FAILURE(
     &       x0, y0, x1, y1, isValid, failStage, failCode,
     &       BOM_STAGE_K2, BOM_FAIL_NONFINITE,
     &       'N08 midpoint arithmetic overflow guard',
     &       nFail, myThid )

        CALL BOM_VERIFY_RK4_ASSERT(
     &       bomNPartTile(bi,bj).EQ.1
     &       .AND. bomStatus(1,bi,bj).EQ.BOM_ALIVE
     &       .AND. bomX(1,bi,bj).EQ.123. _d 0
     &       .AND. bomY(1,bi,bj).EQ.-456. _d 0
     &       .AND. bomAge(1,bi,bj).EQ.789. _d 0
     &       .AND. bomReleaseTime(1,bi,bj).EQ.2468. _d 0,
     &       'N08 authoritative particle state unchanged',
     &       nFail, myThid )
        bomNPartTile(bi,bj) = savedCount
        bomStatus(1,bi,bj) = savedStatus
        bomX(1,bi,bj) = savedX
        bomY(1,bi,bj) = savedY
        bomAge(1,bi,bj) = savedAge
        bomReleaseTime(1,bi,bj) = savedRelease
        caseCount = caseCount + 7
      ENDIF

      bomLeewayWindCoeff = savedCoeff
      bomAdvCFL = savedCFL
      bomFieldsReady = .FALSE.

      globalCaseCount = caseCount
      CALL GLOBAL_SUM_INT( globalCaseCount, myThid )
      CALL BOM_VERIFY_RK4_ASSERT(
     &     globalCaseCount.GT.0, 'RK4 scenario exercised',
     &     nFail, myThid )
      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I6)')
     &         'BOM_VERIFY_RK4: failed assertions=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_RK4'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        IF ( isZero ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-RK4 ZERO PASS: bitwise stationary step'
        ELSEIF ( isConstant ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-RK4 CONSTANT PASS: analytic displacement'
        ELSEIF ( isSpherical ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-I03 RK4 PASS: spherical analytic displacement'
        ELSEIF ( isConvergence ) THEN
          WRITE(msgBuf,'(A,2F8.4)')
     &         'P1-I06 RK4 PASS: two finest orders=',
     &         orders(2), orders(3)
        ELSE
          WRITE(msgBuf,'(A)')
     &         'P1-N08 RK4 PASS: staged failure rollback'
        ENDIF
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_RK4_FILL_CONSTANT(
     I     waterEast, waterNorth, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      _RL waterEast, waterNorth
      INTEGER myThid

#ifdef ALLOW_BOM
      INTEGER bi, bj, i, j
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          maskC(i,j,1,bi,bj) = 1.
          bomGridVEast(i,j,1,bi,bj) = waterEast
          bomGridVNorth(i,j,1,bi,bj) = waterNorth
          bomGridWindEast(i,j,1,bi,bj) = 0. _d 0
          bomGridWindNorth(i,j,1,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      bomFieldsReady = .TRUE.
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_RK4_FILL_AFFINE(
     I     xRef, yRef, u0, v0, ax, ay, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      _RL xRef, yRef, u0, v0, ax, ay
      INTEGER myThid

#ifdef ALLOW_BOM
      INTEGER bi, bj, i, j
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          maskC(i,j,1,bi,bj) = 1.
          bomGridVEast(i,j,1,bi,bj) =
     &         u0 + ax*(xC(i,j,bi,bj)-xRef)
          bomGridVNorth(i,j,1,bi,bj) =
     &         v0 + ay*(yC(i,j,bi,bj)-yRef)
          bomGridWindEast(i,j,1,bi,bj) = 0. _d 0
          bomGridWindNorth(i,j,1,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      bomFieldsReady = .TRUE.
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_RK4_FAILURE(
     I     x0, y0, x1, y1, isValid, failStage, failCode,
     I     expectedStage, expectedCode, label, nFail, myThid )

      IMPLICIT NONE
      _RL x0, y0, x1, y1
      LOGICAL isValid
      INTEGER failStage, failCode, expectedStage, expectedCode
      INTEGER nFail, myThid
      CHARACTER*(*) label

      CALL BOM_VERIFY_RK4_ASSERT(
     &     .NOT.isValid
     &     .AND. failStage.EQ.expectedStage
     &     .AND. failCode.EQ.expectedCode
     &     .AND. x1.EQ.x0 .AND. y1.EQ.y0,
     &     label, nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_RK4_ASSERT(
     I     condition, label, nFail, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"

      LOGICAL condition
      CHARACTER*(*) label
      INTEGER nFail, myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf

      IF ( .NOT.condition ) THEN
        nFail = nFail + 1
        WRITE(msgBuf,'(A,A)') 'BOM_VERIFY_RK4 assertion: ', label
        CALL PRINT_ERROR( msgBuf, myThid )
      ENDIF

      RETURN
      END
