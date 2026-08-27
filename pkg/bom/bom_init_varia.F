#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_VARIA

C !INTERFACE:
      SUBROUTINE BOM_INIT_VARIA( myThid )

C !DESCRIPTION:
C     Initialise a fresh compact owner state at bomInitialIter, or restore
C     the transactional P1.5 pickup for a later core restart iteration.

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

      CALL BOM_INIT_STATE( myThid )
      IF ( nIter0.EQ.bomInitialIter ) THEN
        IF ( bomMode.EQ.'BOM' ) THEN
          CALL BOM_BUILD_ENDPOINTS(
     I         startTime, nIter0, .TRUE., myThid )
        ENDIF
        IF ( bomMaxParticles.GT.0 ) THEN
          CALL BOM_READ_INITIAL( myThid )
        ENDIF
        CALL BOM_INIT_OUTPUT_SCHEDULE( startTime, myThid )
      ELSEIF ( nIter0.GT.bomInitialIter ) THEN
        CALL BOM_READ_PICKUP( myThid )
      ELSE
        _BEGIN_MASTER(myThid)
        WRITE(msgBuf,'(A,2I12)')
     &       'BOM_INIT_VARIA: nIter0 below bomInitialIter=',
     &       nIter0, bomInitialIter
        CALL PRINT_ERROR( msgBuf, myThid )
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_INIT_VARIA'
      ENDIF
#endif

      RETURN
      END
