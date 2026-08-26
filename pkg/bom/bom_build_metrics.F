#include "BOM_OPTIONS.h"
#include "FCORI_MACROS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_TRY_BUILD_METRICS
C !INTERFACE:
      SUBROUTINE BOM_TRY_BUILD_METRICS(
     O                 failCode, buildValid,
     I                 myThid )

C !DESCRIPTION:
C     Build time-invariant C-point tauSphere and fCori in transaction
C     scratch.  Dry points are explicit invalid zeros.  Accepted metric
C     state is changed only by the enclosing derivative/endpoint commit.

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

C !OUTPUT PARAMETERS:
      INTEGER failCode
      LOGICAL buildValid
C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
      INTEGER bi, bj, i, j
      INTEGER localErr, globalErr
      _RL latitude, coriInput, tauValue, coriValue, validWork
      LOGICAL pointValid
#endif

      failCode = BOM_FAIL_METRIC
      buildValid = .FALSE.

#ifdef ALLOW_BOM
      localErr = 0
      IF ( usingCartesianGrid.EQV.usingSphericalPolarGrid )
     &     localErr = localErr + 1
      IF ( usingSphericalPolarGrid ) THEN
        IF ( .NOT.IEEE_IS_FINITE(rSphere) .OR.
     &       rSphere.LE.0. _d 0 ) localErr = localErr + 1
      ENDIF
      globalErr = localErr
      CALL GLOBAL_SUM_INT( globalErr, myThid )
      IF ( globalErr.GT.0 ) RETURN

C--   Initialise all overlaps before owned interiors are evaluated.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomTauSphereScratch(i,j,bi,bj) = 0. _d 0
          bomFCoriScratch(i,j,bi,bj) = 0. _d 0
          bomMetricValidWork(i,j,bi,bj) = 0. _d 0
          bomMetricValidScratch(i,j,bi,bj) = .FALSE.
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          IF ( maskC(i,j,1,bi,bj).GT.0. ) THEN
            latitude = DBLE(yC(i,j,bi,bj))
            coriInput = DBLE(_fCori(i,j,bi,bj))
            CALL BOM_EVAL_CPOINT_METRICS(
     I           latitude, coriInput,
     O           tauValue, coriValue, pointValid )
            IF ( pointValid ) THEN
              bomTauSphereScratch(i,j,bi,bj) = tauValue
              bomFCoriScratch(i,j,bi,bj) = coriValue
              bomMetricValidWork(i,j,bi,bj) = oneRL
            ELSE
              localErr = localErr + 1
            ENDIF
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErr = localErr
      CALL GLOBAL_SUM_INT( globalErr, myThid )
      IF ( globalErr.GT.0 ) RETURN

C--   Exchange physical scalars and the numeric validity mask together.
      CALL EXCH_XY_RL( bomTauSphereScratch, myThid )
      CALL EXCH_XY_RL( bomFCoriScratch, myThid )
      CALL EXCH_XY_RL( bomMetricValidWork, myThid )

C--   Decode the halo mask and require exact invalid-zero semantics.
      localErr = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          validWork = bomMetricValidWork(i,j,bi,bj)
          tauValue = bomTauSphereScratch(i,j,bi,bj)
          coriValue = bomFCoriScratch(i,j,bi,bj)
          IF ( validWork.EQ.oneRL ) THEN
            bomMetricValidScratch(i,j,bi,bj) = .TRUE.
            IF ( .NOT.IEEE_IS_FINITE(tauValue) .OR.
     &           .NOT.IEEE_IS_FINITE(coriValue) )
     &           localErr = localErr + 1
            IF ( usingCartesianGrid .AND.
     &           tauValue.NE.0. _d 0 ) localErr = localErr + 1
          ELSEIF ( validWork.EQ.0. _d 0 ) THEN
            bomMetricValidScratch(i,j,bi,bj) = .FALSE.
            IF ( tauValue.NE.0. _d 0 .OR.
     &           coriValue.NE.0. _d 0 ) localErr = localErr + 1
          ELSE
            localErr = localErr + 1
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErr = localErr
      CALL GLOBAL_SUM_INT( globalErr, myThid )
      IF ( globalErr.GT.0 ) RETURN

      failCode = BOM_FAIL_NONE
      buildValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_EVAL_CPOINT_METRICS
C !INTERFACE:
      SUBROUTINE BOM_EVAL_CPOINT_METRICS(
     I                 latitude, coriInput,
     O                 tauSphere, coriOutput, metricValid )

C !DESCRIPTION:
C     Evaluate the frozen regular-grid C-point metric contract.  Latitude
C     is in degrees and rSphere in metres.  tauSphere has units m^-1 and
C     fCori keeps the MITgcm s^-1 value required by the Phase-2 operators.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL latitude, coriInput, tauSphere, coriOutput
      _RL latRad, cosLat, tanLat, cosMin
      LOGICAL metricValid
CEOP

      tauSphere = 0. _d 0
      coriOutput = 0. _d 0
      metricValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(latitude) .OR.
     &     .NOT.IEEE_IS_FINITE(coriInput) ) RETURN
      IF ( usingCartesianGrid .AND.
     &     .NOT.usingSphericalPolarGrid ) THEN
        coriOutput = coriInput
        metricValid = .TRUE.
        RETURN
      ENDIF
      IF ( .NOT.usingSphericalPolarGrid .OR.
     &     usingCartesianGrid ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(rSphere) .OR.
     &     rSphere.LE.0. _d 0 ) RETURN
      IF ( ABS(latitude).GT.90. _d 0 ) RETURN

      latRad = deg2rad*latitude
      IF ( .NOT.IEEE_IS_FINITE(latRad) ) RETURN
      cosLat = COS(latRad)
      cosMin = SQRT(EPSILON(oneRL))
      IF ( .NOT.IEEE_IS_FINITE(cosLat) .OR.
     &     ABS(cosLat).LT.cosMin ) RETURN
      tanLat = TAN(latRad)
      IF ( .NOT.IEEE_IS_FINITE(tanLat) ) RETURN
      IF ( rSphere.LT.oneRL ) THEN
        IF ( ABS(tanLat).GT.HUGE(tauSphere)*rSphere ) RETURN
      ENDIF
      tauSphere = tanLat/rSphere
      IF ( .NOT.IEEE_IS_FINITE(tauSphere) ) THEN
        tauSphere = 0. _d 0
        RETURN
      ENDIF
      coriOutput = coriInput
      metricValid = .TRUE.

      RETURN
      END
