#include "BOM_OPTIONS.h"
#ifdef ALLOW_EXF
# include "EXF_OPTIONS.h"
#endif

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_CHECK

C !INTERFACE:
      SUBROUTINE BOM_CHECK( myThid )

C !DESCRIPTION:
C     Validate the Phase-1.5 setup, state, migration, and restart controls.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#ifdef ALLOW_EXF
# include "EXF_PARAM.h"
#endif
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER errCount, nSub
      _RL subRatio, dtSub
      LOGICAL deltaTFinite, targetFinite, outputFinite
      LOGICAL pickupFinite, coeffFinite, wetFinite, cflFinite
      LOGICAL alphaFinite, tauDaysFinite, rFinite, sigmaFinite
      LOGICAL stokesStartFinite, stokesPeriodFinite
      LOGICAL stokesRepFinite, stokesScaleFinite
      LOGICAL tauDaysInRange

      _BEGIN_MASTER(myThid)

      WRITE(msgBuf,'(A)')
     &     'BOM_CHECK: Phase-1.4 setup, state, and migration gate'
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)')
     &     'BOM_CHECK: Phase-1.5 restart and output extensions'
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )
      CALL WRITE_0D_C( bomMode, -1, INDEX_NONE,
     &     'bomMode =', ' /* BOM formulation */')
      CALL WRITE_0D_C( bomEquationMode, -1, INDEX_NONE,
     &     'bomEquationMode =', ' /* equation convention */')
      CALL WRITE_0D_C( bomIntegrator, -1, INDEX_NONE,
     &     'bomIntegrator =', ' /* time integrator */')
      CALL WRITE_0D_RL( bomDeltaTTarget, INDEX_NONE,
     &     'bomDeltaTTarget =', ' /* target particle step [s] */')
      CALL WRITE_0D_I( bomMaxParticles, INDEX_NONE,
     &     'bomMaxParticles =', ' /* global runtime upper bound */')
      CALL WRITE_0D_I( bomInitGlobalLimit, INDEX_NONE,
     &     'bomInitGlobalLimit =', ' /* global input hard limit */')
      CALL WRITE_0D_I( bomInitialIter, INDEX_NONE,
     &     'bomInitialIter =', ' /* fresh BOM initial iteration */')
      CALL WRITE_0D_C( bomWindSource, -1, INDEX_NONE,
     &     'bomWindSource =', ' /* NONE or EXF */')
      CALL WRITE_0D_C( bomStokesSource, -1, INDEX_NONE,
     &     'bomStokesSource =', ' /* NONE, FILES, COUPLER */')
      CALL WRITE_0D_C( bomCurrentPolicy, -1, INDEX_NONE,
     &     'bomCurrentPolicy =', ' /* explicit current policy */')

      errCount = 0
      nSub = 0
      subRatio = 0. _d 0
      dtSub = 0. _d 0
      deltaTFinite = IEEE_IS_FINITE(deltaTClock)
      targetFinite = IEEE_IS_FINITE(bomDeltaTTarget)
      outputFinite = IEEE_IS_FINITE(bomOutputFreq)
      pickupFinite = IEEE_IS_FINITE(bomPickupFreq)
      coeffFinite = IEEE_IS_FINITE(bomLeewayWindCoeff)
      wetFinite = IEEE_IS_FINITE(bomWetWeightMin)
      cflFinite = IEEE_IS_FINITE(bomAdvCFL)
      alphaFinite = IEEE_IS_FINITE(bomAlpha)
      tauDaysFinite = IEEE_IS_FINITE(bomTauDays)
      rFinite = IEEE_IS_FINITE(bomR)
      sigmaFinite = IEEE_IS_FINITE(bomSigma)
      stokesStartFinite = IEEE_IS_FINITE(bomStokesStartTime)
      stokesPeriodFinite = IEEE_IS_FINITE(bomStokesPeriod)
      stokesRepFinite = IEEE_IS_FINITE(bomStokesRepCycle)
      stokesScaleFinite = IEEE_IS_FINITE(bomStokesInScale)
      tauDaysInRange = .FALSE.
      bomTau = 0. _d 0

      IF ( bomMode.NE.'LEEW' .AND.
     &     bomMode.NE.'BOM' ) THEN
        WRITE(msgBuf,'(A,A)')
     &       'BOM_CHECK: unsupported bomMode: ', bomMode
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomEquationMode.NE.'PAPER2024' .AND.
     &     bomEquationMode.NE.'JULIA' ) THEN
        WRITE(msgBuf,'(A,A)')
     &       'BOM_CHECK: unsupported bomEquationMode: ',
     &       bomEquationMode
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomIntegrator.NE.'RK2' .AND.
     &     bomIntegrator.NE.'RK4' ) THEN
        WRITE(msgBuf,'(A,A)')
     &       'BOM_CHECK: unsupported bomIntegrator: ',
     &       bomIntegrator
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

