#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_FILL_CGRID_BOUNDARY

C !INTERFACE:
      SUBROUTINE BOM_FILL_CGRID_BOUNDARY(
     U                 uField, vField,
     I                 myThid )

C !DESCRIPTION:
C     Complete the positive physical faces of a Cartesian C-grid before
C     BOM collocates velocity at tracer points.  A global Nx-by-Ny native
C     C-grid record stores the west U and south V face of each tracer cell;
C     it therefore has no record for the east face at i=Nx+1 or the north
C     face at j=Ny+1.  Periodic and internal faces are already supplied by
C     exchange.  At a non-periodic positive boundary, extend the last two
C     stored faces linearly into the missing halo face.  This is exact for
C     affine fields and changes BOM-owned work arrays only.
C
C     A one-cell tile cannot form a second-order one-sided continuation;
C     in that case use a constant continuation without reading out of bounds.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "PARAMS.h"

C !INPUT/OUTPUT PARAMETERS:
      _RL uField(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      _RL vField(
     &     1-OLx:sNx+OLx,1-OLy:sNy+OLy,1,nSx,nSy)
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER bi, bj, i, j, iGlobalHi, jGlobalHi
      LOGICAL closeXBoundary, closeYBoundary

      closeXBoundary = notUsingXPeriodicity
      closeYBoundary = notUsingYPeriodicity
#ifdef ALWAYS_PREVENT_X_PERIODICITY
      closeXBoundary = .TRUE.
#endif
#ifdef ALWAYS_PREVENT_Y_PERIODICITY
      closeYBoundary = .TRUE.
#endif

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        iGlobalHi = myXGlobalLo-1+(bi-1)*sNx+sNx
        jGlobalHi = myYGlobalLo-1+(bj-1)*sNy+sNy

        IF ( closeXBoundary .AND. iGlobalHi.EQ.Nx ) THEN
          DO j=1-OLy,sNy+OLy
            IF ( sNx.GE.2 ) THEN
              uField(sNx+1,j,1,bi,bj) =
     &             2. _d 0*uField(sNx,j,1,bi,bj)
     &             -uField(sNx-1,j,1,bi,bj)
            ELSE
              uField(sNx+1,j,1,bi,bj) =
     &             uField(sNx,j,1,bi,bj)
            ENDIF
          ENDDO
        ENDIF

        IF ( closeYBoundary .AND. jGlobalHi.EQ.Ny ) THEN
          DO i=1-OLx,sNx+OLx
            IF ( sNy.GE.2 ) THEN
              vField(i,sNy+1,1,bi,bj) =
     &             2. _d 0*vField(i,sNy,1,bi,bj)
     &             -vField(i,sNy-1,1,bi,bj)
            ELSE
              vField(i,sNy+1,1,bi,bj) =
     &             vField(i,sNy,1,bi,bj)
            ENDIF
          ENDDO
        ENDIF
       ENDDO
      ENDDO
#endif /* ALLOW_BOM */

      RETURN
      END
