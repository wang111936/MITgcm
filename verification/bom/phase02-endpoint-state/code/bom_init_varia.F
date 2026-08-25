#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_INIT_VARIA

C !INTERFACE:
      SUBROUTINE BOM_INIT_VARIA( myThid )

C !DESCRIPTION:
C     Test-only P2.1 endpoint-state gate.

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
      CALL BOM_INIT_STATE( myThid )
      IF ( the_run_name.EQ.'P21-ENDPOINT-STATE' ) THEN
        CALL BOM_VERIFY_ENDPOINT_STATE( myThid )
      ENDIF
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_ENDPOINT_STATE( myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      INTEGER myThid

#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, i, j, iEnd, iSource
      INTEGER nFail, globalFail
      _RL expectedTau, tol

      nFail = 0
      expectedTau = 86400. _d 0*0.0103 _d 0
      tol = 4096. _d 0*EPSILON(oneRL)

      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     BOM_ENV_EULERIAN.EQ.1 .AND.
     &     BOM_ENV_STOKES.EQ.2 .AND.
     &     BOM_ENV_WIND.EQ.3 .AND.
     &     BOM_ENV_NSOURCE.EQ.3,
     &     'stable environmental source codes', nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     BOM_ENV_OLD.EQ.1 .AND. BOM_ENV_NEW.EQ.2 .AND.
     &     BOM_ENV_NEND.EQ.2,
     &     'stable endpoint codes', nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     BOM_FAIL_FIELD_TIME.EQ.9 .AND.
     &     BOM_FAIL_FIELD_SOURCE.EQ.10 .AND.
     &     BOM_FAIL_METRIC.EQ.11 .AND.
     &     BOM_FAIL_GRADIENT.EQ.12 .AND.
     &     BOM_FAIL_EQUATION.EQ.13 .AND.
     &     BOM_FAIL_STOKES_DUPLICATE.EQ.14 .AND.
     &     BOM_FAIL_PICKUP_SCHEMA.EQ.15,
     &     'stable Phase-2 failure codes', nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     BOM_STAGE_FIELD_OLD.EQ.6 .AND.
     &     BOM_STAGE_FIELD_NEW.EQ.7 .AND.
     &     BOM_STAGE_DERIVATIVE.EQ.8,
     &     'stable Phase-2 stage codes', nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     bomCurrentPolicy.EQ.'EULERIAN' .AND.
     &     bomEquationMode.EQ.'PAPER2024',
     &     'frozen character parameter contract', nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     bomAlpha.EQ.0. _d 0 .AND.
     &     ABS(bomTau-expectedTau).LE.tol*MAX(1. _d 0,
     &                                             expectedTau) .AND.
     &     ABS(bomR-0.823 _d 0).LE.tol .AND.
     &     bomSigma.EQ.0. _d 0,
     &     'validated and converted BOM parameters', nFail, myThid )
      CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &     .NOT.bomEnvReady .AND. .NOT.bomFieldsReady,
     &     'endpoint and Phase-1 fields start unpublished',
     &     nFail, myThid )

      DO iEnd=1,BOM_ENV_NEND
        CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &       bomEnvTime(iEnd).EQ.0. _d 0 .AND.
     &       bomEnvIter(iEnd).EQ.0,
     &       'deterministic endpoint metadata', nFail, myThid )
      ENDDO

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          DO iSource=1,BOM_ENV_NSOURCE
           DO iEnd=1,BOM_ENV_NEND
            CALL BOM_VERIFY_ENDPOINT_ASSERT(
     &           bomEnvEast(i,j,iEnd,iSource,bi,bj).EQ.0. _d 0
     &           .AND.
     &           bomEnvNorth(i,j,iEnd,iSource,bi,bj).EQ.0. _d 0
     &           .AND.
     &           .NOT.bomEnvValid(i,j,iEnd,iSource,bi,bj),
     &           'deterministic endpoint field initialization',
     &           nFail, myThid )
           ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      globalFail = nFail
      CALL GLOBAL_SUM_INT( globalFail, myThid )
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_VERIFY_ENDPOINT_STATE: failed assertions=',
     &         globalFail
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_VERIFY_ENDPOINT_STATE'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P2.1 ENDPOINT STATE PASS: parameters, codes, zero state'
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_ENDPOINT_ASSERT(
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
        IF ( nFail.LT.12 ) THEN
          WRITE(msgBuf,'(2A)')
     &         'BOM_VERIFY_ENDPOINT_STATE: FAIL: ', label
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        nFail = nFail + 1
      ENDIF

      RETURN
      END
