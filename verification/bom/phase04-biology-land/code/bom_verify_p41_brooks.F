#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P41_BROOKS( myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE, IEEE_VALUE, IEEE_QUIET_NAN
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*16 labels(13)
      _RL temps(13), nutrients(13)
      _RL tf, nf, rate, nanValue
      _RL savedMu, savedMort, savedKN, savedTMin, savedTMax
      _RL savedS0, savedSMin, savedSMax
      _RL sValue, sTrial, sCandidate, expected, tolerance
      INTEGER iCase, iStep, nFail, globalFail
      INTEGER failCode, p4Phase, eventType
      LOGICAL rateValid, planValid, missingGrowth

      DATA labels /
     & 't-below', 't-min', 't-lower', 't-opt', 't-upper',
     & 't-max', 't-above', 'n-negative', 'n-zero', 'n-small',
     & 'n-kn', 'n-large', 'n-extreme' /
      DATA temps /
     & 9. _d 0, 10. _d 0, 17.5 _d 0, 25. _d 0,
     & 32.5 _d 0, 40. _d 0, 41. _d 0,
     & 25. _d 0, 25. _d 0, 25. _d 0,
     & 25. _d 0, 25. _d 0, 25. _d 0 /
      DATA nutrients /
     & 2. _d 0, 2. _d 0, 2. _d 0, 2. _d 0,
     & 2. _d 0, 2. _d 0, 2. _d 0,
     & -1. _d 0, 0. _d 0, 1. _d -6,
     & 2. _d 0, 1. _d 6, 1. _d 300 /

      nFail = 0
      DO iCase=1,13
        CALL BOM_BROOKS_RATE(
     I       temps(iCase), nutrients(iCase),
     I       0.2 _d 0, 0.01 _d 0, 2. _d 0,
     I       10. _d 0, 40. _d 0,
     O       tf, nf, rate, failCode, rateValid )
        CALL BOM_VERIFY_P41_ASSERT(
     &       rateValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &       IEEE_IS_FINITE(tf) .AND. IEEE_IS_FINITE(nf) .AND.
     &       IEEE_IS_FINITE(rate),
     &       'finite Brooks reference row', nFail, myThid )
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,1X,A,3(1X,ES26.17E3))')
     &         'P41-BROOKS-RECORD', labels(iCase), tf, nf, rate
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                        SQUEEZE_RIGHT, myThid )
        ENDIF
        _END_MASTER(myThid)
      ENDDO
      CALL BOM_VERIFY_P41_ASSERT(
     &     nutrients(8).LT.0. _d 0,
     &     'negative-N row retained in oracle', nFail, myThid )
      CALL BOM_BROOKS_RATE(
     I     25. _d 0, -1. _d 0,
     I     0.2 _d 0, 0.01 _d 0, 2. _d 0,
     I     10. _d 0, 40. _d 0,
     O     tf, nf, rate, failCode, rateValid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     rateValid .AND. nf.EQ.0. _d 0 .AND.
     &     rate.EQ.-0.01 _d 0,
     &     'negative N equals zero N', nFail, myThid )
      nanValue = IEEE_VALUE(oneRL,IEEE_QUIET_NAN)
      CALL BOM_BROOKS_RATE(
     I     nanValue, oneRL, oneRL, 0. _d 0, oneRL,
     I     0. _d 0, 2. _d 0,
     O     tf, nf, rate, failCode, rateValid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     .NOT.rateValid .AND. failCode.EQ.BOM_FAIL_BROOKS,
     &     'nonfinite Brooks input fails 28', nFail, myThid )

C--   B12 uses a binary-exact constant law for analytical fixed-step rows.
      savedMu = bomMuMax
      savedMort = bomMort
      savedKN = bomKN
      savedTMin = bomTMin
      savedTMax = bomTMax
      savedS0 = bomS0
      savedSMin = bomSMin
      savedSMax = bomSMax
      bomMuMax = 0.25 _d 0
      bomMort = 0.0625 _d 0
      bomKN = oneRL
      bomTMin = 0. _d 0
      bomTMax = 2. _d 0
      bomS0 = oneRL
      bomSMin = -100. _d 0
      bomSMax = 100. _d 0
      sValue = oneRL
      DO iStep=1,16
        CALL BOM_BIOLOGY_PLAN(
     I       BOM_ALIVE, sValue, oneRL, oneRL, 2. _d 0, .TRUE.,
     O       tf, nf, rate, sTrial, sCandidate, eventType,
     O       missingGrowth, failCode, p4Phase, planValid )
        CALL BOM_VERIFY_P41_ASSERT(
     &       planValid .AND. eventType.EQ.BOM_EVENT_NONE,
     &       'B12 constant-field immutable plan', nFail, myThid )
        sValue = sCandidate
      ENDDO
      expected = oneRL+16. _d 0*2. _d 0
     &         *(0.25 _d 0*0.5 _d 0-0.0625 _d 0)
      tolerance = 64. _d 0*EPSILON(oneRL)*MAX(oneRL,ABS(expected))
      CALL BOM_VERIFY_P41_ASSERT(
     &     ABS(sValue-expected).LE.tolerance,
     &     'B12 analytical constant-field line', nFail, myThid )

      CALL BOM_BIOLOGY_PLAN(
     I     BOM_WAITING, 7. _d 0, nanValue, nanValue,
     I     0. _d 0, .FALSE.,
     O     tf, nf, rate, sTrial, sCandidate, eventType,
     O     missingGrowth, failCode, p4Phase, planValid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     planValid .AND. sCandidate.EQ.7. _d 0 .AND.
     &     eventType.EQ.BOM_EVENT_NONE,
     &     'still-WAITING receives no biology', nFail, myThid )
      CALL BOM_BIOLOGY_PLAN(
     I     BOM_ALIVE, oneRL, oneRL, oneRL,
     I     oneRL, .TRUE.,
     O     tf, nf, rate, sTrial, sCandidate, eventType,
     O     missingGrowth, failCode, p4Phase, planValid )
      expected = oneRL+(0.25 _d 0*0.5 _d 0-0.0625 _d 0)
      CALL BOM_VERIFY_P41_ASSERT(
     &     planValid .AND. sCandidate.EQ.expected,
     &     'mid-substep release uses dtActive only', nFail, myThid )

