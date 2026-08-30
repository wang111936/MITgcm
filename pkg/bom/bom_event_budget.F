#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_EVENT_BUDGET_CHECK
C !INTERFACE:
      SUBROUTINE BOM_EVENT_BUDGET_CHECK(
     O                 failCode,
     I                 myThid)

C !DESCRIPTION:
C     Close the authoritative live/event/free-tail budget.  Shard and
C     unflushed-buffer counts are combined exactly, so the same check applies
C     after a substep, output flush, or same-decomposition restart.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER failCode,myThid
      INTEGER bi,bj,ip,localOwners,globalOwners
      INTEGER localErrCount,globalErrCount,freeFail,eventType
      INTEGER*8 localCounts(5),globalCounts(5),recordWords(32)
      INTEGER*8 expectedLive
      LOGICAL freeValid,recordValid

      failCode=BOM_FAIL_EVENT_BUDGET
      localErrCount=0
      localOwners=0
      localCounts(1)=bomEventShardBirth
      localCounts(2)=bomEventShardDeath
      localCounts(3)=bomEventShardBeach
      localCounts(4)=bomEventShardOutside
      localCounts(5)=bomEventShardCancel
      IF ( bomEventBufferCount.LT.0 .OR.
     &     bomEventBufferCount.GT.bomMaxEventBuffer )
     &     localErrCount=localErrCount+1
      DO ip=1,MAX(0,MIN(bomEventBufferCount,bomMaxEventBuffer))
        CALL BOM_EVENT_PACK_RECORD(ip,recordWords,recordValid)
        IF ( .NOT.recordValid ) localErrCount=localErrCount+1
        eventType=bomEventTypeBuffer(ip)
        IF ( eventType.GE.BOM_EVENT_BIRTH .AND.
     &       eventType.LE.BOM_EVENT_BIRTH_CANCEL )
     &       localCounts(eventType)=localCounts(eventType)+1_8
      ENDDO
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        CALL BOM_FREE_VALIDATE(bi,bj,freeFail,freeValid)
        IF ( .NOT.freeValid ) localErrCount=localErrCount+1
        IF ( bomFreeCount(bi,bj).NE.
     &       bomMaxPartTile-bomNPartTile(bi,bj) )
     &       localErrCount=localErrCount+1
        localOwners=localOwners+bomNPartTile(bi,bj)
        DO ip=1,bomNPartTile(bi,bj)
          IF ( bomId(ip,bi,bj).LE.0_8 .OR.
     &         bomId(ip,bi,bj).GE.bomNextId .OR.
     &         bomParentId(ip,bi,bj).LT.0_8 .OR.
     &         bomParentId(ip,bi,bj).EQ.bomId(ip,bi,bj) .OR.
     &         .NOT.IEEE_IS_FINITE(bomS(ip,bi,bj)) )
     &         localErrCount=localErrCount+1
        ENDDO
       ENDDO
      ENDDO
      globalErrCount=localErrCount
      CALL GLOBAL_SUM_INT(globalErrCount,myThid)
      IF ( globalErrCount.GT.0 ) RETURN
      globalOwners=localOwners
      CALL GLOBAL_SUM_INT(globalOwners,myThid)
      CALL BOM_P4_GLOBAL_SUM_COUNTS(
     I     localCounts,5,
     O     globalCounts,localErrCount,
     I     myThid)
      globalErrCount=localErrCount
      CALL GLOBAL_SUM_INT(globalErrCount,myThid)
      IF ( globalErrCount.GT.0 ) RETURN
      expectedLive=INT(bomNPartExpected,8)+bomBirthEvents-
     &     bomDeathEvents-bomBeachEvents-bomOutsideEvents
      IF ( globalOwners.NE.bomNPartLiveExpected .OR.
     &     expectedLive.NE.INT(bomNPartLiveExpected,8) .OR.
     &     globalCounts(1).NE.bomBirthEvents .OR.
     &     globalCounts(2).NE.bomDeathEvents .OR.
     &     globalCounts(3).NE.bomBeachEvents .OR.
     &     globalCounts(4).NE.bomOutsideEvents .OR.
     &     globalCounts(5).NE.bomCancelEvents .OR.
     &     bomMissingGrowthEvents.LT.0_8 .OR.
     &     bomEventTimeIndex.LT.0_8 ) RETURN
      failCode=BOM_FAIL_NONE
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_DIAGNOSTICS_INIT
C !INTERFACE:
      SUBROUTINE BOM_DIAGNOSTICS_INIT(myThid)
      IMPLICIT NONE
#include "EEPARAMS.h"
      INTEGER myThid
