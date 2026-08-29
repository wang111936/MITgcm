#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P41_INTERP( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*12 savedPolicy
      INTEGER nFail, globalFail, failCode, failStage, p4Phase
      INTEGER bi, bj, ii, jj
      _RL valueT, valueN, wetWeight, midTime, valueTol
      _RL sTrial, sCandidate, tf, nf, rate, expected
      _RS savedMask(0:1,0:1)
      LOGICAL pointValid, interpValid, missingGrowth, planValid
      INTEGER eventType

      nFail = 0
      bi = myBxLo(myThid)
      bj = myByLo(myThid)
      midTime = halfRL*(bomBioTime(BOM_ENV_OLD)
     &                  +bomBioTime(BOM_ENV_NEW))

C--   Exact endpoint and midpoint time interpolation.
      CALL BOM_INTERP_BIO_TIME(
     I     1, 1, bi, bj, bomBioTime(BOM_ENV_OLD),
     O     valueT, valueN, pointValid,
     O     failCode, failStage, p4Phase, interpValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     interpValid .AND. pointValid .AND.
     &     valueT.EQ.14. _d 0 .AND. valueN.EQ.4. _d 0,
     &     'exact OLD biology sample', nFail, myThid )
      CALL BOM_INTERP_BIO_TIME(
     I     1, 1, bi, bj, midTime,
     O     valueT, valueN, pointValid,
     O     failCode, failStage, p4Phase, interpValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     interpValid .AND. pointValid .AND.
     &     valueT.EQ.15. _d 0 .AND. valueN.EQ.5. _d 0,
     &     'exact midpoint biology sample', nFail, myThid )
      CALL BOM_INTERP_BIO_TIME(
     I     1, 1, bi, bj, bomBioTime(BOM_ENV_NEW),
     O     valueT, valueN, pointValid,
     O     failCode, failStage, p4Phase, interpValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     interpValid .AND. pointValid .AND.
     &     valueT.EQ.16. _d 0 .AND. valueN.EQ.6. _d 0,
     &     'exact NEW biology sample', nFail, myThid )
      CALL BOM_INTERP_BIO_TIME(
     I     1, 1, bi, bj, bomBioTime(BOM_ENV_NEW)+deltaTClock,
     O     valueT, valueN, pointValid,
     O     failCode, failStage, p4Phase, interpValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     .NOT.interpValid .AND.
     &     failCode.EQ.BOM_FAIL_BIOLOGY_FIELD .AND.
     &     p4Phase.EQ.BOM_P4_PHASE_ENDPOINT,
     &     'out-of-bracket time is failure 27', nFail, myThid )

C--   Exchanged low-overlap values exercise a periodic-X style stencil.
      CALL BOM_INTERP_BIO_PAIR(
     I     0.75 _d 0, 1.25 _d 0, bi, bj, midTime,
     O     valueT, valueN, wetWeight, pointValid,
     O     failCode, failStage, p4Phase, interpValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     interpValid .AND. pointValid .AND.
     &     valueT.EQ.15. _d 0 .AND. valueN.EQ.5. _d 0,
     &     'low-overlap common wet interpolation', nFail, myThid )

C--   Nonuniform space/time values have one common normalized wet sum.
      DO jj=0,1
       DO ii=0,1
        bomBioTemp(1+ii,1+jj,BOM_ENV_OLD,bi,bj) =
     &       10. _d 0+10. _d 0*DFLOAT(ii+2*jj)
        bomBioTemp(1+ii,1+jj,BOM_ENV_NEW,bi,bj) =
     &       14. _d 0+10. _d 0*DFLOAT(ii+2*jj)
        bomBioN(1+ii,1+jj,BOM_ENV_OLD,bi,bj) =
     &       2. _d 0+2. _d 0*DFLOAT(ii+2*jj)
        bomBioN(1+ii,1+jj,BOM_ENV_NEW,bi,bj) =
     &       4. _d 0+2. _d 0*DFLOAT(ii+2*jj)
        bomBioValid(1+ii,1+jj,BOM_ENV_OLD,bi,bj) = .TRUE.
        bomBioValid(1+ii,1+jj,BOM_ENV_NEW,bi,bj) = .TRUE.
        savedMask(ii,jj) = maskC(1+ii,1+jj,1,bi,bj)
        maskC(1+ii,1+jj,1,bi,bj) = 1.
       ENDDO
      ENDDO
      CALL BOM_INTERP_BIO_PAIR(
     I     1.25 _d 0, 1.5 _d 0, bi, bj, midTime,
     O     valueT, valueN, wetWeight, pointValid,
     O     failCode, failStage, p4Phase, interpValid,
     I     myThid )
      valueTol = 256. _d 0*EPSILON(oneRL)
     &         *MAX(oneRL,ABS(valueT),ABS(valueN))
      CALL BOM_VERIFY_P41_ASSERT(
     &     interpValid .AND. pointValid .AND.
     &     ABS(valueT-24.5 _d 0).LE.valueTol .AND.
     &     ABS(valueN-5.5 _d 0).LE.valueTol .AND.
     &     wetWeight.EQ.oneRL,
     &     'nonuniform common wet weights', nFail, myThid )

