#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BUILD_DERIVATIVES
C !INTERFACE:
      SUBROUTINE BOM_BUILD_DERIVATIVES( myThid )

C !DESCRIPTION:
C     Rebuild and atomically publish spatial derivatives from accepted
C     Phase-2 endpoint fields.  This is used after schema-2 pickup restore.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, i, j, iEnd, iSource
      INTEGER failCode
      LOGICAL buildValid

      CALL BOM_TRY_BUILD_DERIVATIVES(
     I     .FALSE.,
     O     failCode, buildValid,
     I     myThid )
      IF ( .NOT.buildValid ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I5)')
     &         'BOM_BUILD_DERIVATIVES: failed code=', failCode
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_BUILD_DERIVATIVES'
      ENDIF

C--   Scratch is complete on every rank: publish one derived-state commit.
      _BEGIN_MASTER(myThid)
      bomGradReady = .FALSE.
      _END_MASTER(myThid)
      _BARRIER
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO iSource=1,BOM_ENV_NSOURCE
         DO iEnd=1,BOM_ENV_NEND
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            bomGradEastEast(i,j,iEnd,iSource,bi,bj) =
     &           bomGradEastEastScratch(i,j,iEnd,iSource,bi,bj)
            bomGradNorthEast(i,j,iEnd,iSource,bi,bj) =
     &           bomGradNorthEastScratch(i,j,iEnd,iSource,bi,bj)
            bomGradEastNorth(i,j,iEnd,iSource,bi,bj) =
     &           bomGradEastNorthScratch(i,j,iEnd,iSource,bi,bj)
            bomGradNorthNorth(i,j,iEnd,iSource,bi,bj) =
     &           bomGradNorthNorthScratch(i,j,iEnd,iSource,bi,bj)
            bomGradValid(i,j,iEnd,iSource,bi,bj) =
     &           bomGradValidScratch(i,j,iEnd,iSource,bi,bj)
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BARRIER
      _BEGIN_MASTER(myThid)
      bomGradReady = .TRUE.
      _END_MASTER(myThid)
      _BARRIER
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_TRY_BUILD_DERIVATIVES
C !INTERFACE:
      SUBROUTINE BOM_TRY_BUILD_DERIVATIVES(
     I                 useEnvScratch,
     O                 failCode, buildValid,
     I                 myThid )

C !DESCRIPTION:
C     Build second-order nonuniform C-point gradients into scratch storage.
C     Centered stencils are preferred; an inward three-point one-sided
C     stencil is permitted only when all three points are wet, available,
C     and finite.  Missing stencils publish false validity, never a valid
C     zero.  Metric or arithmetic failure leaves accepted state unchanged.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      LOGICAL useEnvScratch
      INTEGER myThid

C !OUTPUT PARAMETERS:
      INTEGER failCode
      LOGICAL buildValid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER bi, bj, i, j, iEnd, iSource
      INTEGER localMetricErr, globalMetricErr
      INTEGER localGradErr, globalGradErr
      _RL dEastEast, dEastNorth, dNorthEast, dNorthNorth
      _RL validWork, value
      LOGICAL xValid, yValid, metricValid, valueValid
#endif

      failCode = BOM_FAIL_GRADIENT
      buildValid = .FALSE.

#ifdef ALLOW_BOM
      localMetricErr = 0
      localGradErr = 0

C--   First P2.2 increment supports the frozen Cartesian operator only.
      IF ( OLx.LT.2 .OR. OLy.LT.2 ) localMetricErr = 1
      IF ( .NOT.usingCartesianGrid .OR.
     &     usingSphericalPolarGrid ) localMetricErr = 1
      IF ( .NOT.useEnvScratch .AND. .NOT.bomEnvReady )
     &     localGradErr = 1
      globalMetricErr = localMetricErr
      CALL GLOBAL_SUM_INT( globalMetricErr, myThid )
      globalGradErr = localGradErr
      CALL GLOBAL_SUM_INT( globalGradErr, myThid )
      IF ( globalMetricErr.GT.0 ) THEN
        failCode = BOM_FAIL_METRIC
        RETURN
      ELSEIF ( globalGradErr.GT.0 ) THEN
        failCode = BOM_FAIL_GRADIENT
        RETURN
      ENDIF

