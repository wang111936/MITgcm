#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_STATE

C !INTERFACE:
      SUBROUTINE BOM_INIT_STATE( myThid )

C !DESCRIPTION:
C     Reset owner slots and Phase-1.3 surface fields deterministically.
C     Valid records later occupy 1:bomNPartTile on each tile.

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
      INTEGER bi, bj, i, j, ip

      _BEGIN_MASTER(myThid)
      bomFieldsReady = .FALSE.
      bomFieldTime = 0. _d 0
      bomWindFieldTime = 0. _d 0
      bomFieldIter = 0
      bomWindFieldIter = 0
      bomNPartExpected = 0
      DO bj=1,nSy
       DO bi=1,nSx
        bomNPartTile(bi,bj) = 0
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomGridUWork(i,j,1,bi,bj) = 0. _d 0
          bomGridVWork(i,j,1,bi,bj) = 0. _d 0
          bomGridVEast(i,j,1,bi,bj) = 0. _d 0
          bomGridVNorth(i,j,1,bi,bj) = 0. _d 0
          bomGridWindEast(i,j,1,bi,bj) = 0. _d 0
          bomGridWindNorth(i,j,1,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
        DO ip=1,bomMaxPartTile
          bomId(ip,bi,bj)          = 0
          bomStatus(ip,bi,bj)      = BOM_UNUSED
          bomX(ip,bi,bj)           = 0. _d 0
          bomY(ip,bi,bj)           = 0. _d 0
          bomReleaseTime(ip,bi,bj) = 0. _d 0
          bomAge(ip,bi,bj)         = 0. _d 0
          bomI(ip,bi,bj)           = 0. _d 0
          bomJ(ip,bi,bj)           = 0. _d 0
          bomVEast(ip,bi,bj)       = 0. _d 0
          bomVNorth(ip,bi,bj)      = 0. _d 0
          bomWindEast(ip,bi,bj)    = 0. _d 0
          bomWindNorth(ip,bi,bj)   = 0. _d 0
          bomDriftEast(ip,bi,bj)   = 0. _d 0
          bomDriftNorth(ip,bi,bj)  = 0. _d 0
        ENDDO
       ENDDO
      ENDDO
      _END_MASTER(myThid)
      _BARRIER
#endif

      RETURN
      END
