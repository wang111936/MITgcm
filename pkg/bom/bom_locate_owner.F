#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_LOCATE_OWNER

C !INTERFACE:
      SUBROUTINE BOM_LOCATE_OWNER(
     I                 xx, yy, sourceBi, sourceBj,
     O                 xOwner, yOwner, ownerRank, ownerBi, ownerBj,
     O                 hopCount, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Locate the unique P1.4 owner on a supported regular grid.  Global
C     half-open face tables are searched logarithmically.  Actual MITgcm
C     rank origins are used instead of assuming communicator rank order.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL xx, yy
      INTEGER sourceBi, sourceBj, myThid

C !OUTPUT PARAMETERS:
      _RL xOwner, yOwner
      INTEGER ownerRank, ownerBi, ownerBj, hopCount
      LOGICAL isValid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER lo, hi, mid, iGlobal, jGlobal
      INTEGER tileX, tileY, sourceTileX, sourceTileY
      INTEGER procX, procY
#ifdef ALLOW_USE_MPI
      INTEGER rankIndex
#endif
      INTEGER expectedXLo, expectedYLo
      INTEGER dxTile, dyTile, nTileX
      LOGICAL isInsideX
#endif

      xOwner = xx
      yOwner = yy
      ownerRank = -1
      ownerBi = 0
      ownerBj = 0
      hopCount = 0
      isValid = .FALSE.

#ifdef ALLOW_BOM
      IF ( .NOT.IEEE_IS_FINITE(xx) .OR.
     &     .NOT.IEEE_IS_FINITE(yy) ) RETURN
      IF ( sourceBi.LT.1 .OR. sourceBi.GT.nSx .OR.
     &     sourceBj.LT.1 .OR. sourceBj.GT.nSy ) RETURN

      CALL BOM_NORMALIZE_X( xx, xOwner, isInsideX, myThid )
      IF ( .NOT.isInsideX ) RETURN
      IF ( yOwner.LT.bomMapYLo .OR. yOwner.GE.bomMapYHi ) RETURN
      IF ( ABS(bomMapXFace(0)-bomMapXLo).GT.bomMapTol .OR.
     &     ABS(bomMapXFace(Nx)-bomMapXHi).GT.bomMapTol .OR.
     &     ABS(bomMapYFace(0)-bomMapYLo).GT.bomMapTol .OR.
     &     ABS(bomMapYFace(Ny)-bomMapYHi).GT.bomMapTol ) RETURN

C--   Exact face ties select the cell on the east/north side.
      lo = 1
      hi = Nx
      DO WHILE ( lo.LT.hi )
        mid = (lo+hi)/2
        IF ( xOwner.LT.bomMapXFace(mid) ) THEN
          hi = mid
        ELSE
          lo = mid + 1
        ENDIF
      ENDDO
      iGlobal = lo

C--   Resolve roundoff-level internal-face ambiguity to east ownership.
      IF ( iGlobal.GT.1 ) THEN
        IF ( ABS(xOwner-bomMapXFace(iGlobal-1))
     &       .LE.bomMapTol ) xOwner=bomMapXFace(iGlobal-1)
      ENDIF
      IF ( iGlobal.LT.Nx ) THEN
        IF ( ABS(xOwner-bomMapXFace(iGlobal)).LE.bomMapTol ) THEN
          xOwner = bomMapXFace(iGlobal)
          iGlobal = iGlobal + 1
        ENDIF
      ENDIF

      lo = 1
      hi = Ny
      DO WHILE ( lo.LT.hi )
        mid = (lo+hi)/2
        IF ( yOwner.LT.bomMapYFace(mid) ) THEN
          hi = mid
        ELSE
          lo = mid + 1
        ENDIF
      ENDDO
      jGlobal = lo
      IF ( jGlobal.GT.1 ) THEN
        IF ( ABS(yOwner-bomMapYFace(jGlobal-1))
     &       .LE.bomMapTol ) yOwner=bomMapYFace(jGlobal-1)
      ENDIF
      IF ( jGlobal.LT.Ny ) THEN
        IF ( ABS(yOwner-bomMapYFace(jGlobal)).LE.bomMapTol ) THEN
          yOwner = bomMapYFace(jGlobal)
          jGlobal = jGlobal + 1
        ENDIF
      ENDIF

      IF ( iGlobal.LT.1 .OR. iGlobal.GT.Nx .OR.
     &     jGlobal.LT.1 .OR. jGlobal.GT.Ny ) RETURN
      tileX = (iGlobal-1)/sNx
      tileY = (jGlobal-1)/sNy
      procX = tileX/nSx
      procY = tileY/nSy
      ownerBi = MOD(tileX,nSx) + 1
      ownerBj = MOD(tileY,nSy) + 1
      expectedXLo = 1 + procX*nSx*sNx
      expectedYLo = 1 + procY*nSy*sNy

#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        DO rankIndex=1,nPx*nPy
          IF ( mpi_myXGlobalLo(rankIndex).EQ.expectedXLo .AND.
     &         mpi_myYGlobalLo(rankIndex).EQ.expectedYLo ) THEN
            IF ( ownerRank.NE.-1 ) RETURN
            ownerRank = rankIndex - 1
          ENDIF
        ENDDO
      ELSE
#endif
        IF ( expectedXLo.EQ.myXGlobalLo .AND.
     &       expectedYLo.EQ.myYGlobalLo ) ownerRank = myProcId
#ifdef ALLOW_USE_MPI
      ENDIF
#endif
      IF ( ownerRank.LT.0 .OR. ownerRank.GE.nPx*nPy ) RETURN

      sourceTileX = (myXGlobalLo-1)/sNx + sourceBi - 1
      sourceTileY = (myYGlobalLo-1)/sNy + sourceBj - 1
      dxTile = ABS(tileX-sourceTileX)
      nTileX = nPx*nSx
      IF ( bomMapPeriodicX ) dxTile = MIN(dxTile,nTileX-dxTile)
      dyTile = ABS(tileY-sourceTileY)
      hopCount = MAX(dxTile,dyTile)
      IF ( hopCount.LT.0 ) RETURN

      isValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END
