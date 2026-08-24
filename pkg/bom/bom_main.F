#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_MAIN

C !INTERFACE:
      SUBROUTINE BOM_MAIN( myTime, myIter, myThid )

C !DESCRIPTION:
C     Publish frozen step-end surface velocity fields and diagnose each
C     existing owner record without advancing particle state.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL     myTime
      INTEGER myIter
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, ip, errCount, globalErrCount
      _RL xMap, ix, jy, valueEast, valueNorth, wetWeight
      LOGICAL isOwner, hasStencil, isValid

      IF ( bomMaxParticles.LE.0 ) RETURN
      CALL BOM_BUILD_FIELDS( myTime, myIter, myThid )

C--   P1.2 only diagnoses committed positions.  It does not change owner
C     counts, IDs, positions, release state, status, age, or motion state.
      errCount = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomNPartTile(bi,bj)
          xMap = bomX(ip,bi,bj)
          ix = -1. _d 0
          jy = -1. _d 0
          valueEast = 0. _d 0
          valueNorth = 0. _d 0
          wetWeight = 0. _d 0
          isOwner = .FALSE.
          hasStencil = .FALSE.
          isValid = .FALSE.
          CALL BOM_MAP_XY2IJLOCAL(
     I         bomX(ip,bi,bj), bomY(ip,bi,bj), bi, bj,
     O         xMap, ix, jy, isOwner, hasStencil,
     I         myThid )
          IF ( isOwner .AND. hasStencil ) THEN
            CALL BOM_INTERP_WET_PAIR(
     I           ix, jy, bi, bj,
     I           bomGridVEast, bomGridVNorth,
     O           valueEast, valueNorth, wetWeight, isValid,
     I           myThid )
          ENDIF

          IF ( isOwner .AND. hasStencil .AND. isValid ) THEN
            bomI(ip,bi,bj) = ix
            bomJ(ip,bi,bj) = jy
            bomVEast(ip,bi,bj) = valueEast
            bomVNorth(ip,bi,bj) = valueNorth
          ELSE
            IF ( errCount.LT.8 ) THEN
              WRITE(msgBuf,'(A,I8,A,2I5,A,I20)')
     &             'BOM_MAIN: invalid diagnostic ip=', ip,
     &             ' tile=', bi, bj, ' id=', bomId(ip,bi,bj)
              CALL PRINT_ERROR( msgBuf, myThid )
              WRITE(msgBuf,'(A,4(1X,1PE24.16))')
     &             'BOM_MAIN: xMap/ix/jy/wetWeight=',
     &             xMap, ix, jy, wetWeight
              CALL PRINT_ERROR( msgBuf, myThid )
              WRITE(msgBuf,'(A,3L3)')
     &             'BOM_MAIN: owner/stencil/interpValid=',
     &             isOwner, hasStencil, isValid
              CALL PRINT_ERROR( msgBuf, myThid )
            ENDIF
            errCount = errCount + 1
          ENDIF
        ENDDO
       ENDDO
      ENDDO

      globalErrCount = errCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8,A)')
     &         'BOM_MAIN: detected ', globalErrCount,
     &         ' fatal P1.2 particle diagnostic error(s)'
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_MAIN'
      ENDIF
#endif

      RETURN
      END