#ifdef ALLOW_DIAGNOSTICS
      INTEGER diagNum
      CHARACTER*8 diagName
      CHARACTER*16 diagCode,diagUnits
      CHARACTER*80 diagTitle
      INTEGER DIAGS_GET_PARMS_I
      EXTERNAL DIAGS_GET_PARMS_I
      diagNum=DIAGS_GET_PARMS_I('LAST_DIAG_ID',myThid)
      diagCode='SM      M1      '
      diagName='BOMCOUNT'
      diagUnits='1               '
      diagTitle='Live BOM owner count per surface cell'
      CALL DIAGNOSTICS_ADDTOLIST(diagNum,diagName,diagCode,
     I     diagUnits,diagTitle,0,myThid)
      diagName='BOMMASS '
      diagUnits='amount          '
      diagTitle='Live BOM biological amount per surface cell'
      CALL DIAGNOSTICS_ADDTOLIST(diagNum,diagName,diagCode,
     I     diagUnits,diagTitle,0,myThid)
      diagName='BOMBIRTH'
      diagUnits='events          '
      diagTitle='Accepted BOM birth events per surface cell'
      CALL DIAGNOSTICS_ADDTOLIST(diagNum,diagName,diagCode,
     I     diagUnits,diagTitle,0,myThid)
      diagName='BOMDEAD '
      diagUnits='events          '
      diagTitle='Accepted BOM biological deaths per surface cell'
      CALL DIAGNOSTICS_ADDTOLIST(diagNum,diagName,diagCode,
     I     diagUnits,diagTitle,0,myThid)
      diagName='BOMBEACH'
      diagUnits='events          '
      diagTitle='Accepted BOM beaching events per surface cell'
      CALL DIAGNOSTICS_ADDTOLIST(diagNum,diagName,diagCode,
     I     diagUnits,diagTitle,0,myThid)
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_DIAGNOSTICS_FILL
C !INTERFACE:
      SUBROUTINE BOM_DIAGNOSTICS_FILL(
     I                 firstEvent,nEvents,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER firstEvent,nEvents,myThid
#ifdef ALLOW_DIAGNOSTICS
      _RL countField(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL massField(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL birthField(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL deathField(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      _RL beachField(1-OLx:sNx+OLx,1-OLy:sNy+OLy,nSx,nSy)
      INTEGER bi,bj,ip,i,j,eventSlot,eventType
      INTEGER iGlobal,jGlobal
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          countField(i,j,bi,bj)=0. _d 0
          massField(i,j,bi,bj)=0. _d 0
          birthField(i,j,bi,bj)=0. _d 0
          deathField(i,j,bi,bj)=0. _d 0
          beachField(i,j,bi,bj)=0. _d 0
         ENDDO
        ENDDO
        iGlobal=myXGlobalLo+(bi-1)*sNx
        jGlobal=myYGlobalLo+(bj-1)*sNy
        DO ip=1,bomNPartTile(bi,bj)
          IF ( bomStatus(ip,bi,bj).EQ.BOM_ALIVE ) THEN
            i=MAX(1,MIN(sNx,NINT(bomI(ip,bi,bj))-iGlobal+1))
            j=MAX(1,MIN(sNy,NINT(bomJ(ip,bi,bj))-jGlobal+1))
            countField(i,j,bi,bj)=countField(i,j,bi,bj)+1. _d 0
            massField(i,j,bi,bj)=massField(i,j,bi,bj)+
     &           bomS(ip,bi,bj)
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      DO ip=1,nEvents
        eventSlot=firstEvent+ip-1
        IF ( eventSlot.GE.1 .AND.
     &       eventSlot.LE.bomEventBufferCount ) THEN
          bi=bomEventSourceBiBuffer(eventSlot)
          bj=bomEventSourceBjBuffer(eventSlot)
          IF ( bi.GE.myBxLo(myThid) .AND. bi.LE.myBxHi(myThid)
     &         .AND. bj.GE.myByLo(myThid) .AND.
     &         bj.LE.myByHi(myThid) ) THEN
            iGlobal=myXGlobalLo+(bi-1)*sNx
            jGlobal=myYGlobalLo+(bj-1)*sNy
            i=MAX(1,MIN(sNx,NINT(
     &           bomEventAttemptXBuffer(eventSlot))-iGlobal+1))
            j=MAX(1,MIN(sNy,NINT(
     &           bomEventAttemptYBuffer(eventSlot))-jGlobal+1))
            eventType=bomEventTypeBuffer(eventSlot)
            IF ( eventType.EQ.BOM_EVENT_BIRTH )
     &           birthField(i,j,bi,bj)=birthField(i,j,bi,bj)+1. _d 0
            IF ( eventType.EQ.BOM_EVENT_DEAD_BIO )
     &           deathField(i,j,bi,bj)=deathField(i,j,bi,bj)+1. _d 0
            IF ( eventType.EQ.BOM_EVENT_BEACHED )
     &           beachField(i,j,bi,bj)=beachField(i,j,bi,bj)+1. _d 0
          ENDIF
        ENDIF
      ENDDO
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        CALL DIAGNOSTICS_FILL(countField(1-OLx,1-OLy,bi,bj),
     I       'BOMCOUNT',0,1,2,bi,bj,myThid)
        CALL DIAGNOSTICS_FILL(massField(1-OLx,1-OLy,bi,bj),
     I       'BOMMASS ',0,1,2,bi,bj,myThid)
        CALL DIAGNOSTICS_FILL(birthField(1-OLx,1-OLy,bi,bj),
     I       'BOMBIRTH',0,1,2,bi,bj,myThid)
        CALL DIAGNOSTICS_FILL(deathField(1-OLx,1-OLy,bi,bj),
     I       'BOMDEAD ',0,1,2,bi,bj,myThid)
        CALL DIAGNOSTICS_FILL(beachField(1-OLx,1-OLy,bi,bj),
     I       'BOMBEACH',0,1,2,bi,bj,myThid)
       ENDDO
      ENDDO
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
