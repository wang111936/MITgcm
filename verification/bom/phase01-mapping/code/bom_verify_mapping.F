#include "BOM_OPTIONS.h"

C---+----1----2----3----4----5----6----7-|--+----|
      SUBROUTINE BOM_VERIFY_MAPPING( myThid )

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
      INTEGER bi, bj, ownerCount, ownerBi, ownerBj, nFail
      INTEGER refBi, refBj
      _RL xx, yy, xMap, ix, jy, xBack, yBack, tol
      _RL refI, refJ
      LOGICAL isOwner, hasStencil, isValid, isInside

      nFail = 0
      tol = 256. _d 0*EPSILON(oneRL)
     &    *MAX(oneRL,ABS(bomMapXHi),ABS(bomMapYHi))

      IF ( usingCartesianGrid ) THEN
C--     Interior point and analytic fractional indices.
        xx = xG(2,1,1,1)
     &     + 0.3 _d 0*(xG(3,1,1,1)-xG(2,1,1,1))
        yy = yG(1,2,1,1)
     &     + 0.7 _d 0*(yG(1,3,1,1)-yG(1,2,1,1))
        CALL BOM_MAP_XY2IJLOCAL(
     &       xx, yy, 1, 1, xMap, ix, jy,
     &       isOwner, hasStencil, myThid )
        CALL BOM_VERIFY_ASSERT( isOwner .AND. hasStencil,
     &       'M01 interior owner/stencil', nFail, myThid )
        CALL BOM_VERIFY_ASSERT(
     &       ABS(ix-1.8 _d 0).LE.tol .AND.
     &       ABS(jy-2.2 _d 0).LE.tol,
     &       'M01 interior analytic ij', nFail, myThid )
        CALL BOM_MAP_IJLOCAL2XY(
     &       ix, jy, 1, 1, xBack, yBack, isValid, myThid )
        CALL BOM_VERIFY_ASSERT( isValid .AND.
     &       ABS(xBack-xx).LE.tol .AND. ABS(yBack-yy).LE.tol,
     &       'M01 interior round trip', nFail, myThid )

C--     A face remains owner-local and maps to a half index.
        xx = xG(2,1,1,1)
        yy = halfRL*(yG(1,2,1,1)+yG(1,3,1,1))
        CALL BOM_MAP_XY2IJLOCAL(
     &       xx, yy, 1, 1, xMap, ix, jy,
     &       isOwner, hasStencil, myThid )
        CALL BOM_VERIFY_ASSERT( isOwner .AND.
     &       ABS(ix-1.5 _d 0).LE.tol .AND.
     &       ABS(jy-2.0 _d 0).LE.tol,
     &       'M01 face half index', nFail, myThid )

C--     The shared internal corner belongs only to the north-east tile.
        xx = xG(sNx+1,1,1,1)
        yy = yG(1,sNy+1,1,1)
        ownerCount = 0
        ownerBi = 0
        ownerBj = 0
        DO bj=1,nSy
         DO bi=1,nSx
          CALL BOM_MAP_XY2IJLOCAL(
     &         xx, yy, bi, bj, xMap, ix, jy,
     &         isOwner, hasStencil, myThid )
          IF ( isOwner ) THEN
            ownerCount = ownerCount + 1
            ownerBi = bi
            ownerBj = bj
          ENDIF
         ENDDO
        ENDDO
        CALL BOM_VERIFY_ASSERT( ownerCount.EQ.1 .AND.
     &       ownerBi.EQ.2 .AND. ownerBj.EQ.2,
     &       'M01 half-open internal corner owner', nFail, myThid )

