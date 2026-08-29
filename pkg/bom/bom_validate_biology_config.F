#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VALIDATE_BIOLOGY_CONFIG
C !INTERFACE:
      SUBROUTINE BOM_VALIDATE_BIOLOGY_CONFIG(
     O                 failCode, configValid,
     I                 myThid )

C !DESCRIPTION:
C     Validate the frozen P4.1 parameter contract without changing
C     accepted fields or particle state.  Derived rates are published only
C     after the complete configuration succeeds.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#ifdef ALLOW_PTRACERS
# include "PTRACERS_SIZE.h"
# include "PTRACERS_PARAMS.h"
#endif
#include "BOM_SIZE.h"
#include "BOM.h"

C !OUTPUT PARAMETERS:
      INTEGER failCode
      LOGICAL configValid

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      _RL muCandidate, mortCandidate, cycleRecords
      LOGICAL localValid

      failCode = BOM_FAIL_BIOLOGY_CONFIG
      configValid = .FALSE.
      localValid = .TRUE.
      muCandidate = 0. _d 0
      mortCandidate = 0. _d 0

C--   Biology-disabled land tracking is the P4.2 production subset.  It
C     remains BOM-only and fail-closes persistence until schema 4 arrives.
      IF ( .NOT.bomUseBiology ) THEN
        IF ( bomTempSource.NE.'NONE' ) localValid = .FALSE.
        IF ( bomNSource.NE.'NONE' ) localValid = .FALSE.
        IF ( bomBiologyMissingPolicy.NE.'STOP' .AND.
     &       bomBiologyMissingPolicy.NE.'NO_GROWTH' )
     &       localValid = .FALSE.
        IF ( bomUseLand ) THEN
          IF ( bomMode.NE.'BOM' ) localValid = .FALSE.
          IF ( bomOutputFreq.NE.0. _d 0 .OR.
     &         bomPickupFreq.NE.0. _d 0 ) localValid = .FALSE.
          IF ( nIter0.NE.bomInitialIter ) localValid = .FALSE.
        ENDIF
        IF ( localValid ) THEN
          failCode = BOM_FAIL_NONE
          configValid = .TRUE.
        ENDIF
        RETURN
      ENDIF

C--   P4 biology is BOM-only and every possible child needs land checks.
      IF ( bomMode.NE.'BOM' ) localValid = .FALSE.
      IF ( .NOT.bomUseLand ) localValid = .FALSE.
      IF ( bomTempSource.NE.'THETA' ) localValid = .FALSE.
      IF ( bomNSource.NE.'PTRACER' .AND.
     &     bomNSource.NE.'FILES' ) localValid = .FALSE.
      IF ( bomBiologyMissingPolicy.NE.'STOP' .AND.
     &     bomBiologyMissingPolicy.NE.'NO_GROWTH' )
     &     localValid = .FALSE.

      IF ( .NOT.IEEE_IS_FINITE(bomMuMaxDay) ) THEN
        localValid = .FALSE.
      ELSEIF ( bomMuMaxDay.LT.0. _d 0 ) THEN
        localValid = .FALSE.
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(bomMortDay) ) THEN
        localValid = .FALSE.
      ELSEIF ( bomMortDay.LT.0. _d 0 ) THEN
        localValid = .FALSE.
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(bomKN) ) THEN
        localValid = .FALSE.
      ELSEIF ( bomKN.LE.0. _d 0 ) THEN
        localValid = .FALSE.
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(bomTMin) .OR.
     &     .NOT.IEEE_IS_FINITE(bomTMax) ) THEN
        localValid = .FALSE.
      ELSEIF ( bomTMin.GE.bomTMax ) THEN
        localValid = .FALSE.
      ENDIF
      IF ( .NOT.IEEE_IS_FINITE(bomS0) .OR.
     &     .NOT.IEEE_IS_FINITE(bomSMin) .OR.
     &     .NOT.IEEE_IS_FINITE(bomSMax) ) THEN
        localValid = .FALSE.
      ELSEIF ( bomSMin.GE.bomS0 .OR. bomS0.GE.bomSMax ) THEN
        localValid = .FALSE.
      ENDIF
      IF ( bomBirthMaxTry.LT.1 ) localValid = .FALSE.
      IF ( .NOT.IEEE_IS_FINITE(bomSpringL) ) THEN
        localValid = .FALSE.
      ELSEIF ( bomSpringL.LE.0. _d 0 ) THEN
        localValid = .FALSE.
      ENDIF

      IF ( bomNSource.EQ.'PTRACER' ) THEN