C--   Phase-2 slow-manifold parameters are active only in BOM mode.
      IF ( bomMode.EQ.'BOM' ) THEN
        IF ( bomCurrentPolicy.NE.'EULERIAN' .AND.
     &       bomCurrentPolicy.NE.'PRECOMBINED' ) THEN
          WRITE(msgBuf,'(A,A)')
     &         'BOM_CHECK: BOM requires explicit current policy: ',
     &         bomCurrentPolicy
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF

        IF ( .NOT.alphaFinite ) THEN
          WRITE(msgBuf,'(A,1PE24.16)')
     &         'BOM_CHECK: non-finite bomAlpha=', bomAlpha
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ELSEIF ( bomAlpha.LT.0. _d 0 .OR.
     &           bomAlpha.GT.1. _d 0 ) THEN
          WRITE(msgBuf,'(A,1PE24.16)')
     &         'BOM_CHECK: bomAlpha outside [0,1]=', bomAlpha
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF

        IF ( .NOT.tauDaysFinite ) THEN
          WRITE(msgBuf,'(A,1PE24.16)')
     &         'BOM_CHECK: non-finite bomTauDays=', bomTauDays
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ELSEIF ( bomTauDays.LT.0. _d 0 ) THEN
          WRITE(msgBuf,'(A,1PE24.16)')
     &         'BOM_CHECK: negative bomTauDays=', bomTauDays
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ELSEIF ( bomTauDays.GT.
     &           HUGE(oneRL)/86400. _d 0 ) THEN
          WRITE(msgBuf,'(A,1PE24.16)')
     &         'BOM_CHECK: bomTauDays overflows seconds=',
     &         bomTauDays
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ELSE
          tauDaysInRange = .TRUE.
          bomTau = 86400. _d 0*bomTauDays
        ENDIF
        IF ( tauDaysInRange ) THEN
          IF ( .NOT.IEEE_IS_FINITE(bomTau) ) THEN
            WRITE(msgBuf,'(A,1PE24.16)')
     &           'BOM_CHECK: non-finite derived bomTau=', bomTau
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
        ENDIF

        IF ( .NOT.rFinite ) THEN
          WRITE(msgBuf,'(A,1PE24.16)')
     &         'BOM_CHECK: non-finite bomR=', bomR
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ELSEIF ( bomR.LE.0. _d 0 .OR. bomR.GT.1. _d 0 ) THEN
          WRITE(msgBuf,'(A,1PE24.16)')
     &         'BOM_CHECK: bomR outside (0,1]=', bomR
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF

        IF ( .NOT.sigmaFinite ) THEN
          WRITE(msgBuf,'(A,1PE24.16)')
     &         'BOM_CHECK: non-finite bomSigma=', bomSigma
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ELSEIF ( bomSigma.LT.0. _d 0 ) THEN
          WRITE(msgBuf,'(A,1PE24.16)')
     &         'BOM_CHECK: negative bomSigma=', bomSigma
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF

        IF ( bomWindSource.EQ.'NONE' .AND. alphaFinite ) THEN
          IF ( bomAlpha.NE.0. _d 0 ) THEN
            WRITE(msgBuf,'(A,1PE24.16)')
     &           'BOM_CHECK: wind source=NONE requires alpha=0:',
     &           bomAlpha
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
        ENDIF

        IF ( bomStokesSource.EQ.'NONE' ) THEN
          IF ( sigmaFinite ) THEN
            IF ( bomSigma.NE.0. _d 0 ) THEN
              WRITE(msgBuf,'(A,1PE24.16)')
     &             'BOM_CHECK: Stokes source=NONE requires sigma=0:',
     &             bomSigma
              CALL PRINT_ERROR( msgBuf, myThid )
              errCount = errCount + 1
            ENDIF
          ENDIF
        ELSEIF ( bomStokesSource.EQ.'FILES' ) THEN
          IF ( bomCurrentPolicy.EQ.'PRECOMBINED' ) THEN
            WRITE(msgBuf,'(2A)')
     &           'BOM_CHECK: precombined current duplicates ',
     &           'FILES Stokes'
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
          IF ( bomUStokesFile.EQ.' ' .OR.
     &         bomVStokesFile.EQ.' ' ) THEN
            WRITE(msgBuf,'(A)')
     &           'BOM_CHECK: FILES requires paired Stokes filenames'
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
          IF ( .NOT.stokesStartFinite ) THEN
            WRITE(msgBuf,'(A,1PE24.16)')
     &           'BOM_CHECK: non-finite bomStokesStartTime=',
     &           bomStokesStartTime
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
          IF ( .NOT.stokesPeriodFinite ) THEN
            WRITE(msgBuf,'(A,1PE24.16)')
     &           'BOM_CHECK: non-finite bomStokesPeriod=',
     &           bomStokesPeriod
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ELSEIF ( bomStokesPeriod.LE.0. _d 0 ) THEN
            WRITE(msgBuf,'(A,1PE24.16)')
     &           'BOM_CHECK: bomStokesPeriod must be positive=',
     &           bomStokesPeriod
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
          IF ( .NOT.stokesRepFinite ) THEN
            WRITE(msgBuf,'(A,1PE24.16)')
     &           'BOM_CHECK: non-finite bomStokesRepCycle=',
     &           bomStokesRepCycle
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ELSEIF ( bomStokesRepCycle.LT.0. _d 0 ) THEN
            WRITE(msgBuf,'(A,1PE24.16)')
     &           'BOM_CHECK: negative bomStokesRepCycle=',
     &           bomStokesRepCycle
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ELSEIF ( stokesPeriodFinite .AND.
     &             bomStokesRepCycle.GT.0. _d 0 .AND.
     &             bomStokesRepCycle.LT.bomStokesPeriod ) THEN
            WRITE(msgBuf,'(A,2(1X,1PE24.16))')
     &           'BOM_CHECK: repeat cycle shorter than period=',
     &           bomStokesRepCycle, bomStokesPeriod
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
          IF ( .NOT.stokesScaleFinite ) THEN
            WRITE(msgBuf,'(A,1PE24.16)')
     &           'BOM_CHECK: non-finite bomStokesInScale=',
     &           bomStokesInScale
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
          IF ( bomStokesFilePrec.NE.32 .AND.
     &         bomStokesFilePrec.NE.64 ) THEN
            WRITE(msgBuf,'(A,I8)')
     &           'BOM_CHECK: bomStokesFilePrec must be 32 or 64:',
     &           bomStokesFilePrec
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
        ELSEIF ( bomStokesSource.EQ.'COUPLER' ) THEN
          IF ( bomCurrentPolicy.EQ.'PRECOMBINED' ) THEN
            WRITE(msgBuf,'(2A)')
     &           'BOM_CHECK: precombined current duplicates ',
     &           'COUPLER Stokes'
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
#ifndef ALLOW_BOM_STOKES_COUPLER
          WRITE(msgBuf,'(A)')
     &         'BOM_CHECK: COUPLER provider hook is not compiled'
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
#endif
        ELSE
          WRITE(msgBuf,'(A,A)')
     &         'BOM_CHECK: unsupported bomStokesSource=',
     &         bomStokesSource
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
      ENDIF

      IF ( .NOT.deltaTFinite ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_CHECK: non-finite deltaTClock=', deltaTClock
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( deltaTClock.LE.0. _d 0 ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_CHECK: deltaTClock must be positive, value=',
     &       deltaTClock
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( .NOT.targetFinite ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_CHECK: non-finite bomDeltaTTarget=',
     &       bomDeltaTTarget
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( bomDeltaTTarget.LE.0. _d 0 ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_CHECK: bomDeltaTTarget must be positive, value=',
     &       bomDeltaTTarget
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( deltaTFinite .AND. targetFinite ) THEN
        IF ( deltaTClock.GT.0. _d 0 .AND.
     &       bomDeltaTTarget.GT.0. _d 0 ) THEN
          IF ( bomDeltaTTarget.LT.
     &         deltaTClock/DFLOAT(HUGE(nSub)) ) THEN
            WRITE(msgBuf,'(A,2(1X,1PE24.16))')
     &           'BOM_CHECK: subRatio exceeds INTEGER range:',
     &           deltaTClock, bomDeltaTTarget
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ELSE
            subRatio = deltaTClock/bomDeltaTTarget
            IF ( .NOT.IEEE_IS_FINITE(subRatio) ) THEN
              WRITE(msgBuf,'(A,1PE24.16)')
     &             'BOM_CHECK: non-finite subRatio=', subRatio
              CALL PRINT_ERROR( msgBuf, myThid )
              errCount = errCount + 1
            ELSEIF ( subRatio.LE.0. _d 0 ) THEN
              WRITE(msgBuf,'(A,1PE24.16)')
     &             'BOM_CHECK: non-positive subRatio=', subRatio
              CALL PRINT_ERROR( msgBuf, myThid )
              errCount = errCount + 1
            ELSEIF ( subRatio.GT.DFLOAT(HUGE(nSub)) ) THEN
              WRITE(msgBuf,'(A,1PE24.16,A,1PE24.16)')
     &             'BOM_CHECK: subRatio exceeds INTEGER range: ratio=',
     &             subRatio, ' limit=', DFLOAT(HUGE(nSub))
              CALL PRINT_ERROR( msgBuf, myThid )
              errCount = errCount + 1
            ELSE
              nSub = CEILING(subRatio)
              IF ( nSub.LT.1 ) THEN
                WRITE(msgBuf,'(A,I12)')
     &               'BOM_CHECK: derived nSub must be positive, value=',
     &               nSub
                CALL PRINT_ERROR( msgBuf, myThid )
                errCount = errCount + 1
              ELSE
                dtSub = deltaTClock/DFLOAT(nSub)
                IF ( .NOT.IEEE_IS_FINITE(dtSub) ) THEN
                  WRITE(msgBuf,'(A,1PE24.16,A,I12)')
     &                 'BOM_CHECK: non-finite derived dtSub=', dtSub,
     &                 ' nSub=', nSub
                  CALL PRINT_ERROR( msgBuf, myThid )
                  errCount = errCount + 1
                ELSEIF ( dtSub.LE.0. _d 0 ) THEN
                  WRITE(msgBuf,'(A,1PE24.16,A,I12)')
     &                 'BOM_CHECK: non-positive derived dtSub=', dtSub,
     &                 ' nSub=', nSub
                  CALL PRINT_ERROR( msgBuf, myThid )
                  errCount = errCount + 1
                ENDIF
              ENDIF
            ENDIF
          ENDIF
        ENDIF
      ENDIF

      IF ( .NOT.outputFinite .OR. .NOT.pickupFinite ) THEN
        WRITE(msgBuf,'(A,2(1X,1PE24.16))')
     &       'BOM_CHECK: non-finite output/pickup frequency=',
     &       bomOutputFreq, bomPickupFreq
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( bomOutputFreq.LT.0. _d 0 .OR.
     &         bomPickupFreq.LT.0. _d 0 ) THEN
        WRITE(msgBuf,'(A,2(1X,1PE24.16))')
     &       'BOM_CHECK: output frequencies must be non-negative:',
     &       bomOutputFreq, bomPickupFreq
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( pickupFinite ) THEN
        IF ( bomPickupFreq.NE.0. _d 0 ) THEN
          WRITE(msgBuf,'(A)')
     &         'BOM_CHECK: bomPickupFreq must be zero in Phase 1'
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
      ENDIF

C--   One step may not cross more than one unavailable sample time.
      IF ( outputFinite .AND. deltaTFinite ) THEN
        IF ( bomOutputFreq.GT.0. _d 0 .AND.
     &       deltaTClock.GT.0. _d 0 .AND.
     &       bomOutputFreq.LT.deltaTClock ) THEN
          WRITE(msgBuf,'(A,2(1X,1PE24.16))')
     &         'BOM_CHECK: output frequency below ocean step=',
     &         bomOutputFreq, deltaTClock
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
      ENDIF

      IF ( bomMaxParticles.LT.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: bomMaxParticles must be non-negative'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomInitialIter.LT.0 ) THEN
        WRITE(msgBuf,'(A,I12)')
     &       'BOM_CHECK: bomInitialIter must be non-negative, value=',
     &       bomInitialIter
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( nIter0.LT.bomInitialIter ) THEN
        WRITE(msgBuf,'(A,2I12)')
     &       'BOM_CHECK: nIter0 below bomInitialIter=',
     &       nIter0, bomInitialIter
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomInitGlobalLimit.LT.1 .OR.
     &     bomInitGlobalLimit.GT.bomMaxInitRecords ) THEN
        WRITE(msgBuf,'(A,I8,A,I8)')
     &       'BOM_CHECK: bomInitGlobalLimit=', bomInitGlobalLimit,
     &       ' exceeds compile limit=', bomMaxInitRecords
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( nIter0.EQ.bomInitialIter .AND.
     &     bomMaxParticles.EQ.0 .AND.
     &     bomInitialFile.NE.' ' ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: zero-particle mode requires blank input file'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( nIter0.EQ.bomInitialIter .AND.
     &     bomMaxParticles.GT.0 .AND.
     &     bomInitialFile.EQ.' ' ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: positive particle count requires input file'
        CALL PRINT_ERROR( msgBuf, myThid )
C-      Retain the Phase-0 gate signature while that baseline is frozen.
        WRITE(msgBuf,'(2A)')
     &       'BOM_CHECK: particle state is unavailable in Phase 0',
     &       ' input; set bomInitialFile for Phase 1'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( .NOT.coeffFinite ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_CHECK: non-finite bomLeewayWindCoeff=',
     &       bomLeewayWindCoeff
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( bomLeewayWindCoeff.LT.0. _d 0 .OR.
     &         bomLeewayWindCoeff.GT.0.1 _d 0 ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_CHECK: bomLeewayWindCoeff outside [0,0.1]=',
     &       bomLeewayWindCoeff
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomWindSource.EQ.'NONE' ) THEN
        IF ( coeffFinite ) THEN
          IF ( bomLeewayWindCoeff.NE.0. _d 0 ) THEN
            WRITE(msgBuf,'(A,1PE24.16,A)')
     &           'BOM_CHECK: wind source=NONE coeff=',
     &           bomLeewayWindCoeff, ' must be zero'
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ENDIF
        ENDIF
      ELSEIF ( bomWindSource.EQ.'EXF' ) THEN
#ifndef ALLOW_EXF
        WRITE(msgBuf,'(A,1PE24.16,A)')
     &       'BOM_CHECK: wind source=EXF coeff=',
     &       bomLeewayWindCoeff, ' requires ALLOW_EXF'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
#else
        IF ( .NOT.useEXF ) THEN
          WRITE(msgBuf,'(A,1PE24.16,A)')
     &         'BOM_CHECK: wind source=EXF coeff=',
     &         bomLeewayWindCoeff, ' requires useEXF=.TRUE.'
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ELSEIF ( .NOT.useAtmWind ) THEN
          WRITE(msgBuf,'(A,1PE24.16,A)')
     &         'BOM_CHECK: wind source=EXF coeff=',
     &         bomLeewayWindCoeff, ' requires useAtmWind=.TRUE.'
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
#endif
      ELSE
        WRITE(msgBuf,'(A,A,A,1PE24.16)')
     &       'BOM_CHECK: unsupported bomWindSource=', bomWindSource,
     &       ' coeff=', bomLeewayWindCoeff
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomMode.NE.'BOM' .AND.
     &     bomStokesSource.NE.'NONE' ) THEN
        WRITE(msgBuf,'(A,A)')
     &       'BOM_CHECK: LEEW Stokes source must be NONE: ',
     &       bomStokesSource
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( .NOT.wetFinite ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_CHECK: non-finite bomWetWeightMin=',
     &       bomWetWeightMin
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( bomWetWeightMin.LE.0. _d 0 .OR.
     &         bomWetWeightMin.GT.1. _d 0 ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_CHECK: bomWetWeightMin outside (0,1]=',
     &       bomWetWeightMin
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( .NOT.cflFinite ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_CHECK: non-finite bomAdvCFL=', bomAdvCFL
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( bomAdvCFL.LE.0. _d 0 .OR.
     &         bomAdvCFL.GT.1. _d 0 ) THEN
        WRITE(msgBuf,'(A,1PE24.16)')
     &       'BOM_CHECK: bomAdvCFL outside (0,1]=', bomAdvCFL
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomMaxHop.LT.1 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: bomMaxHop must be positive'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomMaxExchange.LT.1 ) THEN
        WRITE(msgBuf,'(A,I12)')
     &       'BOM_CHECK: invalid migration capacity=',
     &       bomMaxExchange
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomMaxParticles.GT.0 ) THEN
        IF ( OLx.LT.2 .OR. OLy.LT.2 ) THEN
          WRITE(msgBuf,'(A,2I6)')
     &         'BOM_CHECK: P1.4 migration requires OLx/OLy >= 2:',
     &         OLx, OLy
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
        IF ( .NOT.usingCartesianGrid .AND.
     &       .NOT.usingSphericalPolarGrid ) THEN
          WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: Phase-1.1 grid must be Cartesian or spherical'
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
        IF ( rotateGrid ) THEN
          WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: rotated grids are unavailable in Phase 1'
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
        IF ( nTx*nTy.NE.1 ) THEN
          WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: Phase-1.1 non-zero state is MPI-only'
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
#ifdef ALLOW_EXCH2
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: EXCH2 is unavailable in Phase 1'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
#endif
      ENDIF

      IF ( errCount.GE.1 ) THEN
        WRITE(msgBuf,'(A,I3,A)')
     &       'BOM_CHECK: detected', errCount,' fatal error(s)'
        CALL PRINT_ERROR( msgBuf, myThid )
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_CHECK'
      ENDIF

      WRITE(msgBuf,'(A,1PE16.8,A,I12,A,1PE16.8)')
     &     'BOM_CHECK: substep preflight ratio=', subRatio,
     &     ' nSub=', nSub, ' dtSub=', dtSub
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A,5(I4,1X))')
     &     'BOM_CHECK: compile limits = ',
     &     bomMaxPartTile, bomMaxGhostTile, bomMaxExchange,
     &     bomMaxNeighbor, bomMaxEventBuffer
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A,I8)')
     &     'BOM_CHECK: initial-record compile limit = ',
     &     bomMaxInitRecords
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )
      WRITE(msgBuf,'(A)') 'BOM_CHECK: done'
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )

      _END_MASTER(myThid)
#endif /* ALLOW_BOM */

      RETURN
      END