C--     Negative fractional overlap exercises mathematical floor.
        xx = xG(0,1,2,2)
     &     + 0.25 _d 0*(xG(1,1,2,2)-xG(0,1,2,2))
        yy = yG(1,0,2,2)
     &     + 0.25 _d 0*(yG(1,1,2,2)-yG(1,0,2,2))
        CALL BOM_MAP_XY2IJLOCAL(
     &       xx, yy, 2, 2, xMap, ix, jy,
     &       isOwner, hasStencil, myThid )
        CALL BOM_VERIFY_ASSERT( .NOT.isOwner .AND. hasStencil .AND.
     &       ABS(ix+0.25 _d 0).LE.tol .AND.
     &       ABS(jy+0.25 _d 0).LE.tol,
     &       'M01 negative overlap valid floor', nFail, myThid )
        CALL BOM_MAP_IJLOCAL2XY(
     &       ix, jy, 2, 2, xBack, yBack, isValid, myThid )
        CALL BOM_VERIFY_ASSERT( isValid .AND.
     &       ABS(xBack-xx).LE.tol .AND. ABS(yBack-yy).LE.tol,
     &       'M01 negative overlap round trip', nFail, myThid )

        xx = xG(-1,1,2,2)
     &     + 0.25 _d 0*(xG(0,1,2,2)-xG(-1,1,2,2))
        CALL BOM_MAP_XY2IJLOCAL(
     &       xx, yy, 2, 2, xMap, ix, jy,
     &       isOwner, hasStencil, myThid )
        CALL BOM_VERIFY_ASSERT( .NOT.hasStencil .AND.
     &       ABS(ix+1.25 _d 0).LE.tol,
     &       'M01 floor rejects lower missing stencil', nFail, myThid )

        CALL BOM_NORMALIZE_X(
     &       bomMapXHi, xMap, isInside, myThid )
        CALL BOM_VERIFY_ASSERT( .NOT.isInside .AND.
     &       xMap.EQ.bomMapXHi,
     &       'M01 Cartesian upper bound is open', nFail, myThid )

        IF ( nFail.EQ.0 ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-M01 PASS: Cartesian mapping and floor semantics'
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                        SQUEEZE_RIGHT, myThid )
        ENDIF

      ELSEIF ( usingSphericalPolarGrid ) THEN
        IF ( bomMapPeriodicX ) THEN
          CALL BOM_NORMALIZE_X(
     &         bomMapXLo-360. _d 0, xMap, isInside, myThid )
          CALL BOM_VERIFY_ASSERT( isInside .AND.
     &         ABS(xMap-bomMapXLo).LE.tol,
     &         'M02 global xLo-360 normalization', nFail, myThid )
          CALL BOM_NORMALIZE_X(
     &         bomMapXHi, xMap, isInside, myThid )
          CALL BOM_VERIFY_ASSERT( isInside .AND.
     &         ABS(xMap-bomMapXLo).LE.tol,
     &         'M02 global xHi normalization', nFail, myThid )
          CALL BOM_NORMALIZE_X(
     &         HUGE(oneRL), xMap, isInside, myThid )
          CALL BOM_VERIFY_ASSERT( isInside .AND.
     &         xMap.GE.bomMapXLo .AND. xMap.LT.bomMapXHi,
     &         'M02 huge finite longitude normalization',
     &         nFail, myThid )
          CALL BOM_NORMALIZE_X(
     &         -HUGE(oneRL), xMap, isInside, myThid )
          CALL BOM_VERIFY_ASSERT( isInside .AND.
     &         xMap.GE.bomMapXLo .AND. xMap.LT.bomMapXHi,
     &         'M02 negative huge longitude normalization',
     &         nFail, myThid )

          xx = bomMapXLo + 0.37 _d 0*bomMapXPeriod
          yy = bomMapYLo + 0.63 _d 0*(bomMapYHi-bomMapYLo)
          CALL BOM_VERIFY_OWNER(
     &         xx, yy, ownerCount, refBi, refBj,
     &         refI, refJ, myThid )
          CALL BOM_VERIFY_ASSERT( ownerCount.EQ.1 .AND.
     &         ABS(yy).GT.tol,
     &         'M02 global nonzero-latitude owner', nFail, myThid )
          CALL BOM_VERIFY_OWNER(
     &         xx+360. _d 0, yy, ownerCount, ownerBi, ownerBj,
     &         ix, jy, myThid )
          CALL BOM_VERIFY_ASSERT( ownerCount.EQ.1 .AND.
     &         ownerBi.EQ.refBi .AND. ownerBj.EQ.refBj .AND.
     &         ABS(ix-refI).LE.tol .AND. ABS(jy-refJ).LE.tol,
     &         'M02 +360 owner equivalence', nFail, myThid )
          CALL BOM_VERIFY_OWNER(
     &         xx-360. _d 0, yy, ownerCount, ownerBi, ownerBj,
     &         ix, jy, myThid )
          CALL BOM_VERIFY_ASSERT( ownerCount.EQ.1 .AND.
     &         ownerBi.EQ.refBi .AND. ownerBj.EQ.refBj .AND.
     &         ABS(ix-refI).LE.tol .AND. ABS(jy-refJ).LE.tol,
     &         'M02 -360 owner equivalence', nFail, myThid )
          CALL BOM_MAP_IJLOCAL2XY(
     &         refI, refJ, refBi, refBj,
     &         xBack, yBack, isValid, myThid )
          CALL BOM_VERIFY_ASSERT( isValid .AND.
     &         ABS(xBack-xx).LE.tol .AND. ABS(yBack-yy).LE.tol,
     &         'M02 global canonical round trip', nFail, myThid )
          IF ( nFail.EQ.0 ) THEN
            WRITE(msgBuf,'(A)')
     &           'P1-M02 GLOBAL PASS: 360-degree normalization'
            CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                          SQUEEZE_RIGHT, myThid )
          ENDIF
        ELSE
          CALL BOM_NORMALIZE_X(
     &         bomMapXLo+360. _d 0, xMap, isInside, myThid )
          CALL BOM_VERIFY_ASSERT( .NOT.isInside .AND.
     &         xMap.EQ.bomMapXLo+360. _d 0,
     &         'M02 regional longitude does not wrap', nFail, myThid )
          CALL BOM_NORMALIZE_X(
     &         bomMapXHi, xMap, isInside, myThid )
          CALL BOM_VERIFY_ASSERT( .NOT.isInside .AND.
     &         xMap.EQ.bomMapXHi,
     &         'M02 regional upper bound is open', nFail, myThid )

          xx = bomMapXLo + 0.41 _d 0*(bomMapXHi-bomMapXLo)
          yy = bomMapYLo + 0.59 _d 0*(bomMapYHi-bomMapYLo)
          CALL BOM_VERIFY_OWNER(
     &         xx, yy, ownerCount, refBi, refBj,
     &         refI, refJ, myThid )
          CALL BOM_VERIFY_ASSERT( ownerCount.EQ.1 .AND.
     &         ABS(yy).GT.tol,
     &         'M02 regional nonzero-latitude owner', nFail, myThid )
          CALL BOM_MAP_IJLOCAL2XY(
     &         refI, refJ, refBi, refBj,
     &         xBack, yBack, isValid, myThid )
          CALL BOM_VERIFY_ASSERT( isValid .AND.
     &         ABS(xBack-xx).LE.tol .AND. ABS(yBack-yy).LE.tol,
     &         'M02 regional round trip', nFail, myThid )
          IF ( nFail.EQ.0 ) THEN
            WRITE(msgBuf,'(A)')
     &           'P1-M02 REGIONAL PASS: no longitude wrapping'
            CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                          SQUEEZE_RIGHT, myThid )
          ENDIF
        ENDIF
      ENDIF

      IF ( nFail.GE.1 ) THEN
        WRITE(msgBuf,'(A,I5)')
     &       'BOM_VERIFY_MAPPING: failed assertions=', nFail
        CALL PRINT_ERROR( msgBuf, myThid )
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_MAPPING'
      ENDIF
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----2----3----4----5----6----7-|--+----|
      SUBROUTINE BOM_VERIFY_OWNER(
     I                 xx, yy,
     O                 ownerCount, ownerBi, ownerBj, ownerI, ownerJ,
     I                 myThid )

      IMPLICIT NONE
