#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_EVENT_FLUSH
C !INTERFACE:
      SUBROUTINE BOM_EVENT_FLUSH(
     I                 forceFlush,
     O                 localErrCount,
     I                 myThid)
      IMPLICIT NONE
      LOGICAL forceFlush
      INTEGER localErrCount,myThid
      CALL BOM_EVENT_FLUSH_IMPL(
     I     forceFlush,.FALSE.,
     O     localErrCount,
     I     myThid)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_EVENT_FLUSH_IMPL
C !INTERFACE:
      SUBROUTINE BOM_EVENT_FLUSH_IMPL(
     I                 forceFlush,injectFailure,
     O                 localErrCount,
     I                 myThid)

C !DESCRIPTION:
C     Transactionally append the accepted buffer to this rank's event
C     shard.  State and the buffer are changed only after the new shard and
C     its checksummed manifest have both been prepared successfully.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      LOGICAL forceFlush,injectFailure
      INTEGER localErrCount,myThid
      CHARACTER*(MAX_LEN_FNAM) shardName,manifestName
      CHARACTER*(MAX_LEN_FNAM) shardTemp,manifestTemp
      CHARACTER*(MAX_LEN_MBUF) line
      CHARACTER*64 shardDigest,paramDigest
      INTEGER ioUnit,ios,closeErr,renameErr,ip,k
      INTEGER loadedErr
      INTEGER*8 recordWords(bomP4EventFields)
      INTEGER*8 newRecords,newBirth,newDeath,newBeach
      INTEGER*8 newOutside,newCancel,loadedRecords
      INTEGER*8 loadedBirth,loadedDeath,loadedBeach
      INTEGER*8 loadedOutside,loadedCancel,shardBytes
      _RL newTimeMin,newTimeMax,loadedTimeMin,loadedTimeMax
      LOGICAL recordValid,exists
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

      localErrCount=0
      IF ( bomEventBufferCount.LT.0 .OR.
     &     bomEventBufferCount.GT.bomMaxEventBuffer .OR.
     &     ILNBLNK(bomEventFile).LE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF
      IF ( bomEventBufferCount.EQ.0 .AND.
     &     bomEventShardReady .AND. .NOT.forceFlush ) RETURN
      DO ip=1,bomEventBufferCount
        CALL BOM_EVENT_PACK_RECORD(
     I       ip,
     O       recordWords,recordValid)
        IF ( .NOT.recordValid ) localErrCount=localErrCount+1
      ENDDO
      IF ( injectFailure ) localErrCount=localErrCount+1
      IF ( localErrCount.NE.0 ) RETURN

      WRITE(shardName,'(A,A,I6.6,A)')
     &     bomEventFile(1:ILNBLNK(bomEventFile)),'.r',myProcId,
     &     '.events'
      WRITE(manifestName,'(A,A,I6.6,A)')
     &     bomEventFile(1:ILNBLNK(bomEventFile)),'.r',myProcId,
     &     '.manifest'
      WRITE(shardTemp,'(A,A)')
     &     shardName(1:ILNBLNK(shardName)),'.tmp'
      WRITE(manifestTemp,'(A,A)')
     &     manifestName(1:ILNBLNK(manifestName)),'.tmp'

      loadedRecords=0_8
      loadedBirth=0_8
      loadedDeath=0_8
      loadedBeach=0_8
      loadedOutside=0_8
      loadedCancel=0_8
      loadedTimeMin=0. _d 0
      loadedTimeMax=0. _d 0
      IF ( bomEventShardReady ) THEN
        CALL BOM_LOAD_EVENT_SHARD_STATE(
     O       loadedRecords,loadedBirth,loadedDeath,loadedBeach,
     O       loadedOutside,loadedCancel,
     O       loadedTimeMin,loadedTimeMax,
     O       loadedErr,
     I       myThid)
        IF ( loadedErr.NE.0 .OR.
     &       loadedRecords.NE.bomEventShardRecords .OR.
     &       loadedBirth.NE.bomEventShardBirth .OR.
     &       loadedDeath.NE.bomEventShardDeath .OR.
     &       loadedBeach.NE.bomEventShardBeach .OR.
     &       loadedOutside.NE.bomEventShardOutside .OR.
     &       loadedCancel.NE.bomEventShardCancel .OR.
     &       TRANSFER(loadedTimeMin,0_8).NE.
     &       TRANSFER(bomEventShardTimeMin,0_8) .OR.
     &       TRANSFER(loadedTimeMax,0_8).NE.
     &       TRANSFER(bomEventShardTimeMax,0_8) ) THEN
          localErrCount=1
          RETURN
        ENDIF
      ENDIF

      CALL BOM_COPY_FILE_BYTES(
     I     shardName,shardTemp,bomEventShardReady,
     O     localErrCount)
      IF ( localErrCount.NE.0 ) RETURN
      CALL MDSFINDUNIT(ioUnit,myThid)
      OPEN(ioUnit,FILE=shardTemp,STATUS='OLD',POSITION='APPEND',
     &     ACTION='WRITE',FORM='FORMATTED',IOSTAT=ios)
      IF ( ios.NE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF
      IF ( .NOT.bomEventShardReady ) THEN
        WRITE(ioUnit,'(A)',IOSTAT=ios)
     &       'MITGCM_BOM_EVENT_SHARD 1 32'
      ENDIF
      DO ip=1,bomEventBufferCount
        IF ( ios.EQ.0 ) THEN
          CALL BOM_EVENT_PACK_RECORD(
     I         ip,
     O         recordWords,recordValid)
          IF ( .NOT.recordValid ) ios=1
        ENDIF
        IF ( ios.EQ.0 ) WRITE(ioUnit,
     &       '(32(Z16.16,1X))',IOSTAT=ios)
     &       (recordWords(k),k=1,bomP4EventFields)
      ENDDO
      CLOSE(ioUnit,IOSTAT=closeErr)
      IF ( ios.NE.0 .OR. closeErr.NE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF

      newRecords=loadedRecords+INT(bomEventBufferCount,8)
      newBirth=loadedBirth
      newDeath=loadedDeath
      newBeach=loadedBeach
      newOutside=loadedOutside
      newCancel=loadedCancel
      newTimeMin=loadedTimeMin
      newTimeMax=loadedTimeMax
      DO ip=1,bomEventBufferCount
        IF ( bomEventTypeBuffer(ip).EQ.BOM_EVENT_BIRTH )
     &       newBirth=newBirth+1_8
        IF ( bomEventTypeBuffer(ip).EQ.BOM_EVENT_DEAD_BIO )
     &       newDeath=newDeath+1_8
        IF ( bomEventTypeBuffer(ip).EQ.BOM_EVENT_BEACHED )
     &       newBeach=newBeach+1_8
        IF ( bomEventTypeBuffer(ip).EQ.BOM_EVENT_OUTSIDE )
     &       newOutside=newOutside+1_8
        IF ( bomEventTypeBuffer(ip).EQ.BOM_EVENT_BIRTH_CANCEL )
     &       newCancel=newCancel+1_8
        IF ( loadedRecords.EQ.0_8 .AND. ip.EQ.1 ) THEN
          newTimeMin=bomEventTimeBuffer(ip)
          newTimeMax=bomEventTimeBuffer(ip)
        ELSE
          newTimeMin=MIN(newTimeMin,bomEventTimeBuffer(ip))
          newTimeMax=MAX(newTimeMax,bomEventTimeBuffer(ip))
        ENDIF
      ENDDO
      INQUIRE(FILE=shardTemp,EXIST=exists,SIZE=shardBytes,
     &        IOSTAT=ios)
      IF ( ios.NE.0 .OR. .NOT.exists .OR. shardBytes.LE.0_8 ) THEN
        localErrCount=1
        RETURN
      ENDIF
      CALL BOM_SHA256_FILE(shardTemp,shardDigest,localErrCount)
      IF ( localErrCount.NE.0 ) RETURN
      CALL BOM_EVENT_PARAMETER_SHA(paramDigest,localErrCount,myThid)
      IF ( localErrCount.NE.0 ) RETURN

      CALL MDSFINDUNIT(ioUnit,myThid)
      OPEN(ioUnit,FILE=manifestTemp,STATUS='REPLACE',ACTION='WRITE',
     &     FORM='FORMATTED',IOSTAT=ios)
      IF ( ios.NE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF
      WRITE(ioUnit,'(A)',IOSTAT=ios)
     &     'MITGCM_BOM_EVENT_MANIFEST 1'
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0,A,I0)',IOSTAT=ios)
     &     'schema ',bomP4EventSchema,' fields ',bomP4EventFields
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,A)',IOSTAT=ios)
     &     'source_head ',bomP4SourceHead
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,A)',IOSTAT=ios)
     &     'parameter_sha256 ',paramDigest
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0,A,I0)',IOSTAT=ios)
     &     'rank ',myProcId,' ranks ',nPx*nPy
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0)',IOSTAT=ios)
     &     'record_count ',newRecords
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0,A,I0,A,I0)',IOSTAT=ios)
     &     'birth ',newBirth,' death ',newDeath,' beach ',newBeach
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0,A,I0)',IOSTAT=ios)
     &     'outside ',newOutside,' cancel ',newCancel
      IF ( ios.EQ.0 ) WRITE(ioUnit,
     &     '(A,Z16.16,A,Z16.16)',IOSTAT=ios)
     &     'time_min_bits ',TRANSFER(newTimeMin,0_8),
     &     ' time_max_bits ',TRANSFER(newTimeMax,0_8)
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0)',IOSTAT=ios)
     &     'shard_size ',shardBytes
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,A)',IOSTAT=ios)
     &     'shard_sha256 ',shardDigest
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,A)',IOSTAT=ios)
     &     'shard_name ',shardName(1:ILNBLNK(shardName))
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A)',IOSTAT=ios) 'complete 1'
      CLOSE(ioUnit,IOSTAT=closeErr)
      IF ( ios.NE.0 .OR. closeErr.NE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF
      CALL BOM_P4_ATOMIC_RENAME(
     I     shardTemp,shardName,
     O     renameErr)
      IF ( renameErr.EQ.0 ) CALL BOM_P4_ATOMIC_RENAME(
     I     manifestTemp,manifestName,
     O     renameErr)
      IF ( renameErr.NE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF

C--   The publication point is the successful manifest rename.
      bomEventShardRecords=newRecords
      bomEventShardBirth=newBirth
      bomEventShardDeath=newDeath
      bomEventShardBeach=newBeach
      bomEventShardOutside=newOutside
      bomEventShardCancel=newCancel
      bomEventShardTimeMin=newTimeMin
      bomEventShardTimeMax=newTimeMax
      bomEventShardReady=.TRUE.
      CALL BOM_EVENT_BUFFER_CLEAR
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_EVENT_PACK_RECORD(
     I                 eventSlot,
     O                 words,isValid)
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER eventSlot
      INTEGER*8 words(bomP4EventFields)
      LOGICAL isValid,wordValid
      INTEGER k,eventType,newStatus
      INTEGER*8 highWord,lowWord

      isValid=.FALSE.
      DO k=1,bomP4EventFields
        words(k)=0_8
      ENDDO
      IF ( eventSlot.LT.1 .OR.
     &     eventSlot.GT.bomEventBufferCount ) RETURN
      eventType=bomEventTypeBuffer(eventSlot)
      newStatus=bomEventNewStatusBuffer(eventSlot)
      IF ( eventType.LT.BOM_EVENT_BIRTH .OR.
     &     eventType.GT.BOM_EVENT_BIRTH_CANCEL ) RETURN
      IF ( bomEventIterBuffer(eventSlot).LT.0 .OR.
     &     bomEventSubstepBuffer(eventSlot).LT.0 .OR.
     &     bomEventRetryBuffer(eventSlot).LT.0 .OR.
     &     bomEventSourceRankBuffer(eventSlot).LT.0 .OR.
     &     bomEventSourceRankBuffer(eventSlot).GE.nPx*nPy .OR.
     &     bomEventDestRankBuffer(eventSlot).LT.0 .OR.
     &     bomEventDestRankBuffer(eventSlot).GE.nPx*nPy .OR.
     &     bomEventSourceBiBuffer(eventSlot).LT.1 .OR.
     &     bomEventSourceBiBuffer(eventSlot).GT.nSx .OR.
     &     bomEventSourceBjBuffer(eventSlot).LT.1 .OR.
     &     bomEventSourceBjBuffer(eventSlot).GT.nSy .OR.
     &     bomEventDestBiBuffer(eventSlot).LT.1 .OR.
     &     bomEventDestBiBuffer(eventSlot).GT.nSx .OR.
     &     bomEventDestBjBuffer(eventSlot).LT.1 .OR.
     &     bomEventDestBjBuffer(eventSlot).GT.nSy ) RETURN
      IF ( bomEventStageBuffer(eventSlot).LT.BOM_STAGE_NONE .OR.
     &     bomEventStageBuffer(eventSlot).GT.BOM_STAGE_FINAL ) RETURN
      IF ( bomEventOldStatusBuffer(eventSlot).NE.BOM_ALIVE ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(bomEventTimeBuffer(eventSlot)) .OR.
     &     .NOT.IEEE_IS_FINITE(bomEventAcceptedXBuffer(eventSlot)) .OR.
     &     .NOT.IEEE_IS_FINITE(bomEventAcceptedYBuffer(eventSlot)) .OR.
     &     .NOT.IEEE_IS_FINITE(bomEventAttemptXBuffer(eventSlot)) .OR.
     &     .NOT.IEEE_IS_FINITE(bomEventAttemptYBuffer(eventSlot)) .OR.
     &     .NOT.IEEE_IS_FINITE(bomEventSBeforeBuffer(eventSlot)) .OR.
     &     .NOT.IEEE_IS_FINITE(bomEventSTrialBuffer(eventSlot)) .OR.
     &     .NOT.IEEE_IS_FINITE(bomEventSAfterBuffer(eventSlot)) ) RETURN
      IF ( eventType.EQ.BOM_EVENT_BIRTH ) THEN
        IF ( newStatus.NE.BOM_ALIVE .OR.
     &       bomEventChildIdBuffer(eventSlot).LE.0_8 .OR.
     &       bomEventSubjectIdBuffer(eventSlot).NE.
     &       bomEventChildIdBuffer(eventSlot) .OR.
     &       bomEventParentIdBuffer(eventSlot).LE.0_8 ) RETURN
      ELSEIF ( eventType.EQ.BOM_EVENT_BIRTH_CANCEL ) THEN
        IF ( newStatus.NE.BOM_ALIVE .OR.
     &       bomEventChildIdBuffer(eventSlot).NE.0_8 .OR.
     &       bomEventSubjectIdBuffer(eventSlot).NE.
     &       bomEventParentIdBuffer(eventSlot) .OR.
     &       bomEventParentIdBuffer(eventSlot).LE.0_8 ) RETURN
      ELSE
        IF ( bomEventChildIdBuffer(eventSlot).NE.0_8 .OR.
     &       bomEventSubjectIdBuffer(eventSlot).LE.0_8 ) RETURN
        IF ( eventType.EQ.BOM_EVENT_DEAD_BIO .AND.
     &       newStatus.NE.BOM_DEAD_BIO ) RETURN
        IF ( eventType.EQ.BOM_EVENT_BEACHED .AND.
     &       newStatus.NE.BOM_BEACHED ) RETURN
        IF ( eventType.EQ.BOM_EVENT_OUTSIDE .AND.
     &       newStatus.NE.BOM_OUTSIDE ) RETURN
      ENDIF

      words(1)=INT(bomP4EventSchema,8)
      words(2)=INT(eventType,8)
      CALL BOM_P4_I8_WORDS(
     I     bomEventIndexBuffer(eventSlot),highWord,lowWord,wordValid)
      IF ( .NOT.wordValid ) RETURN
      words(3)=highWord
      words(4)=lowWord
      words(5)=TRANSFER(bomEventTimeBuffer(eventSlot),words(5))
      words(6)=INT(bomEventIterBuffer(eventSlot),8)
      words(7)=INT(bomEventSubstepBuffer(eventSlot),8)
      CALL BOM_P4_I8_WORDS(
     I     bomEventSubjectIdBuffer(eventSlot),highWord,lowWord,
     O     wordValid)
      IF ( .NOT.wordValid ) RETURN
      words(8)=highWord
      words(9)=lowWord
      CALL BOM_P4_I8_WORDS(
     I     bomEventParentIdBuffer(eventSlot),highWord,lowWord,
     O     wordValid)
      IF ( .NOT.wordValid ) RETURN
      words(10)=highWord
      words(11)=lowWord
      CALL BOM_P4_I8_WORDS(
     I     bomEventChildIdBuffer(eventSlot),highWord,lowWord,
     O     wordValid)
      IF ( .NOT.wordValid ) RETURN
      words(12)=highWord
      words(13)=lowWord
      words(14)=INT(bomEventOldStatusBuffer(eventSlot),8)
      words(15)=INT(newStatus,8)
      words(16)=TRANSFER(bomEventAcceptedXBuffer(eventSlot),words(16))
      words(17)=TRANSFER(bomEventAcceptedYBuffer(eventSlot),words(17))
      words(18)=TRANSFER(bomEventAttemptXBuffer(eventSlot),words(18))
      words(19)=TRANSFER(bomEventAttemptYBuffer(eventSlot),words(19))
      words(20)=TRANSFER(bomEventSBeforeBuffer(eventSlot),words(20))
      words(21)=TRANSFER(bomEventSTrialBuffer(eventSlot),words(21))
      words(22)=TRANSFER(bomEventSAfterBuffer(eventSlot),words(22))
      words(23)=INT(bomEventRetryBuffer(eventSlot),8)
      words(24)=INT(bomEventStageBuffer(eventSlot),8)
      words(25)=INT(bomEventSourceRankBuffer(eventSlot),8)
      words(26)=INT(bomEventSourceBiBuffer(eventSlot),8)
      words(27)=INT(bomEventSourceBjBuffer(eventSlot),8)
      words(28)=INT(bomEventDestRankBuffer(eventSlot),8)
      words(29)=INT(bomEventDestBiBuffer(eventSlot),8)
      words(30)=INT(bomEventDestBjBuffer(eventSlot),8)
      words(31)=0_8
      words(32)=0_8
      isValid=.TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_EVENT_BUFFER_CLEAR
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER ip
      DO ip=1,bomEventBufferCount
        bomEventTypeBuffer(ip)=BOM_EVENT_NONE
        bomEventStageBuffer(ip)=BOM_STAGE_NONE
        bomEventOldStatusBuffer(ip)=BOM_UNUSED
        bomEventNewStatusBuffer(ip)=BOM_UNUSED
        bomEventIterBuffer(ip)=0
        bomEventSubstepBuffer(ip)=0
        bomEventSourceRankBuffer(ip)=0
        bomEventSourceBiBuffer(ip)=0
        bomEventSourceBjBuffer(ip)=0
        bomEventDestRankBuffer(ip)=0
        bomEventDestBiBuffer(ip)=0
        bomEventDestBjBuffer(ip)=0
        bomEventRetryBuffer(ip)=0
        bomEventIndexBuffer(ip)=0_8
        bomEventSubjectIdBuffer(ip)=0_8
        bomEventParentIdBuffer(ip)=0_8
        bomEventChildIdBuffer(ip)=0_8
        bomEventTimeBuffer(ip)=0. _d 0
        bomEventAcceptedXBuffer(ip)=0. _d 0
        bomEventAcceptedYBuffer(ip)=0. _d 0
        bomEventAttemptXBuffer(ip)=0. _d 0
        bomEventAttemptYBuffer(ip)=0. _d 0
        bomEventSBeforeBuffer(ip)=0. _d 0
        bomEventSTrialBuffer(ip)=0. _d 0
        bomEventSAfterBuffer(ip)=0. _d 0
      ENDDO
      bomEventBufferCount=0
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_LOAD_EVENT_SHARD_STATE(
     O                 recordCount,birthCount,deathCount,beachCount,
     O                 outsideCount,cancelCount,timeMin,timeMax,
     O                 localErrCount,
     I                 myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER*8 recordCount,birthCount,deathCount,beachCount
      INTEGER*8 outsideCount,cancelCount
      _RL timeMin,timeMax
      INTEGER localErrCount,myThid
      CHARACTER*(MAX_LEN_FNAM) shardName,manifestName,storedName
      CHARACTER*(MAX_LEN_MBUF) line,expectedLine
      CHARACTER*64 storedDigest,actualDigest,paramDigest
      CHARACTER*32 tag1,tag2,tag3
      INTEGER ioUnit,ios,storedSchema,storedFields
      INTEGER storedRank,storedRanks
      INTEGER*8 storedBytes,actualBytes,timeMinBits,timeMaxBits
      INTEGER*8 countedRecords,countedBirth,countedDeath,countedBeach
      INTEGER*8 countedOutside,countedCancel
      _RL countedTimeMin,countedTimeMax
      LOGICAL exists
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

      localErrCount=0
      recordCount=0_8
      birthCount=0_8
      deathCount=0_8
      beachCount=0_8
      outsideCount=0_8
      cancelCount=0_8
      timeMin=0. _d 0
      timeMax=0. _d 0
      WRITE(shardName,'(A,A,I6.6,A)')
     &     bomEventFile(1:ILNBLNK(bomEventFile)),'.r',myProcId,
     &     '.events'
      WRITE(manifestName,'(A,A,I6.6,A)')
     &     bomEventFile(1:ILNBLNK(bomEventFile)),'.r',myProcId,
     &     '.manifest'
      INQUIRE(FILE=manifestName,EXIST=exists)
      IF ( .NOT.exists ) THEN
        localErrCount=1
        RETURN
      ENDIF
      CALL MDSFINDUNIT(ioUnit,myThid)
      OPEN(ioUnit,FILE=manifestName,STATUS='OLD',ACTION='READ',
     &     FORM='FORMATTED',IOSTAT=ios)
      IF ( ios.NE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF
      READ(ioUnit,'(A)',IOSTAT=ios) line
      IF ( ios.EQ.0 .AND.
     &     line.NE.'MITGCM_BOM_EVENT_MANIFEST 1' ) ios=1
      storedSchema=-1
      storedFields=-1
      IF ( ios.EQ.0 ) READ(ioUnit,*,IOSTAT=ios)
     &     tag1,storedSchema,tag2,storedFields
      IF ( ios.EQ.0 .AND.
     &     ( tag1.NE.'schema' .OR. tag2.NE.'fields' .OR.
     &       storedSchema.NE.bomP4EventSchema .OR.
     &       storedFields.NE.bomP4EventFields ) ) ios=1
      IF ( ios.EQ.0 ) THEN
        WRITE(expectedLine,'(A,A)') 'source_head ',bomP4SourceHead
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND.
     &       line(1:ILNBLNK(line)).NE.
     &       expectedLine(1:ILNBLNK(expectedLine)) ) ios=1
      ENDIF
      CALL BOM_EVENT_PARAMETER_SHA(paramDigest,localErrCount,myThid)
      IF ( ios.EQ.0 .AND. localErrCount.EQ.0 ) THEN
        WRITE(expectedLine,'(A,A)') 'parameter_sha256 ',paramDigest
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND.
     &       line(1:ILNBLNK(line)).NE.
     &       expectedLine(1:ILNBLNK(expectedLine)) ) ios=1
      ENDIF
      storedRank=-1
      storedRanks=-1
      IF ( ios.EQ.0 ) READ(ioUnit,*,IOSTAT=ios)
     &     tag1,storedRank,tag2,storedRanks
      IF ( ios.EQ.0 .AND.
     &     ( tag1.NE.'rank' .OR. tag2.NE.'ranks' .OR.
     &       storedRank.NE.myProcId .OR.
     &       storedRanks.NE.nPx*nPy ) ) ios=1
      IF ( ios.EQ.0 ) READ(ioUnit,*,IOSTAT=ios) tag1,recordCount
      IF ( ios.EQ.0 .AND. tag1.NE.'record_count' ) ios=1
      IF ( ios.EQ.0 ) READ(ioUnit,*,IOSTAT=ios)
     &     tag1,birthCount,tag2,deathCount,tag3,beachCount
      IF ( ios.EQ.0 .AND.
     &     ( tag1.NE.'birth' .OR. tag2.NE.'death' .OR.
     &       tag3.NE.'beach' ) ) ios=1
      IF ( ios.EQ.0 ) READ(ioUnit,*,IOSTAT=ios)
     &     tag1,outsideCount,tag2,cancelCount
      IF ( ios.EQ.0 .AND.
     &     ( tag1.NE.'outside' .OR. tag2.NE.'cancel' ) ) ios=1
      IF ( ios.EQ.0 ) READ(ioUnit,
     &     '(14X,Z16,15X,Z16)',IOSTAT=ios) timeMinBits,timeMaxBits
      timeMin=TRANSFER(timeMinBits,timeMin)
      timeMax=TRANSFER(timeMaxBits,timeMax)
      IF ( ios.EQ.0 ) READ(ioUnit,*,IOSTAT=ios) tag1,storedBytes
      IF ( ios.EQ.0 .AND. tag1.NE.'shard_size' ) ios=1
      IF ( ios.EQ.0 ) READ(ioUnit,*,IOSTAT=ios)
     &     tag1,storedDigest
      IF ( ios.EQ.0 .AND. tag1.NE.'shard_sha256' ) ios=1
      storedName=' '
      IF ( ios.EQ.0 ) READ(ioUnit,*,IOSTAT=ios) tag1,storedName
      IF ( ios.EQ.0 .AND.
     &     ( tag1.NE.'shard_name' .OR.
     &       storedName.NE.shardName ) ) ios=1
      IF ( ios.EQ.0 ) THEN
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND. line.NE.'complete 1' ) ios=1
      ENDIF
      IF ( ios.EQ.0 ) THEN
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.NE.-1 ) ios=1
      ENDIF
      CLOSE(ioUnit)
      IF ( ios.NE.-1 .OR. localErrCount.NE.0 .OR.
     &     recordCount.LT.0_8 .OR. birthCount.LT.0_8 .OR.
     &     deathCount.LT.0_8 .OR. beachCount.LT.0_8 .OR.
     &     outsideCount.LT.0_8 .OR. cancelCount.LT.0_8 .OR.
     &     birthCount+deathCount+beachCount+outsideCount+
     &     cancelCount.NE.recordCount ) THEN
        localErrCount=1
        RETURN
      ENDIF
      actualBytes=-1_8
      INQUIRE(FILE=shardName,EXIST=exists,SIZE=actualBytes,IOSTAT=ios)
      IF ( ios.NE.0 .OR. .NOT.exists .OR.
     &     actualBytes.NE.storedBytes ) THEN
        localErrCount=1
        RETURN
      ENDIF
      CALL BOM_SHA256_FILE(shardName,actualDigest,localErrCount)
      IF ( localErrCount.NE.0 .OR.
     &     actualDigest.NE.storedDigest ) THEN
        localErrCount=1
        RETURN
      ENDIF
      CALL BOM_VALIDATE_EVENT_SHARD_CONTENT(
     I     shardName,
     O     countedRecords,countedBirth,countedDeath,countedBeach,
     O     countedOutside,countedCancel,
     O     countedTimeMin,countedTimeMax,
     O     localErrCount,
     I     myThid)
      IF ( localErrCount.NE.0 .OR.
     &     countedRecords.NE.recordCount .OR.
     &     countedBirth.NE.birthCount .OR.
     &     countedDeath.NE.deathCount .OR.
     &     countedBeach.NE.beachCount .OR.
     &     countedOutside.NE.outsideCount .OR.
     &     countedCancel.NE.cancelCount .OR.
     &     TRANSFER(countedTimeMin,0_8).NE.timeMinBits .OR.
     &     TRANSFER(countedTimeMax,0_8).NE.timeMaxBits )
     &     localErrCount=1
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VALIDATE_EVENT_SHARD_CONTENT(
     I                 shardName,
     O                 recordCount,birthCount,deathCount,beachCount,
     O                 outsideCount,cancelCount,timeMin,timeMax,
     O                 localErrCount,
     I                 myThid)
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) shardName
      INTEGER*8 recordCount,birthCount,deathCount,beachCount
      INTEGER*8 outsideCount,cancelCount
      _RL timeMin,timeMax,eventTime
      INTEGER localErrCount,myThid
      CHARACTER*(MAX_LEN_MBUF) line
      INTEGER*8 words(bomP4EventFields)
      INTEGER*8 subjectId,parentId,childId,radix
      INTEGER ioUnit,ios,k,eventType
      _RL realValue

      localErrCount=0
      recordCount=0_8
      birthCount=0_8
      deathCount=0_8
      beachCount=0_8
      outsideCount=0_8
      cancelCount=0_8
      timeMin=0. _d 0
      timeMax=0. _d 0
      radix=4294967296_8
      CALL MDSFINDUNIT(ioUnit,myThid)
      OPEN(ioUnit,FILE=shardName,STATUS='OLD',ACTION='READ',
     &     FORM='FORMATTED',IOSTAT=ios)
      IF ( ios.NE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF
      READ(ioUnit,'(A)',IOSTAT=ios) line
      IF ( ios.EQ.0 .AND.
     &     line.NE.'MITGCM_BOM_EVENT_SHARD 1 32' ) ios=1
      DO WHILE ( ios.EQ.0 )
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 ) THEN
          READ(line,'(32(Z16.16,1X))',IOSTAT=ios)
     &         (words(k),k=1,bomP4EventFields)
          IF ( ios.EQ.0 ) THEN
            eventType=INT(words(2))
            eventTime=TRANSFER(words(5),eventTime)
            IF ( words(1).NE.INT(bomP4EventSchema,8) .OR.
     &           eventType.LT.BOM_EVENT_BIRTH .OR.
     &           eventType.GT.BOM_EVENT_BIRTH_CANCEL .OR.
     &           words(3).LT.0_8 .OR.
     &           words(3).GT.2147483647_8 .OR.
     &           words(4).LT.0_8 .OR.
     &           words(4).GT.4294967295_8 .OR.
     &           words(8).LT.0_8 .OR.
     &           words(8).GT.2147483647_8 .OR.
     &           words(9).LT.0_8 .OR.
     &           words(9).GT.4294967295_8 .OR.
     &           words(10).LT.0_8 .OR.
     &           words(10).GT.2147483647_8 .OR.
     &           words(11).LT.0_8 .OR.
     &           words(11).GT.4294967295_8 .OR.
     &           words(12).LT.0_8 .OR.
     &           words(12).GT.2147483647_8 .OR.
     &           words(13).LT.0_8 .OR.
     &           words(13).GT.4294967295_8 .OR.
     &           words(6).LT.0_8 .OR. words(7).LT.0_8 .OR.
     &           words(14).NE.INT(BOM_ALIVE,8) .OR.
     &           words(23).LT.0_8 .OR.
     &           words(24).LT.INT(BOM_STAGE_NONE,8) .OR.
     &           words(24).GT.INT(BOM_STAGE_FINAL,8) .OR.
     &           words(25).LT.0_8 .OR.
     &           words(25).GE.INT(nPx*nPy,8) .OR.
     &           words(26).LT.1_8 .OR. words(26).GT.INT(nSx,8)
     &           .OR. words(27).LT.1_8 .OR.
     &           words(27).GT.INT(nSy,8) .OR.
     &           words(28).LT.0_8 .OR.
     &           words(28).GE.INT(nPx*nPy,8) .OR.
     &           words(29).LT.1_8 .OR. words(29).GT.INT(nSx,8)
     &           .OR. words(30).LT.1_8 .OR.
     &           words(30).GT.INT(nSy,8) .OR.
     &           words(31).NE.0_8 .OR. words(32).NE.0_8 .OR.
     &           .NOT.IEEE_IS_FINITE(eventTime) ) ios=1
            subjectId=words(8)*radix+words(9)
            parentId=words(10)*radix+words(11)
            childId=words(12)*radix+words(13)
            DO k=16,22
              realValue=TRANSFER(words(k),realValue)
              IF ( .NOT.IEEE_IS_FINITE(realValue) ) ios=1
            ENDDO
            IF ( subjectId.LE.0_8 .OR. parentId.LT.0_8 ) ios=1
            IF ( eventType.EQ.BOM_EVENT_BIRTH ) THEN
              IF ( childId.LE.0_8 .OR. subjectId.NE.childId .OR.
     &             parentId.LE.0_8 .OR.
     &             parentId.EQ.subjectId .OR.
     &             words(15).NE.INT(BOM_ALIVE,8) ) ios=1
            ELSEIF ( eventType.EQ.BOM_EVENT_BIRTH_CANCEL ) THEN
              IF ( childId.NE.0_8 .OR. subjectId.NE.parentId .OR.
     &             words(15).NE.INT(BOM_ALIVE,8) ) ios=1
            ELSE
              IF ( childId.NE.0_8 .OR. parentId.EQ.subjectId ) ios=1
              IF ( eventType.EQ.BOM_EVENT_DEAD_BIO .AND.
     &             words(15).NE.INT(BOM_DEAD_BIO,8) ) ios=1
              IF ( eventType.EQ.BOM_EVENT_BEACHED .AND.
     &             words(15).NE.INT(BOM_BEACHED,8) ) ios=1
              IF ( eventType.EQ.BOM_EVENT_OUTSIDE .AND.
     &             words(15).NE.INT(BOM_OUTSIDE,8) ) ios=1
            ENDIF
          ENDIF
          IF ( ios.EQ.0 ) THEN
            recordCount=recordCount+1_8
            IF ( recordCount.EQ.1_8 ) THEN
              timeMin=eventTime
              timeMax=eventTime
            ELSE
              timeMin=MIN(timeMin,eventTime)
              timeMax=MAX(timeMax,eventTime)
            ENDIF
            IF ( eventType.EQ.BOM_EVENT_BIRTH )
     &           birthCount=birthCount+1_8
            IF ( eventType.EQ.BOM_EVENT_DEAD_BIO )
     &           deathCount=deathCount+1_8
            IF ( eventType.EQ.BOM_EVENT_BEACHED )
     &           beachCount=beachCount+1_8
            IF ( eventType.EQ.BOM_EVENT_OUTSIDE )
     &           outsideCount=outsideCount+1_8
            IF ( eventType.EQ.BOM_EVENT_BIRTH_CANCEL )
     &           cancelCount=cancelCount+1_8
          ENDIF
        ENDIF
      ENDDO
      CLOSE(ioUnit)
      IF ( ios.NE.-1 ) localErrCount=1
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_EVENT_PARAMETER_SHA(
     O                 digest,localErrCount,
     I                 myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*64 digest
      INTEGER localErrCount,myThid
      CHARACTER*(MAX_LEN_FNAM) tempName
      INTEGER ioUnit,ios,closeErr
      INTEGER*8 realBits(18)
      LOGICAL exists

      localErrCount=0
      WRITE(tempName,'(A,I6.6,A)')
     &     '.bom-p4-parameters.r',myProcId,'.tmp'
      realBits(1)=TRANSFER(bomSpringL,realBits(1))
      realBits(2)=TRANSFER(bomHookeK,realBits(2))
      realBits(3)=TRANSFER(bomSpringA,realBits(3))
      realBits(4)=TRANSFER(bomSpringDelta,realBits(4))
      realBits(5)=TRANSFER(bomNeighborCutoff,realBits(5))
      realBits(6)=TRANSFER(bomPairDistanceMin,realBits(6))
      realBits(7)=TRANSFER(bomMuMax,realBits(7))
      realBits(8)=TRANSFER(bomMort,realBits(8))
      realBits(9)=TRANSFER(bomKN,realBits(9))
      realBits(10)=TRANSFER(bomTMin,realBits(10))
      realBits(11)=TRANSFER(bomTMax,realBits(11))
      realBits(12)=TRANSFER(bomS0,realBits(12))
      realBits(13)=TRANSFER(bomSMin,realBits(13))
      realBits(14)=TRANSFER(bomSMax,realBits(14))
      realBits(15)=TRANSFER(bomNStartTime,realBits(15))
      realBits(16)=TRANSFER(bomNPeriod,realBits(16))
      realBits(17)=TRANSFER(bomNRepCycle,realBits(17))
      realBits(18)=TRANSFER(bomNInScale,realBits(18))
      CALL MDSFINDUNIT(ioUnit,myThid)
      OPEN(ioUnit,FILE=tempName,STATUS='REPLACE',ACTION='WRITE',
     &     FORM='FORMATTED',IOSTAT=ios)
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A)',IOSTAT=ios)
     &     'MITGCM_BOM_P4_PARAMETERS 1'
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(9(I0,1X))',IOSTAT=ios)
     &     nPx,nPy,sNx,sNy,nSx,nSy,Nx,Ny,bomMaxPartTile
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(5(I0,1X))',IOSTAT=ios)
     &     bomSeed,bomMaxParticles,bomBirthMaxTry,
     &     bomNTracerIndex,bomNFilePrec
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(18(Z16.16,1X))',IOSTAT=ios)
     &     realBits
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(10(A,1X))',IOSTAT=ios)
     &     bomMode,bomEquationMode,bomIntegrator,bomCurrentPolicy,
     &     bomSpringLaw,bomNeighborPolicy,bomTempSource,bomNSource,
     &     bomBiologyMissingPolicy,bomEventFile
      CLOSE(ioUnit,IOSTAT=closeErr)
      IF ( ios.NE.0 .OR. closeErr.NE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF
      CALL BOM_SHA256_FILE(tempName,digest,localErrCount)
      INQUIRE(FILE=tempName,EXIST=exists)
      IF ( exists ) THEN
        OPEN(ioUnit,FILE=tempName,STATUS='OLD',IOSTAT=ios)
        IF ( ios.EQ.0 ) CLOSE(ioUnit,STATUS='DELETE')
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
