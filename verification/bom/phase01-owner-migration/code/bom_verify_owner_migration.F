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
      LOGICAL isPeriodic, isMulti, isCapacity
      LOGICAL isHop, isStencil, isTileCapacity
      LOGICAL isSourceRank, putValid, locateValid

      nFail = 0
      localFound = 0
      globalFound = 0
      tol = 65536. _d 0*EPSILON(oneRL)*MAX(oneRL,deltaTClock)
      isHorizontal = the_run_name.EQ.'P1-X01-H'
      isVertical = the_run_name.EQ.'P1-X01-V'
      isCorner = the_run_name.EQ.'P1-X01-C'
      isLargeId = the_run_name.EQ.'P1-X04-ID'
      isPeriodic = the_run_name.EQ.'P1-X02-P'
      isMulti = the_run_name.EQ.'P1-X03'
      isCapacity = the_run_name.EQ.'P1-N03B-CAP'
      isHop = the_run_name.EQ.'P1-X03-HOP'
      isStencil = the_run_name.EQ.'P1-X-STENCIL'
      isTileCapacity = the_run_name.EQ.'P1-N03B-TILE'
      CALL BOM_VERIFY_OWNER_ASSERT(
     &     isHorizontal .OR. isVertical .OR. isCorner .OR.
     &     isLargeId .OR. isPeriodic .OR. isMulti .OR.
     &     isCapacity .OR. isHop .OR. isStencil .OR.
     &     isTileCapacity,
     &     'recognized owner scenario', nFail, myThid )

      IF ( isPeriodic ) THEN
        CALL BOM_VERIFY_OWNER_PERIODIC(
     O       globalFound,
     U       nFail,
     I       myThid )
        GOTO 900
      ENDIF
      IF ( isHop ) THEN
        CALL BOM_VERIFY_OWNER_HOP(
     O       globalFound,
     U       nFail,
     I       myThid )
        GOTO 900
      ENDIF
      IF ( isTileCapacity ) THEN
        CALL BOM_VERIFY_OWNER_TILE_CAPACITY(
     O       globalFound,
     U       nFail,
     I       myThid )
        GOTO 900
      ENDIF
      IF ( isStencil ) THEN
        CALL BOM_VERIFY_OWNER_STENCIL(
     O       globalFound,
     U       nFail,
     I       myThid )
        GOTO 900
      ENDIF

      waterEast = 0. _d 0
      waterNorth = 0. _d 0
      ixSeed = 1.7 _d 0
      jySeed = 1.7 _d 0
      IF ( isHorizontal .OR. isLargeId .OR. isCapacity ) THEN
        waterEast = 0.5 _d 0
        ixSeed = 4.35 _d 0
      ELSEIF ( isMulti ) THEN
        waterEast = 0.9 _d 0
        ixSeed = 2.35 _d 0
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

      IF ( isCapacity ) THEN
        bomMaxParticles = 2
        bomNPartExpected = 2
      ELSE
        bomMaxParticles = 1
        bomNPartExpected = 1
      ENDIF
      bomDeltaTTarget = 300. _d 0
      bomWetWeightMin = 0.5 _d 0
      bomAdvCFL = 0.5 _d 0
      bomLeewayWindCoeff = 0. _d 0
      bomWindSource = 'NONE'
      bomStokesSource = 'NONE'
      bomIntegrator = 'RK4'
      IF ( isMulti ) THEN
        bomMaxHop = 1
      ELSE
        bomMaxHop = 8
      ENDIF
      bomCheckEverySubstep = .TRUE.

      CALL BOM_VERIFY_OWNER_FILL_MODEL(
     I     waterEast, waterNorth, myThid )

C--   The global south-west tile is the common decomposition oracle.
      isSourceRank = myXGlobalLo.EQ.1 .AND. myYGlobalLo.EQ.1
      IF ( isSourceRank ) THEN
        bi = 1
        bj = 1
        IF ( isCapacity ) THEN
          bomNPartTile(bi,bj) = 2
        ELSE
          bomNPartTile(bi,bj) = 1
        ENDIF
        CALL BOM_VERIFY_OWNER_PUT(
     I       1, bi, bj, testId, ixSeed, jySeed,
     O       putValid, xSeed, ySeed,
     I       myThid )
        CALL BOM_VERIFY_OWNER_ASSERT( putValid,
     &       'source record accepted', nFail, myThid )
        IF ( isCapacity ) THEN
          CALL BOM_VERIFY_OWNER_PUT(
     I         2, bi, bj, testId+1_8, ixSeed, jySeed,
     O         putValid, xSeed, ySeed,
     I         myThid )
          CALL BOM_VERIFY_OWNER_ASSERT( putValid,
     &         'second source record accepted', nFail, myThid )
        ENDIF
      ENDIF

