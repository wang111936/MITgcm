#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_RHS( myThid )

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
      INTEGER caseCount, globalCaseCount, failCode
      INTEGER*8 infBits
      _RL infValue
      _RL xx, yy, xxOther, yyOther
      _RL rhsX, rhsY, ix, jy
      _RL oceanEast, oceanNorth, windEast, windNorth
      _RL driftEast, driftNorth, wetWeight, stageCFL
      _RL expectedX, expectedY, expectedCFL, tol
      _RL savedMetricX, savedMetricX2, savedMetricY
      _RL savedCoeff, savedCFL, savedField
      _RL savedX, savedY, savedAge
      INTEGER savedCount, savedStatus
      LOGICAL coordValid, isOwner, isValid
      LOGICAL isZero, isCartesian, isSpherical, isLeeway, isN08
      EQUIVALENCE ( infBits, infValue )
      DATA infBits / Z'7FF0000000000000' /

      nFail = 0
      caseCount = 0
      tol = 16384. _d 0*EPSILON(oneRL)
      isZero = the_run_name.EQ.'P1-I01-ZERO'
      isCartesian = the_run_name.EQ.'P1-I02-CART'
      isSpherical = the_run_name.EQ.'P1-I03-SPHERE'
      isLeeway = the_run_name.EQ.'P1-I04-LEEWAY'
      isN08 = the_run_name.EQ.'P1-N08-RHS'
      CALL BOM_VERIFY_RHS_ASSERT(
     &     isZero .OR. isCartesian .OR. isSpherical
     &     .OR. isLeeway .OR. isN08,
     &     'recognized RHS scenario', nFail, myThid )

      savedCoeff = bomLeewayWindCoeff
      savedCFL = bomAdvCFL
      bomWetWeightMin = 0.5 _d 0

      IF ( isZero ) THEN
        bomLeewayWindCoeff = 0. _d 0
        bomAdvCFL = 0.5 _d 0
        CALL BOM_VERIFY_RHS_FILL(
     &       0. _d 0, 0. _d 0, 0. _d 0, 0. _d 0, myThid )
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          CALL BOM_MAP_IJLOCAL2XY(
     &         1.25 _d 0, 1.25 _d 0, bi, bj,
     &         xx, yy, coordValid, myThid )
          CALL BOM_VERIFY_RHS_ASSERT( coordValid,
     &         'I01 seed coordinate', nFail, myThid )
          CALL BOM_RHS_LEEWAY(
     &         xx, yy, 1200. _d 0, bi, bj,
     &         rhsX, rhsY, ix, jy,
     &         oceanEast, oceanNorth, windEast, windNorth,
     &         driftEast, driftNorth, wetWeight, stageCFL,
     &         isOwner, isValid, failCode, myThid )
          CALL BOM_VERIFY_RHS_ASSERT(
     &         isValid .AND. isOwner
     &         .AND. failCode.EQ.BOM_FAIL_NONE,
     &         'I01 valid zero RHS', nFail, myThid )
          CALL BOM_VERIFY_RHS_ASSERT(
     &         rhsX.EQ.0. _d 0 .AND. rhsY.EQ.0. _d 0
     &         .AND. oceanEast.EQ.0. _d 0
     &         .AND. oceanNorth.EQ.0. _d 0
     &         .AND. windEast.EQ.0. _d 0
     &         .AND. windNorth.EQ.0. _d 0
     &         .AND. driftEast.EQ.0. _d 0
     &         .AND. driftNorth.EQ.0. _d 0
     &         .AND. stageCFL.EQ.0. _d 0,
     &         'I01 bitwise zero diagnostics', nFail, myThid )
          caseCount = caseCount + 1
         ENDDO
        ENDDO

      ELSEIF ( isCartesian ) THEN
        bomLeewayWindCoeff = 0. _d 0
        bomAdvCFL = 10. _d 0
        CALL BOM_VERIFY_RHS_FILL(
     &       1.25 _d 0, -2.5 _d 0,
     &       0. _d 0, 0. _d 0, myThid )
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          CALL BOM_MAP_IJLOCAL2XY(
     &         1.25 _d 0, 1.25 _d 0, bi, bj,
     &         xx, yy, coordValid, myThid )
          CALL BOM_RHS_LEEWAY(
     &         xx, yy, 1200. _d 0, bi, bj,
     &         rhsX, rhsY, ix, jy,
     &         oceanEast, oceanNorth, windEast, windNorth,
     &         driftEast, driftNorth, wetWeight, stageCFL,
     &         isOwner, isValid, failCode, myThid )
          expectedCFL = 1200. _d 0*MAX(
     &         1.25 _d 0*recip_dxF(1,1,bi,bj),
     &         2.5 _d 0*recip_dyF(1,1,bi,bj) )
          CALL BOM_VERIFY_RHS_ASSERT(
     &         coordValid .AND. isValid .AND. isOwner
     &         .AND. failCode.EQ.BOM_FAIL_NONE,
     &         'I02 Cartesian valid', nFail, myThid )
          CALL BOM_VERIFY_RHS_ASSERT(
     &         ABS(rhsX-1.25 _d 0).LE.tol
     &         .AND. ABS(rhsY+2.5 _d 0).LE.tol
     &         .AND. ABS(oceanEast-1.25 _d 0).LE.tol
     &         .AND. ABS(oceanNorth+2.5 _d 0).LE.tol
     &         .AND. ABS(driftEast-1.25 _d 0).LE.tol
     &         .AND. ABS(driftNorth+2.5 _d 0).LE.tol,
     &         'I02 SI velocity equals native rate', nFail, myThid )
          CALL BOM_VERIFY_RHS_ASSERT(
     &         ABS(stageCFL-expectedCFL).LE.
     &         tol*MAX(oneRL,expectedCFL),
     &         'I02 analytic CFL', nFail, myThid )
          caseCount = caseCount + 1
         ENDDO
        ENDDO

      ELSEIF ( isLeeway ) THEN
        bomAdvCFL = oneRL
        CALL BOM_VERIFY_RHS_PREP_EXF( myThid )
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          CALL BOM_MAP_IJLOCAL2XY(
     &         1.25 _d 0, 1.25 _d 0, bi, bj,
     &         xx, yy, coordValid, myThid )
          CALL BOM_RHS_LEEWAY(
     &         xx, yy, 1200. _d 0, bi, bj,
     &         rhsX, rhsY, ix, jy,
     &         oceanEast, oceanNorth, windEast, windNorth,
     &         driftEast, driftNorth, wetWeight, stageCFL,
     &         isOwner, isValid, failCode, myThid )
          expectedX = 0.2 _d 0 + 0.02 _d 0*2.5 _d 0
          expectedY = -0.4 _d 0 + 0.02 _d 0*(-1.25 _d 0)
          CALL BOM_VERIFY_RHS_ASSERT(
     &         coordValid .AND. isValid .AND. isOwner
     &         .AND. failCode.EQ.BOM_FAIL_NONE
     &         .AND. ABS(bomLeewayWindCoeff-0.02 _d 0).LE.tol,
     &         'I04 EXF Leeway valid', nFail, myThid )
          CALL BOM_VERIFY_RHS_ASSERT(
     &         ABS(rhsX-expectedX).LE.tol
     &         .AND. ABS(rhsY-expectedY).LE.tol
     &         .AND. ABS(driftEast-expectedX).LE.tol
     &         .AND. ABS(driftNorth-expectedY).LE.tol
     &         .AND. ABS(oceanEast-0.2 _d 0).LE.tol
     &         .AND. ABS(oceanNorth+0.4 _d 0).LE.tol
     &         .AND. ABS(windEast-2.5 _d 0).LE.tol
     &         .AND. ABS(windNorth+1.25 _d 0).LE.tol,
     &         'I04 EXF snapshot plus ocean', nFail, myThid )
          CALL BOM_VERIFY_RHS_ASSERT(
     &         ABS(rhsX*86.4 _d 0-expectedX*86.4 _d 0)
     &         .LE.tol*86.4 _d 0
     &         .AND. ABS(rhsY*86.4 _d 0-expectedY*86.4 _d 0)
     &         .LE.tol*86.4 _d 0,
     &         'I04 m/s to km/day algebra', nFail, myThid )
          caseCount = caseCount + 1
         ENDDO
        ENDDO

      ELSEIF ( isSpherical ) THEN
        bomLeewayWindCoeff = 0. _d 0
        bomAdvCFL = 10. _d 0
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          CALL BOM_MAP_IJLOCAL2XY(
     &         1.25 _d 0, 1.25 _d 0, bi, bj,
     &         xx, yy, coordValid, myThid )
          CALL BOM_VERIFY_RHS_FILL(
     &         2. _d 0, 0. _d 0,
     &         0. _d 0, 0. _d 0, myThid )
          CALL BOM_RHS_LEEWAY(
     &         xx, yy, 1200. _d 0, bi, bj,
     &         rhsX, rhsY, ix, jy,
     &         oceanEast, oceanNorth, windEast, windNorth,
     &         driftEast, driftNorth, wetWeight, stageCFL,
     &         isOwner, isValid, failCode, myThid )
          expectedX = 2. _d 0/
     &         (rSphere*deg2rad*COS(deg2rad*yy))
          CALL BOM_VERIFY_RHS_ASSERT(
     &         coordValid .AND. ABS(yy).GT.0. _d 0
     &         .AND. isValid .AND. isOwner,
     &         'I03 spherical east valid', nFail, myThid )
          CALL BOM_VERIFY_RHS_ASSERT(
     &         ABS(rhsX-expectedX).LE.
     &         tol*MAX(oneRL,ABS(expectedX))
     &         .AND. rhsY.EQ.0. _d 0,
     &         'I03 east m/s to longitude rate', nFail, myThid )

          CALL BOM_VERIFY_RHS_FILL(
     &         0. _d 0, 3. _d 0,
     &         0. _d 0, 0. _d 0, myThid )
          CALL BOM_RHS_LEEWAY(
     &         xx, yy, 1200. _d 0, bi, bj,
     &         rhsX, rhsY, ix, jy,
     &         oceanEast, oceanNorth, windEast, windNorth,
     &         driftEast, driftNorth, wetWeight, stageCFL,
     &         isOwner, isValid, failCode, myThid )
          expectedY = 3. _d 0/(rSphere*deg2rad)
          CALL BOM_VERIFY_RHS_ASSERT(
     &         isValid .AND. isOwner
     &         .AND. rhsX.EQ.0. _d 0
     &         .AND. ABS(rhsY-expectedY).LE.
     &         tol*MAX(oneRL,ABS(expectedY)),
     &         'I03 north m/s to latitude rate', nFail, myThid )
          caseCount = caseCount + 2
         ENDDO
        ENDDO

      ELSEIF ( isN08 ) THEN
