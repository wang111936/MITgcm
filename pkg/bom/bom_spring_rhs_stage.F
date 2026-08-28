#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_SPRING_RHS_STAGE
C !INTERFACE:
      SUBROUTINE BOM_SPRING_RHS_STAGE(
     I                 nOwner, ownerId, ownerStatus,
     I                 ownerX, ownerY, ownerBi, ownerBj,
     I                 stageTime, dtGuard, rhsStage,
     I                 ghostEpoch, ghostSubstep,
     O                 rateX, rateY, mappedI, mappedJ,
     O                 rhsDiag, springEast, springNorth,
     O                 neighborCount, wetWeight, stageCFL,
     O                 ownerRecords, ghostRecords, nonEmptyCells,
     O                 candidateComparisons, directedNeighbors,
     O                 undirectedEdges, maximumNeighbors,
     O                 failCode, p3FailPhase, stageValid,
     I                 myThid )

C !DESCRIPTION:
C     Evaluate one synchronous spring-enabled RK stage.  Phase-2 base RHS
C     calls use dt=0 so a cancelling spring is judged only by the required
C     combined-drift CFL.  Candidate arrays publish after a global status
C     reduction; the consumed ghost publication is then invalidated.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nOwner
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER ownerStatus(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord), ownerY(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord), ownerBj(bomMaxOwnerRecord)
      _RL stageTime, dtGuard
      INTEGER rhsStage, ghostEpoch, ghostSubstep, myThid
      _RL rateX(bomMaxOwnerRecord), rateY(bomMaxOwnerRecord)
      _RL mappedI(bomMaxOwnerRecord), mappedJ(bomMaxOwnerRecord)
      _RL rhsDiag(BOM_RHS_NDIAG,bomMaxOwnerRecord)
      _RL springEast(bomMaxOwnerRecord)
      _RL springNorth(bomMaxOwnerRecord)
      INTEGER neighborCount(bomMaxOwnerRecord)
      _RL wetWeight(bomMaxOwnerRecord)
      _RL stageCFL(bomMaxOwnerRecord)
      INTEGER*8 ownerRecords, ghostRecords, nonEmptyCells
      INTEGER*8 candidateComparisons, directedNeighbors
      INTEGER*8 undirectedEdges, maximumNeighbors
      INTEGER failCode, p3FailPhase
      LOGICAL stageValid
CEOP

#ifdef ALLOW_BOM
      INTEGER owner, iDiag, localFail, localPhase
      INTEGER globalFail, globalPhase, rhsFail, rhsFailStage
      INTEGER springFail, springPhase
      _RL baseRateX, baseRateY
      _RL baseDiag(BOM_RHS_NDIAG)
      _RL rateXWork(bomMaxOwnerRecord)
      _RL rateYWork(bomMaxOwnerRecord)
      _RL mappedIWork(bomMaxOwnerRecord)
      _RL mappedJWork(bomMaxOwnerRecord)
      _RL rhsDiagWork(BOM_RHS_NDIAG,bomMaxOwnerRecord)
      _RL springEastWork(bomMaxOwnerRecord)
      _RL springNorthWork(bomMaxOwnerRecord)
      INTEGER neighborWork(bomMaxOwnerRecord)
      _RL wetWork(bomMaxOwnerRecord)
      _RL cflWork(bomMaxOwnerRecord)
      _RL baseWet, baseCFL, combinedCFL
      LOGICAL ghostValid, springValid, rhsOwner, rhsValid
      LOGICAL combineValid, globalValid
      SAVE rhsDiagWork
#endif

      failCode = BOM_FAIL_STATE
      p3FailPhase = BOM_P3_PHASE_POSITION
      stageValid = .FALSE.

