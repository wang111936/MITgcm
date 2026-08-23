#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_FIELDS( myThid )

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
      INTEGER bi, bj, i, j, k, gi, gj
      INTEGER nFail, globalFail, originalMax
      INTEGER haloCount, globalHaloCount
      INTEGER dryCount, globalDryCount
      _RL rawU, rawV, uCenter, vCenter
      _RL expectedEast, expectedNorth, tol
      LOGICAL isF01, isF02, isOwnerCell
      LOGICAL sideHalo, insideGlobal, checkPoint, isDry

      nFail = 0
      haloCount = 0
      dryCount = 0
      tol = 4096. _d 0*EPSILON(oneRL)*100. _d 0
      isF01 = the_run_name.EQ.'P1-F01-UNIFORM'
      isF02 = the_run_name.EQ.'P1-F02-ROTATED'
      CALL BOM_VERIFY_FIELD_ASSERT( isF01 .OR. isF02,
     &     'recognized field scenario', nFail, myThid )
      CALL BOM_VERIFY_FIELD_ASSERT( Nr.GE.2,
     &     'multi-level model build', nFail, myThid )

C--   Deterministic initialization and zero-particle return.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          CALL BOM_VERIFY_FIELD_ASSERT(
     &         bomGridUWork(i,j,1,bi,bj).EQ.0. _d 0 .AND.
     &         bomGridVWork(i,j,1,bi,bj).EQ.0. _d 0 .AND.
     &         bomGridVEast(i,j,1,bi,bj).EQ.0. _d 0 .AND.
     &         bomGridVNorth(i,j,1,bi,bj).EQ.0. _d 0,
     &         'deterministic field zero', nFail, myThid )
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      originalMax = bomMaxParticles
      bomMaxParticles = 0
      bomFieldsReady = .FALSE.
      bomFieldTime = -7. _d 0
      bomFieldIter = -7
      CALL BOM_MAIN( 99. _d 0, 3, myThid )
      CALL BOM_VERIFY_FIELD_ASSERT(
     &     .NOT.bomFieldsReady .AND.
     &     bomFieldTime.EQ.-7. _d 0 .AND. bomFieldIter.EQ.-7,
     &     'zero-particle BOM_MAIN return', nFail, myThid )

C--   Populate all face inputs consistently.  F02 gives non-owner halo
C     angles a different rotation so scalar exchange is observable.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          gi = myXGlobalLo - 1 + (bi-1)*sNx + i
          gj = myYGlobalLo - 1 + (bj-1)*sNy + j
          isOwnerCell = i.GE.1 .AND. i.LE.sNx
     &              .AND. j.GE.1 .AND. j.LE.sNy
          IF ( isF01 ) THEN
            rawU = 2.5 _d 0
            rawV = -1.25 _d 0
            angleCosC(i,j,bi,bj) = 1.
            angleSinC(i,j,bi,bj) = 0.
            maskC(i,j,1,bi,bj) = 1.
          ELSE
            rawU = 10. _d 0 + 2. _d 0*DFLOAT(gi)
     &                         + 3. _d 0*DFLOAT(gj)
            rawV = -5. _d 0 + 4. _d 0*DFLOAT(gi)
     &                         - 2. _d 0*DFLOAT(gj)
            isDry = gi.EQ.5 .AND. gj.EQ.4
            IF ( isDry ) THEN
              maskC(i,j,1,bi,bj) = 0.
            ELSE
              maskC(i,j,1,bi,bj) = 1.
            ENDIF
            IF ( isOwnerCell ) THEN
              angleCosC(i,j,bi,bj) = 0.
              angleSinC(i,j,bi,bj) = 1.
            ELSE
              angleCosC(i,j,bi,bj) = 0.6
              angleSinC(i,j,bi,bj) = 0.8
            ENDIF
          ENDIF
          DO k=1,Nr
            uVel(i,j,k,bi,bj) = 0. _d 0
            vVel(i,j,k,bi,bj) = 0. _d 0
          ENDDO
          uVel(i,j,1,bi,bj) = rawU
          vVel(i,j,1,bi,bj) = rawV
          uVel(i,j,2,bi,bj) = 1000. _d 0 + DFLOAT(gi)
          vVel(i,j,2,bi,bj) = -1000. _d 0 - DFLOAT(gj)
          bomGridUWork(i,j,1,bi,bj) = -901. _d 0
          bomGridVWork(i,j,1,bi,bj) = -902. _d 0
          bomGridVEast(i,j,1,bi,bj) = -903. _d 0
          bomGridVNorth(i,j,1,bi,bj) = -904. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      bomMaxParticles = 1
      CALL BOM_MAIN( 123.5 _d 0, 7, myThid )
      bomMaxParticles = originalMax
      CALL BOM_VERIFY_FIELD_ASSERT(
     &     bomFieldsReady .AND.
     &     bomFieldTime.EQ.123.5 _d 0 .AND. bomFieldIter.EQ.7,
     &     'field metadata published last', nFail, myThid )