C--     The negative matrix is serial and uses tile (1,1).
        bi = 1
        bj = 1
        bomLeewayWindCoeff = 0. _d 0
        bomAdvCFL = 10. _d 0
        CALL BOM_VERIFY_RHS_FILL(
     &       1. _d 0, 0. _d 0,
     &       0. _d 0, 0. _d 0, myThid )
        CALL BOM_MAP_IJLOCAL2XY(
     &       1.25 _d 0, 1.25 _d 0, bi, bj,
     &       xx, yy, coordValid, myThid )
        CALL BOM_VERIFY_RHS_ASSERT( coordValid,
     &       'N08 seed coordinate', nFail, myThid )

C--     Store sentinels proving every failure remains stateless.
        savedCount = bomNPartTile(bi,bj)
        savedStatus = bomStatus(1,bi,bj)
        savedX = bomX(1,bi,bj)
        savedY = bomY(1,bi,bj)
        savedAge = bomAge(1,bi,bj)
        bomNPartTile(bi,bj) = 1
        bomStatus(1,bi,bj) = BOM_ALIVE
        bomX(1,bi,bj) = 123. _d 0
        bomY(1,bi,bj) = -456. _d 0
        bomAge(1,bi,bj) = 789. _d 0

        CALL BOM_RHS_LEEWAY(
     &       xx, yy, -1. _d 0, bi, bj,
     &       rhsX, rhsY, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       isOwner, isValid, failCode, myThid )
        CALL BOM_VERIFY_RHS_FAILURE(
     &       .NOT.isOwner, isValid, failCode, BOM_FAIL_NONFINITE,
     &       'N08 negative dtGuard', nFail, myThid )

        CALL BOM_RHS_LEEWAY(
     &       xx, yy, infValue, bi, bj,
     &       rhsX, rhsY, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       isOwner, isValid, failCode, myThid )
        CALL BOM_VERIFY_RHS_FAILURE(
     &       .NOT.isOwner, isValid, failCode, BOM_FAIL_NONFINITE,
     &       'N08 infinite dtGuard', nFail, myThid )

        CALL BOM_RHS_LEEWAY(
     &       bomMapXLo-oneRL, yy, 0. _d 0, bi, bj,
     &       rhsX, rhsY, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       isOwner, isValid, failCode, myThid )
        CALL BOM_VERIFY_RHS_FAILURE(
     &       .NOT.isOwner, isValid, failCode, BOM_FAIL_MAP,
     &       'N08 global map', nFail, myThid )

        CALL BOM_MAP_IJLOCAL2XY(
     &       2.25 _d 0, 1.25 _d 0, 2, 1,
     &       xxOther, yyOther, coordValid, myThid )
        CALL BOM_RHS_LEEWAY(
     &       xxOther, yyOther, 0. _d 0, bi, bj,
     &       rhsX, rhsY, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       isOwner, isValid, failCode, myThid )
        CALL BOM_VERIFY_RHS_FAILURE(
     &       .NOT.isOwner, isValid, failCode, BOM_FAIL_OWNER,
     &       'N08 owner departure', nFail, myThid )

        bomFieldsReady = .FALSE.
        CALL BOM_RHS_LEEWAY(
     &       xx, yy, 0. _d 0, bi, bj,
     &       rhsX, rhsY, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       isOwner, isValid, failCode, myThid )
        CALL BOM_VERIFY_RHS_FAILURE(
     &       isOwner, isValid, failCode, BOM_FAIL_INTERP,
     &       'N08 unpublished fields', nFail, myThid )
        bomFieldsReady = .TRUE.

        savedField = bomGridVEast(1,1,1,bi,bj)
        bomGridVEast(1,1,1,bi,bj) = infValue
        CALL BOM_RHS_LEEWAY(
     &       xx, yy, 0. _d 0, bi, bj,
     &       rhsX, rhsY, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       isOwner, isValid, failCode, myThid )
        CALL BOM_VERIFY_RHS_FAILURE(
     &       isOwner, isValid, failCode, BOM_FAIL_INTERP,
     &       'N08 non-finite field', nFail, myThid )
        bomGridVEast(1,1,1,bi,bj) = savedField

        CALL BOM_VERIFY_RHS_FILL(
     &       HUGE(oneRL), 0. _d 0,
     &       HUGE(oneRL), 0. _d 0, myThid )
        bomLeewayWindCoeff = 0.1 _d 0
        CALL BOM_RHS_LEEWAY(
     &       xx, yy, 0. _d 0, bi, bj,
     &       rhsX, rhsY, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       isOwner, isValid, failCode, myThid )
        CALL BOM_VERIFY_RHS_FAILURE(
     &       isOwner, isValid, failCode, BOM_FAIL_NONFINITE,
     &       'N08 derived drift overflow', nFail, myThid )

        CALL BOM_VERIFY_RHS_FILL(
     &       1. _d 0, 0. _d 0,
     &       0. _d 0, 0. _d 0, myThid )
        bomLeewayWindCoeff = 0. _d 0
        savedMetricX = recip_dxF(1,1,bi,bj)
        recip_dxF(1,1,bi,bj) = 0.
        CALL BOM_RHS_LEEWAY(
     &       xx, yy, 0. _d 0, bi, bj,
     &       rhsX, rhsY, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       isOwner, isValid, failCode, myThid )
        CALL BOM_VERIFY_RHS_FAILURE(
     &       isOwner, isValid, failCode, BOM_FAIL_NONFINITE,
     &       'N08 zero metric', nFail, myThid )
        recip_dxF(1,1,bi,bj) = savedMetricX

