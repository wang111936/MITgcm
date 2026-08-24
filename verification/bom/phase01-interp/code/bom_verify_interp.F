#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_INTERP( myThid )

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
      INTEGER bi, bj, i, j, nFail, globalFail
      INTEGER caseCount, globalCaseCount
      INTEGER*8 infBits
      _RL infValue
      _RL valueEast, valueNorth, wetWeight
      _RL expectedEast, expectedNorth, originalWetMin, tol
      LOGICAL isValid, isFull, isPartial, isN05
      EQUIVALENCE ( infBits, infValue )
      DATA infBits / Z'7FF0000000000000' /

      nFail = 0
      caseCount = 0
      tol = 4096. _d 0*EPSILON(oneRL)*100. _d 0
      isFull = the_run_name.EQ.'P1-F03-FULL'
      isPartial = the_run_name.EQ.'P1-F03-PARTIAL'
      isN05 = the_run_name.EQ.'P1-N05-INVALID'
      CALL BOM_VERIFY_INTERP_ASSERT(
     &     isFull .OR. isPartial .OR. isN05,
     &     'recognized interpolation scenario', nFail, myThid )

      originalWetMin = bomWetWeightMin
      bomWetWeightMin = 0.5 _d 0
      bomFieldsReady = .TRUE.

C--   Start each local field and mask from a finite state.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          maskC(i,j,1,bi,bj) = 1.
          bomGridVEast(i,j,1,bi,bj) =
     &         10. _d 0 + 2. _d 0*DFLOAT(i)
     &                   - 3. _d 0*DFLOAT(j)
          bomGridVNorth(i,j,1,bi,bj) =
     &         -4. _d 0 + 0.5 _d 0*DFLOAT(i)
     &                   + 4. _d 0*DFLOAT(j)
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      IF ( isFull ) THEN
C--     A negative fractional index proves floor in overlap.
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            bomGridVEast(i,j,1,bi,bj) = 3.25 _d 0
            bomGridVNorth(i,j,1,bi,bj) = -7.5 _d 0
           ENDDO
          ENDDO
          CALL BOM_INTERP_WET_PAIR(
     I         -0.25 _d 0, -0.25 _d 0, bi, bj,
     I         bomGridVEast, bomGridVNorth,
     O         valueEast, valueNorth, wetWeight, isValid,
     I         myThid )
          CALL BOM_VERIFY_INTERP_ASSERT( isValid,
     &         'full constant valid', nFail, myThid )
          CALL BOM_VERIFY_INTERP_ASSERT(
     &         ABS(valueEast-3.25 _d 0).LE.tol .AND.
     &         ABS(valueNorth+7.5 _d 0).LE.tol .AND.
     &         ABS(wetWeight-oneRL).LE.tol,
     &         'full constant and negative floor', nFail, myThid )

C--       A fully wet affine C-point pair must interpolate analytically.
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            bomGridVEast(i,j,1,bi,bj) =
     &           10. _d 0 + 2. _d 0*DFLOAT(i)
     &                     - 3. _d 0*DFLOAT(j)
            bomGridVNorth(i,j,1,bi,bj) =
     &           -4. _d 0 + 0.5 _d 0*DFLOAT(i)
     &                     + 4. _d 0*DFLOAT(j)
           ENDDO
          ENDDO
          CALL BOM_INTERP_WET_PAIR(
     I         2.25 _d 0, 1.75 _d 0, bi, bj,
     I         bomGridVEast, bomGridVNorth,
     O         valueEast, valueNorth, wetWeight, isValid,
     I         myThid )
          expectedEast = 10. _d 0 + 2. _d 0*2.25 _d 0
     &                                - 3. _d 0*1.75 _d 0
          expectedNorth = -4. _d 0 + 0.5 _d 0*2.25 _d 0
     &                                  + 4. _d 0*1.75 _d 0
          CALL BOM_VERIFY_INTERP_ASSERT( isValid,
     &         'full affine valid', nFail, myThid )
          CALL BOM_VERIFY_INTERP_ASSERT(
     &         ABS(valueEast-expectedEast).LE.tol .AND.
     &         ABS(valueNorth-expectedNorth).LE.tol .AND.
     &         ABS(wetWeight-oneRL).LE.tol,
     &         'full affine analytic values', nFail, myThid )
          caseCount = caseCount + 2
         ENDDO
        ENDDO

      ELSEIF ( isPartial ) THEN