#ifdef ALLOW_BOM
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,rhsStage,ghostEpoch,ghostSubstep,
     O     localFail,localPhase,ghostValid,myThid)
      IF ( .NOT.ghostValid ) THEN
        failCode = localFail
        p3FailPhase = localPhase
        RETURN
      ENDIF

      CALL BOM_SPRING_STAGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     rhsStage,ghostEpoch,ghostSubstep,dtGuard,
     O     springEastWork,springNorthWork,neighborWork,
     O     ownerRecords,ghostRecords,nonEmptyCells,
     O     candidateComparisons,directedNeighbors,
     O     undirectedEdges,maximumNeighbors,
     O     springFail,springPhase,springValid,myThid)
      IF ( springValid ) THEN
        localFail = BOM_FAIL_NONE
        localPhase = BOM_P3_PHASE_NONE
      ELSE
        localFail = springFail
        localPhase = springPhase
      ENDIF
      CALL BOM_P3_GLOBAL_STATUS(
     I     localFail,localPhase,
     O     globalFail,globalPhase,globalValid,myThid)
      IF ( .NOT.globalValid ) THEN
        CALL BOM_GHOST_INVALIDATE
        failCode = globalFail
        p3FailPhase = globalPhase
        RETURN
      ENDIF

      localFail = BOM_FAIL_NONE
      localPhase = BOM_P3_PHASE_NONE
      DO owner=1,nOwner
        rateXWork(owner) = 0. _d 0
        rateYWork(owner) = 0. _d 0
        mappedIWork(owner) = -1. _d 0
        mappedJWork(owner) = -1. _d 0
        wetWork(owner) = 0. _d 0
        cflWork(owner) = 0. _d 0
        DO iDiag=1,BOM_RHS_NDIAG
          rhsDiagWork(iDiag,owner) = 0. _d 0
        ENDDO
        IF ( ownerStatus(owner).EQ.BOM_ALIVE .AND.
     &       localFail.EQ.BOM_FAIL_NONE ) THEN
          CALL BOM_RHS_SLOW_MANIFOLD(
     I         ownerX(owner),ownerY(owner),stageTime,0. _d 0,
     I         ownerBi(owner),ownerBj(owner),rhsStage,
     O         baseRateX,baseRateY,
     O         mappedIWork(owner),mappedJWork(owner),baseDiag,
     O         baseWet,baseCFL,rhsOwner,rhsValid,
     O         rhsFail,rhsFailStage,myThid)
          IF ( .NOT.rhsValid ) THEN
            localFail = rhsFail
            localPhase = BOM_P3_PHASE_BASE_RHS
          ELSE
            CALL BOM_COMBINE_SPRING_RHS(
     I           ownerX(owner),ownerY(owner),
     I           mappedIWork(owner),mappedJWork(owner),
     I           ownerBi(owner),ownerBj(owner),dtGuard,
     I           baseRateX,baseRateY,baseDiag,
     I           springEastWork(owner),springNorthWork(owner),
     O           rateXWork(owner),rateYWork(owner),
     O           rhsDiagWork(1,owner),combinedCFL,
     O           rhsFail,combineValid,myThid)
            IF ( .NOT.combineValid ) THEN
              localFail = rhsFail
              localPhase = BOM_P3_PHASE_NATIVE_RATE
            ELSE
              wetWork(owner) = baseWet
              cflWork(owner) = combinedCFL
            ENDIF
          ENDIF
        ELSEIF ( ownerStatus(owner).NE.BOM_WAITING .AND.
     &           ownerStatus(owner).NE.BOM_ALIVE .AND.
     &           localFail.EQ.BOM_FAIL_NONE ) THEN
          localFail = BOM_FAIL_STATE
          localPhase = BOM_P3_PHASE_POSITION
        ENDIF
      ENDDO

      CALL BOM_P3_GLOBAL_STATUS(
     I     localFail,localPhase,
     O     globalFail,globalPhase,globalValid,myThid)
      CALL BOM_GHOST_INVALIDATE
      IF ( .NOT.globalValid ) THEN
        failCode = globalFail
        p3FailPhase = globalPhase
        RETURN
      ENDIF

      DO owner=1,nOwner
        rateX(owner) = rateXWork(owner)
        rateY(owner) = rateYWork(owner)
        mappedI(owner) = mappedIWork(owner)
        mappedJ(owner) = mappedJWork(owner)
        springEast(owner) = springEastWork(owner)
        springNorth(owner) = springNorthWork(owner)
        neighborCount(owner) = neighborWork(owner)
        wetWeight(owner) = wetWork(owner)
        stageCFL(owner) = cflWork(owner)
        DO iDiag=1,BOM_RHS_NDIAG
          rhsDiag(iDiag,owner) = rhsDiagWork(iDiag,owner)
        ENDDO
      ENDDO
      failCode = BOM_FAIL_NONE
      p3FailPhase = BOM_P3_PHASE_NONE
      stageValid = .TRUE.
