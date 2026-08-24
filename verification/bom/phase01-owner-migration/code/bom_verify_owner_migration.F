#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_OWNER_MIGRATION( myThid )

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
      INTEGER bi, bj, ip, nFail, globalFail
      INTEGER localFound, globalFound
      INTEGER ownerRank, ownerBi, ownerBj, hopCount
      INTEGER*8 testId, xBits, yBits, releaseBits, ageBits
      _RL waterEast, waterNorth, ixSeed, jySeed
      _RL xSeed, ySeed, expectedX, expectedY, xOwner, yOwner
      _RL tol
      LOGICAL isHorizontal, isVertical, isCorner, isLargeId
      LOGICAL isSourceRank, putValid, locateValid

      nFail = 0
      localFound = 0
      tol = 65536. _d 0*EPSILON(oneRL)*MAX(oneRL,deltaTClock)
      isHorizontal = the_run_name.EQ.'P1-X01-H'
      isVertical = the_run_name.EQ.'P1-X01-V'
      isCorner = the_run_name.EQ.'P1-X01-C'
      isLargeId = the_run_name.EQ.'P1-X04-ID'
      CALL BOM_VERIFY_OWNER_ASSERT(
     &     isHorizontal .OR. isVertical .OR. isCorner .OR.
     &     isLargeId, 'recognized owner scenario', nFail, myThid )

      waterEast = 0. _d 0
      waterNorth = 0. _d 0
      ixSeed = 1.7 _d 0
      jySeed = 1.7 _d 0
      IF ( isHorizontal .OR. isLargeId ) THEN
        waterEast = 0.5 _d 0
        ixSeed = 4.35 _d 0
      ELSEIF ( isVertical ) THEN
        waterNorth = 0.4 _d 0
        jySeed = 3.35 _d 0
      ELSEIF ( isCorner ) THEN
        waterEast = 0.5 _d 0
        waterNorth = 0.4 _d 0
        ixSeed = 4.35 _d 0
        jySeed = 3.35 _d 0
      ENDIF

      IF ( isLargeId ) THEN
        testId = 9007199254740993_8
      ELSE
        testId = 4100000001_8
      ENDIF

      bomMaxParticles = 1
      bomNPartExpected = 1
      bomDeltaTTarget = 300. _d 0
      bomWetWeightMin = 0.5 _d 0
      bomAdvCFL = 0.5 _d 0
      bomLeewayWindCoeff = 0. _d 0
      bomWindSource = 'NONE'
      bomStokesSource = 'NONE'
      bomIntegrator = 'RK4'
      bomMaxHop = 8
      bomCheckEverySubstep = .TRUE.

      CALL BOM_VERIFY_OWNER_FILL_MODEL(
     I     waterEast, waterNorth, myThid )

C--   The global south-west tile is the common decomposition oracle.
      isSourceRank = myXGlobalLo.EQ.1 .AND. myYGlobalLo.EQ.1
      IF ( isSourceRank ) THEN
        bi = 1
        bj = 1
        bomNPartTile(bi,bj) = 1
        CALL BOM_VERIFY_OWNER_PUT(
     I       1, bi, bj, testId, ixSeed, jySeed,
     O       putValid, xSeed, ySeed,
     I       myThid )
        CALL BOM_VERIFY_OWNER_ASSERT( putValid,
     &       'source record accepted', nFail, myThid )
      ENDIF

C--   Compute the same physical oracle from global faces on every rank.
      IF ( ixSeed.EQ.4.35 _d 0 ) THEN
        xSeed = bomMapXFace(3) + 0.85 _d 0*
     &          (bomMapXFace(4)-bomMapXFace(3))
      ELSE
        xSeed = bomMapXFace(1) + 0.2 _d 0*
     &          (bomMapXFace(2)-bomMapXFace(1))
      ENDIF
      IF ( jySeed.EQ.3.35 _d 0 ) THEN
        ySeed = bomMapYFace(2) + 0.85 _d 0*
     &          (bomMapYFace(3)-bomMapYFace(2))
      ELSE
        ySeed = bomMapYFace(1) + 0.2 _d 0*
     &          (bomMapYFace(2)-bomMapYFace(1))
      ENDIF
      expectedX = xSeed + deltaTClock*waterEast
      expectedY = ySeed + deltaTClock*waterNorth