C--   Clear the whole overlap before computing owned C points.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO iSource=1,BOM_ENV_NSOURCE
         DO iEnd=1,BOM_ENV_NEND
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            bomGradEastEastScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradNorthEastScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradEastNorthScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradNorthNorthScratch(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradValidWork(i,j,iEnd,iSource,bi,bj) =
     &           0. _d 0
            bomGradValidScratch(i,j,iEnd,iSource,bi,bj) =
     &           .FALSE.
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Compute only owned interiors.  Scalar exchanges below populate halos.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO iSource=1,BOM_ENV_NSOURCE
         DO iEnd=1,BOM_ENV_NEND
          DO j=1,sNy
           DO i=1,sNx
            CALL BOM_DERIVATIVE_X_PAIR(
     I           i, j, bi, bj, iEnd, iSource, useEnvScratch,
     O           dEastEast, dEastNorth,
     O           xValid, metricValid, valueValid )
            IF ( .NOT.metricValid ) localMetricErr =
     &           localMetricErr + 1
            IF ( .NOT.valueValid ) localGradErr =
     &           localGradErr + 1
            CALL BOM_DERIVATIVE_Y_PAIR(
     I           i, j, bi, bj, iEnd, iSource, useEnvScratch,
     O           dNorthEast, dNorthNorth,
     O           yValid, metricValid, valueValid )
            IF ( .NOT.metricValid ) localMetricErr =
     &           localMetricErr + 1
            IF ( .NOT.valueValid ) localGradErr =
     &           localGradErr + 1
            IF ( xValid .AND. yValid ) THEN
              bomGradEastEastScratch(i,j,iEnd,iSource,bi,bj) =
     &             dEastEast
              bomGradNorthEastScratch(i,j,iEnd,iSource,bi,bj) =
     &             dNorthEast
              bomGradEastNorthScratch(i,j,iEnd,iSource,bi,bj) =
     &             dEastNorth
              bomGradNorthNorthScratch(i,j,iEnd,iSource,bi,bj) =
     &             dNorthNorth
              bomGradValidWork(i,j,iEnd,iSource,bi,bj) =
     &             oneRL
            ENDIF
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      globalMetricErr = localMetricErr
      CALL GLOBAL_SUM_INT( globalMetricErr, myThid )
      globalGradErr = localGradErr
      CALL GLOBAL_SUM_INT( globalGradErr, myThid )
      IF ( globalMetricErr.GT.0 ) THEN
        failCode = BOM_FAIL_METRIC
        RETURN
      ELSEIF ( globalGradErr.GT.0 ) THEN
        failCode = BOM_FAIL_GRADIENT
        RETURN
      ENDIF

C--   Exchange each geographic scalar through a single-level workspace.
C     This obeys MAX_NR_EXCH even when endpoint/source count exceeds Nr.
      DO iSource=1,BOM_ENV_NSOURCE
       DO iEnd=1,BOM_ENV_NEND
        CALL BOM_EXCH_GRAD_SLICE(
     U       bomGradEastEastScratch,
     I       iEnd, iSource, myThid )
        CALL BOM_EXCH_GRAD_SLICE(
     U       bomGradNorthEastScratch,
     I       iEnd, iSource, myThid )
        CALL BOM_EXCH_GRAD_SLICE(
     U       bomGradEastNorthScratch,
     I       iEnd, iSource, myThid )
        CALL BOM_EXCH_GRAD_SLICE(
     U       bomGradNorthNorthScratch,
     I       iEnd, iSource, myThid )
        CALL BOM_EXCH_GRAD_SLICE(
     U       bomGradValidWork,
     I       iEnd, iSource, myThid )
       ENDDO
      ENDDO

C--   Decode and validate the exchanged numeric mask before publication.
      localGradErr = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO iSource=1,BOM_ENV_NSOURCE
         DO iEnd=1,BOM_ENV_NEND
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            validWork = bomGradValidWork(
     &           i,j,iEnd,iSource,bi,bj)
            IF ( validWork.EQ.oneRL ) THEN
              bomGradValidScratch(i,j,iEnd,iSource,bi,bj) =
     &             .TRUE.
              value = bomGradEastEastScratch(
     &             i,j,iEnd,iSource,bi,bj)
              IF ( .NOT.IEEE_IS_FINITE(value) )
     &             localGradErr = localGradErr + 1
              value = bomGradNorthEastScratch(
     &             i,j,iEnd,iSource,bi,bj)
              IF ( .NOT.IEEE_IS_FINITE(value) )
     &             localGradErr = localGradErr + 1
              value = bomGradEastNorthScratch(
     &             i,j,iEnd,iSource,bi,bj)
              IF ( .NOT.IEEE_IS_FINITE(value) )
     &             localGradErr = localGradErr + 1
              value = bomGradNorthNorthScratch(
     &             i,j,iEnd,iSource,bi,bj)
              IF ( .NOT.IEEE_IS_FINITE(value) )
     &             localGradErr = localGradErr + 1
            ELSEIF ( validWork.EQ.0. _d 0 ) THEN
              bomGradValidScratch(i,j,iEnd,iSource,bi,bj) =
     &             .FALSE.
              IF ( bomGradEastEastScratch(
     &             i,j,iEnd,iSource,bi,bj).NE.0. _d 0 .OR.
     &             bomGradNorthEastScratch(
     &             i,j,iEnd,iSource,bi,bj).NE.0. _d 0 .OR.
     &             bomGradEastNorthScratch(
     &             i,j,iEnd,iSource,bi,bj).NE.0. _d 0 .OR.
     &             bomGradNorthNorthScratch(
     &             i,j,iEnd,iSource,bi,bj).NE.0. _d 0 )
     &             localGradErr = localGradErr + 1
            ELSE
              localGradErr = localGradErr + 1
            ENDIF
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalGradErr = localGradErr
      CALL GLOBAL_SUM_INT( globalGradErr, myThid )
      IF ( globalGradErr.GT.0 ) THEN
        failCode = BOM_FAIL_GRADIENT
        RETURN
      ENDIF

      failCode = BOM_FAIL_NONE
      buildValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_DERIVATIVE_X_PAIR(
     I                 i, j, bi, bj, iEnd, iSource, useEnvScratch,
     O                 dEast, dNorth,
     O                 gradValid, metricValid, valueValid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER i, j, bi, bj, iEnd, iSource
      _RL dEast, dNorth
      LOGICAL useEnvScratch, gradValid, metricValid, valueValid
      _RL eastM2, eastM1, east0, eastP1, eastP2
      _RL northM2, northM1, north0, northP1, northP2
      _RL h1, h2, a0, a1, a2
      LOGICAL availM2, availM1, avail0, availP1, availP2
      LOGICAL coeffValid, eastValid, northValid

      dEast = 0. _d 0
      dNorth = 0. _d 0
      gradValid = .FALSE.
      metricValid = .TRUE.
      valueValid = .TRUE.

      CALL BOM_DERIV_GET_POINT(
     I     i-2,j,bi,bj,iEnd,iSource,useEnvScratch,
     O     eastM2,northM2,availM2,valueValid )
      IF ( .NOT.valueValid ) RETURN
      CALL BOM_DERIV_GET_POINT(
     I     i-1,j,bi,bj,iEnd,iSource,useEnvScratch,
     O     eastM1,northM1,availM1,valueValid )
      IF ( .NOT.valueValid ) RETURN
      CALL BOM_DERIV_GET_POINT(
     I     i,j,bi,bj,iEnd,iSource,useEnvScratch,
     O     east0,north0,avail0,valueValid )
      IF ( .NOT.valueValid .OR. .NOT.avail0 ) RETURN
      CALL BOM_DERIV_GET_POINT(
     I     i+1,j,bi,bj,iEnd,iSource,useEnvScratch,
     O     eastP1,northP1,availP1,valueValid )
      IF ( .NOT.valueValid ) RETURN
      CALL BOM_DERIV_GET_POINT(
     I     i+2,j,bi,bj,iEnd,iSource,useEnvScratch,
     O     eastP2,northP2,availP2,valueValid )
      IF ( .NOT.valueValid ) RETURN

      IF ( availM1 .AND. availP1 ) THEN
        h1 = dxC(i,j,bi,bj)
        h2 = dxC(i+1,j,bi,bj)
        CALL BOM_DERIV_COEFF_CENTRAL(
     I       h1, h2,
     O       a0, a1, a2, coeffValid )
        IF ( .NOT.coeffValid ) THEN
          metricValid = .FALSE.
          RETURN
        ENDIF
        CALL BOM_DERIV_APPLY3(
     I       eastM1, east0, eastP1, a0, a1, a2,
     O       dEast, eastValid )
        CALL BOM_DERIV_APPLY3(
     I       northM1, north0, northP1, a0, a1, a2,
     O       dNorth, northValid )
      ELSEIF ( availP1 .AND. availP2 ) THEN
        h1 = dxC(i+1,j,bi,bj)
        h2 = dxC(i+2,j,bi,bj)
        CALL BOM_DERIV_COEFF_FORWARD(
     I       h1, h2,
     O       a0, a1, a2, coeffValid )
        IF ( .NOT.coeffValid ) THEN
          metricValid = .FALSE.
          RETURN
        ENDIF
        CALL BOM_DERIV_APPLY3(
     I       east0, eastP1, eastP2, a0, a1, a2,
     O       dEast, eastValid )
        CALL BOM_DERIV_APPLY3(
     I       north0, northP1, northP2, a0, a1, a2,
     O       dNorth, northValid )
      ELSEIF ( availM1 .AND. availM2 ) THEN
        h1 = dxC(i,j,bi,bj)
        h2 = dxC(i-1,j,bi,bj)
        CALL BOM_DERIV_COEFF_BACKWARD(
     I       h1, h2,
     O       a0, a1, a2, coeffValid )
        IF ( .NOT.coeffValid ) THEN
          metricValid = .FALSE.
          RETURN
        ENDIF
        CALL BOM_DERIV_APPLY3(
     I       east0, eastM1, eastM2, a0, a1, a2,
     O       dEast, eastValid )
        CALL BOM_DERIV_APPLY3(
     I       north0, northM1, northM2, a0, a1, a2,
     O       dNorth, northValid )
      ELSE
        RETURN
      ENDIF

      valueValid = eastValid .AND. northValid
      IF ( .NOT.valueValid ) THEN
        dEast = 0. _d 0
        dNorth = 0. _d 0
        RETURN
      ENDIF
      gradValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_DERIVATIVE_Y_PAIR(
     I                 i, j, bi, bj, iEnd, iSource, useEnvScratch,
     O                 dEast, dNorth,
     O                 gradValid, metricValid, valueValid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER i, j, bi, bj, iEnd, iSource
      _RL dEast, dNorth
      LOGICAL useEnvScratch, gradValid, metricValid, valueValid
      _RL eastM2, eastM1, east0, eastP1, eastP2
      _RL northM2, northM1, north0, northP1, northP2
      _RL h1, h2, a0, a1, a2
      LOGICAL availM2, availM1, avail0, availP1, availP2
      LOGICAL coeffValid, eastValid, northValid

      dEast = 0. _d 0
      dNorth = 0. _d 0
      gradValid = .FALSE.
      metricValid = .TRUE.
      valueValid = .TRUE.

      CALL BOM_DERIV_GET_POINT(
     I     i,j-2,bi,bj,iEnd,iSource,useEnvScratch,
     O     eastM2,northM2,availM2,valueValid )
      IF ( .NOT.valueValid ) RETURN
      CALL BOM_DERIV_GET_POINT(
     I     i,j-1,bi,bj,iEnd,iSource,useEnvScratch,
     O     eastM1,northM1,availM1,valueValid )
      IF ( .NOT.valueValid ) RETURN
      CALL BOM_DERIV_GET_POINT(
     I     i,j,bi,bj,iEnd,iSource,useEnvScratch,
     O     east0,north0,avail0,valueValid )
      IF ( .NOT.valueValid .OR. .NOT.avail0 ) RETURN
      CALL BOM_DERIV_GET_POINT(
     I     i,j+1,bi,bj,iEnd,iSource,useEnvScratch,
     O     eastP1,northP1,availP1,valueValid )
      IF ( .NOT.valueValid ) RETURN
      CALL BOM_DERIV_GET_POINT(
     I     i,j+2,bi,bj,iEnd,iSource,useEnvScratch,
     O     eastP2,northP2,availP2,valueValid )
      IF ( .NOT.valueValid ) RETURN

      IF ( availM1 .AND. availP1 ) THEN
        h1 = dyC(i,j,bi,bj)
        h2 = dyC(i,j+1,bi,bj)
        CALL BOM_DERIV_COEFF_CENTRAL(
     I       h1, h2,
     O       a0, a1, a2, coeffValid )
        IF ( .NOT.coeffValid ) THEN
          metricValid = .FALSE.
          RETURN
        ENDIF
        CALL BOM_DERIV_APPLY3(
     I       eastM1, east0, eastP1, a0, a1, a2,
     O       dEast, eastValid )
        CALL BOM_DERIV_APPLY3(
     I       northM1, north0, northP1, a0, a1, a2,
     O       dNorth, northValid )
      ELSEIF ( availP1 .AND. availP2 ) THEN
        h1 = dyC(i,j+1,bi,bj)
        h2 = dyC(i,j+2,bi,bj)
        CALL BOM_DERIV_COEFF_FORWARD(
     I       h1, h2,
     O       a0, a1, a2, coeffValid )
        IF ( .NOT.coeffValid ) THEN
          metricValid = .FALSE.
          RETURN
        ENDIF
        CALL BOM_DERIV_APPLY3(
     I       east0, eastP1, eastP2, a0, a1, a2,
     O       dEast, eastValid )
        CALL BOM_DERIV_APPLY3(
     I       north0, northP1, northP2, a0, a1, a2,
     O       dNorth, northValid )
      ELSEIF ( availM1 .AND. availM2 ) THEN
        h1 = dyC(i,j,bi,bj)
        h2 = dyC(i,j-1,bi,bj)
        CALL BOM_DERIV_COEFF_BACKWARD(
     I       h1, h2,
     O       a0, a1, a2, coeffValid )
        IF ( .NOT.coeffValid ) THEN
          metricValid = .FALSE.
          RETURN
        ENDIF
        CALL BOM_DERIV_APPLY3(
     I       east0, eastM1, eastM2, a0, a1, a2,
     O       dEast, eastValid )
        CALL BOM_DERIV_APPLY3(
     I       north0, northM1, northM2, a0, a1, a2,
     O       dNorth, northValid )
      ELSE
        RETURN
      ENDIF

      valueValid = eastValid .AND. northValid
      IF ( .NOT.valueValid ) THEN
        dEast = 0. _d 0
        dNorth = 0. _d 0
        RETURN
      ENDIF
      gradValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_DERIV_GET_POINT(
     I                 i, j, bi, bj, iEnd, iSource, useEnvScratch,
     O                 eastValue, northValue, available, valueValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER i, j, bi, bj, iEnd, iSource
      _RL eastValue, northValue
      LOGICAL useEnvScratch, available, valueValid
      LOGICAL declaredValid

      eastValue = 0. _d 0
      northValue = 0. _d 0
      available = .FALSE.
      valueValid = .TRUE.
      IF ( i.LT.1-OLx .OR. i.GT.sNx+OLx .OR.
     &     j.LT.1-OLy .OR. j.GT.sNy+OLy ) RETURN

      IF ( useEnvScratch ) THEN
        eastValue = bomEnvEastScratch(i,j,iEnd,iSource,bi,bj)
        northValue = bomEnvNorthScratch(i,j,iEnd,iSource,bi,bj)
        declaredValid =
     &       bomEnvValidScratch(i,j,iEnd,iSource,bi,bj)
      ELSE
        eastValue = bomEnvEast(i,j,iEnd,iSource,bi,bj)
        northValue = bomEnvNorth(i,j,iEnd,iSource,bi,bj)
        declaredValid = bomEnvValid(i,j,iEnd,iSource,bi,bj)
      ENDIF
      available = maskC(i,j,1,bi,bj).GT.0. .AND. declaredValid
      IF ( available ) THEN
        valueValid = IEEE_IS_FINITE(eastValue) .AND.
     &               IEEE_IS_FINITE(northValue)
      ENDIF

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_EXCH_GRAD_SLICE(
     U                 field,
     I                 iEnd, iSource, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL field(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,
     &     BOM_ENV_NEND,BOM_ENV_NSOURCE,nSx,nSy)
      INTEGER iEnd, iSource, myThid
      INTEGER bi, bj, i, j

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomGradExchangeWork(i,j,1,bi,bj) =
     &         field(i,j,iEnd,iSource,bi,bj)
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      CALL EXCH_3D_RL( bomGradExchangeWork, 1, myThid )

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          field(i,j,iEnd,iSource,bi,bj) =
     &         bomGradExchangeWork(i,j,1,bi,bj)
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_DERIV_COEFF_CENTRAL(
     I                 hMinus, hPlus,
     O                 aMinus, aZero, aPlus, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL hMinus, hPlus, aMinus, aZero, aPlus
      _RL hSum, invMinus, invPlus, invSum
      LOGICAL isValid

      aMinus = 0. _d 0
      aZero = 0. _d 0
      aPlus = 0. _d 0
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(hMinus) .OR.
     &     .NOT.IEEE_IS_FINITE(hPlus) ) RETURN
      IF ( hMinus.LE.0. _d 0 .OR. hPlus.LE.0. _d 0 ) RETURN
      hSum = hMinus+hPlus
      IF ( .NOT.IEEE_IS_FINITE(hSum) .OR. hSum.LE.0. _d 0 ) RETURN
      invMinus = 1. _d 0/hMinus
      invPlus = 1. _d 0/hPlus
      invSum = 1. _d 0/hSum
      aMinus = -(hPlus/hMinus)*invSum
      aZero = invMinus-invPlus
      aPlus = (hMinus/hPlus)*invSum
      isValid = IEEE_IS_FINITE(aMinus) .AND.
     &          IEEE_IS_FINITE(aZero) .AND.
     &          IEEE_IS_FINITE(aPlus)

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_DERIV_COEFF_FORWARD(
     I                 hFirst, hSecond,
     O                 aZero, aFirst, aSecond, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL hFirst, hSecond, aZero, aFirst, aSecond
      _RL hSum, invFirst, invSecond, invSum
      LOGICAL isValid

      aZero = 0. _d 0
      aFirst = 0. _d 0
      aSecond = 0. _d 0
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(hFirst) .OR.
     &     .NOT.IEEE_IS_FINITE(hSecond) ) RETURN
      IF ( hFirst.LE.0. _d 0 .OR. hSecond.LE.0. _d 0 ) RETURN
      hSum = hFirst+hSecond
      IF ( .NOT.IEEE_IS_FINITE(hSum) .OR. hSum.LE.0. _d 0 ) RETURN
      invFirst = 1. _d 0/hFirst
      invSecond = 1. _d 0/hSecond
      invSum = 1. _d 0/hSum
      aZero = -invFirst-invSum
      aFirst = invFirst+invSecond
      aSecond = -(hFirst/hSecond)*invSum
      isValid = IEEE_IS_FINITE(aZero) .AND.
     &          IEEE_IS_FINITE(aFirst) .AND.
     &          IEEE_IS_FINITE(aSecond)

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_DERIV_COEFF_BACKWARD(
     I                 hFirst, hSecond,
     O                 aZero, aFirst, aSecond, isValid )

      IMPLICIT NONE
      _RL hFirst, hSecond, aZero, aFirst, aSecond
      _RL fZero, fFirst, fSecond
      LOGICAL isValid

      CALL BOM_DERIV_COEFF_FORWARD(
     I     hFirst, hSecond,
     O     fZero, fFirst, fSecond, isValid )
      IF ( isValid ) THEN
        aZero = -fZero
        aFirst = -fFirst
        aSecond = -fSecond
      ELSE
        aZero = 0. _d 0
        aFirst = 0. _d 0
        aSecond = 0. _d 0
      ENDIF

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_DERIV_APPLY3(
     I                 qZero, qOne, qTwo,
     I                 aZero, aOne, aTwo,
     O                 derivative, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL qZero, qOne, qTwo, aZero, aOne, aTwo
      _RL derivative, scaleQ, scaleA, sumScaled, factor
      LOGICAL isValid

      derivative = 0. _d 0
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(qZero) .OR.
     &     .NOT.IEEE_IS_FINITE(qOne) .OR.
     &     .NOT.IEEE_IS_FINITE(qTwo) .OR.
     &     .NOT.IEEE_IS_FINITE(aZero) .OR.
     &     .NOT.IEEE_IS_FINITE(aOne) .OR.
     &     .NOT.IEEE_IS_FINITE(aTwo) ) RETURN

C--   Preserve the exact derivative of a constant represented field.
      IF ( qZero.EQ.qOne .AND. qOne.EQ.qTwo ) THEN
        isValid = .TRUE.
        RETURN
      ENDIF

      scaleQ = MAX(ABS(qZero),ABS(qOne),ABS(qTwo))
      scaleA = MAX(ABS(aZero),ABS(aOne),ABS(aTwo))
      IF ( scaleQ.EQ.0. _d 0 ) THEN
        isValid = .TRUE.
        RETURN
      ENDIF
      IF ( scaleA.LE.0. _d 0 .OR.
     &     .NOT.IEEE_IS_FINITE(scaleQ) .OR.
     &     .NOT.IEEE_IS_FINITE(scaleA) ) RETURN

      sumScaled = (aZero/scaleA)*(qZero/scaleQ)
     &          + (aOne/scaleA)*(qOne/scaleQ)
     &          + (aTwo/scaleA)*(qTwo/scaleQ)
      IF ( .NOT.IEEE_IS_FINITE(sumScaled) ) RETURN
      IF ( ABS(sumScaled).GT.1. _d 0 ) THEN
        IF ( scaleA.GT.HUGE(factor)/ABS(sumScaled) ) RETURN
      ENDIF
      factor = sumScaled*scaleA
      IF ( .NOT.IEEE_IS_FINITE(factor) ) RETURN
      IF ( ABS(factor).GT.1. _d 0 ) THEN
        IF ( scaleQ.GT.HUGE(derivative)/ABS(factor) ) RETURN
      ENDIF
      derivative = factor*scaleQ
      IF ( .NOT.IEEE_IS_FINITE(derivative) ) THEN
        derivative = 0. _d 0
        RETURN
      ENDIF
      isValid = .TRUE.

      RETURN
      END