C--   Compute the same physical oracle from global faces on every rank.
      IF ( ixSeed.EQ.4.35 _d 0 ) THEN
        xSeed = bomMapXFace(3) + 0.85 _d 0*
     &          (bomMapXFace(4)-bomMapXFace(3))
      ELSEIF ( ixSeed.EQ.2.35 _d 0 ) THEN
        xSeed = bomMapXFace(1) + 0.85 _d 0*
     &          (bomMapXFace(2)-bomMapXFace(1))
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
      IF ( .NOT.isMulti ) THEN
        CALL BOM_VERIFY_OWNER_ASSERT( hopCount.LE.bomMaxHop,
     &       'destination hop within limit', nFail, myThid )
      ENDIF

  900 CONTINUE
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
      SUBROUTINE BOM_VERIFY_OWNER_HOP(
     O     globalFound,
     U     nFail,
     I     myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      INTEGER globalFound, nFail, myThid
      INTEGER bi, bj
      INTEGER*8 testId
      _RL xSeed, ySeed
      LOGICAL isSourceRank, putValid

      testId = 4100000001_8
      globalFound = 0
      bomMaxParticles = 1
      bomNPartExpected = 1
      bomDeltaTTarget = 300. _d 0
      bomWetWeightMin = 0.5 _d 0
      bomAdvCFL = 0.5 _d 0
      bomLeewayWindCoeff = 0. _d 0
      bomWindSource = 'NONE'
      bomStokesSource = 'NONE'
      bomIntegrator = 'RK4'
      bomMaxHop = 1
      bomCheckEverySubstep = .TRUE.
      CALL BOM_VERIFY_OWNER_FILL_MODEL(
     I     0. _d 0, 0. _d 0, myThid )

C--   Move directly from global tile one to tile three: hop two.
      isSourceRank = myXGlobalLo.EQ.1 .AND. myYGlobalLo.EQ.1
      IF ( isSourceRank ) THEN
        bi = 1
        bj = 1
        bomNPartTile(bi,bj) = 1
        CALL BOM_VERIFY_OWNER_PUT(
     I       1, bi, bj, testId, 1.7 _d 0, 1.7 _d 0,
     O       putValid, xSeed, ySeed,
     I       myThid )
        CALL BOM_VERIFY_OWNER_ASSERT( putValid,
     &       'hop source record accepted', nFail, myThid )
        bomX(1,bi,bj) = bomMapXFace(5) + 0.2 _d 0*
     &       (bomMapXFace(6)-bomMapXFace(5))
      ENDIF

      CALL BOM_BUILD_FIELDS( 600. _d 0, 9, myThid )
      CALL BOM_PARTICLE_EXCHANGE( 600. _d 0, 9, 3, myThid )
      CALL BOM_VERIFY_OWNER_ASSERT( .FALSE.,
     &     'hop-limit exchange returned', nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_OWNER_TILE_CAPACITY(
     O     globalFound,
     U     nFail,
     I     myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      INTEGER globalFound, nFail, myThid
      INTEGER*8 testId
      _RL xSeed, ySeed
      LOGICAL isSourceRank, putValid

      testId = 4100000001_8
      globalFound = 0
      bomMaxParticles = 2
      bomNPartExpected = 2
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
     I     0. _d 0, 0. _d 0, myThid )

C--   One retained record plus one same-rank migrant must not truncate.
      isSourceRank = myXGlobalLo.EQ.1 .AND. myYGlobalLo.EQ.1
      IF ( isSourceRank ) THEN
        bomNPartTile(1,1) = 1
        CALL BOM_VERIFY_OWNER_PUT(
     I       1, 1, 1, testId, 1.7 _d 0, 1.7 _d 0,
     O       putValid, xSeed, ySeed,
     I       myThid )
        CALL BOM_VERIFY_OWNER_ASSERT( putValid,
     &       'tile-capacity source accepted', nFail, myThid )
        bomNPartTile(2,1) = 1
        CALL BOM_VERIFY_OWNER_PUT(
     I       1, 2, 1, testId+1_8, 1.7 _d 0, 1.7 _d 0,
     O       putValid, xSeed, ySeed,
     I       myThid )
        CALL BOM_VERIFY_OWNER_ASSERT( putValid,
     &       'tile-capacity target accepted', nFail, myThid )
        bomX(1,1,1) = bomMapXFace(sNx+1) + 0.2 _d 0*
     &       (bomMapXFace(sNx+2)-bomMapXFace(sNx+1))
      ENDIF

      CALL BOM_BUILD_FIELDS( 700. _d 0, 10, myThid )
      CALL BOM_PARTICLE_EXCHANGE( 700. _d 0, 10, 2, myThid )
      CALL BOM_VERIFY_OWNER_ASSERT( .FALSE.,
     &     'tile-capacity exchange returned', nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_OWNER_STENCIL(
     O     globalFound,
     U     nFail,
     I     myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      INTEGER globalFound, nFail, myThid
      INTEGER failStage, failCode
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      _RL x0, y0, x1, y1, ix, jy
      _RL oceanEast, oceanNorth, windEast, windNorth
      _RL driftEast, driftNorth, wetWeight, stageCFL
      LOGICAL isSourceRank, putValid, rkValid

      globalFound = 0
      bomMaxParticles = 1
      bomNPartExpected = 1
      bomDeltaTTarget = 300. _d 0
      bomWetWeightMin = 0.5 _d 0
C--   Verification override permits a trial beyond the supported CFL.
      bomAdvCFL = 10. _d 0
      bomLeewayWindCoeff = 0. _d 0
      bomWindSource = 'NONE'
      bomStokesSource = 'NONE'
      bomIntegrator = 'RK4'
      bomMaxHop = 8
      bomCheckEverySubstep = .TRUE.
      CALL BOM_VERIFY_OWNER_FILL_MODEL(
     I     1. _d 0, 0. _d 0, myThid )
      CALL BOM_BUILD_FIELDS( 0. _d 0, 0, myThid )

      isSourceRank = myXGlobalLo.EQ.1 .AND. myYGlobalLo.EQ.1
      IF ( isSourceRank ) THEN
        bomNPartTile(1,1) = 1
        CALL BOM_VERIFY_OWNER_PUT(
     I       1, 1, 1, 4100000001_8,
     I       DFLOAT(sNx)+0.35 _d 0, 1.7 _d 0,
     O       putValid, x0, y0,
     I       myThid )
        CALL BOM_VERIFY_OWNER_ASSERT( putValid,
     &       'stencil source accepted', nFail, myThid )
        CALL BOM_RK4_MIGRATE(
     I       x0, y0, 4000. _d 0, 1, 1,
     O       x1, y1, ix, jy,
     O       oceanEast, oceanNorth, windEast, windNorth,
     O       driftEast, driftNorth, wetWeight, stageCFL,
     O       failStage, failCode, rkValid,
     I       myThid )
        CALL BOM_VERIFY_OWNER_ASSERT( .NOT.rkValid,
     &       'stencil trial rejected', nFail, myThid )
        WRITE(msgBuf,'(A,2I8,A,4(1X,1PE24.16))')
     &       'P1-P14-STENCIL stage/code=', failStage, failCode,
     &       ' x0/y0/x1/y1=', x0, y0, x1, y1
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
        CALL BOM_VERIFY_OWNER_ASSERT(
     &       failStage.GE.BOM_STAGE_K2 .AND.
     &       failStage.LE.BOM_STAGE_FINAL .AND.
     &       (failCode.EQ.BOM_FAIL_MAP .OR.
     &        failCode.EQ.BOM_FAIL_STENCIL),
     &       'stencil post-K1 failure code', nFail, myThid )
        CALL BOM_VERIFY_OWNER_ASSERT(
     &       x1.EQ.x0 .AND. y1.EQ.y0,
     &       'stencil coordinate rollback', nFail, myThid )
        globalFound = 1
      ENDIF
      CALL GLOBAL_SUM_INT( globalFound, myThid )
      CALL BOM_VERIFY_OWNER_ASSERT( globalFound.EQ.1,
     &     'stencil source count', nFail, myThid )

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_OWNER_PERIODIC(
     O     globalFound,
     U     nFail,
     I     myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      INTEGER globalFound, nFail, myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, ip, localFound
      INTEGER ownerRank, ownerBi, ownerBj, hopCount
      INTEGER*8 testId, xBits, yBits, releaseBits, ageBits
      _RL xSeed, ySeed, xOwner, yOwner
      LOGICAL isSourceRank, putValid, locateValid

      testId = 9007199254740993_8
      localFound = 0
      bomMaxParticles = 1
      bomNPartExpected = 1
      bomDeltaTTarget = 300. _d 0
      bomWetWeightMin = 0.5 _d 0
      bomAdvCFL = 0.5 _d 0
      bomLeewayWindCoeff = 0. _d 0
      bomWindSource = 'NONE'
      bomStokesSource = 'NONE'
      bomIntegrator = 'RK4'
      bomMaxHop = 1
      bomCheckEverySubstep = .TRUE.
      CALL BOM_VERIFY_OWNER_FILL_MODEL(
     I     0. _d 0, 0. _d 0, myThid )

C--   Seed the global south-east tile, then present a wrapped candidate.
      isSourceRank = (myXGlobalLo+nSx*sNx-1).EQ.Nx .AND.
     &               myYGlobalLo.EQ.1
      IF ( isSourceRank ) THEN
        bi = nSx
        bj = 1
        bomNPartTile(bi,bj) = 1
        CALL BOM_VERIFY_OWNER_PUT(
     I       1, bi, bj, testId,
     I       DFLOAT(sNx)+0.2 _d 0, 1.7 _d 0,
     O       putValid, xSeed, ySeed,
     I       myThid )
        CALL BOM_VERIFY_OWNER_ASSERT( putValid,
     &       'periodic source record accepted', nFail, myThid )
        bomX(1,bi,bj) = bomMapXHi + 5. _d 0
      ENDIF

      CALL BOM_BUILD_FIELDS( 0. _d 0, 0, myThid )
      CALL BOM_PARTICLE_EXCHANGE( 0. _d 0, 0, 1, myThid )
      CALL BOM_LOCATE_OWNER(
     I     bomMapXLo+5. _d 0, bomMapYFace(1)+
     I     0.2 _d 0*(bomMapYFace(2)-bomMapYFace(1)), 1, 1,
     O     xOwner, yOwner, ownerRank, ownerBi, ownerBj, hopCount,
     O     locateValid,
     I     myThid )
      CALL BOM_VERIFY_OWNER_ASSERT( locateValid,
     &     'canonical periodic destination located', nFail, myThid )
      IF ( locateValid .AND. myProcId.EQ.ownerRank ) THEN
        CALL BOM_VERIFY_OWNER_ASSERT( hopCount.EQ.0,
     &       'periodic owner self-hop zero', nFail, myThid )
      ENDIF

      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          IF ( bomId(ip,bi,bj).EQ.testId ) THEN
            localFound = localFound + 1
            CALL BOM_VERIFY_OWNER_ASSERT(
     &           myProcId.EQ.ownerRank .AND. bi.EQ.ownerBi .AND.
     &           bj.EQ.ownerBj,
     &           'periodic record on west owner', nFail, myThid )
            CALL BOM_VERIFY_OWNER_ASSERT(
     &           bomX(ip,bi,bj).EQ.xOwner .AND.
     &           bomY(ip,bi,bj).EQ.yOwner .AND.
     &           bomStatus(ip,bi,bj).EQ.BOM_ALIVE .AND.
     &           bomAge(ip,bi,bj).EQ.7. _d 0,
     &           'periodic state canonical and unchanged',
     &           nFail, myThid )
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
     &     'periodic global owner count conserved', nFail, myThid )
      CALL BOM_CHECK_STATE( 0. _d 0, 0, 'P1-X02-P', myThid )
 1000 FORMAT(A,I20,A,I3,A,4(1X,Z16.16))

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
