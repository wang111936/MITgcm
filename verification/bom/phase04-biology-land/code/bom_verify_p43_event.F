#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P43_EVENT( myThid )
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
      INTEGER ip,jp,bi,bj,nFail,globalFail,failCode,p4Phase
      INTEGER failRank,failBi,failBj,failSlot,newSlot,seedFail
      INTEGER foundLocal,foundGlobal,eventLocal,eventGlobal
      INTEGER ownerRank,ownerBi,ownerBj,hop,nBefore,eventBefore
      INTEGER birthCountBefore,statusBefore
      INTEGER*8 failId,idBefore,nextBefore,birthBefore,cancelBefore
      INTEGER*8 deathBefore,freeRemoveBefore,freeAllocBefore
      _RL xOwner,yOwner,sBefore
      LOGICAL isValid,locateValid,seedValid,eventValid
      LOGICAL foundParent(4),foundChild(4),sidecarValid
      _RL xFix(4),yFix(4)
      DATA xFix / -100. _d 0, 100. _d 0,
     &             -100. _d 0, 100. _d 0 /
      DATA yFix / -100. _d 0,-100. _d 0,
     &              100. _d 0, 100. _d 0 /

      nFail=0
      CALL BOM_VERIFY_P43_EVENT_SCHEMA(myThid,nFail)

C--   M01: force one complete biology owner across a rank/tile boundary.
      CALL BOM_INIT_STATE(myThid)
      CALL BOM_VERIFY_P43_EVENT_CONFIG(
     I     0. _d 0,deltaTClock,.FALSE.,myThid)
      bomMaxParticles=1
      CALL BOM_LOCATE_OWNER(
     I     -1500. _d 0,-500. _d 0,1,1,
     O     xOwner,yOwner,ownerRank,ownerBi,ownerBj,
     O     hop,locateValid,myThid)
      seedValid=.TRUE.
      IF ( myProcId.EQ.ownerRank ) THEN
        CALL BOM_VERIFY_P43_EVENT_ALLOC(
     I       ownerBi,ownerBj,777_8,333_8,9,2.25 _d 0,
     I       -1500. _d 0,-500. _d 0,BOM_ALIVE,
     O       newSlot,seedFail,seedValid,myThid)
        bomX(newSlot,ownerBi,ownerBj)=1500. _d 0
      ENDIF
      CALL BOM_VERIFY_P43_ASSERT(
     &     locateValid .AND. seedValid,
     &     'P4-M01 migration seed',nFail,myThid)
      bomNPartExpected=1
      bomNPartLiveExpected=1
      bomNextId=778_8
      CALL BOM_PARTICLE_EXCHANGE(deltaTClock,1,1,myThid)
      foundLocal=0
      sidecarValid=.TRUE.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomNPartTile(bi,bj)
          IF ( bomId(ip,bi,bj).EQ.777_8 ) THEN
            foundLocal=foundLocal+1
            sidecarValid=sidecarValid .AND.
     &           bomParentId(ip,bi,bj).EQ.333_8 .AND.
     &           bomBirthCount(ip,bi,bj).EQ.9 .AND.
     &           bomS(ip,bi,bj).EQ.2.25 _d 0
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      foundGlobal=foundLocal
      CALL GLOBAL_SUM_INT(foundGlobal,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     foundGlobal.EQ.1 .AND. sidecarValid,
     &     'P4-M01 schema3 parent/count/S migration',nFail,myThid)

C--   B14/B17: four decomposition-invariant parents all give birth.
      CALL BOM_INIT_STATE(myThid)
      CALL BOM_VERIFY_P43_EVENT_CONFIG(
     I     0. _d 0,deltaTClock,.TRUE.,myThid)
      bomMaxParticles=16
      DO jp=1,4
        CALL BOM_LOCATE_OWNER(
     I       xFix(jp),yFix(jp),1,1,
     O       xOwner,yOwner,ownerRank,ownerBi,ownerBj,
     O       hop,locateValid,myThid)
        seedValid=.TRUE.
        IF ( myProcId.EQ.ownerRank ) CALL BOM_VERIFY_P43_EVENT_ALLOC(
     I       ownerBi,ownerBj,INT(10*jp,8),0_8,jp-1,4. _d 0,
     I       xFix(jp),yFix(jp),BOM_ALIVE,
     O       newSlot,seedFail,seedValid,myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       locateValid .AND. seedValid,
     &       'B14 canonical parent seed',nFail,myThid)
      ENDDO
      bomNPartExpected=4
      bomNPartLiveExpected=4
      bomNextId=1000_8