C--   Removing the 0.375 corner leaves an allowed 0.625 stencil.
      maskC(1,1,1,bi,bj) = 0.
      CALL BOM_INTERP_BIO_PAIR(
     I     1.25 _d 0, 1.5 _d 0, bi, bj, midTime,
     O     valueT, valueN, wetWeight, pointValid,
     O     failCode, failStage, p4Phase, interpValid,
     I     myThid )
      valueTol = 256. _d 0*EPSILON(oneRL)
     &         *MAX(oneRL,ABS(valueT),ABS(valueN))
      CALL BOM_VERIFY_P41_ASSERT(
     &     interpValid .AND. pointValid .AND.
     &     ABS(valueT-32. _d 0).LE.valueTol .AND.
     &     ABS(valueN-7. _d 0).LE.valueTol .AND.
     &     wetWeight.EQ.0.625 _d 0,
     &     'partial wet stencil renormalizes the pair', nFail, myThid )

C--   Only the 0.125 corner remains: return a missing sample for policy.
      maskC(2,1,1,bi,bj) = 0.
      maskC(1,2,1,bi,bj) = 0.
      CALL BOM_INTERP_BIO_PAIR(
     I     1.25 _d 0, 1.5 _d 0, bi, bj, midTime,
     O     valueT, valueN, wetWeight, pointValid,
     O     failCode, failStage, p4Phase, interpValid,
     I     myThid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     interpValid .AND. .NOT.pointValid .AND.
     &     wetWeight.EQ.0.125 _d 0,
     &     'insufficient wet weight is an explicit missing sample',
     &     nFail, myThid )

      savedPolicy = bomBiologyMissingPolicy
      bomBiologyMissingPolicy = 'STOP'
      CALL BOM_BIOLOGY_PLAN(
     I     BOM_ALIVE, oneRL, valueT, valueN, 10. _d 0,
     I     pointValid,
     O     tf, nf, rate, sTrial, sCandidate, eventType,
     O     missingGrowth, failCode, p4Phase, planValid )
      CALL BOM_VERIFY_P41_ASSERT(
     &     .NOT.planValid .AND.
     &     failCode.EQ.BOM_FAIL_BIOLOGY_FIELD .AND.
     &     p4Phase.EQ.BOM_P4_PHASE_ENDPOINT .AND.
     &     sCandidate.EQ.oneRL,
     &     'STOP fails without an amount candidate mutation',
     &     nFail, myThid )
      bomBiologyMissingPolicy = 'NO_GROWTH'
      CALL BOM_BIOLOGY_PLAN(
     I     BOM_ALIVE, oneRL, valueT, valueN, 10. _d 0,
     I     pointValid,
     O     tf, nf, rate, sTrial, sCandidate, eventType,
     O     missingGrowth, failCode, p4Phase, planValid )
      expected = oneRL-10. _d 0*bomMort
      CALL BOM_VERIFY_P41_ASSERT(
     &     planValid .AND. missingGrowth .AND.
     &     tf.EQ.0. _d 0 .AND. nf.EQ.0. _d 0 .AND.
     &     rate.EQ.-bomMort .AND. sTrial.EQ.expected .AND.
     &     eventType.EQ.BOM_EVENT_NONE,
     &     'NO_GROWTH retains mortality only', nFail, myThid )
      bomBiologyMissingPolicy = savedPolicy

      DO jj=0,1
       DO ii=0,1
        maskC(1+ii,1+jj,1,bi,bj) = savedMask(ii,jj)
       ENDDO
      ENDDO
      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) CALL BOM_VERIFY_P41_ABORT(
     &     'BOM_VERIFY_P41_INTERP', globalFail, myThid )
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P4-E02 PASS: exact time, wet weights, missing policy'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif
      RETURN
      END