C--     At ix=1.5 the nearest metric must be iC=2, not iC=1.
        CALL BOM_MAP_IJLOCAL2XY(
     &       1.5 _d 0, 1.0 _d 0, bi, bj,
     &       xxOther, yyOther, coordValid, myThid )
        savedMetricX = recip_dxF(1,1,bi,bj)
        savedMetricX2 = recip_dxF(2,1,bi,bj)
        savedMetricY = recip_dyF(2,1,bi,bj)
        recip_dxF(1,1,bi,bj) = 0.1
        recip_dxF(2,1,bi,bj) = 1.
        recip_dyF(2,1,bi,bj) = 0.1
        bomAdvCFL = 0.5 _d 0
        CALL BOM_RHS_LEEWAY(
     &       xxOther, yyOther, 1. _d 0, bi, bj,
     &       rhsX, rhsY, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       isOwner, isValid, failCode, myThid )
        CALL BOM_VERIFY_RHS_FAILURE(
     &       isOwner, isValid, failCode, BOM_FAIL_CFL,
     &       'N08 half-cell east metric tie', nFail, myThid )
        CALL BOM_VERIFY_RHS_ASSERT(
     &       ABS(stageCFL-oneRL).LE.tol,
     &       'N08 half-cell CFL diagnostic', nFail, myThid )
        recip_dxF(1,1,bi,bj) = savedMetricX
        recip_dxF(2,1,bi,bj) = savedMetricX2
        recip_dyF(2,1,bi,bj) = savedMetricY

        bomAdvCFL = 0.5 _d 0
        expectedX = 2. _d 0*bomAdvCFL/
     &       recip_dxF(1,1,bi,bj)
        CALL BOM_RHS_LEEWAY(
     &       xx, yy, expectedX, bi, bj,
     &       rhsX, rhsY, ix, jy,
     &       oceanEast, oceanNorth, windEast, windNorth,
     &       driftEast, driftNorth, wetWeight, stageCFL,
     &       isOwner, isValid, failCode, myThid )
        CALL BOM_VERIFY_RHS_FAILURE(
     &       isOwner, isValid, failCode, BOM_FAIL_CFL,
     &       'N08 stage CFL limit', nFail, myThid )

        CALL BOM_VERIFY_RHS_ASSERT(
     &       bomNPartTile(bi,bj).EQ.1
     &       .AND. bomStatus(1,bi,bj).EQ.BOM_ALIVE
     &       .AND. bomX(1,bi,bj).EQ.123. _d 0
     &       .AND. bomY(1,bi,bj).EQ.-456. _d 0
     &       .AND. bomAge(1,bi,bj).EQ.789. _d 0,
     &       'N08 particle state unchanged', nFail, myThid )
        bomNPartTile(bi,bj) = savedCount
        bomStatus(1,bi,bj) = savedStatus
        bomX(1,bi,bj) = savedX
        bomY(1,bi,bj) = savedY
        bomAge(1,bi,bj) = savedAge
        caseCount = caseCount + 10
      ENDIF

      bomLeewayWindCoeff = savedCoeff
      bomAdvCFL = savedCFL
      bomFieldsReady = .FALSE.

      globalCaseCount = caseCount
      CALL GLOBAL_SUM_INT( globalCaseCount, myThid )
      CALL BOM_VERIFY_RHS_ASSERT( globalCaseCount.GT.0,
     &     'RHS scenario exercised', nFail, myThid )
      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I6)')
     &         'BOM_VERIFY_RHS: failed assertions=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_RHS'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        IF ( isZero ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-I01 PASS: zero Leeway RHS'
        ELSEIF ( isCartesian ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-I02 PASS: Cartesian SI coordinate rate'
        ELSEIF ( isSpherical ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-I03 PASS: spherical degree-per-second rate'
        ELSEIF ( isLeeway ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-I04 PASS: water plus wind Leeway algebra'
        ELSE
          WRITE(msgBuf,'(A)')
     &         'P1-N08 RHS PASS: stable failure codes and no commit'
        ENDIF
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_RHS_FILL(
     I     waterEast, waterNorth, airEast, airNorth, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      _RL waterEast, waterNorth, airEast, airNorth
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
          bomGridWindEast(i,j,1,bi,bj) = airEast
          bomGridWindNorth(i,j,1,bi,bj) = airNorth
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      bomFieldsReady = .TRUE.
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_RHS_PREP_EXF( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "DYNVARS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

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
          uVel(i,j,1,bi,bj) = 0.2 _d 0
          vVel(i,j,1,bi,bj) = -0.4 _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      CALL BOM_BUILD_FIELDS( 123.5 _d 0, 7, myThid )
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_RHS_FAILURE(
     I     ownerCorrect, isValid, failCode, expectedCode,
     I     label, nFail, myThid )

      IMPLICIT NONE
      LOGICAL ownerCorrect, isValid
      INTEGER failCode, expectedCode, nFail, myThid
      CHARACTER*(*) label

      CALL BOM_VERIFY_RHS_ASSERT(
     &     ownerCorrect .AND. .NOT.isValid
     &     .AND. failCode.EQ.expectedCode,
     &     label, nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_RHS_ASSERT(
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
        WRITE(msgBuf,'(A,A)') 'BOM_VERIFY_RHS assertion: ', label
        CALL PRINT_ERROR( msgBuf, myThid )
      ENDIF

      RETURN
      END
