#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_READPARMS

C !INTERFACE:
      SUBROUTINE BOM_READPARMS( myThid )

C !DESCRIPTION:
C     Set the accepted defaults, including inactive Phase-3 springs, and
C     read the pkg/bom namelists.
C     Return without reading data.bom when useBOM is false.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER iUnit
      INTEGER iErr

      NAMELIST /BOM_PARM01/
     &       bomMode, bomEquationMode, bomIntegrator,
     &       bomDeltaTTarget, bomOutputFreq, bomPickupFreq,
     &       bomSeed, bomMaxParticles, bomInitialIter,
     &       bomInitialFile, bomSpringLaw, bomNeighborPolicy
      NAMELIST /BOM_PARM02/
     &       bomLeewayWindCoeff, bomWindSource,
     &       bomStokesSource, bomWetWeightMin, bomAdvCFL,
     &       bomCurrentPolicy, bomAlpha, bomTauDays,
     &       bomR, bomSigma,
     &       bomUStokesFile, bomVStokesFile,
     &       bomStokesStartTime, bomStokesPeriod,
     &       bomStokesRepCycle, bomStokesInScale,
     &       bomStokesFilePrec,
     &       bomMaxHop, bomInitGlobalLimit,
     &       bomCheckEverySubstep,
     &       bomSpringL, bomHookeK, bomSpringA,
     &       bomSpringDelta, bomNeighborCutoff,
     &       bomPairDistanceMin, bomSpringCFL,
     &       bomRaftDiagnostics

      IF ( .NOT.useBOM ) THEN
C-    pkg BOM is not used; report an unexpected data.bom if present.
        _BEGIN_MASTER(myThid)
         CALL PACKAGES_UNUSED_MSG( 'useBOM', ' ', ' ' )
        _END_MASTER(myThid)
        RETURN
      ENDIF

      _BEGIN_MASTER(myThid)

C--   Safe Phase-1.5 defaults retain an inactive state and inactive output.
      bomMode          = 'LEEW'
      bomEquationMode  = 'PAPER2024'
      bomIntegrator    = 'RK4'
      bomDeltaTTarget  = deltaTClock
      bomOutputFreq    = 0. _d 0
      bomPickupFreq    = 0. _d 0
      bomSeed           = 20240801
      bomMaxParticles   = 0
      bomInitialIter    = 0
      bomInitialFile    = ' '
      bomLeewayWindCoeff = 0. _d 0
      bomWindSource       = 'NONE'
      bomStokesSource     = 'NONE'
      bomCurrentPolicy    = 'UNSET'
      bomSpringLaw        = 'NONE'
      bomNeighborPolicy   = 'NONE'
      bomAlpha            = 0. _d 0
      bomTauDays          = 0. _d 0
      bomTau              = 0. _d 0
      bomR                = 1. _d 0
      bomSigma            = 0. _d 0
      bomUStokesFile      = ' '
      bomVStokesFile      = ' '
      bomStokesStartTime  = 0. _d 0
      bomStokesPeriod     = 0. _d 0
      bomStokesRepCycle   = 0. _d 0
      bomStokesInScale    = 1. _d 0
      bomStokesFilePrec   = 64
      bomSpringL          = 0. _d 0
      bomHookeK           = 0. _d 0
      bomSpringA          = 0. _d 0
      bomSpringDelta      = 0. _d 0
      bomNeighborCutoff   = 0. _d 0
      bomPairDistanceMin  = 0. _d 0
      bomSpringCFL        = 0.5 _d 0
      bomWetWeightMin     = 0.5 _d 0
      bomAdvCFL           = 0.5 _d 0
      bomMaxHop            = 8
      bomInitGlobalLimit   = bomMaxInitRecords
      bomCheckEverySubstep = .TRUE.
      bomRaftDiagnostics   = .FALSE.

      WRITE(msgBuf,'(A)') 'BOM_READPARMS: opening data.bom'
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )
      CALL OPEN_COPY_DATA_FILE(
     I                     'data.bom', 'BOM_READPARMS',
     O                     iUnit,
     I                     myThid )

      READ(UNIT=iUnit,NML=BOM_PARM01)
      READ(UNIT=iUnit,NML=BOM_PARM02,IOSTAT=iErr)
      IF ( iErr.GT.0 ) THEN
        WRITE(msgBuf,'(A,I8)')
     &       'BOM_READPARMS: invalid BOM_PARM02, IOSTAT=', iErr
        CALL PRINT_ERROR( msgBuf, myThid )
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_READPARMS'
      ENDIF
      WRITE(msgBuf,'(A)')
     &    'BOM_READPARMS: finished reading data.bom'
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )
#ifdef SINGLE_DISK_IO
      CLOSE(iUnit)
#else
      CLOSE(iUnit,STATUS='DELETE')
#endif

      _END_MASTER(myThid)
      _BARRIER
#endif /* ALLOW_BOM */

      RETURN
      END