C--   Check owner cells and internal side halos.  Halo expectations use
C     the owner rotation, not the deliberately different halo angle.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          gi = myXGlobalLo - 1 + (bi-1)*sNx + i
          gj = myYGlobalLo - 1 + (bj-1)*sNy + j
          isOwnerCell = i.GE.1 .AND. i.LE.sNx
     &              .AND. j.GE.1 .AND. j.LE.sNy
          sideHalo = ((i.LT.1 .OR. i.GT.sNx) .AND.
     &                j.GE.1 .AND. j.LE.sNy) .OR.
     &               ((j.LT.1 .OR. j.GT.sNy) .AND.
     &                i.GE.1 .AND. i.LE.sNx)
          insideGlobal = gi.GE.1 .AND. gi.LE.Nx
     &               .AND. gj.GE.1 .AND. gj.LE.Ny
          checkPoint = isOwnerCell .OR.
     &                 (sideHalo .AND. insideGlobal)
          IF ( checkPoint ) THEN
            IF ( sideHalo .AND. insideGlobal )
     &           haloCount = haloCount + 1
            IF ( isF01 ) THEN
              rawU = 2.5 _d 0
              rawV = -1.25 _d 0
              expectedEast = rawU
              expectedNorth = rawV
            ELSE
              rawU = 10. _d 0 + 2. _d 0*DFLOAT(gi)
     &                           + 3. _d 0*DFLOAT(gj)
              rawV = -5. _d 0 + 4. _d 0*DFLOAT(gi)
     &                           - 2. _d 0*DFLOAT(gj)
              uCenter = 11. _d 0 + 2. _d 0*DFLOAT(gi)
     &                              + 3. _d 0*DFLOAT(gj)
              vCenter = -6. _d 0 + 4. _d 0*DFLOAT(gi)
     &                              - 2. _d 0*DFLOAT(gj)
              isDry = gi.EQ.5 .AND. gj.EQ.4
              IF ( isDry ) THEN
                expectedEast = 0. _d 0
                expectedNorth = 0. _d 0
                dryCount = dryCount + 1
              ELSE
                expectedEast = -vCenter
                expectedNorth = uCenter
              ENDIF
            ENDIF
            CALL BOM_VERIFY_FIELD_ASSERT(
     &           ABS(bomGridUWork(i,j,1,bi,bj)-rawU).LE.tol,
     &           'surface U work copy', nFail, myThid )
            CALL BOM_VERIFY_FIELD_ASSERT(
     &           ABS(bomGridVWork(i,j,1,bi,bj)-rawV).LE.tol,
     &           'surface V work copy', nFail, myThid )
            CALL BOM_VERIFY_FIELD_ASSERT(
     &           ABS(bomGridVEast(i,j,1,bi,bj)
     &               -expectedEast).LE.tol,
     &           'east rotation/mask/halo', nFail, myThid )
            CALL BOM_VERIFY_FIELD_ASSERT(
     &           ABS(bomGridVNorth(i,j,1,bi,bj)
     &               -expectedNorth).LE.tol,
     &           'north rotation/mask/halo', nFail, myThid )
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Restore the zero-step model state after the focused assertions.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          angleCosC(i,j,bi,bj) = 1.
          angleSinC(i,j,bi,bj) = 0.
          maskC(i,j,1,bi,bj) = 1.
          DO k=1,Nr
            uVel(i,j,k,bi,bj) = 0. _d 0
            vVel(i,j,k,bi,bj) = 0. _d 0
          ENDDO
          bomGridUWork(i,j,1,bi,bj) = 0. _d 0
          bomGridVWork(i,j,1,bi,bj) = 0. _d 0
          bomGridVEast(i,j,1,bi,bj) = 0. _d 0
          bomGridVNorth(i,j,1,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      bomFieldsReady = .FALSE.
      bomFieldTime = 0. _d 0
      bomFieldIter = 0

      globalHaloCount = haloCount
      globalDryCount = dryCount
      CALL GLOBAL_SUM_INT( globalHaloCount, myThid )
      CALL GLOBAL_SUM_INT( globalDryCount, myThid )
      CALL BOM_VERIFY_FIELD_ASSERT( globalHaloCount.GT.0,
     &     'internal scalar halo coverage', nFail, myThid )
      IF ( isF02 ) THEN
        CALL BOM_VERIFY_FIELD_ASSERT( globalDryCount.GT.0,
     &       'dry-cell coverage', nFail, myThid )
      ENDIF
      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I6)')
     &         'BOM_VERIFY_FIELDS: failed assertions=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_FIELDS'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        IF ( isF01 ) THEN
          WRITE(msgBuf,'(A)')
     &         'P1-F01 PASS: uniform C-grid surface fields'
        ELSE
          WRITE(msgBuf,'(A)')
     &         'P1-F02 PASS: rotation, mask, and scalar halos'
        ENDIF
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_FIELD_ASSERT(
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
        IF ( nFail.LT.12 ) THEN
          WRITE(msgBuf,'(2A)') 'BOM_VERIFY_FIELDS: FAIL: ', label
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        nFail = nFail + 1
      ENDIF

      RETURN
      END
