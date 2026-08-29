#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P44_IO(myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
      CHARACTER*64 shaBefore,shaAfter,dataSha
      CHARACTER*(MAX_LEN_FNAM) shardName
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER err,nFail,globalFail
      INTEGER*8 records,births,deaths,beaches,outsides,cancels
      _RL timeMin,timeMax

      nFail=0
      bomEventFile='p44_event_io'
      bomP4SourceHead='0123456789abcdef0123456789abcdef01234567'
      bomMaxParticles=32
      CALL BOM_VERIFY_P44_SET_EVENT(
     I     1,BOM_EVENT_BIRTH,10_8,10. _d 0,101_8,11_8,101_8,
     I     myThid)
      CALL BOM_VERIFY_P44_SET_EVENT(
     I     2,BOM_EVENT_DEAD_BIO,10_8,10. _d 0,12_8,0_8,0_8,
     I     myThid)
      bomEventBufferCount=2
      CALL BOM_EVENT_FLUSH_IMPL(.TRUE.,.FALSE.,err,myThid)
      IF ( err.NE.0 .OR. bomEventBufferCount.NE.0 ) nFail=nFail+1
      CALL BOM_VERIFY_P44_SET_EVENT(
     I     1,BOM_EVENT_BEACHED,11_8,20. _d 0,13_8,0_8,0_8,
     I     myThid)
      CALL BOM_VERIFY_P44_SET_EVENT(
     I     2,BOM_EVENT_OUTSIDE,11_8,20. _d 0,14_8,0_8,0_8,
     I     myThid)
      CALL BOM_VERIFY_P44_SET_EVENT(
     I     3,BOM_EVENT_BIRTH_CANCEL,11_8,20. _d 0,
     I     15_8,15_8,0_8,myThid)
      bomEventBufferCount=3
      CALL BOM_EVENT_FLUSH_IMPL(.TRUE.,.FALSE.,err,myThid)
      IF ( err.NE.0 .OR. bomEventBufferCount.NE.0 ) nFail=nFail+1
      CALL BOM_LOAD_EVENT_SHARD_STATE(
     O     records,births,deaths,beaches,outsides,cancels,
     O     timeMin,timeMax,
     O     err,
     I     myThid)
      IF ( err.NE.0 .OR. records.NE.5_8 .OR. births.NE.1_8 .OR.
     &     deaths.NE.1_8 .OR. beaches.NE.1_8 .OR.
     &     outsides.NE.1_8 .OR. cancels.NE.1_8 .OR.
     &     timeMin.NE.10. _d 0 .OR. timeMax.NE.20. _d 0 )
     &     nFail=nFail+1
      CALL BOM_EVENT_FLUSH_IMPL(.TRUE.,.FALSE.,err,myThid)
      IF ( err.NE.0 .OR. bomEventShardRecords.NE.5_8 ) nFail=nFail+1

      WRITE(shardName,'(A,A,I6.6,A)')
     &     bomEventFile(1:LEN_TRIM(bomEventFile)),'.r',myProcId,
     &     '.events'
      CALL BOM_SHA256_FILE(shardName,shaBefore,err)
      CALL BOM_VERIFY_P44_SET_EVENT(
     I     1,BOM_EVENT_BIRTH_CANCEL,12_8,30. _d 0,
     I     16_8,16_8,0_8,myThid)
      bomEventBufferCount=1
      CALL BOM_EVENT_FLUSH_IMPL(.TRUE.,.TRUE.,err,myThid)
      IF ( err.EQ.0 .OR. bomEventBufferCount.NE.1 .OR.
     &     bomEventShardRecords.NE.5_8 ) nFail=nFail+1
      CALL BOM_SHA256_FILE(shardName,shaAfter,err)
      IF ( err.NE.0 .OR. shaAfter.NE.shaBefore ) nFail=nFail+1
      CALL BOM_EVENT_BUFFER_CLEAR
      CALL BOM_SHA256_FILE('data',dataSha,err)
      IF ( err.NE.0 ) nFail=nFail+1
      WRITE(msgBuf,'(A,A)') 'P44-SHA DATA ',dataSha
      CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                   SQUEEZE_RIGHT,myThid)
      globalFail=nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.NE.0 ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P4.4 IO FIXTURE'
      ENDIF
      IF ( myProcId.EQ.0 ) CALL PRINT_MESSAGE(
     &     'P4-EV01 PASS: event shards, SHA and rollback',
     &     standardMessageUnit,SQUEEZE_RIGHT,myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P44_WRITE(useSpring,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
      INTEGER ownerRank,bi,bj,hop,newSlot,seedFail,globalFail
      INTEGER failCode
      _RL xMap,yMap,theta
      INTEGER*8 randomWord
      LOGICAL useSpring,locateValid,seedValid,randomValid
      CHARACTER*10 suffix
      CHARACTER*(MAX_LEN_MBUF) msgBuf

      globalFail=0
      CALL BOM_VERIFY_P43_EVENT_CONFIG(
     I     0. _d 0,0. _d 0,useSpring,myThid)
      IF ( useSpring ) THEN
        bomSpringLaw='EBOMB'
        bomSpringA=0.001 _d 0
        bomSpringDelta=0.01 _d 0
        bomNeighborCutoff=50. _d 0
      ENDIF
      bomEnvIter(BOM_ENV_NEW)=bomEnvIter(BOM_ENV_OLD)
      bomBioIter(BOM_ENV_NEW)=bomBioIter(BOM_ENV_OLD)
      bomEventFile='p44_restart_events'
      bomP4SourceHead='0123456789abcdef0123456789abcdef01234567'
      bomOutputFreq=1200. _d 0
      bomNextOutputTime=1200. _d 0
      bomOutputScheduleReady=.TRUE.
      bomMaxParticles=16
      CALL BOM_LOCATE_OWNER(
     I     -100. _d 0,-100. _d 0,1,1,
     O     xMap,yMap,ownerRank,bi,bj,hop,locateValid,myThid)
      seedValid=.TRUE.
      IF ( myProcId.EQ.ownerRank ) CALL BOM_VERIFY_P43_EVENT_ALLOC(
     I     bi,bj,10_8,0_8,2,1.25 _d 0,
     I     -100. _d 0,-100. _d 0,BOM_ALIVE,
     O     newSlot,seedFail,seedValid,myThid)
      IF ( .NOT.locateValid .OR. .NOT.seedValid ) globalFail=1
      CALL BOM_LOCATE_OWNER(
     I     100. _d 0,100. _d 0,1,1,
     O     xMap,yMap,ownerRank,bi,bj,hop,locateValid,myThid)
      seedValid=.TRUE.
      IF ( myProcId.EQ.ownerRank ) CALL BOM_VERIFY_P43_EVENT_ALLOC(
     I     bi,bj,100_8,10_8,0,0.75 _d 0,
     I     100. _d 0,100. _d 0,BOM_ALIVE,
     O     newSlot,seedFail,seedValid,myThid)
      IF ( .NOT.locateValid .OR. .NOT.seedValid ) globalFail=1
      CALL BOM_VERIFY_P44_SET_P3_STATE(useSpring,myThid)
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.NE.0 ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P4.4 WRITE SEED'
      ENDIF
      bomNPartExpected=4
      bomNPartLiveExpected=2
      bomNextId=101_8
      bomEventTimeIndex=10_8
      bomBirthEvents=1_8
      bomDeathEvents=1_8
      bomBeachEvents=1_8
      bomOutsideEvents=1_8
      bomCancelEvents=1_8
      bomMissingGrowthEvents=2_8
      IF ( myProcId.EQ.0 ) THEN
        CALL BOM_VERIFY_P44_SET_EVENT(
     I       1,BOM_EVENT_BIRTH,5_8,300. _d 0,
     I       100_8,10_8,100_8,myThid)
        CALL BOM_VERIFY_P44_SET_EVENT(
     I       2,BOM_EVENT_DEAD_BIO,6_8,600. _d 0,
     I       20_8,0_8,0_8,myThid)
        CALL BOM_VERIFY_P44_SET_EVENT(
     I       3,BOM_EVENT_BEACHED,7_8,900. _d 0,
     I       30_8,0_8,0_8,myThid)
        CALL BOM_VERIFY_P44_SET_EVENT(
     I       4,BOM_EVENT_OUTSIDE,8_8,1200. _d 0,
     I       40_8,0_8,0_8,myThid)
        CALL BOM_VERIFY_P44_SET_EVENT(
     I       5,BOM_EVENT_BIRTH_CANCEL,9_8,1500. _d 0,
     I       10_8,10_8,0_8,myThid)
        bomEventBufferCount=5
      ENDIF
      WRITE(suffix,'(I10.10)') 0
      CALL BOM_WRITE_PICKUP(suffix,0. _d 0,0,myThid)
      CALL BOM_WRITE_TRAJECTORY(0. _d 0,0. _d 0,0,myThid)
      CALL BOM_BIRTH_RANDOM(
     I     bomSeed,10_8,2,bomEventTimeIndex,0,
     O     randomWord,theta,failCode,randomValid)
      IF ( .NOT.randomValid ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P4.4 WRITE RNG'
      ENDIF
      WRITE(msgBuf,1001) randomWord,TRANSFER(theta,0_8),
     &     bomNextId,bomEventTimeIndex
      CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                   SQUEEZE_RIGHT,myThid)
      CALL BOM_VERIFY_P44_PRINT_STATE('CONT',myThid)
      IF ( myProcId.EQ.0 ) CALL PRINT_MESSAGE(
     &     'P4-S01/B15 WRITE PASS: schema4 pickup and trajectory',
     &     standardMessageUnit,SQUEEZE_RIGHT,myThid)
 1001 FORMAT('P44-NEXT ',4(I20,1X))
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P44_READ(useSpring,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid,bi,bj,ip,i,j,iEnd,nLocal,nGlobal,failCode
      INTEGER*8 randomWord
      _RL theta
      LOGICAL useSpring,stateValid,randomValid
      CHARACTER*(MAX_LEN_MBUF) msgBuf

      CALL BOM_VERIFY_P43_EVENT_CONFIG(
     I     0. _d 0,0. _d 0,useSpring,myThid)
      IF ( useSpring ) THEN
        bomSpringLaw='EBOMB'
        bomSpringA=0.001 _d 0
        bomSpringDelta=0.01 _d 0
        bomNeighborCutoff=50. _d 0
      ENDIF
      bomEnvIter(BOM_ENV_NEW)=bomEnvIter(BOM_ENV_OLD)
      bomBioIter(BOM_ENV_NEW)=bomBioIter(BOM_ENV_OLD)
      bomEventFile='p44_restart_events'
      bomP4SourceHead='0123456789abcdef0123456789abcdef01234567'
      bomOutputFreq=1200. _d 0
      bomMaxParticles=16
      CALL BOM_VERIFY_P44_POISON_BIO(myThid)
      pickupSuff='0000000000'
      CALL BOM_READ_PICKUP(myThid)
      pickupSuff=' '
      stateValid=bomNPartExpected.EQ.4 .AND.
     &     bomNPartLiveExpected.EQ.2 .AND. bomNextId.EQ.101_8 .AND.
     &     bomEventTimeIndex.EQ.10_8 .AND. bomBirthEvents.EQ.1_8
     &     .AND. bomDeathEvents.EQ.1_8 .AND.
     &     bomBeachEvents.EQ.1_8 .AND. bomOutsideEvents.EQ.1_8
     &     .AND. bomCancelEvents.EQ.1_8 .AND.
     &     bomMissingGrowthEvents.EQ.2_8 .AND.
     &     bomEventBufferCount.EQ.0 .AND. bomEventShardReady
      stateValid=stateValid .AND. bomBioReady .AND.
     &     bomBioTime(BOM_ENV_OLD).EQ.0. _d 0 .AND.
     &     bomBioTime(BOM_ENV_NEW).EQ.0. _d 0 .AND.
     &     bomBioIter(BOM_ENV_OLD).EQ.0 .AND.
     &     bomBioIter(BOM_ENV_NEW).EQ.0
      nLocal=0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        IF ( bomFreeCount(bi,bj).NE.
     &       bomMaxPartTile-bomNPartTile(bi,bj) ) stateValid=.FALSE.
        DO ip=1,bomNPartTile(bi,bj)
          nLocal=nLocal+1
          IF ( bomId(ip,bi,bj).EQ.10_8 ) THEN
            IF ( bomParentId(ip,bi,bj).NE.0_8 .OR.
     &           bomBirthCount(ip,bi,bj).NE.2 .OR.
     &           bomS(ip,bi,bj).NE.1.25 _d 0 ) stateValid=.FALSE.
          ELSEIF ( bomId(ip,bi,bj).EQ.100_8 ) THEN
            IF ( bomParentId(ip,bi,bj).NE.10_8 .OR.
     &           bomBirthCount(ip,bi,bj).NE.0 .OR.
     &           bomS(ip,bi,bj).NE.0.75 _d 0 ) stateValid=.FALSE.
          ELSE
            stateValid=.FALSE.
          ENDIF
          IF ( useSpring ) THEN
            IF ( bomSpringEast(ip,bi,bj).NE.0. _d 0 .OR.
     &           bomSpringNorth(ip,bi,bj).NE.0. _d 0 .OR.
     &           bomNeighborCount(ip,bi,bj).NE.0 .OR.
     &           bomRaftId(ip,bi,bj).NE.bomId(ip,bi,bj) .OR.
     &           bomRaftSize(ip,bi,bj).NE.1 ) stateValid=.FALSE.
          ELSEIF ( bomSpringEast(ip,bi,bj).NE.0. _d 0 .OR.
     &             bomSpringNorth(ip,bi,bj).NE.0. _d 0 .OR.
     &             bomNeighborCount(ip,bi,bj).NE.0 .OR.
     &             bomRaftId(ip,bi,bj).NE.0_8 .OR.
     &             bomRaftSize(ip,bi,bj).NE.0 ) THEN
            stateValid=.FALSE.
          ENDIF
        ENDDO
        DO iEnd=1,BOM_ENV_NEND
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
            IF ( bomBioTemp(i,j,iEnd,bi,bj).NE.20. _d 0 .OR.
     &           bomBioN(i,j,iEnd,bi,bj).NE.1. _d 0 .OR.
     &           .NOT.bomBioValid(i,j,iEnd,bi,bj) )
     &           stateValid=.FALSE.
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      nGlobal=nLocal
      CALL GLOBAL_SUM_INT(nGlobal,myThid)
      IF ( nGlobal.NE.2 ) stateValid=.FALSE.
      CALL BOM_BIRTH_RANDOM(
     I     bomSeed,10_8,2,bomEventTimeIndex,0,
     O     randomWord,theta,failCode,randomValid)
      stateValid=stateValid .AND. randomValid
      CALL BOM_EVENT_BUDGET_CHECK(failCode,myThid)
      stateValid=stateValid .AND. failCode.EQ.BOM_FAIL_NONE
      IF ( .NOT.stateValid ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P4.4 READ STATE'
      ENDIF
      WRITE(msgBuf,1001) randomWord,TRANSFER(theta,0_8),
     &     bomNextId,bomEventTimeIndex
      CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                   SQUEEZE_RIGHT,myThid)
      CALL BOM_VERIFY_P44_PRINT_STATE('SPLIT',myThid)
      IF ( myProcId.EQ.0 ) CALL PRINT_MESSAGE(
     &     'B15/B18 READ PASS: bitwise schema4 restart and budget',
     &     standardMessageUnit,SQUEEZE_RIGHT,myThid)
 1001 FORMAT('P44-NEXT ',4(I20,1X))
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P44_SET_P3_STATE(useSpring,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      LOGICAL useSpring
      INTEGER myThid,bi,bj,ip
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomNPartTile(bi,bj)
          bomSpringEast(ip,bi,bj)=0. _d 0
          bomSpringNorth(ip,bi,bj)=0. _d 0
          bomNeighborCount(ip,bi,bj)=0
          bomRaftId(ip,bi,bj)=0_8
          bomRaftSize(ip,bi,bj)=0
          IF ( useSpring ) THEN
            bomRaftId(ip,bi,bj)=bomId(ip,bi,bj)
            bomRaftSize(ip,bi,bj)=1
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P44_POISON_BIO(myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid,bi,bj,i,j,iEnd
      bomBioReady=.FALSE.
      DO iEnd=1,BOM_ENV_NEND
        bomBioTime(iEnd)=-100. _d 0-DFLOAT(iEnd)
        bomBioIter(iEnd)=-iEnd
        bomBioTempSource(iEnd)=BOM_BIO_TEMP_NONE
        bomBioNSource(iEnd)=BOM_BIO_N_NONE
      ENDDO
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO iEnd=1,BOM_ENV_NEND
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
            bomBioTemp(i,j,iEnd,bi,bj)=-999. _d 0
            bomBioN(i,j,iEnd,bi,bj)=-999. _d 0
            bomBioValid(i,j,iEnd,bi,bj)=.FALSE.
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P44_SET_EVENT(
     I     slot,eventType,eventIndex,eventTime,subject,parent,child,
     I     myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER slot,eventType,myThid,newStatus
      INTEGER*8 eventIndex,subject,parent,child
      _RL eventTime
      newStatus=BOM_ALIVE
      IF ( eventType.EQ.BOM_EVENT_DEAD_BIO ) newStatus=BOM_DEAD_BIO
      IF ( eventType.EQ.BOM_EVENT_BEACHED ) newStatus=BOM_BEACHED
      IF ( eventType.EQ.BOM_EVENT_OUTSIDE ) newStatus=BOM_OUTSIDE
      bomEventTypeBuffer(slot)=eventType
      bomEventStageBuffer(slot)=BOM_STAGE_NONE
      bomEventOldStatusBuffer(slot)=BOM_ALIVE
      bomEventNewStatusBuffer(slot)=newStatus
      bomEventIterBuffer(slot)=INT(eventIndex)
      bomEventSubstepBuffer(slot)=1
      bomEventSourceRankBuffer(slot)=myProcId
      bomEventSourceBiBuffer(slot)=1
      bomEventSourceBjBuffer(slot)=1
      bomEventDestRankBuffer(slot)=myProcId
      bomEventDestBiBuffer(slot)=1
      bomEventDestBjBuffer(slot)=1
      bomEventRetryBuffer(slot)=0
      bomEventIndexBuffer(slot)=eventIndex
      bomEventSubjectIdBuffer(slot)=subject
      bomEventParentIdBuffer(slot)=parent
      bomEventChildIdBuffer(slot)=child
      bomEventTimeBuffer(slot)=eventTime
      bomEventAcceptedXBuffer(slot)=0. _d 0
      bomEventAcceptedYBuffer(slot)=0. _d 0
      bomEventAttemptXBuffer(slot)=0. _d 0
      bomEventAttemptYBuffer(slot)=0. _d 0
      bomEventSBeforeBuffer(slot)=1. _d 0
      bomEventSTrialBuffer(slot)=1. _d 0
      bomEventSAfterBuffer(slot)=1. _d 0
      IF ( eventType.EQ.BOM_EVENT_DEAD_BIO .OR.
     &     eventType.EQ.BOM_EVENT_BEACHED .OR.
     &     eventType.EQ.BOM_EVENT_OUTSIDE )
     &     bomEventSAfterBuffer(slot)=0. _d 0
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P44_PRINT_STATE(label,myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) label
      INTEGER myThid,bi,bj,ip
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomNPartTile(bi,bj)
          WRITE(msgBuf,1001) label,bomId(ip,bi,bj),
     &         bomParentId(ip,bi,bj),bomBirthCount(ip,bi,bj),
     &         TRANSFER(bomS(ip,bi,bj),0_8),bomStatus(ip,bi,bj),
     &         TRANSFER(bomSpringEast(ip,bi,bj),0_8),
     &         TRANSFER(bomSpringNorth(ip,bi,bj),0_8),
     &         bomNeighborCount(ip,bi,bj),bomRaftId(ip,bi,bj),
     &         bomRaftSize(ip,bi,bj)
          CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                       SQUEEZE_RIGHT,myThid)
        ENDDO
       ENDDO
      ENDDO
 1001 FORMAT('P44-STATE ',A,1X,2(I20,1X),I10,1X,I20,1X,I4,
     &       1X,2(I20,1X),I10,1X,I20,1X,I10)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