C--   Freeze the first nominal-substep owner before the lifecycle call.
      CALL BOM_LOCATE_OWNER(
     I     xSeed+300. _d 0*waterEast,
     I     ySeed+300. _d 0*waterNorth, 1, 1,
     O     xOwner, yOwner, ownerRank, ownerBi, ownerBj, hopCount,
     O     locateValid,
     I     myThid )
      CALL BOM_VERIFY_OWNER_ASSERT( locateValid,
     &     'first-substep destination located', nFail, myThid )
      IF ( isSourceRank ) THEN
        WRITE(msgBuf,'(A,4I8,A,2(1X,1PE24.16))')
     &       'P1-P14-PLAN rank/bi/bj/hop=',
     &       ownerRank, ownerBi, ownerBj, hopCount,
     &       ' xy=', xOwner, yOwner
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF

      CALL BOM_MAIN( deltaTClock, 1, myThid )

      CALL BOM_LOCATE_OWNER(
     I     expectedX, expectedY, 1, 1,
     O     xOwner, yOwner, ownerRank, ownerBi, ownerBj, hopCount,
     O     locateValid,
     I     myThid )
      CALL BOM_VERIFY_OWNER_ASSERT( locateValid,
     &     'expected destination located', nFail, myThid )

      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          IF ( bomId(ip,bi,bj).EQ.testId ) THEN
            localFound = localFound + 1
            CALL BOM_VERIFY_OWNER_ASSERT(
     &           myProcId.EQ.ownerRank .AND. bi.EQ.ownerBi .AND.
     &           bj.EQ.ownerBj,
     &           'record on unique expected owner', nFail, myThid )
            CALL BOM_VERIFY_OWNER_ASSERT(
     &           ABS(bomX(ip,bi,bj)-xOwner).LE.tol .AND.
     &           ABS(bomY(ip,bi,bj)-yOwner).LE.tol,
     &           'constant-flow final position', nFail, myThid )
            CALL BOM_VERIFY_OWNER_ASSERT(
     &           bomStatus(ip,bi,bj).EQ.BOM_ALIVE .AND.
     &           bomReleaseTime(ip,bi,bj).EQ.0. _d 0 .AND.
     &           bomAge(ip,bi,bj).EQ.deltaTClock+7. _d 0,
     &           'status release and age preserved', nFail, myThid )
            CALL BOM_VERIFY_OWNER_ASSERT(
     &           ABS(bomVEast(ip,bi,bj)-waterEast).LE.tol .AND.
     &           ABS(bomVNorth(ip,bi,bj)-waterNorth).LE.tol,
     &           'target-owner diagnostics refreshed', nFail, myThid )
            xBits = TRANSFER(bomX(ip,bi,bj),xBits)
            yBits = TRANSFER(bomY(ip,bi,bj),yBits)
            releaseBits = TRANSFER(
     &                    bomReleaseTime(ip,bi,bj),releaseBits)
            ageBits = TRANSFER(bomAge(ip,bi,bj),ageBits)
            WRITE(msgBuf,1000) 'P1-P14-STATE id=',
     &           bomId(ip,bi,bj), ' status=', bomStatus(ip,bi,bj),
     &           ' bits=', xBits, yBits, releaseBits, ageBits
            CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                          SQUEEZE_RIGHT, myThid )
          ENDIF
        ENDDO
       ENDDO
      ENDDO

      globalFound = localFound
      CALL GLOBAL_SUM_INT( globalFound, myThid )
      CALL BOM_VERIFY_OWNER_ASSERT( globalFound.EQ.1,
     &     'global owner and ID count conserved', nFail, myThid )
      CALL BOM_VERIFY_OWNER_ASSERT( hopCount.LE.bomMaxHop,
     &     'destination hop within limit', nFail, myThid )

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_VERIFY_OWNER_MIGRATION: failures=', globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_OWNER_MIGRATION'
      ENDIF

      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A,A,A,I8)')
     &       'P1.4 OWNER PASS: scenario=', the_run_name,
     &       ' global-count=', globalFound
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
 1000 FORMAT(A,I20,A,I3,A,4(1X,Z16.16))
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_OWNER_FILL_MODEL(
     I     waterEast, waterNorth, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "DYNVARS.h"
#include "GRID.h"

      _RL waterEast, waterNorth
      INTEGER myThid
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
          uVel(i,j,1,bi,bj) = waterEast
          vVel(i,j,1,bi,bj) = waterNorth
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_OWNER_PUT(
     I     ip, bi, bj, particleId, ixSeed, jySeed,
     O     isValid, xx, yy,
     I     myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      INTEGER ip, bi, bj, myThid
      INTEGER*8 particleId
      _RL ixSeed, jySeed, xx, yy, xMap, ix, jy
      LOGICAL isValid, coordValid, isOwner, hasStencil

      isValid = .FALSE.
      CALL BOM_MAP_IJLOCAL2XY(
     I     ixSeed, jySeed, bi, bj,
     O     xx, yy, coordValid,
     I     myThid )
      IF ( .NOT.coordValid ) RETURN
      CALL BOM_MAP_XY2IJLOCAL(
     I     xx, yy, bi, bj,
     O     xMap, ix, jy, isOwner, hasStencil,
     I     myThid )
      IF ( .NOT.isOwner .OR. .NOT.hasStencil ) RETURN
      bomId(ip,bi,bj) = particleId
      bomStatus(ip,bi,bj) = BOM_ALIVE
      bomX(ip,bi,bj) = xx
      bomY(ip,bi,bj) = yy
      bomReleaseTime(ip,bi,bj) = 0. _d 0
      bomAge(ip,bi,bj) = 7. _d 0
      bomI(ip,bi,bj) = ix
      bomJ(ip,bi,bj) = jy
      bomVEast(ip,bi,bj) = 0. _d 0
      bomVNorth(ip,bi,bj) = 0. _d 0
      bomWindEast(ip,bi,bj) = 0. _d 0
      bomWindNorth(ip,bi,bj) = 0. _d 0
      bomDriftEast(ip,bi,bj) = 0. _d 0
      bomDriftNorth(ip,bi,bj) = 0. _d 0
      isValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_OWNER_ASSERT(
     I     condition, label,
     U     nFail,
     I     myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"

      LOGICAL condition
      CHARACTER*(*) label
      INTEGER nFail, myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf

      IF ( .NOT.condition ) THEN
        nFail = nFail + 1
        WRITE(msgBuf,'(A,A)')
     &       'BOM_VERIFY_OWNER assertion: ', label
        CALL PRINT_ERROR( msgBuf, myThid )
      ENDIF

      RETURN
      END
