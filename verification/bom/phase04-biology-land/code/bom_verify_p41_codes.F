#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P41_CODES_CONFIG( myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE, IEEE_VALUE, IEEE_QUIET_NAN
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*8 savedMode, savedTemp, savedN
      CHARACTER*12 savedPolicy
      CHARACTER*(MAX_LEN_FNAM) savedNFile
      INTEGER nFail, globalFail, failCode
      INTEGER savedTry, savedTracer, savedPrec
      _RL savedKN, savedTMin, savedTMax, savedS0, savedSMin
      _RL savedSMax, savedL, savedPeriod, savedScale, savedRate
      LOGICAL configValid, savedLand

      nFail = 0
      CALL BOM_VERIFY_P41_ASSERT(
     &     BOM_UNUSED.EQ.0 .AND. BOM_WAITING.EQ.6 .AND.
     &     BOM_FAIL_PICKUP_SCHEMA3.EQ.25 .AND.
     &     BOM_P3_PHASE_SCHEMA3.EQ.9,
     &     'released status/failure/phase codes unchanged',
     &     nFail, myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     BOM_FAIL_BIOLOGY_CONFIG.EQ.26 .AND.
     &     BOM_FAIL_BIOLOGY_FIELD.EQ.27 .AND.
     &     BOM_FAIL_BROOKS.EQ.28 .AND.
     &     BOM_FAIL_BOUNDARY_EVENT.EQ.29 .AND.
     &     BOM_FAIL_EVENT_CAPACITY.EQ.30 .AND.
     &     BOM_FAIL_EVENT_TRANSACTION.EQ.31 .AND.
     &     BOM_FAIL_BIRTH_CAPACITY.EQ.32 .AND.
     &     BOM_FAIL_BIRTH_RNG.EQ.33 .AND.
     &     BOM_FAIL_BIRTH_ID.EQ.34 .AND.
     &     BOM_FAIL_PICKUP_SCHEMA4.EQ.35 .AND.
     &     BOM_FAIL_EVENT_IO.EQ.36 .AND.
     &     BOM_FAIL_EVENT_BUDGET.EQ.37,
     &     'P4 failure codes 26 through 37', nFail, myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     BOM_EVENT_NONE.EQ.0 .AND. BOM_EVENT_BIRTH.EQ.1 .AND.
     &     BOM_EVENT_DEAD_BIO.EQ.2 .AND.
     &     BOM_EVENT_BEACHED.EQ.3 .AND.
     &     BOM_EVENT_OUTSIDE.EQ.4 .AND.
     &     BOM_EVENT_BIRTH_CANCEL.EQ.5,
     &     'P4 event codes 0 through 5', nFail, myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     BOM_P4_PHASE_NONE.EQ.0 .AND.
     &     BOM_P4_PHASE_ENDPOINT.EQ.1 .AND.
     &     BOM_P4_PHASE_BOUNDARY.EQ.2 .AND.
     &     BOM_P4_PHASE_BIOLOGY.EQ.3 .AND.
     &     BOM_P4_PHASE_TERMINAL.EQ.4 .AND.
     &     BOM_P4_PHASE_BIRTH_ORDER.EQ.5 .AND.
     &     BOM_P4_PHASE_BIRTH_PLACE.EQ.6 .AND.
     &     BOM_P4_PHASE_CAPACITY.EQ.7 .AND.
     &     BOM_P4_PHASE_GRAPH.EQ.8 .AND.
     &     BOM_P4_PHASE_SCHEMA4.EQ.9 .AND.
     &     BOM_P4_PHASE_EVENT_IO.EQ.10 .AND.
     &     BOM_P4_PHASE_BUDGET.EQ.11,
     &     'P4 operation phase codes 0 through 11', nFail, myThid )

      CALL BOM_VALIDATE_BIOLOGY_CONFIG(
     O     failCode, configValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     configValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     IEEE_IS_FINITE(bomMuMax) .AND.
     &     IEEE_IS_FINITE(bomMort) .AND.
     &     bomMuMax.EQ.bomMuMaxDay/86400. _d 0 .AND.
     &     bomMort.EQ.bomMortDay/86400. _d 0,
     &     'valid THETA/PTRACER and one rate conversion',
     &     nFail, myThid )