#endif /* ALLOW_BOM */
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_COMBINE_SPRING_RHS(
     I                 xx, yy, ix, jy, bi, bj, dtGuard,
     I                 baseRateX, baseRateY, baseDiag,
     I                 springEast, springNorth,
     O                 totalRateX, totalRateY, totalDiag,
     O                 combinedCFL, failCode, combineValid,
     I                 myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL xx, yy, ix, jy, dtGuard, baseRateX, baseRateY
      _RL baseDiag(BOM_RHS_NDIAG), springEast, springNorth
      INTEGER bi, bj, myThid
      _RL totalRateX, totalRateY
      _RL totalDiag(BOM_RHS_NDIAG), combinedCFL
      INTEGER failCode
      LOGICAL combineValid
      _RL diagWork(BOM_RHS_NDIAG)
      _RL springRateX, springRateY, rateXWork, rateYWork
      _RL cosLat, denomX, denomY, recipDx, recipDy, wetWeight
      INTEGER iDiag
      LOGICAL calcValid, termValid, metricValid, cflValid

      combineValid = .FALSE.
      failCode = BOM_FAIL_NONFINITE
      combinedCFL = 0. _d 0
      IF ( .NOT.IEEE_IS_FINITE(xx) .OR.
     &     .NOT.IEEE_IS_FINITE(yy) .OR.
     &     .NOT.IEEE_IS_FINITE(baseRateX) .OR.
     &     .NOT.IEEE_IS_FINITE(baseRateY) .OR.
     &     .NOT.IEEE_IS_FINITE(springEast) .OR.
     &     .NOT.IEEE_IS_FINITE(springNorth) ) RETURN
      DO iDiag=1,BOM_RHS_NDIAG
        IF ( .NOT.IEEE_IS_FINITE(baseDiag(iDiag)) ) RETURN
        diagWork(iDiag) = baseDiag(iDiag)
      ENDDO
      CALL BOM_SAFE_ADD_RL(
     I     baseDiag(BOM_RHS_DRIFT_E),springEast,
     O     diagWork(BOM_RHS_DRIFT_E),calcValid)
      IF ( .NOT.calcValid ) RETURN
      CALL BOM_SAFE_ADD_RL(
     I     baseDiag(BOM_RHS_DRIFT_N),springNorth,
     O     diagWork(BOM_RHS_DRIFT_N),calcValid)
      IF ( .NOT.calcValid ) RETURN

      IF ( usingCartesianGrid .AND.
     &     .NOT.usingSphericalPolarGrid ) THEN
        springRateX = springEast
        springRateY = springNorth
      ELSEIF ( usingSphericalPolarGrid .AND.
     &         .NOT.usingCartesianGrid ) THEN
        IF ( .NOT.IEEE_IS_FINITE(rSphere) .OR.
     &       rSphere.LE.0. _d 0 ) RETURN
        cosLat = COS(deg2rad*yy)
        IF ( .NOT.IEEE_IS_FINITE(cosLat) .OR.
     &       ABS(cosLat).LT.SQRT(EPSILON(oneRL)) ) RETURN
        CALL BOM_SAFE_MULT_RL(rSphere,deg2rad,denomY,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_MULT_RL(denomY,cosLat,denomX,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_DIV_RL(
     I       springEast,denomX,
     O       springRateX,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_DIV_RL(
     I       springNorth,denomY,
     O       springRateY,calcValid)
        IF ( .NOT.calcValid ) RETURN
      ELSE
        RETURN
      ENDIF
      CALL BOM_SAFE_ADD_RL(
     I     baseRateX,springRateX,
     O     rateXWork,calcValid)
      IF ( .NOT.calcValid ) RETURN
      CALL BOM_SAFE_ADD_RL(
     I     baseRateY,springRateY,
     O     rateYWork,termValid)
      IF ( .NOT.termValid ) RETURN

      CALL BOM_SPRING_INTERP_METRICS(
     I     ix,jy,bi,bj,
     O     recipDx,recipDy,wetWeight,metricValid,myThid)
      IF ( .NOT.metricValid ) THEN
        failCode = BOM_FAIL_METRIC
        RETURN
      ENDIF
      CALL BOM_RHS_CFL_GUARD(
     I     diagWork(BOM_RHS_DRIFT_E),
     I     diagWork(BOM_RHS_DRIFT_N),
     I     dtGuard,recipDx,recipDy,bomAdvCFL,
     O     combinedCFL,cflValid)
      IF ( .NOT.cflValid ) THEN
        failCode = BOM_FAIL_CFL
        RETURN
      ENDIF

      totalRateX = rateXWork
      totalRateY = rateYWork
      DO iDiag=1,BOM_RHS_NDIAG
        totalDiag(iDiag) = diagWork(iDiag)
      ENDDO
      failCode = BOM_FAIL_NONE
      combineValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SPRING_INTERP_METRICS(
     I                 ix, jy, bi, bj,
     O                 recipDx, recipDy, wetWeight, isValid,
     I                 myThid )
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL ix, jy, recipDx, recipDy, wetWeight
      INTEGER bi, bj, myThid
      LOGICAL isValid
      INTEGER i1, j1, ii, jj
      _RL fracI, fracJ, weight, normWeight
      _RL weights(0:1,0:1), pointDx, pointDy

      recipDx = 0. _d 0
      recipDy = 0. _d 0
      wetWeight = 0. _d 0
      isValid = .FALSE.
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(ix) .OR.
     &     .NOT.IEEE_IS_FINITE(jy) ) RETURN
      IF ( ix.LT.DFLOAT(1-OLx) .OR. ix.GE.DFLOAT(sNx+OLx)
     &     .OR. jy.LT.DFLOAT(1-OLy)
     &     .OR. jy.GE.DFLOAT(sNy+OLy) ) RETURN
      i1 = INT(ix)
      IF ( DFLOAT(i1).GT.ix ) i1=i1-1
      j1 = INT(jy)
      IF ( DFLOAT(j1).GT.jy ) j1=j1-1
      IF ( i1.LT.1-OLx .OR. i1+1.GT.sNx+OLx .OR.
     &     j1.LT.1-OLy .OR. j1+1.GT.sNy+OLy ) RETURN
      fracI = ix-DFLOAT(i1)
      fracJ = jy-DFLOAT(j1)
      weights(0,0) = (oneRL-fracI)*(oneRL-fracJ)
      weights(1,0) = fracI*(oneRL-fracJ)
      weights(0,1) = (oneRL-fracI)*fracJ
      weights(1,1) = fracI*fracJ
      DO jj=0,1
       DO ii=0,1
        IF ( maskC(i1+ii,j1+jj,1,bi,bj).GT.0. )
     &       wetWeight=wetWeight+weights(ii,jj)
       ENDDO
      ENDDO
      IF ( .NOT.IEEE_IS_FINITE(wetWeight) .OR.
     &     wetWeight.LT.bomWetWeightMin ) RETURN
      DO jj=0,1
       DO ii=0,1
        weight = weights(ii,jj)
        IF ( maskC(i1+ii,j1+jj,1,bi,bj).GT.0. .AND.
     &       weight.GT.0. _d 0 ) THEN
          pointDx = recip_dxF(i1+ii,j1+jj,bi,bj)
          pointDy = recip_dyF(i1+ii,j1+jj,bi,bj)
          IF ( .NOT.IEEE_IS_FINITE(pointDx) .OR.
     &         .NOT.IEEE_IS_FINITE(pointDy) .OR.
     &         pointDx.LE.0. _d 0 .OR.
     &         pointDy.LE.0. _d 0 ) RETURN
          normWeight = weight/wetWeight
          recipDx = recipDx+normWeight*pointDx
          recipDy = recipDy+normWeight*pointDy
        ENDIF
       ENDDO
      ENDDO
      IF ( .NOT.IEEE_IS_FINITE(recipDx) .OR.
     &     .NOT.IEEE_IS_FINITE(recipDy) .OR.
     &     recipDx.LE.0. _d 0 .OR. recipDy.LE.0. _d 0 ) RETURN
      isValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P3_GLOBAL_STATUS(
     I                 localFail, localPhase,
     O                 globalFail, globalPhase, isValid,
     I                 myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER localFail, localPhase, globalFail, globalPhase
      INTEGER myThid, packedLocal, packedGlobal
      LOGICAL isValid
#ifdef ALLOW_USE_MPI
      INTEGER mpiRC
#endif
      packedLocal = 0
      IF ( localFail.NE.BOM_FAIL_NONE )
     &     packedLocal=32*localFail+localPhase
      packedGlobal = packedLocal
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allreduce(
     I       packedLocal,packedGlobal,1,MPI_INTEGER,MPI_MAX,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) THEN
          packedGlobal =
     &         32*BOM_FAIL_GHOST_PACKET+BOM_P3_PHASE_GHOST
        ENDIF
      ENDIF
#endif
      IF ( packedGlobal.EQ.0 ) THEN
        globalFail = BOM_FAIL_NONE
        globalPhase = BOM_P3_PHASE_NONE
        isValid = .TRUE.
      ELSE
        globalFail = packedGlobal/32
        globalPhase = MOD(packedGlobal,32)
        isValid = .FALSE.
      ENDIF
      RETURN
      END