C--   Ordered strict thresholds: equality has no event; first crossing does.
      bomSMin = 0.5 _d 0
      bomSMax = 2. _d 0
      CALL BOM_BIOLOGY_PLAN(
     I     BOM_ALIVE, 1.9375 _d 0, oneRL, oneRL,
     I     oneRL, .TRUE.,
     O     tf, nf, rate, sTrial, sCandidate, eventType,
     O     missingGrowth, failCode, p4Phase, planValid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     planValid .AND. sTrial.EQ.2. _d 0 .AND.
     &     eventType.EQ.BOM_EVENT_NONE,
     &     'Smax equality creates no event', nFail, myThid )
      CALL BOM_BIOLOGY_PLAN(
     I     BOM_ALIVE, 1.9375 _d 0, oneRL, oneRL,
     I     2. _d 0, .TRUE.,
     O     tf, nf, rate, sTrial, sCandidate, eventType,
     O     missingGrowth, failCode, p4Phase, planValid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     planValid .AND. sTrial.GT.bomSMax .AND.
     &     eventType.EQ.BOM_EVENT_BIRTH .AND.
     &     sCandidate.EQ.bomS0,
     &     'first strict upper crossing proposes one birth',
     &     nFail, myThid )
      bomMuMax = 0. _d 0
      bomMort = 0.5 _d 0
      CALL BOM_BIOLOGY_PLAN(
     I     BOM_ALIVE, oneRL, oneRL, oneRL,
     I     oneRL, .TRUE.,
     O     tf, nf, rate, sTrial, sCandidate, eventType,
     O     missingGrowth, failCode, p4Phase, planValid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     planValid .AND. sTrial.EQ.bomSMin .AND.
     &     eventType.EQ.BOM_EVENT_NONE,
     &     'Smin equality creates no event', nFail, myThid )
      CALL BOM_BIOLOGY_PLAN(
     I     BOM_ALIVE, oneRL, oneRL, oneRL,
     I     2. _d 0, .TRUE.,
     O     tf, nf, rate, sTrial, sCandidate, eventType,
     O     missingGrowth, failCode, p4Phase, planValid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     planValid .AND. sTrial.LT.bomSMin .AND.
     &     eventType.EQ.BOM_EVENT_DEAD_BIO,
     &     'first strict lower crossing proposes death', nFail, myThid )

C--   Safe multiply/add must reject a forced amount overflow.
      bomMuMax = HUGE(oneRL)
      bomMort = 0. _d 0
      CALL BOM_BIOLOGY_PLAN(
     I     BOM_ALIVE, HUGE(oneRL), oneRL, HUGE(oneRL),
     I     2. _d 0, .TRUE.,
     O     tf, nf, rate, sTrial, sCandidate, eventType,
     O     missingGrowth, failCode, p4Phase, planValid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     .NOT.planValid .AND. failCode.EQ.BOM_FAIL_BROOKS,
     &     'forced amount overflow fails 28', nFail, myThid )

      bomMuMax = savedMu
      bomMort = savedMort
      bomKN = savedKN
      bomTMin = savedTMin
      bomTMax = savedTMax
      bomS0 = savedS0
      bomSMin = savedSMin
      bomSMax = savedSMax
      CALL BOM_VERIFY_P41_ASSERT(
     &     bomNPartTile(myBxLo(myThid),myByLo(myThid)).EQ.0,
     &     'P4.1 plans do not mutate owner counts', nFail, myThid )

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) CALL BOM_VERIFY_P41_ABORT(
     &     'BOM_VERIFY_P41_BROOKS', globalFail, myThid )
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P4-B01/B12 PASS: Brooks oracle rows and analytical plans'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif
      RETURN
      END