C--     Only (1,1) and (2,2) are wet; their raw weights sum to 0.5.
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          maskC(1,1,1,bi,bj) = 1.
          maskC(2,1,1,bi,bj) = 0.
          maskC(1,2,1,bi,bj) = 0.
          maskC(2,2,1,bi,bj) = 1.
          bomGridVEast(1,1,1,bi,bj) = 2. _d 0
          bomGridVEast(2,1,1,bi,bj) = 1000. _d 0
          bomGridVEast(1,2,1,bi,bj) = -1000. _d 0
          bomGridVEast(2,2,1,bi,bj) = 10. _d 0
          bomGridVNorth(1,1,1,bi,bj) = -5. _d 0
          bomGridVNorth(2,1,1,bi,bj) = -2000. _d 0
          bomGridVNorth(1,2,1,bi,bj) = 2000. _d 0
          bomGridVNorth(2,2,1,bi,bj) = 7. _d 0
          CALL BOM_INTERP_WET_PAIR(
     I         1.25 _d 0, 1.5 _d 0, bi, bj,
     I         bomGridVEast, bomGridVNorth,
     O         valueEast, valueNorth, wetWeight, isValid,
     I         myThid )
          CALL BOM_VERIFY_INTERP_ASSERT( isValid,
     &         'partial exact-threshold valid', nFail, myThid )
          CALL BOM_VERIFY_INTERP_ASSERT(
     &         ABS(wetWeight-0.5 _d 0).LE.tol .AND.
     &         ABS(valueEast-4. _d 0).LE.tol .AND.
     &         ABS(valueNorth+2. _d 0).LE.tol,
     &         'partial shared normalized weights', nFail, myThid )
          caseCount = caseCount + 1
         ENDDO
        ENDDO

      ELSEIF ( isN05 ) THEN
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
C--       Unpublished fields must never be read.
          bomFieldsReady = .FALSE.
          CALL BOM_INTERP_WET_PAIR(
     I         1.25 _d 0, 1.5 _d 0, bi, bj,
     I         bomGridVEast, bomGridVNorth,
     O         valueEast, valueNorth, wetWeight, isValid,
     I         myThid )
          CALL BOM_VERIFY_INTERP_INVALID(
     I         valueEast, valueNorth, wetWeight, isValid,
     I         0. _d 0, 'unready fields', nFail, myThid )
          bomFieldsReady = .TRUE.

C--       Missing overlap stencils return invalid before access.
          CALL BOM_INTERP_WET_PAIR(
     I         DFLOAT(1-OLx)-0.25 _d 0, 1.5 _d 0, bi, bj,
     I         bomGridVEast, bomGridVNorth,
     O         valueEast, valueNorth, wetWeight, isValid,
     I         myThid )
          CALL BOM_VERIFY_INTERP_INVALID(
     I         valueEast, valueNorth, wetWeight, isValid,
     I         0. _d 0, 'missing low stencil', nFail, myThid )
          CALL BOM_INTERP_WET_PAIR(
     I         DFLOAT(sNx+OLx), 1.5 _d 0, bi, bj,
     I         bomGridVEast, bomGridVNorth,
     O         valueEast, valueNorth, wetWeight, isValid,
     I         myThid )
          CALL BOM_VERIFY_INTERP_INVALID(
     I         valueEast, valueNorth, wetWeight, isValid,
     I         0. _d 0, 'missing high stencil', nFail, myThid )

C--       Infinite coordinate and field values are rejected explicitly.
          CALL BOM_INTERP_WET_PAIR(
     I         infValue, 1.5 _d 0, bi, bj,
     I         bomGridVEast, bomGridVNorth,
     O         valueEast, valueNorth, wetWeight, isValid,
     I         myThid )
          CALL BOM_VERIFY_INTERP_INVALID(
     I         valueEast, valueNorth, wetWeight, isValid,
     I         0. _d 0, 'non-finite coordinate', nFail, myThid )
          CALL BOM_INTERP_WET_PAIR(
     I         HUGE(oneRL), 1.5 _d 0, bi, bj,
     I         bomGridVEast, bomGridVNorth,
     O         valueEast, valueNorth, wetWeight, isValid,
     I         myThid )
          CALL BOM_VERIFY_INTERP_INVALID(
     I         valueEast, valueNorth, wetWeight, isValid,
     I         0. _d 0, 'finite coordinate outside stencil',
     I         nFail, myThid )
          expectedEast = bomGridVEast(1,1,1,bi,bj)
          bomGridVEast(1,1,1,bi,bj) = infValue
          CALL BOM_INTERP_WET_PAIR(
     I         1.25 _d 0, 1.5 _d 0, bi, bj,
     I         bomGridVEast, bomGridVNorth,
     O         valueEast, valueNorth, wetWeight, isValid,
     I         myThid )
          CALL BOM_VERIFY_INTERP_INVALID(
     I         valueEast, valueNorth, wetWeight, isValid,
     I         0. _d 0, 'non-finite pair field', nFail, myThid )
          bomGridVEast(1,1,1,bi,bj) = expectedEast

