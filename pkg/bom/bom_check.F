#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_CHECK

C !INTERFACE:
      SUBROUTINE BOM_CHECK( myThid )

C !DESCRIPTION:
C     Validate the Phase-0 zero-particle package configuration.

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

      WRITE(msgBuf,'(A)') 'BOM_CHECK: Phase-0 zero-particle skeleton'
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
     &     'bomMaxParticles =', ' /* zero in Phase 0 */')

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

C--   A non-zero count or input file would imply unimplemented state.
      IF ( bomMaxParticles.NE.0 .OR. bomInitialFile.NE.' ' ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_CHECK: particle state is unavailable in Phase 0'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
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
      WRITE(msgBuf,'(A)') 'BOM_CHECK: done'
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )

      _END_MASTER(myThid)
#endif /* ALLOW_BOM */

      RETURN
      END