#ifndef ALLOW_PTRACERS
        localValid = .FALSE.
#else
        IF ( .NOT.usePTRACERS ) localValid = .FALSE.
        IF ( bomNTracerIndex.LT.1 .OR.
     &       bomNTracerIndex.GT.PTRACERS_num .OR.
     &       bomNTracerIndex.GT.PTRACERS_numInUse )
     &       localValid = .FALSE.
#endif
      ELSEIF ( bomNSource.EQ.'FILES' ) THEN
        IF ( bomNFile.EQ.' ' ) localValid = .FALSE.
        IF ( .NOT.IEEE_IS_FINITE(bomNStartTime) )
     &       localValid = .FALSE.
        IF ( .NOT.IEEE_IS_FINITE(bomNPeriod) ) THEN
          localValid = .FALSE.
        ELSEIF ( bomNPeriod.LE.0. _d 0 ) THEN
          localValid = .FALSE.
        ENDIF
        IF ( .NOT.IEEE_IS_FINITE(bomNRepCycle) ) THEN
          localValid = .FALSE.
        ELSEIF ( bomNRepCycle.LT.0. _d 0 ) THEN
          localValid = .FALSE.
        ENDIF
        IF ( .NOT.IEEE_IS_FINITE(bomNInScale) ) THEN
          localValid = .FALSE.
        ELSEIF ( bomNInScale.LE.0. _d 0 ) THEN
          localValid = .FALSE.
        ENDIF
        IF ( bomNFilePrec.NE.32 .AND. bomNFilePrec.NE.64 )
     &       localValid = .FALSE.
        IF ( IEEE_IS_FINITE(bomNPeriod) .AND.
     &       IEEE_IS_FINITE(bomNRepCycle) ) THEN
          IF ( bomNPeriod.GT.0. _d 0 .AND.
     &         bomNRepCycle.GT.0. _d 0 ) THEN
            IF ( bomNPeriod.LT.bomNRepCycle/HUGE(oneRL) ) THEN
              localValid = .FALSE.
            ELSE
              cycleRecords = ANINT(bomNRepCycle/bomNPeriod)
              IF ( .NOT.IEEE_IS_FINITE(cycleRecords) ) THEN
                localValid = .FALSE.
              ELSEIF ( cycleRecords.LT.1. _d 0 .OR.
     &                 bomNRepCycle.NE.cycleRecords*bomNPeriod ) THEN
                localValid = .FALSE.
              ENDIF
            ENDIF
          ENDIF
        ENDIF
      ENDIF

C--   P4.1 has no schema-4 persistence and no live event commit yet.
      IF ( bomOutputFreq.NE.0. _d 0 .OR.
     &     bomPickupFreq.NE.0. _d 0 ) localValid = .FALSE.
      IF ( nIter0.NE.bomInitialIter ) localValid = .FALSE.
      IF ( bomMaxParticles.GT.0 ) localValid = .FALSE.

      IF ( localValid ) THEN
        muCandidate = bomMuMaxDay/86400. _d 0
        mortCandidate = bomMortDay/86400. _d 0
        IF ( .NOT.IEEE_IS_FINITE(muCandidate) .OR.
     &       .NOT.IEEE_IS_FINITE(mortCandidate) )
     &       localValid = .FALSE.
      ENDIF
      IF ( .NOT.localValid ) RETURN

      bomMuMax = muCandidate
      bomMort = mortCandidate
      failCode = BOM_FAIL_NONE
      configValid = .TRUE.
#else
      failCode = BOM_FAIL_BIOLOGY_CONFIG
      configValid = .FALSE.
#endif

      RETURN
      END
