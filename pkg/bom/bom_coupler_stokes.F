#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_CLEAR_COUPLER_STOKES
C !INTERFACE:
      SUBROUTINE BOM_CLEAR_COUPLER_STOKES( myThid )

C !DESCRIPTION:
C     Invalidate and zero every BOM-owned COUPLER Stokes publication.

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
      INTEGER bi, bj, i, j, iComponent

      _BEGIN_MASTER(myThid)
      DO iComponent=1,BOM_COUPLER_NCOMP
        bomCouplerStokesReady(iComponent) = .FALSE.
        bomCouplerStokesTime(iComponent) = 0. _d 0
        bomCouplerStokesIter(iComponent) = 0
      ENDDO
      _END_MASTER(myThid)
      _BARRIER

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomCouplerStokesEast(i,j,1,bi,bj) = 0. _d 0
          bomCouplerStokesNorth(i,j,1,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BARRIER
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_SET_COUPLER_STOKES
C !INTERFACE:
      SUBROUTINE BOM_SET_COUPLER_STOKES(
     I                 component, componentField,
     I                 fieldTime, fieldIter,
     O                 setValid,
     I                 myThid )

C !DESCRIPTION:
C     Copy one geographic C-point component from an external producer.
C     Publication becomes ready only after the complete field is validated
C     and copied.  Producer storage is never aliased by BOM.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER component, fieldIter, myThid
      _RL fieldTime
      _RL componentField(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)

C !OUTPUT PARAMETERS:
      LOGICAL setValid
CEOP

#if defined(ALLOW_BOM) && defined(ALLOW_BOM_STOKES_COUPLER)
C !LOCAL VARIABLES:
      INTEGER bi, bj, i, j
      INTEGER localErrCount, globalErrCount
      _RL fieldValue
      LOGICAL wetPoint

      setValid = .FALSE.
      localErrCount = 0
      IF ( component.NE.BOM_COUPLER_EAST .AND.
     &     component.NE.BOM_COUPLER_NORTH ) THEN
        localErrCount = 1
      ELSE
        _BEGIN_MASTER(myThid)
        bomCouplerStokesReady(component) = .FALSE.
        _END_MASTER(myThid)
        _BARRIER
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(fieldTime) )
     &     localErrCount = 1

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          fieldValue = componentField(i,j,1,bi,bj)
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          IF ( .NOT.IEEE_IS_FINITE(fieldValue) )
     &         localErrCount = 1
          IF ( .NOT.wetPoint .AND. fieldValue.NE.0. _d 0 )
     &         localErrCount = 1
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          IF ( component.EQ.BOM_COUPLER_EAST ) THEN
            bomCouplerStokesEast(i,j,1,bi,bj) = 0. _d 0
          ELSE
            bomCouplerStokesNorth(i,j,1,bi,bj) = 0. _d 0
          ENDIF
         ENDDO
        ENDDO
        DO j=1,sNy
         DO i=1,sNx
          IF ( component.EQ.BOM_COUPLER_EAST ) THEN
            bomCouplerStokesEast(i,j,1,bi,bj) =
     &           componentField(i,j,1,bi,bj)
          ELSE
            bomCouplerStokesNorth(i,j,1,bi,bj) =
     &           componentField(i,j,1,bi,bj)
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      _BARRIER
      _BEGIN_MASTER(myThid)
      bomCouplerStokesTime(component) = fieldTime
      bomCouplerStokesIter(component) = fieldIter
      bomCouplerStokesReady(component) = .TRUE.
      _END_MASTER(myThid)
      _BARRIER
      setValid = .TRUE.
#else
      setValid = .FALSE.
#endif

      RETURN
      END

C---+----1----2----3----4----5----6----7-|--+----|
CBOP
C !ROUTINE: BOM_GET_COUPLER_STOKES
C !INTERFACE:
      SUBROUTINE BOM_GET_COUPLER_STOKES(
     I                 targetTime, targetIter,
     O                 failCode, stokesValid,
     I                 myThid )

C !DESCRIPTION:
C     Select one complete copied publication with exact component labels.
C     Accepted endpoint state is never changed by this provider.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL targetTime
      INTEGER targetIter, myThid

C !OUTPUT PARAMETERS:
      INTEGER failCode
      LOGICAL stokesValid
CEOP

#if defined(ALLOW_BOM) && defined(ALLOW_BOM_STOKES_COUPLER)
C !LOCAL VARIABLES:
      INTEGER bi, bj, i, j, iComponent
      INTEGER localErrCount, globalErrCount
      _RL timeScale, timeTol, eastValue, northValue
      LOGICAL isNear, compareValid, wetPoint, invalidValue

      failCode = BOM_FAIL_FIELD_SOURCE
      stokesValid = .FALSE.
      localErrCount = 0
      IF ( bomStokesSource.NE.'COUPLER' .OR.
     &     .NOT.IEEE_IS_FINITE(targetTime) )
     &     localErrCount = localErrCount + 1
      DO iComponent=1,BOM_COUPLER_NCOMP
        IF ( .NOT.bomCouplerStokesReady(iComponent) .OR.
     &       bomCouplerStokesIter(iComponent).NE.targetIter .OR.
     &       .NOT.IEEE_IS_FINITE(
     &              bomCouplerStokesTime(iComponent)) ) THEN
          localErrCount = localErrCount + 1
        ELSE
          timeScale = MAX(oneRL,ABS(targetTime),
     &                    ABS(bomCouplerStokesTime(iComponent)))
          timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
          CALL BOM_TIME_NEAR(
     I         bomCouplerStokesTime(iComponent), targetTime,
     I         timeTol,
     O         isNear, compareValid )
          IF ( .NOT.compareValid .OR. .NOT.isNear )
     &         localErrCount = localErrCount + 1
        ENDIF
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomStokesEastWork(i,j,1,bi,bj) = 0. _d 0
          bomStokesNorthWork(i,j,1,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
        DO j=1,sNy
         DO i=1,sNx
          bomStokesEastWork(i,j,1,bi,bj) =
     &         bomCouplerStokesEast(i,j,1,bi,bj)
          bomStokesNorthWork(i,j,1,bi,bj) =
     &         bomCouplerStokesNorth(i,j,1,bi,bj)
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      CALL EXCH_3D_RL( bomStokesEastWork, 1, myThid )
      CALL EXCH_3D_RL( bomStokesNorthWork, 1, myThid )

      localErrCount = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          eastValue = bomStokesEastWork(i,j,1,bi,bj)
          northValue = bomStokesNorthWork(i,j,1,bi,bj)
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          invalidValue = .NOT.IEEE_IS_FINITE(eastValue) .OR.
     &                   .NOT.IEEE_IS_FINITE(northValue)
          IF ( .NOT.wetPoint ) invalidValue = invalidValue .OR.
     &         eastValue.NE.0. _d 0 .OR.
     &         northValue.NE.0. _d 0
          IF ( invalidValue ) localErrCount = 1
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      failCode = BOM_FAIL_NONE
      stokesValid = .TRUE.
#else
      failCode = BOM_FAIL_FIELD_SOURCE
      stokesValid = .FALSE.
#endif

      RETURN
      END