C--       Preserve the actual wet weight when it is below the threshold.
          maskC(1,1,1,bi,bj) = 0.
          maskC(2,1,1,bi,bj) = 0.
          maskC(1,2,1,bi,bj) = 0.
          maskC(2,2,1,bi,bj) = 1.
          CALL BOM_INTERP_WET_PAIR(
     I         1.25 _d 0, 1.5 _d 0, bi, bj,
     I         bomGridVEast, bomGridVNorth,
     O         valueEast, valueNorth, wetWeight, isValid,
     I         myThid )
          CALL BOM_VERIFY_INTERP_INVALID(
     I         valueEast, valueNorth, wetWeight, isValid,
     I         0.125 _d 0, 'wet weight below threshold',
     I         nFail, myThid )
          caseCount = caseCount + 7
         ENDDO
        ENDDO

C--     An invalid tile index must return before any field access.
        CALL BOM_INTERP_WET_PAIR(
     I       1.25 _d 0, 1.5 _d 0, 0, 1,
     I       bomGridVEast, bomGridVNorth,
     O       valueEast, valueNorth, wetWeight, isValid,
     I       myThid )
        CALL BOM_VERIFY_INTERP_INVALID(
     I       valueEast, valueNorth, wetWeight, isValid,
     I       0. _d 0, 'invalid tile', nFail, myThid )
        caseCount = caseCount + 1
      ENDIF

