#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INTERP_BIO_PAIR
C !INTERFACE:
      SUBROUTINE BOM_INTERP_BIO_PAIR(
     I                 ix, jy, bi, bj, stageTime,
     O                 stageTemp, stageN, wetWeight, sampleValid,
     O                 failCode, failStage, p4FailPhase,
     O                 interpValid,
     I                 myThid )

C !DESCRIPTION:
C     Time-interpolate each used C point, then apply the same normalized
C     bilinear wet weights to temperature and nutrient.  A geometrically
C     missing sample is returned separately for STOP/NO_GROWTH policy.

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
      _RL ix, jy, stageTime
      INTEGER bi, bj, myThid

C !OUTPUT PARAMETERS:
      _RL stageTemp, stageN, wetWeight
      LOGICAL sampleValid, interpValid
      INTEGER failCode, failStage, p4FailPhase
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER i1, j1, ii, jj, i, j
      INTEGER pointFailCode, pointFailStage, pointP4Phase
      _RL fracI, fracJ, weight, normWeight
      _RL weights(0:1,0:1)
      _RL pointTemp(0:1,0:1), pointN(0:1,0:1)
      _RL tempScale, nScale, tempScaled, nScaled
      LOGICAL pointValid, pointInterpValid, missingSample
#endif

      stageTemp = 0. _d 0
      stageN = 0. _d 0
      wetWeight = 0. _d 0
      sampleValid = .FALSE.
      interpValid = .FALSE.
      failCode = BOM_FAIL_BIOLOGY_FIELD
      failStage = BOM_STAGE_FIELD_OLD
      p4FailPhase = BOM_P4_PHASE_ENDPOINT

#ifdef ALLOW_BOM
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) RETURN
      IF ( bi.LT.myBxLo(myThid) .OR. bi.GT.myBxHi(myThid)
     &     .OR. bj.LT.myByLo(myThid)
     &     .OR. bj.GT.myByHi(myThid) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(ix) .OR.
     &     .NOT.IEEE_IS_FINITE(jy) .OR.
     &     .NOT.IEEE_IS_FINITE(stageTime) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(bomWetWeightMin) ) RETURN
      IF ( bomWetWeightMin.LE.0. _d 0 .OR.
     &     bomWetWeightMin.GT.oneRL ) RETURN
      IF ( ix.LT.DFLOAT(1-OLx) .OR. ix.GE.DFLOAT(sNx+OLx)
     &     .OR. jy.LT.DFLOAT(1-OLy)
     &     .OR. jy.GE.DFLOAT(sNy+OLy) ) RETURN

      i1 = INT(ix)
      IF ( DFLOAT(i1).GT.ix ) i1 = i1-1
      j1 = INT(jy)
      IF ( DFLOAT(j1).GT.jy ) j1 = j1-1
      IF ( i1.LT.1-OLx .OR. i1+1.GT.sNx+OLx
     &     .OR. j1.LT.1-OLy .OR. j1+1.GT.sNy+OLy ) RETURN
      fracI = ix-DFLOAT(i1)
      fracJ = jy-DFLOAT(j1)
      weights(0,0) = (oneRL-fracI)*(oneRL-fracJ)
      weights(1,0) = fracI*(oneRL-fracJ)
      weights(0,1) = (oneRL-fracI)*fracJ
      weights(1,1) = fracI*fracJ

      DO jj=0,1
       DO ii=0,1
        pointTemp(ii,jj) = 0. _d 0
        pointN(ii,jj) = 0. _d 0
        IF ( maskC(i1+ii,j1+jj,1,bi,bj).GT.0. )
     &       wetWeight = wetWeight+weights(ii,jj)
       ENDDO
      ENDDO
      IF ( .NOT.IEEE_IS_FINITE(wetWeight) ) RETURN
      IF ( wetWeight.LT.bomWetWeightMin ) THEN
        failCode = BOM_FAIL_NONE
        failStage = BOM_STAGE_NONE
        p4FailPhase = BOM_P4_PHASE_NONE
        interpValid = .TRUE.
        RETURN
      ENDIF

      tempScale = 0. _d 0
      nScale = 0. _d 0
      missingSample = .FALSE.
      DO jj=0,1
       DO ii=0,1
        weight = weights(ii,jj)
        IF ( maskC(i1+ii,j1+jj,1,bi,bj).GT.0. .AND.
     &       weight.GT.0. _d 0 ) THEN
          i = i1+ii
          j = j1+jj
          CALL BOM_INTERP_BIO_TIME(
     I         i, j, bi, bj, stageTime,
     O         pointTemp(ii,jj), pointN(ii,jj), pointValid,
     O         pointFailCode, pointFailStage, pointP4Phase,
     O         pointInterpValid,
     I         myThid )
          IF ( .NOT.pointInterpValid ) THEN
            failCode = pointFailCode
            failStage = pointFailStage
            p4FailPhase = pointP4Phase
            RETURN
          ENDIF
          IF ( .NOT.pointValid ) missingSample = .TRUE.
          tempScale = MAX(tempScale,ABS(pointTemp(ii,jj)))
          nScale = MAX(nScale,ABS(pointN(ii,jj)))
        ENDIF
       ENDDO
      ENDDO
      IF ( missingSample ) THEN
        failCode = BOM_FAIL_NONE
        failStage = BOM_STAGE_NONE
        p4FailPhase = BOM_P4_PHASE_NONE
        interpValid = .TRUE.
        RETURN
      ENDIF

      tempScaled = 0. _d 0
      nScaled = 0. _d 0
      DO jj=0,1
       DO ii=0,1
        weight = weights(ii,jj)
        IF ( maskC(i1+ii,j1+jj,1,bi,bj).GT.0. .AND.
     &       weight.GT.0. _d 0 ) THEN
          normWeight = weight/wetWeight
          IF ( tempScale.GT.0. _d 0 )
     &         tempScaled = tempScaled+normWeight
     &              *(pointTemp(ii,jj)/tempScale)
          IF ( nScale.GT.0. _d 0 )
     &         nScaled = nScaled+normWeight
     &              *(pointN(ii,jj)/nScale)
        ENDIF
       ENDDO
      ENDDO
      tempScaled = MAX(-oneRL,MIN(oneRL,tempScaled))
      nScaled = MAX(0. _d 0,MIN(oneRL,nScaled))
      stageTemp = tempScale*tempScaled
      stageN = nScale*nScaled
      IF ( .NOT.IEEE_IS_FINITE(stageTemp) .OR.
     &     .NOT.IEEE_IS_FINITE(stageN) ) THEN
        stageTemp = 0. _d 0
        stageN = 0. _d 0
        RETURN
      ENDIF
      IF ( stageN.LT.0. _d 0 ) THEN
        stageTemp = 0. _d 0
        stageN = 0. _d 0
        RETURN
      ENDIF

      sampleValid = .TRUE.
      interpValid = .TRUE.
      failCode = BOM_FAIL_NONE
      failStage = BOM_STAGE_NONE
      p4FailPhase = BOM_P4_PHASE_NONE
#endif

      RETURN
      END