C--   Save the accepted configuration and exercise the stateless negatives.
      savedMode = bomMode
      savedTemp = bomTempSource
      savedN = bomNSource
      savedPolicy = bomBiologyMissingPolicy
      savedNFile = bomNFile
      savedLand = bomUseLand
      savedKN = bomKN
      savedTMin = bomTMin
      savedTMax = bomTMax
      savedS0 = bomS0
      savedSMin = bomSMin
      savedSMax = bomSMax
      savedL = bomSpringL
      savedPeriod = bomNPeriod
      savedScale = bomNInScale
      savedTry = bomBirthMaxTry
      savedTracer = bomNTracerIndex
      savedPrec = bomNFilePrec
      savedRate = bomMuMax

      bomMode = 'LEEW'
      CALL BOM_VERIFY_P41_REJECT( 'LEEW biology', nFail, myThid )
      bomMode = savedMode
      bomUseLand = .FALSE.
      CALL BOM_VERIFY_P41_REJECT(
     &     'biology without land', nFail, myThid )
      bomUseLand = savedLand
      bomTempSource = 'NONE'
      CALL BOM_VERIFY_P41_REJECT( 'missing THETA', nFail, myThid )
      bomTempSource = savedTemp
      bomNSource = 'NONE'
      CALL BOM_VERIFY_P41_REJECT( 'missing nutrient', nFail, myThid )
      bomNSource = savedN
      bomBiologyMissingPolicy = 'BAD'
      CALL BOM_VERIFY_P41_REJECT( 'bad missing policy', nFail, myThid )
      bomBiologyMissingPolicy = savedPolicy
      bomKN = 0. _d 0
      CALL BOM_VERIFY_P41_REJECT( 'zero kN', nFail, myThid )
      bomKN = savedKN
      bomTMin = savedTMax
      CALL BOM_VERIFY_P41_REJECT( 'invalid T range', nFail, myThid )
      bomTMin = savedTMin
      bomS0 = savedSMax
      CALL BOM_VERIFY_P41_REJECT( 'invalid S range', nFail, myThid )
      bomS0 = savedS0
      bomBirthMaxTry = 0
      CALL BOM_VERIFY_P41_REJECT( 'zero birth tries', nFail, myThid )
      bomBirthMaxTry = savedTry
      bomSpringL = 0. _d 0
      CALL BOM_VERIFY_P41_REJECT( 'zero birth distance', nFail, myThid )
      bomSpringL = savedL
      bomMuMaxDay = IEEE_VALUE(bomMuMaxDay,IEEE_QUIET_NAN)
      CALL BOM_VERIFY_P41_REJECT( 'nonfinite biology', nFail, myThid )
      bomMuMaxDay = 0.20 _d 0

C--   FILES is valid only with complete positive timing/precision metadata.
      bomNSource = 'FILES'
      bomNFile = 'fixture'
      bomNPeriod = 1200. _d 0
      bomNRepCycle = 2400. _d 0
      bomNInScale = oneRL
      bomNFilePrec = 64
      CALL BOM_VALIDATE_BIOLOGY_CONFIG(
     O     failCode, configValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     configValid .AND. failCode.EQ.BOM_FAIL_NONE,
     &     'valid THETA/FILES configuration', nFail, myThid )
      bomNPeriod = 0. _d 0
      CALL BOM_VERIFY_P41_REJECT( 'bad FILES period', nFail, myThid )
      bomNPeriod = 1200. _d 0
      bomNInScale = 0. _d 0
      CALL BOM_VERIFY_P41_REJECT( 'bad FILES scale', nFail, myThid )
      bomNInScale = oneRL
      bomNFilePrec = 16
      CALL BOM_VERIFY_P41_REJECT(
     &     'bad FILES precision', nFail, myThid )

      bomMode = savedMode
      bomTempSource = savedTemp
      bomNSource = savedN
      bomBiologyMissingPolicy = savedPolicy
      bomNFile = savedNFile
      bomUseLand = savedLand
      bomKN = savedKN
      bomTMin = savedTMin
      bomTMax = savedTMax
      bomS0 = savedS0
      bomSMin = savedSMin
      bomSMax = savedSMax
      bomSpringL = savedL
      bomNPeriod = savedPeriod
      bomNInScale = savedScale
      bomBirthMaxTry = savedTry
      bomNTracerIndex = savedTracer
      bomNFilePrec = savedPrec
      CALL BOM_VALIDATE_BIOLOGY_CONFIG(
     O     failCode, configValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     configValid .AND. bomMuMax.EQ.savedRate,
     &     'configuration restored exactly', nFail, myThid )

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) CALL BOM_VERIFY_P41_ABORT(
     &     'BOM_VERIFY_P41_CODES_CONFIG', globalFail, myThid )
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P4-C01 PASS: codes, PTRACER/FILES config, negatives'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P41_REJECT( label, nFail, myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) label
      INTEGER nFail, myThid, failCode
      LOGICAL configValid
      CALL BOM_VALIDATE_BIOLOGY_CONFIG(
     O     failCode, configValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     .NOT.configValid .AND.
     &     failCode.EQ.BOM_FAIL_BIOLOGY_CONFIG,
     &     label, nFail, myThid )
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P41_ASSERT(
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
          WRITE(msgBuf,'(A,A)') 'P4.1 assertion failed: ', label
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        nFail = nFail+1
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P41_ABORT( routine, nFail, myThid )
      IMPLICIT NONE
#include "EEPARAMS.h"
      CHARACTER*(*) routine
      INTEGER nFail, myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A,A,A,I8)') 'P4.1 ', routine,
     &       ': failures=', nFail
        CALL PRINT_ERROR( msgBuf, myThid )
      ENDIF
      _END_MASTER(myThid)
      CALL ALL_PROC_DIE( 0 )
      STOP 'ABNORMAL END: P4.1 DIRECT GATE'
      END
