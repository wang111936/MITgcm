#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_CHECK

C !INTERFACE:
      SUBROUTINE BOM_CHECK( myThid )

C !DESCRIPTION:
C     Validate the Phase-1.1 state and initial-file configuration.

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
      INTEGER errCount

      _BEGIN_MASTER(myThid)

      WRITE(msgBuf,'(A)')
     &     'BOM_CHECK: Phase-1.1 state and initial-file gate'
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
      CALL WRITE_0D_C( bomWindSource, -1, INDEX_NONE,
     &     'bomWindSource =', ' /* Phase 1.1: NONE */')
      CALL WRITE_0D_C( bomStokesSource, -1, INDEX_NONE,
     &     'bomStokesSource =', ' /* Phase 1: NONE */')

      errCount = 0

      IF ( bomMode.NE.'LEEW' .AND.
     &     bomMode.NE.'BOM'  .AND.
     &     bomMode.NE.'EBOM' .AND.
     &     bomMode.NE.'EBOMB' ) THEN
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

      IF ( bomDeltaTTarget.LE.0. _d 0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: bomDeltaTTarget must be positive'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomOutputFreq.LT.0. _d 0 .OR.
     &     bomPickupFreq.LT.0. _d 0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: output frequencies must be non-negative'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomPickupFreq.NE.0. _d 0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: bomPickupFreq must be zero in Phase 1'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomMaxParticles.LT.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: bomMaxParticles must be non-negative'
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

      IF ( bomMaxParticles.EQ.0 .AND.
     &     bomInitialFile.NE.' ' ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: zero-particle mode requires blank input file'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomMaxParticles.GT.0 .AND.
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

      IF ( bomMaxParticles.GT.0 .AND. bomMode.NE.'LEEW' ) THEN
        WRITE(msgBuf,'(A,A)')
     &       'BOM_CHECK: non-zero Phase-1.1 state requires LEEW: ',
     &       bomMode
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomLeewayWindCoeff.LT.0. _d 0 .OR.
     &     bomLeewayWindCoeff.GT.0.1 _d 0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: bomLeewayWindCoeff must be in [0,0.1]'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomWindSource.NE.'NONE' ) THEN
        WRITE(msgBuf,'(A,A)')
     &       'BOM_CHECK: Phase-1.1 wind source must be NONE: ',
     &       bomWindSource
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSEIF ( bomLeewayWindCoeff.NE.0. _d 0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: wind coefficient requires a wind source'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomStokesSource.NE.'NONE' ) THEN
        WRITE(msgBuf,'(A,A)')
     &       'BOM_CHECK: Phase-1 Stokes source must be NONE: ',
     &       bomStokesSource
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomWetWeightMin.LE.0. _d 0 .OR.
     &     bomWetWeightMin.GT.1. _d 0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: bomWetWeightMin must be in (0,1]'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomAdvCFL.LE.0. _d 0 .OR.
     &     bomAdvCFL.GT.1. _d 0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: bomAdvCFL must be in (0,1]'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomMaxHop.LT.1 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: bomMaxHop must be positive'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

      IF ( bomMaxParticles.GT.0 ) THEN
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