#include "SIZE.h"
      _RL xx, yy, ownerI, ownerJ
      INTEGER ownerCount, ownerBi, ownerBj, myThid

#ifdef ALLOW_BOM
      INTEGER bi, bj
      _RL xMap, ix, jy
      LOGICAL isOwner, hasStencil
#endif

      ownerCount = 0
      ownerBi = 0
      ownerBj = 0
      ownerI = 0. _d 0
      ownerJ = 0. _d 0
#ifdef ALLOW_BOM
      DO bj=1,nSy
       DO bi=1,nSx
        CALL BOM_MAP_XY2IJLOCAL(
     &       xx, yy, bi, bj, xMap, ix, jy,
     &       isOwner, hasStencil, myThid )
        IF ( isOwner ) THEN
          ownerCount = ownerCount + 1
          ownerBi = bi
          ownerBj = bj
          ownerI = ix
          ownerJ = jy
        ENDIF
       ENDDO
      ENDDO
#endif

      RETURN
      END

C---+----1----2----3----4----5----6----7-|--+----|
      SUBROUTINE BOM_VERIFY_ASSERT(
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
        nFail = nFail + 1
        WRITE(msgBuf,'(2A)') 'BOM_VERIFY_MAPPING: FAIL: ', label
        CALL PRINT_ERROR( msgBuf, myThid )
      ENDIF

      RETURN
      END
