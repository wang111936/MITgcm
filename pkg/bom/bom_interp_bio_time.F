#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INTERP_BIO_TIME
C !INTERFACE:
      SUBROUTINE BOM_INTERP_BIO_TIME(
     I                 i, j, bi, bj, stageTime,
     O                 stageTemp, stageN, pointValid,
     O                 failCode, failStage, p4FailPhase,
     O                 interpValid,
     I                 myThid )

C !DESCRIPTION:
C     Evaluate one accepted P4.1 scalar pair at an exact or interior time.
C     No time derivative is formed and accepted state is read-only.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER i, j, bi, bj, myThid
      _RL stageTime

C !OUTPUT PARAMETERS:
      _RL stageTemp, stageN
      LOGICAL pointValid, interpValid
      INTEGER failCode, failStage, p4FailPhase
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER iter0, iter1, selectedEnd
      INTEGER tempCode, nCode
      _RL time0, time1, interval, timeScale, timeTol
      _RL effectiveTime, fraction
      _RL temp0, temp1, n0, n1
      LOGICAL valid0, valid1, freshBracket
      LOGICAL near0, near1, compareValid, diffValid
      LOGICAL mixValid
#endif

      stageTemp = 0. _d 0
      stageN = 0. _d 0
      pointValid = .FALSE.
      interpValid = .FALSE.
      failCode = BOM_FAIL_BIOLOGY_CONFIG
      failStage = BOM_STAGE_FIELD_OLD
      p4FailPhase = BOM_P4_PHASE_ENDPOINT