C--   Both early and post-graph failures preserve authoritative state.
      nBefore=0
      idBefore=0_8
      sBefore=0. _d 0
      birthCountBefore=0
      statusBefore=0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        nBefore=nBefore+bomNPartTile(bi,bj)
        IF ( bomNPartTile(bi,bj).GT.0 .AND. idBefore.EQ.0_8 ) THEN
          idBefore=bomId(1,bi,bj)
          sBefore=bomS(1,bi,bj)
          birthCountBefore=bomBirthCount(1,bi,bj)
          statusBefore=bomStatus(1,bi,bj)
        ENDIF
       ENDDO
      ENDDO
      eventBefore=bomEventBufferCount
      nextBefore=bomNextId
      birthBefore=bomBirthEvents
      cancelBefore=bomCancelEvents
      deathBefore=bomDeathEvents
      freeRemoveBefore=bomFreeRemoveOps
      freeAllocBefore=bomFreeAllocOps
      CALL BOM_EVENT_TRANSACTION_P43(
     I     0. _d 0,deltaTClock,2,1,BOM_P4_PHASE_BIRTH_ORDER,
     O     failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O     failId,eventValid,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     .NOT.eventValid .AND.
     &     p4Phase.EQ.BOM_P4_PHASE_BIRTH_ORDER .AND.
     &     failCode.EQ.BOM_FAIL_BIRTH_ID .AND. failRank.EQ.0,
     &     'B13 birth-order rollback signal',nFail,myThid)
      CALL BOM_VERIFY_P43_EVENT_ROLLBACK(
     I     nBefore,idBefore,sBefore,birthCountBefore,statusBefore,
     I     eventBefore,nextBefore,birthBefore,cancelBefore,deathBefore,
     I     freeRemoveBefore,freeAllocBefore,
     O     isValid,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     isValid,'B13 birth-order authoritative rollback',
     &     nFail,myThid)
      CALL BOM_EVENT_TRANSACTION_P43(
     I     0. _d 0,deltaTClock,2,1,BOM_P4_PHASE_GRAPH,
     O     failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O     failId,eventValid,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     .NOT.eventValid .AND. p4Phase.EQ.BOM_P4_PHASE_GRAPH
     &     .AND. failCode.EQ.BOM_FAIL_COMPONENT
     &     .AND. failRank.EQ.0,
     &     'B17 post-graph rollback signal',nFail,myThid)
      CALL BOM_VERIFY_P43_EVENT_ROLLBACK(
     I     nBefore,idBefore,sBefore,birthCountBefore,statusBefore,
     I     eventBefore,nextBefore,birthBefore,cancelBefore,deathBefore,
     I     freeRemoveBefore,freeAllocBefore,
     O     isValid,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     isValid,'B17 post-graph authoritative rollback',nFail,myThid)

      CALL BOM_EVENT_TRANSACTION_P43(
     I     0. _d 0,deltaTClock,2,1,BOM_P4_PHASE_NONE,
     O     failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O     failId,eventValid,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     eventValid .AND. bomNPartLiveExpected.EQ.8 .AND.
     &     bomNextId.EQ.1004_8 .AND. bomBirthEvents.EQ.4_8 .AND.
     &     bomCancelEvents.EQ.0_8 .AND.
     &     bomEventTimeIndex.EQ.1_8,
     &     'B13/B14 full birth transaction counters',nFail,myThid)
      DO jp=1,4
        foundParent(jp)=.FALSE.
        foundChild(jp)=.FALSE.
      ENDDO
      eventLocal=bomEventBufferCount
      eventGlobal=eventLocal
      CALL GLOBAL_SUM_INT(eventGlobal,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     eventGlobal.EQ.4,
     &     'B14 one event per prospective parent',nFail,myThid)
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomNPartTile(bi,bj)
          DO jp=1,4
            IF ( bomId(ip,bi,bj).EQ.INT(10*jp,8) ) THEN
              foundParent(jp)=bomS(ip,bi,bj).EQ.bomS0 .AND.
     &             bomBirthCount(ip,bi,bj).EQ.jp .AND.
     &             bomRaftId(ip,bi,bj).EQ.10_8 .AND.
     &             bomRaftSize(ip,bi,bj).EQ.8
            ELSEIF ( bomId(ip,bi,bj).EQ.999_8+INT(jp,8) ) THEN
              foundChild(jp)=
     &             bomParentId(ip,bi,bj).EQ.INT(10*jp,8) .AND.
     &             bomBirthCount(ip,bi,bj).EQ.0 .AND.
     &             bomS(ip,bi,bj).EQ.bomS0 .AND.
     &             bomReleaseTime(ip,bi,bj).EQ.deltaTClock .AND.
     &             bomAge(ip,bi,bj).EQ.0. _d 0 .AND.
     &             bomRaftId(ip,bi,bj).EQ.10_8 .AND.
     &             bomRaftSize(ip,bi,bj).EQ.8
            ENDIF
          ENDDO
          WRITE(msgBuf,1000) bomId(ip,bi,bj),
     &         bomParentId(ip,bi,bj),bomBirthCount(ip,bi,bj),
     &         bomS(ip,bi,bj),bomRaftId(ip,bi,bj),
     &         bomRaftSize(ip,bi,bj),bomNeighborCount(ip,bi,bj)
          CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                       SQUEEZE_RIGHT,myThid)
        ENDDO
       ENDDO
      ENDDO
      DO jp=1,4
        foundLocal=0
        IF ( foundParent(jp) ) foundLocal=foundLocal+1
        foundGlobal=foundLocal
        CALL GLOBAL_SUM_INT(foundGlobal,myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       foundGlobal.EQ.1,
     &       'B14 parent reset/count/graph',nFail,myThid)
        foundLocal=0
        IF ( foundChild(jp) ) foundLocal=foundLocal+1
        foundGlobal=foundLocal
        CALL GLOBAL_SUM_INT(foundGlobal,myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       foundGlobal.EQ.1,
     &       'B14 child identity/state/graph',nFail,myThid)
      ENDDO
      CALL BOM_VERIFY_P43_ASSERT(
     &     bomP3RebuildCount.GT.0_8,
     &     'B17 event graph rebuild counter',nFail,myThid)