C--   Restore the zero-step model state after the focused assertions.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          maskC(i,j,1,bi,bj) = 1.
          bomGridVEast(i,j,1,bi,bj) = 0. _d 0
          bomGridVNorth(i,j,1,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      bomFieldsReady = .FALSE.
      bomWetWeightMin = originalWetMin

      globalCaseCount = caseCount
      CALL GLOBAL_SUM_INT( globalCaseCount, myThid )
      CALL BOM_VERIFY_INTERP_ASSERT( globalCaseCount.GT.0,
     &     'scenario exercised assertions', nFail, myThid )
      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I6)')
     &         'BOM_VERIFY_INTERP: failed assertions=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_INTERP'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        IF ( isFull ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-F03 FULL PASS: constant and linear wet-pair fields'
        ELSEIF ( isPartial ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-F03 PARTIAL PASS: shared normalized wet weights'
        ELSE
          WRITE(msgBuf,'(A)')
     &         'P1-N05 PASS: invalid interpolation contracts'
        ENDIF
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_MAIN_DIAGNOSTIC( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "DYNVARS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      INTEGER myThid

#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, i, j, k, gi, gj, ip
      INTEGER nFail, globalFail, caseCount, globalCaseCount
      INTEGER originalMax
      INTEGER nBefore(nSx,nSy), statusBefore(nSx,nSy)
      INTEGER*8 idBefore(nSx,nSy)
      _RL xBefore(nSx,nSy), yBefore(nSx,nSy)
      _RL releaseBefore(nSx,nSy), ageBefore(nSx,nSy)
      _RL xx, yy, originalWetMin, tol
      LOGICAL coordValid, isLifecycle, isOutside, isWetFailure
      LOGICAL insideGlobal, wetPoint

      nFail = 0
      caseCount = 0
      tol = 4096. _d 0*EPSILON(oneRL)*100. _d 0
      isLifecycle = the_run_name.EQ.'P1-P12-LIFECYCLE'
      isOutside = the_run_name.EQ.'P1-N05-MAIN-OUTSIDE'
      isWetFailure = the_run_name.EQ.'P1-N05-MAIN-WET'
      CALL BOM_VERIFY_INTERP_ASSERT(
     &     isLifecycle .OR. isOutside .OR. isWetFailure,
     &     'recognized BOM_MAIN diagnostic scenario',
     &     nFail, myThid )

      originalMax = bomMaxParticles
      originalWetMin = bomWetWeightMin
      bomMaxParticles = 1
      bomWetWeightMin = 0.5 _d 0

C--   Populate exchange-consistent model fields and one record per tile.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          gi = myXGlobalLo - 1 + (bi-1)*sNx + i
          gj = myYGlobalLo - 1 + (bj-1)*sNy + j
          insideGlobal = gi.GE.1 .AND. gi.LE.Nx
     &               .AND. gj.GE.1 .AND. gj.LE.Ny
          wetPoint = .TRUE.
          IF ( isWetFailure ) THEN
            wetPoint = insideGlobal
     &           .AND. MOD(gi-1,sNx).EQ.2
     &           .AND. MOD(gj-1,sNy).EQ.1
          ENDIF
          IF ( wetPoint ) THEN
            maskC(i,j,1,bi,bj) = 1.
          ELSE
            maskC(i,j,1,bi,bj) = 0.
          ENDIF
          angleCosC(i,j,bi,bj) = 1.
          angleSinC(i,j,bi,bj) = 0.
          DO k=1,Nr
            uVel(i,j,k,bi,bj) = 0. _d 0
            vVel(i,j,k,bi,bj) = 0. _d 0
          ENDDO
          IF ( .NOT.isWetFailure ) THEN
            uVel(i,j,1,bi,bj) = 1.25 _d 0
            vVel(i,j,1,bi,bj) = -2.5 _d 0
          ENDIF
         ENDDO
        ENDDO

        CALL BOM_MAP_IJLOCAL2XY(
     I       2.25 _d 0, 1.5 _d 0, bi, bj,
     O       xx, yy, coordValid,
     I       myThid )
        CALL BOM_VERIFY_INTERP_ASSERT( coordValid,
     &       'diagnostic seed coordinate is valid', nFail, myThid )
        bomNPartTile(bi,bj) = 1
        ip = 1
        bomId(ip,bi,bj) = INT(myProcId,8)*1000000
     &                   + INT(100*bi+bj,8)
        bomStatus(ip,bi,bj) = BOM_ALIVE
        IF ( MOD(myProcId+bi+bj,2).EQ.0 )
     &       bomStatus(ip,bi,bj) = BOM_WAITING
        bomX(ip,bi,bj) = xx
        bomY(ip,bi,bj) = yy
        IF ( isOutside ) bomX(ip,bi,bj) = bomMapXHi + oneRL
        bomReleaseTime(ip,bi,bj) = 777. _d 0 + DFLOAT(bi+bj)
        bomAge(ip,bi,bj) = 12.5 _d 0 + DFLOAT(myProcId)
        bomI(ip,bi,bj) = -901. _d 0
        bomJ(ip,bi,bj) = -902. _d 0
        bomVEast(ip,bi,bj) = -903. _d 0
        bomVNorth(ip,bi,bj) = -904. _d 0

        nBefore(bi,bj) = bomNPartTile(bi,bj)
        idBefore(bi,bj) = bomId(ip,bi,bj)
        statusBefore(bi,bj) = bomStatus(ip,bi,bj)
        xBefore(bi,bj) = bomX(ip,bi,bj)
        yBefore(bi,bj) = bomY(ip,bi,bj)
        releaseBefore(bi,bj) = bomReleaseTime(ip,bi,bj)
        ageBefore(bi,bj) = bomAge(ip,bi,bj)
       ENDDO
      ENDDO

      CALL BOM_MAIN( 123.5 _d 0, 7, myThid )

      IF ( isLifecycle ) THEN
        DO bj=myByLo(myThid),myByHi(myThid)
         DO bi=myBxLo(myThid),myBxHi(myThid)
          ip = 1
          CALL BOM_VERIFY_INTERP_ASSERT(
     &         bomNPartTile(bi,bj).EQ.nBefore(bi,bj),
     &         'BOM_MAIN owner count bitwise invariant',
     &         nFail, myThid )
          CALL BOM_VERIFY_INTERP_ASSERT(
     &         bomId(ip,bi,bj).EQ.idBefore(bi,bj) .AND.
     &         bomStatus(ip,bi,bj).EQ.statusBefore(bi,bj),
     &         'BOM_MAIN ID and status bitwise invariant',
     &         nFail, myThid )
          CALL BOM_VERIFY_INTERP_ASSERT(
     &         bomX(ip,bi,bj).EQ.xBefore(bi,bj) .AND.
     &         bomY(ip,bi,bj).EQ.yBefore(bi,bj),
     &         'BOM_MAIN position bitwise invariant',
     &         nFail, myThid )
          CALL BOM_VERIFY_INTERP_ASSERT(
     &         bomReleaseTime(ip,bi,bj).EQ.releaseBefore(bi,bj)
     &         .AND. bomAge(ip,bi,bj).EQ.ageBefore(bi,bj),
     &         'BOM_MAIN release and age bitwise invariant',
     &         nFail, myThid )
          CALL BOM_VERIFY_INTERP_ASSERT(
     &         ABS(bomI(ip,bi,bj)-2.25 _d 0).LE.tol .AND.
     &         ABS(bomJ(ip,bi,bj)-1.5 _d 0).LE.tol,
     &         'BOM_MAIN mapping diagnostics', nFail, myThid )
          CALL BOM_VERIFY_INTERP_ASSERT(
     &         ABS(bomVEast(ip,bi,bj)-1.25 _d 0).LE.tol
     &         .AND. ABS(bomVNorth(ip,bi,bj)+2.5 _d 0).LE.tol,
     &         'BOM_MAIN velocity diagnostics', nFail, myThid )
          caseCount = caseCount + 1
         ENDDO
        ENDDO
      ELSE
C--     A negative scenario must have terminated inside production BOM_MAIN.
        CALL BOM_VERIFY_INTERP_ASSERT( .FALSE.,
     &       'invalid BOM_MAIN diagnostic returned', nFail, myThid )
      ENDIF

C--   Restore the zero-step verification state after a positive scenario.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        bomNPartTile(bi,bj) = 0
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          maskC(i,j,1,bi,bj) = 1.
          angleCosC(i,j,bi,bj) = 1.
          angleSinC(i,j,bi,bj) = 0.
          DO k=1,Nr
            uVel(i,j,k,bi,bj) = 0. _d 0
            vVel(i,j,k,bi,bj) = 0. _d 0
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      bomFieldsReady = .FALSE.
      bomFieldTime = 0. _d 0
      bomFieldIter = 0
      bomMaxParticles = originalMax
      bomWetWeightMin = originalWetMin

      globalCaseCount = caseCount
      CALL GLOBAL_SUM_INT( globalCaseCount, myThid )
      CALL BOM_VERIFY_INTERP_ASSERT( globalCaseCount.GT.0,
     &     'BOM_MAIN lifecycle exercised records', nFail, myThid )
      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I6)')
     &         'BOM_VERIFY_MAIN_DIAGNOSTIC: failed=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_MAIN_DIAGNOSTIC'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P1.2 LIFECYCLE PASS: non-moving production diagnostics'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_INTERP_INVALID(
     I                 valueEast, valueNorth, wetWeight, isValid,
     I                 expectedWet, label, nFail, myThid )

      IMPLICIT NONE
#include "EEPARAMS.h"
      _RL valueEast, valueNorth, wetWeight, expectedWet
      LOGICAL isValid
      CHARACTER*(*) label
      INTEGER nFail, myThid
      _RL tol

      tol = 4096. _d 0*EPSILON(oneRL)*100. _d 0
      CALL BOM_VERIFY_INTERP_ASSERT( .NOT.isValid,
     &     label, nFail, myThid )
      CALL BOM_VERIFY_INTERP_ASSERT(
     &     valueEast.EQ.0. _d 0 .AND.
     &     valueNorth.EQ.0. _d 0,
     &     'invalid pair returns zero values', nFail, myThid )
      CALL BOM_VERIFY_INTERP_ASSERT(
     &     ABS(wetWeight-expectedWet).LE.tol,
     &     'invalid pair wet-weight diagnostic', nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_INTERP_ASSERT(
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
        IF ( nFail.LT.16 ) THEN
          WRITE(msgBuf,'(2A)') 'BOM_VERIFY_INTERP: FAIL: ', label
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        nFail = nFail + 1
      ENDIF

      RETURN
      END
