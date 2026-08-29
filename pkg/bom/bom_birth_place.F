#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BIRTH_PLACE
C !INTERFACE:
      SUBROUTINE BOM_BIRTH_PLACE(
     I                 parentX,parentY,sourceBi,sourceBj,
     I                 parentId,parentBirthCount,eventTimeIndex,
     O                 childX,childY,childI,childJ,
     O                 firstAttemptX,firstAttemptY,
     O                 placementWord,placementAngle,attemptUsed,
     O                 eventType,destRank,destBi,destBj,
     O                 failCode,p4FailPhase,isValid,
     I                 myThid )

C !DESCRIPTION:
C     Try deterministic birth positions in counter order.  Land/outside
C     candidates retry; a fatal mapping/numeric result fails the transaction.
C     The first WET candidate wins and is normalized before publication.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL parentX,parentY,childX,childY,childI,childJ
      _RL firstAttemptX,firstAttemptY,placementAngle
      INTEGER sourceBi,sourceBj,parentBirthCount,attemptUsed
      INTEGER eventType,destRank,destBi,destBj
      INTEGER failCode,p4FailPhase,myThid
      INTEGER*8 parentId,eventTimeIndex,placementWord
      LOGICAL isValid

      INTEGER attempt,boundaryClass,classFail,classPhase
      _RL theta,eastOffset,northOffset,candidateX,candidateY
      _RL mappedX,ix,jy,latIncrement,lonIncrement
      _RL latDenominator,lonDenominator,midpointLat,cosMid
      _RL midpointSum,metricProduct
      INTEGER ownerRank,ownerBi,ownerBj,rngFail
      INTEGER*8 word
      LOGICAL rngValid,classValid,calcValid

      childX=0. _d 0
      childY=0. _d 0
      childI=0. _d 0
      childJ=0. _d 0
      firstAttemptX=0. _d 0
      firstAttemptY=0. _d 0
      placementWord=0_8
      placementAngle=0. _d 0
      attemptUsed=0
      eventType=BOM_EVENT_NONE
      destRank=-1
      destBi=0
      destBj=0
      failCode=BOM_FAIL_BIRTH_RNG
      p4FailPhase=BOM_P4_PHASE_BIRTH_PLACE
      isValid=.FALSE.

      IF ( .NOT.IEEE_IS_FINITE(parentX) .OR.
     &     .NOT.IEEE_IS_FINITE(parentY) ) THEN
        failCode=BOM_FAIL_NONFINITE
        RETURN
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(bomSpringL) .OR.
     &     bomSpringL.LE.0. _d 0 .OR. bomBirthMaxTry.LT.1 .OR.
     &     sourceBi.LT.1 .OR. sourceBi.GT.nSx .OR.
     &     sourceBj.LT.1 .OR. sourceBj.GT.nSy ) THEN
        failCode=BOM_FAIL_BIOLOGY_CONFIG
        RETURN
      ENDIF
      IF ( usingCartesianGrid.EQV.usingSphericalPolarGrid ) THEN
        failCode=BOM_FAIL_MAP
        RETURN
      ENDIF

      DO attempt=0,bomBirthMaxTry-1
        CALL BOM_BIRTH_RANDOM(
     I       bomSeed,parentId,parentBirthCount,eventTimeIndex,attempt,
     O       word,theta,rngFail,rngValid)
        IF ( .NOT.rngValid ) THEN
          failCode=rngFail
          RETURN
        ENDIF
        CALL BOM_SAFE_MULT_RL(
     I       bomSpringL,COS(theta),
     O       eastOffset,calcValid)
        IF ( .NOT.calcValid ) THEN
          failCode=BOM_FAIL_BIRTH_RNG
          RETURN
        ENDIF
        CALL BOM_SAFE_MULT_RL(
     I       bomSpringL,SIN(theta),
     O       northOffset,calcValid)
        IF ( .NOT.calcValid ) THEN
          failCode=BOM_FAIL_BIRTH_RNG
          RETURN
        ENDIF

        IF ( usingCartesianGrid ) THEN
          CALL BOM_SAFE_ADD_RL(
     I         parentX,eastOffset,
     O         candidateX,calcValid)
          IF ( .NOT.calcValid ) THEN
            failCode=BOM_FAIL_BIRTH_RNG
            RETURN
          ENDIF
          CALL BOM_SAFE_ADD_RL(
     I         parentY,northOffset,
     O         candidateY,calcValid)
          IF ( .NOT.calcValid ) THEN
            failCode=BOM_FAIL_BIRTH_RNG
            RETURN
          ENDIF
        ELSE
          CALL BOM_SAFE_MULT_RL(
     I         rSphere,deg2rad,
     O         latDenominator,calcValid)
          IF ( .NOT.calcValid .OR.
     &         latDenominator.LE.0. _d 0 ) THEN
            failCode=BOM_FAIL_METRIC
            RETURN
          ENDIF
          latIncrement=northOffset/latDenominator
          IF ( .NOT.IEEE_IS_FINITE(latIncrement) ) THEN
            failCode=BOM_FAIL_METRIC
            RETURN
          ENDIF
          CALL BOM_SAFE_ADD_RL(
     I         parentY,latIncrement,
     O         candidateY,calcValid)
          IF ( .NOT.calcValid ) THEN
            failCode=BOM_FAIL_METRIC
            RETURN
          ENDIF
          CALL BOM_SAFE_ADD_RL(
     I         parentY,candidateY,
     O         midpointSum,calcValid)
          IF ( .NOT.calcValid ) THEN
            failCode=BOM_FAIL_METRIC
            RETURN
          ENDIF
          CALL BOM_SAFE_MULT_RL(
     I         halfRL,midpointSum,
     O         midpointLat,calcValid)
          IF ( .NOT.calcValid .OR.
     &         ABS(midpointLat).GT.90. _d 0 ) THEN
            failCode=BOM_FAIL_METRIC
            RETURN
          ENDIF
          cosMid=COS(deg2rad*midpointLat)
          IF ( .NOT.IEEE_IS_FINITE(cosMid) .OR.
     &         ABS(cosMid).LT.SQRT(EPSILON(oneRL)) ) THEN
            failCode=BOM_FAIL_METRIC
            RETURN
          ENDIF
          CALL BOM_SAFE_MULT_RL(
     I         latDenominator,cosMid,
     O         metricProduct,calcValid)
          IF ( .NOT.calcValid .OR. metricProduct.EQ.0. _d 0 ) THEN
            failCode=BOM_FAIL_METRIC
            RETURN
          ENDIF
          lonDenominator=metricProduct
          lonIncrement=eastOffset/lonDenominator
          IF ( .NOT.IEEE_IS_FINITE(lonIncrement) ) THEN
            failCode=BOM_FAIL_METRIC
            RETURN
          ENDIF
          CALL BOM_SAFE_ADD_RL(
     I         parentX,lonIncrement,
     O         candidateX,calcValid)
          IF ( .NOT.calcValid ) THEN
            failCode=BOM_FAIL_METRIC
            RETURN
          ENDIF
        ENDIF

        IF ( attempt.EQ.0 ) THEN
          firstAttemptX=candidateX
          firstAttemptY=candidateY
        ENDIF
        CALL BOM_CLASSIFY_BOUNDARY(
     I       candidateX,candidateY,sourceBi,sourceBj,
     O       boundaryClass,mappedX,ix,jy,
     O       ownerRank,ownerBi,ownerBj,
     O       classFail,classPhase,classValid,
     I       myThid)
        IF ( .NOT.classValid ) THEN
          failCode=classFail
          RETURN
        ELSEIF ( boundaryClass.EQ.BOM_BOUNDARY_WET ) THEN
          childX=mappedX
          childY=candidateY
          childI=ix
          childJ=jy
          placementWord=word
          placementAngle=theta
          attemptUsed=attempt
          eventType=BOM_EVENT_BIRTH
          destRank=ownerRank
          destBi=ownerBi
          destBj=ownerBj
          failCode=BOM_FAIL_NONE
          p4FailPhase=BOM_P4_PHASE_NONE
          isValid=.TRUE.
          RETURN
        ELSEIF ( boundaryClass.NE.BOM_BOUNDARY_BEACHED .AND.
     &           boundaryClass.NE.BOM_BOUNDARY_OUTSIDE ) THEN
          failCode=BOM_FAIL_BOUNDARY_EVENT
          RETURN
        ENDIF
      ENDDO

      attemptUsed=bomBirthMaxTry
      eventType=BOM_EVENT_BIRTH_CANCEL
      failCode=BOM_FAIL_NONE
      p4FailPhase=BOM_P4_PHASE_NONE
      isValid=.TRUE.
      RETURN
      END