C--   Mixed death/cancel: no child ID, parent S/count unchanged on cancel.
      CALL BOM_INIT_STATE(myThid)
      CALL BOM_VERIFY_P43_EVENT_CONFIG(
     I     0. _d 0,deltaTClock,.FALSE.,myThid)
      bomSpringL=1. _d 9
      bomMaxParticles=4
      DO jp=1,4
        CALL BOM_LOCATE_OWNER(
     I       xFix(jp),yFix(jp),1,1,
     O       xOwner,yOwner,ownerRank,ownerBi,ownerBj,
     O       hop,locateValid,myThid)
        IF ( jp.EQ.1 ) THEN
          sBefore=0.1 _d 0
        ELSEIF ( jp.EQ.2 ) THEN
          sBefore=4. _d 0
        ELSE
          sBefore=2. _d 0
        ENDIF
        statusBefore=BOM_ALIVE
        IF ( jp.EQ.4 ) statusBefore=BOM_WAITING
        seedValid=.TRUE.
        IF ( myProcId.EQ.ownerRank ) CALL BOM_VERIFY_P43_EVENT_ALLOC(
     I       ownerBi,ownerBj,INT(100+10*jp,8),0_8,jp,
     I       sBefore,xFix(jp),yFix(jp),statusBefore,
     O       newSlot,seedFail,seedValid,myThid)
        IF ( myProcId.EQ.ownerRank .AND. jp.EQ.4 )
     &       bomReleaseTime(newSlot,ownerBi,ownerBj)=2. _d 0
      ENDDO
      bomNPartExpected=4
      bomNPartLiveExpected=4
      bomNextId=2000_8
      CALL BOM_EVENT_TRANSACTION_P43(
     I     0. _d 0,deltaTClock,3,1,BOM_P4_PHASE_NONE,
     O     failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O     failId,eventValid,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     eventValid .AND. bomNPartLiveExpected.EQ.3 .AND.
     &     bomNextId.EQ.2000_8 .AND. bomDeathEvents.EQ.1_8 .AND.
     &     bomCancelEvents.EQ.1_8 .AND. bomBirthEvents.EQ.0_8,
     &     'B13 mixed death and canceled birth counters',nFail,myThid)
      foundLocal=0
      sidecarValid=.TRUE.
      eventLocal=0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomNPartTile(bi,bj)
          IF ( bomId(ip,bi,bj).EQ.120_8 ) THEN
            foundLocal=foundLocal+1
            sidecarValid=sidecarValid .AND.
     &           bomS(ip,bi,bj).EQ.4. _d 0 .AND.
     &           bomBirthCount(ip,bi,bj).EQ.2
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      DO ip=1,bomEventBufferCount
        IF ( bomEventTypeBuffer(ip).EQ.BOM_EVENT_BIRTH_CANCEL
     &       .AND. bomEventSubjectIdBuffer(ip).EQ.120_8 .AND.
     &       bomEventChildIdBuffer(ip).EQ.0_8 .AND.
     &       bomEventRetryBuffer(ip).EQ.bomBirthMaxTry )
     &       eventLocal=eventLocal+1
      ENDDO
      foundGlobal=foundLocal
      CALL GLOBAL_SUM_INT(foundGlobal,myThid)
      eventGlobal=eventLocal
      CALL GLOBAL_SUM_INT(eventGlobal,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     foundGlobal.EQ.1 .AND. eventGlobal.EQ.1 .AND.
     &     sidecarValid,
     &     'P4-BR01 cancel preserves parent and emits no child',
     &     nFail,myThid)

      globalFail=nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.GT.0 ) CALL BOM_VERIFY_P43_ABORT(
     &     'BOM_VERIFY_P43_EVENT',globalFail,myThid)
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'B13/B14/P4-M01/B17 PASS: atomic birth graph schema3'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
      ENDIF
      _END_MASTER(myThid)
      CALL BOM_INIT_STATE(myThid)
 1000 FORMAT('P43-CANON ',I20,1X,I20,1X,I6,1X,1PE24.16,
     &       1X,I20,1X,I6,1X,I6)
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P43_EVENT_SCHEMA(myThid,nFail)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid,nFail
      CALL BOM_VERIFY_P43_ASSERT(
     &     bomPacketSchema.EQ.2 .AND. bomPacketInts.EQ.10 .AND.
     &     bomPacketReals.EQ.6 .AND. bomPacketSchema3.EQ.3 .AND.
     &     bomPacketInts3.EQ.13 .AND. bomPacketReals3.EQ.7,
     &     'P4-M01 released schema2 and biology schema3 constants',
     &     nFail,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P43_EVENT_CONFIG(
     I     tOld,tNew,useGraph,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL tOld,tNew
      LOGICAL useGraph
      INTEGER myThid
      INTEGER bi,bj,i,j,iEnd,iSource

      bomMode='BOM'
      bomEquationMode='PAPER2024'
      bomIntegrator='RK2'
      bomCurrentPolicy='EULERIAN'
      bomStokesSource='NONE'
      bomWindSource='NONE'
      bomUseLand=.TRUE.
      bomUseBiology=.TRUE.
      bomTempSource='THETA'
      bomNSource='PTRACER'
      bomBiologyMissingPolicy='STOP'
      bomMuMax=0. _d 0
      bomMort=0. _d 0
      bomKN=oneRL
      bomTMin=0. _d 0
      bomTMax=40. _d 0
      bomS0=oneRL
      bomSMin=0.2 _d 0
      bomSMax=3. _d 0
      bomSeed=314159
      bomBirthMaxTry=8
      bomSpringL=50. _d 0
      bomAlpha=0. _d 0
      bomTau=oneRL
      bomR=0.823 _d 0
      bomSigma=0. _d 0
      bomAdvCFL=10. _d 0
      bomWetWeightMin=0.5 _d 0
      bomNeighborPolicy='NONE'
      bomSpringLaw='NONE'
      bomRaftDiagnostics=.FALSE.
      IF ( useGraph ) THEN
        bomNeighborPolicy='CUTOFF'
        bomSpringLaw='HOOKE'
        bomHookeK=0.001 _d 0
        bomSpringA=0. _d 0
        bomSpringDelta=0. _d 0
        bomNeighborCutoff=1000. _d 0
        bomPairDistanceMin=1. _d -6
        bomSpringCFL=10. _d 0
        bomRaftDiagnostics=.TRUE.
      ENDIF
      bomEnvTime(BOM_ENV_OLD)=tOld
      bomEnvTime(BOM_ENV_NEW)=tNew
      bomEnvIter(BOM_ENV_OLD)=0
      bomEnvIter(BOM_ENV_NEW)=1
      bomBioTime(BOM_ENV_OLD)=tOld
      bomBioTime(BOM_ENV_NEW)=tNew
      bomBioIter(BOM_ENV_OLD)=0
      bomBioIter(BOM_ENV_NEW)=1
      DO iEnd=1,BOM_ENV_NEND
        bomBioTempSource(iEnd)=BOM_BIO_TEMP_THETA
        bomBioNSource(iEnd)=BOM_BIO_N_PTRACER
      ENDDO
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          maskC(i,j,1,bi,bj)=1.
          bomMetricValid(i,j,bi,bj)=.TRUE.
          bomTauSphere(i,j,bi,bj)=0. _d 0
          bomFCori(i,j,bi,bj)=0. _d 0
          DO iEnd=1,BOM_ENV_NEND
            bomBioTemp(i,j,iEnd,bi,bj)=20. _d 0
            bomBioN(i,j,iEnd,bi,bj)=oneRL
            bomBioValid(i,j,iEnd,bi,bj)=.TRUE.
            DO iSource=1,BOM_ENV_NSOURCE
              bomEnvEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomEnvNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomEnvValid(i,j,iEnd,iSource,bi,bj)=.TRUE.
              bomGradEastEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomGradNorthEast(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomGradEastNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomGradNorthNorth(i,j,iEnd,iSource,bi,bj)=0. _d 0
              bomGradValid(i,j,iEnd,iSource,bi,bj)=.TRUE.
            ENDDO
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      bomEnvReady=.TRUE.
      bomGradReady=.TRUE.
      bomMetricReady=.TRUE.
      bomBioReady=.TRUE.
      bomFieldsReady=.TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P43_EVENT_ALLOC(
     I     bi,bj,candidateId,candidateParent,candidateBirthCount,
     I     candidateS,candidateX,candidateY,candidateStatus,
     O     newSlot,failCode,isValid,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER bi,bj,candidateBirthCount,candidateStatus
      INTEGER newSlot,failCode,myThid,iDiag
      INTEGER*8 candidateId,candidateParent
      _RL candidateS,candidateX,candidateY
      _RL diag(BOM_RHS_NDIAG),xMap,ix,jy
      LOGICAL isValid,isOwner,hasStencil
      DO iDiag=1,BOM_RHS_NDIAG
        diag(iDiag)=0. _d 0
      ENDDO
      CALL BOM_MAP_XY2IJLOCAL(
     I     candidateX,candidateY,bi,bj,
     O     xMap,ix,jy,isOwner,hasStencil,myThid)
      IF ( .NOT.isOwner .OR. .NOT.hasStencil ) THEN
        newSlot=0
        failCode=BOM_FAIL_MAP
        isValid=.FALSE.
        RETURN
      ENDIF
      CALL BOM_FREE_ALLOC(
     I     bi,bj,candidateId,candidateParent,candidateStatus,
     I     candidateBirthCount,candidateX,candidateY,0. _d 0,
     I     0. _d 0,ix,jy,0. _d 0,0. _d 0,0. _d 0,0. _d 0,
     I     0. _d 0,0. _d 0,candidateS,0. _d 0,0. _d 0,
     I     0,0_8,0,diag,newSlot,failCode,isValid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P43_EVENT_ROLLBACK(
     I     nBefore,idBefore,sBefore,birthCountBefore,statusBefore,
     I     eventBefore,nextBefore,birthBefore,cancelBefore,deathBefore,
     I     freeRemoveBefore,freeAllocBefore,
     O     isValid,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nBefore,birthCountBefore,statusBefore,eventBefore,myThid
      INTEGER bi,bj,ip,nAfter
      INTEGER*8 idBefore,nextBefore,birthBefore,cancelBefore
      INTEGER*8 deathBefore,freeRemoveBefore,freeAllocBefore
      _RL sBefore
      LOGICAL isValid,found
      nAfter=0
      found=.FALSE.
      isValid=.TRUE.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        nAfter=nAfter+bomNPartTile(bi,bj)
        DO ip=1,bomNPartTile(bi,bj)
          IF ( bomId(ip,bi,bj).EQ.idBefore ) THEN
            found=.TRUE.
            isValid=isValid .AND. bomS(ip,bi,bj).EQ.sBefore
     &           .AND. bomBirthCount(ip,bi,bj).EQ.birthCountBefore
     &           .AND. bomStatus(ip,bi,bj).EQ.statusBefore
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      isValid=isValid .AND. nAfter.EQ.nBefore .AND. found .AND.
     &     bomEventBufferCount.EQ.eventBefore .AND.
     &     bomNextId.EQ.nextBefore .AND.
     &     bomBirthEvents.EQ.birthBefore .AND.
     &     bomCancelEvents.EQ.cancelBefore .AND.
     &     bomDeathEvents.EQ.deathBefore .AND.
     &     bomFreeRemoveOps.EQ.freeRemoveBefore .AND.
     &     bomFreeAllocOps.EQ.freeAllocBefore
      RETURN
      END