#ifdef ALLOW_BOM
      IF ( .NOT.bomUseBiology ) RETURN
      tempCode = BOM_BIO_TEMP_NONE
      nCode = BOM_BIO_N_NONE
      IF ( bomTempSource.EQ.'THETA' )
     &     tempCode = BOM_BIO_TEMP_THETA
      IF ( bomNSource.EQ.'PTRACER' )
     &     nCode = BOM_BIO_N_PTRACER
      IF ( bomNSource.EQ.'FILES' ) nCode = BOM_BIO_N_FILES
      IF ( tempCode.EQ.BOM_BIO_TEMP_NONE .OR.
     &     nCode.EQ.BOM_BIO_N_NONE ) RETURN
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy ) RETURN
      IF ( bi.LT.myBxLo(myThid) .OR. bi.GT.myBxHi(myThid)
     &     .OR. bj.LT.myByLo(myThid)
     &     .OR. bj.GT.myByHi(myThid) ) RETURN
      IF ( i.LT.1-OLx .OR. i.GT.sNx+OLx .OR.
     &     j.LT.1-OLy .OR. j.GT.sNy+OLy ) RETURN

      failCode = BOM_FAIL_BIOLOGY_FIELD
      IF ( .NOT.bomBioReady ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(stageTime) ) RETURN
      time0 = bomBioTime(BOM_ENV_OLD)
      time1 = bomBioTime(BOM_ENV_NEW)
      iter0 = bomBioIter(BOM_ENV_OLD)
      iter1 = bomBioIter(BOM_ENV_NEW)
      IF ( bomBioTempSource(BOM_ENV_OLD).NE.tempCode .OR.
     &     bomBioTempSource(BOM_ENV_NEW).NE.tempCode .OR.
     &     bomBioNSource(BOM_ENV_OLD).NE.nCode .OR.
     &     bomBioNSource(BOM_ENV_NEW).NE.nCode ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(time0) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(time1) ) THEN
        failStage = BOM_STAGE_FIELD_NEW
        RETURN
      ENDIF

      freshBracket = time1.EQ.time0
      interval = 0. _d 0
      IF ( freshBracket ) THEN
        IF ( iter1.NE.iter0 ) THEN
          failStage = BOM_STAGE_FIELD_NEW
          RETURN
        ENDIF
      ELSE
        failStage = BOM_STAGE_FIELD_NEW
        IF ( time1.LT.time0 ) RETURN
        IF ( .NOT.IEEE_IS_FINITE(deltaTClock) ) RETURN
        IF ( deltaTClock.LE.0. _d 0 ) RETURN
        CALL BOM_NONNEG_TIME_DIFF(
     I       time1, time0,
     O       interval, diffValid )
        IF ( .NOT.diffValid .OR. interval.LE.0. _d 0 ) RETURN
        timeScale = MAX(oneRL,ABS(interval),ABS(deltaTClock))
        timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
        CALL BOM_TIME_NEAR(
     I       interval, deltaTClock, timeTol,
     O       near1, compareValid )
        IF ( .NOT.compareValid .OR. .NOT.near1 ) RETURN
        IF ( iter0.GE.HUGE(iter0) ) RETURN
        IF ( iter1.NE.iter0+1 ) RETURN
      ENDIF

      timeScale = MAX(oneRL,ABS(time0),ABS(time1),
     &                ABS(stageTime),ABS(interval))
      timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
      IF ( .NOT.IEEE_IS_FINITE(timeTol) ) RETURN
      CALL BOM_TIME_NEAR(
     I     stageTime, time0, timeTol,
     O     near0, compareValid )
      IF ( .NOT.compareValid ) RETURN
      CALL BOM_TIME_NEAR(
     I     stageTime, time1, timeTol,
     O     near1, compareValid )
      IF ( .NOT.compareValid ) RETURN

      effectiveTime = stageTime
      selectedEnd = BOM_STAGE_NONE
      IF ( stageTime.EQ.time0 ) THEN
        selectedEnd = BOM_ENV_OLD
        effectiveTime = time0
      ELSEIF ( stageTime.EQ.time1 ) THEN
        selectedEnd = BOM_ENV_NEW
        effectiveTime = time1
      ELSEIF ( near0 .AND. near1 ) THEN
        IF ( ABS(stageTime-time0).LE.ABS(time1-stageTime) ) THEN
          selectedEnd = BOM_ENV_OLD
          effectiveTime = time0
        ELSE
          selectedEnd = BOM_ENV_NEW
          effectiveTime = time1
        ENDIF
      ELSEIF ( near0 ) THEN
        selectedEnd = BOM_ENV_OLD
        effectiveTime = time0
      ELSEIF ( near1 ) THEN
        selectedEnd = BOM_ENV_NEW
        effectiveTime = time1
      ENDIF
      IF ( selectedEnd.EQ.BOM_STAGE_NONE ) THEN
        IF ( stageTime.LT.time0 ) THEN
          failStage = BOM_STAGE_FIELD_OLD
          RETURN
        ELSEIF ( stageTime.GT.time1 ) THEN
          failStage = BOM_STAGE_FIELD_NEW
          RETURN
        ENDIF
      ENDIF

      temp0 = bomBioTemp(i,j,BOM_ENV_OLD,bi,bj)
      temp1 = bomBioTemp(i,j,BOM_ENV_NEW,bi,bj)
      n0 = bomBioN(i,j,BOM_ENV_OLD,bi,bj)
      n1 = bomBioN(i,j,BOM_ENV_NEW,bi,bj)
      valid0 = bomBioValid(i,j,BOM_ENV_OLD,bi,bj)
      valid1 = bomBioValid(i,j,BOM_ENV_NEW,bi,bj)
      failStage = BOM_STAGE_FIELD_OLD
      IF ( .NOT.IEEE_IS_FINITE(temp0) .OR.
     &     .NOT.IEEE_IS_FINITE(n0) ) RETURN
      IF ( n0.LT.0. _d 0 ) RETURN
      failStage = BOM_STAGE_FIELD_NEW
      IF ( .NOT.IEEE_IS_FINITE(temp1) .OR.
     &     .NOT.IEEE_IS_FINITE(n1) ) RETURN
      IF ( n1.LT.0. _d 0 ) RETURN

      IF ( freshBracket ) THEN
        IF ( temp1.NE.temp0 .OR. n1.NE.n0 .OR.
     &       (valid1.NEQV.valid0) ) RETURN
        stageTemp = temp0
        stageN = n0
        pointValid = valid0
      ELSEIF ( selectedEnd.EQ.BOM_ENV_OLD ) THEN
        stageTemp = temp0
        stageN = n0
        pointValid = valid0
      ELSEIF ( selectedEnd.EQ.BOM_ENV_NEW ) THEN
        stageTemp = temp1
        stageN = n1
        pointValid = valid1
      ELSE
        fraction = (effectiveTime-time0)/interval
        IF ( .NOT.IEEE_IS_FINITE(fraction) ) RETURN
        IF ( fraction.LT.0. _d 0 .OR. fraction.GT.oneRL ) RETURN
        CALL BOM_BIO_LINEAR_MIX(
     I       temp0, temp1, fraction,
     O       stageTemp, mixValid )
        IF ( .NOT.mixValid ) RETURN
        CALL BOM_BIO_LINEAR_MIX(
     I       n0, n1, fraction,
     O       stageN, mixValid )
        IF ( .NOT.mixValid .OR. stageN.LT.0. _d 0 ) THEN
          stageTemp = 0. _d 0
          stageN = 0. _d 0
          RETURN
        ENDIF
        pointValid = valid0 .AND. valid1
      ENDIF

      failCode = BOM_FAIL_NONE
      failStage = BOM_STAGE_NONE
      p4FailPhase = BOM_P4_PHASE_NONE
      interpValid = .TRUE.
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_BIO_LINEAR_MIX(
     I                 value0, value1, fraction,
     O                 value, isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      _RL value0, value1, fraction, value
      _RL scale, scaled
      LOGICAL isValid

      value = 0. _d 0
      isValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(value0) .OR.
     &     .NOT.IEEE_IS_FINITE(value1) .OR.
     &     .NOT.IEEE_IS_FINITE(fraction) ) RETURN
      IF ( fraction.LT.0. _d 0 .OR. fraction.GT.oneRL ) RETURN
      IF ( fraction.EQ.0. _d 0 ) THEN
        value = value0
      ELSEIF ( fraction.EQ.oneRL ) THEN
        value = value1
      ELSE
        scale = MAX(ABS(value0),ABS(value1))
        IF ( scale.GT.0. _d 0 ) THEN
          scaled = (oneRL-fraction)*(value0/scale)
     &           + fraction*(value1/scale)
          scaled = MAX(-oneRL,MIN(oneRL,scaled))
          value = scale*scaled
        ENDIF
      ENDIF
      isValid = IEEE_IS_FINITE(value)
      IF ( .NOT.isValid ) value = 0. _d 0

      RETURN
      END
