#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_WRITE_P4_MANIFEST
C !INTERFACE:
      SUBROUTINE BOM_WRITE_P4_MANIFEST(
     I                 fileName,fileClass,hasP3,hasBio,
     I                 myTime,scheduledTime,myIter,
     O                 localErrCount,
     I                 myThid)

C !DESCRIPTION:
C     Publish a schema-4 frame only after every immutable member exists.
C     The manifest is written to a temporary file, contains the exact size
C     and SHA-256 of every member, and is renamed last.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) fileName
      INTEGER fileClass,myIter,localErrCount,myThid
      LOGICAL hasP3,hasBio
      _RL myTime,scheduledTime
      CHARACTER*(MAX_LEN_FNAM) manifestName,tempName,memberName
      CHARACTER*(MAX_LEN_MBUF) line
      CHARACTER*64 digest
      INTEGER ioUnit,ios,renameErr,memberCount,memberIndex
      INTEGER*8 memberBytes,timeBits,scheduledBits
      LOGICAL memberExists
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

      localErrCount=0
      CALL BOM_P4_MEMBER_COUNT(
     I     fileClass,hasP3,hasBio,
     O     memberCount)
      IF ( memberCount.LE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF
      WRITE(manifestName,'(A,A)')
     &     fileName(1:ILNBLNK(fileName)),'.p4manifest'
      WRITE(tempName,'(A,A)')
     &     manifestName(1:ILNBLNK(manifestName)),'.tmp'
      CALL MDSFINDUNIT(ioUnit,myThid)
      OPEN(ioUnit,FILE=tempName,STATUS='REPLACE',ACTION='WRITE',
     &     FORM='FORMATTED',IOSTAT=ios)
      IF ( ios.NE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF
      timeBits=TRANSFER(myTime,timeBits)
      scheduledBits=TRANSFER(scheduledTime,scheduledBits)
      WRITE(ioUnit,'(A)',IOSTAT=ios)
     &     'MITGCM_BOM_P4_MANIFEST 1'
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0)',IOSTAT=ios)
     &     'container_schema ',bomP4ContainerSchema
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0)',IOSTAT=ios)
     &     'file_class ',fileClass
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A)',IOSTAT=ios) 'mode BOM'
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0,A,I0,A,I0)',IOSTAT=ios)
     &     'p3 ',MERGE(1,0,hasP3),' p4 1 bio ',MERGE(1,0,hasBio)
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,A)',IOSTAT=ios)
     &     'source_head ',bomP4SourceHead
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0)',IOSTAT=ios)
     &     'iteration ',myIter
      IF ( ios.EQ.0 ) WRITE(ioUnit,
     &     '(A,Z16.16,A,Z16.16)',IOSTAT=ios)
     &     'time_bits ',timeBits,' scheduled_bits ',scheduledBits
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0,A,I0)',IOSTAT=ios)
     &     'initial_count ',bomNPartExpected,
     &     ' live_count ',bomNPartLiveExpected
      IF ( ios.EQ.0 ) WRITE(ioUnit,'(A,I0)',IOSTAT=ios)
     &     'member_count ',memberCount
      DO memberIndex=1,memberCount
        IF ( ios.EQ.0 ) THEN
          CALL BOM_P4_MEMBER_NAME(
     I         fileName,fileClass,hasP3,hasBio,memberIndex,
     O         memberName,localErrCount)
          IF ( localErrCount.EQ.0 ) THEN
            INQUIRE(FILE=memberName,EXIST=memberExists,SIZE=memberBytes,
     &              IOSTAT=localErrCount)
            IF ( localErrCount.NE.0 .OR. .NOT.memberExists .OR.
     &           memberBytes.LT.0_8 ) localErrCount=1
          ENDIF
          IF ( localErrCount.EQ.0 )
     &         CALL BOM_SHA256_FILE(memberName,digest,localErrCount)
          IF ( localErrCount.EQ.0 ) WRITE(ioUnit,
     &         '(A,1X,I0,1X,I0,1X,A,1X,A)',IOSTAT=ios)
     &         'MEMBER',memberIndex,memberBytes,digest,
     &         memberName(1:ILNBLNK(memberName))
        ENDIF
      ENDDO
      IF ( ios.EQ.0 .AND. localErrCount.EQ.0 )
     &     WRITE(ioUnit,'(A)',IOSTAT=ios) 'complete 1'
      CLOSE(ioUnit,IOSTAT=renameErr)
      IF ( ios.NE.0 .OR. renameErr.NE.0 ) localErrCount=1
      IF ( localErrCount.EQ.0 ) THEN
        CALL BOM_P4_ATOMIC_RENAME(
     I       tempName,manifestName,
     O       renameErr)
        IF ( renameErr.NE.0 ) localErrCount=1
      ENDIF
      IF ( localErrCount.NE.0 ) THEN
        OPEN(ioUnit,FILE=tempName,STATUS='OLD',IOSTAT=ios)
        IF ( ios.EQ.0 ) CLOSE(ioUnit,STATUS='DELETE')
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VALIDATE_P4_MANIFEST(
     I                 fileName,fileClass,hasP3,hasBio,
     I                 myTime,scheduledTime,myIter,
     I                 expectedInitial,expectedLive,
     O                 localErrCount,
     I                 myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) fileName
      INTEGER fileClass,myIter,expectedInitial,expectedLive
      INTEGER localErrCount,myThid
      LOGICAL hasP3,hasBio
      _RL myTime,scheduledTime
      CHARACTER*(MAX_LEN_FNAM) manifestName,memberName,storedName
      CHARACTER*(MAX_LEN_MBUF) line,expectedLine
      CHARACTER*16 tag
      CHARACTER*64 storedDigest,actualDigest
      INTEGER ioUnit,ios,memberCount,storedCount,memberIndex
      INTEGER storedIndex
      INTEGER*8 storedBytes,actualBytes,timeBits,scheduledBits
      LOGICAL fileExists
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

      localErrCount=0
      CALL BOM_P4_MEMBER_COUNT(
     I     fileClass,hasP3,hasBio,
     O     memberCount)
      WRITE(manifestName,'(A,A)')
     &     fileName(1:ILNBLNK(fileName)),'.p4manifest'
      INQUIRE(FILE=manifestName,EXIST=fileExists)
      IF ( .NOT.fileExists .OR. memberCount.LE.0 ) THEN
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
      timeBits=TRANSFER(myTime,timeBits)
      scheduledBits=TRANSFER(scheduledTime,scheduledBits)

      READ(ioUnit,'(A)',IOSTAT=ios) line
      IF ( ios.EQ.0 .AND.
     &     line.NE.'MITGCM_BOM_P4_MANIFEST 1' ) ios=1
      IF ( ios.EQ.0 ) THEN
        WRITE(expectedLine,'(A,I0)')
     &       'container_schema ',bomP4ContainerSchema
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND.
     &       line(1:ILNBLNK(line)).NE.
     &       expectedLine(1:ILNBLNK(expectedLine)) ) ios=1
      ENDIF
      IF ( ios.EQ.0 ) THEN
        WRITE(expectedLine,'(A,I0)') 'file_class ',fileClass
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND.
     &       line(1:ILNBLNK(line)).NE.
     &       expectedLine(1:ILNBLNK(expectedLine)) ) ios=1
      ENDIF
      IF ( ios.EQ.0 ) THEN
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND. line.NE.'mode BOM' ) ios=1
      ENDIF
      IF ( ios.EQ.0 ) THEN
        WRITE(expectedLine,'(A,I0,A,I0,A,I0)')
     &       'p3 ',MERGE(1,0,hasP3),' p4 1 bio ',MERGE(1,0,hasBio)
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND.
     &       line(1:ILNBLNK(line)).NE.
     &       expectedLine(1:ILNBLNK(expectedLine)) ) ios=1
      ENDIF
      IF ( ios.EQ.0 ) THEN
        WRITE(expectedLine,'(A,A)') 'source_head ',bomP4SourceHead
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND.
     &       line(1:ILNBLNK(line)).NE.
     &       expectedLine(1:ILNBLNK(expectedLine)) ) ios=1
      ENDIF
      IF ( ios.EQ.0 ) THEN
        WRITE(expectedLine,'(A,I0)') 'iteration ',myIter
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND.
     &       line(1:ILNBLNK(line)).NE.
     &       expectedLine(1:ILNBLNK(expectedLine)) ) ios=1
      ENDIF
      IF ( ios.EQ.0 ) THEN
        WRITE(expectedLine,'(A,Z16.16,A,Z16.16)')
     &       'time_bits ',timeBits,' scheduled_bits ',scheduledBits
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND.
     &       line(1:ILNBLNK(line)).NE.
     &       expectedLine(1:ILNBLNK(expectedLine)) ) ios=1
      ENDIF
      IF ( ios.EQ.0 ) THEN
        WRITE(expectedLine,'(A,I0,A,I0)')
     &       'initial_count ',expectedInitial,
     &       ' live_count ',expectedLive
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND.
     &       line(1:ILNBLNK(line)).NE.
     &       expectedLine(1:ILNBLNK(expectedLine)) ) ios=1
      ENDIF
      storedCount=-1
      IF ( ios.EQ.0 ) THEN
        READ(ioUnit,*,IOSTAT=ios) tag,storedCount
        IF ( ios.EQ.0 .AND.
     &       ( tag.NE.'member_count' .OR.
     &         storedCount.NE.memberCount ) ) ios=1
      ENDIF

      DO memberIndex=1,memberCount
        IF ( ios.EQ.0 ) THEN
          storedName=' '
          READ(ioUnit,*,IOSTAT=ios) tag,storedIndex,storedBytes,
     &         storedDigest,storedName
          CALL BOM_P4_MEMBER_NAME(
     I         fileName,fileClass,hasP3,hasBio,memberIndex,
     O         memberName,localErrCount)
          IF ( ios.EQ.0 .AND. localErrCount.EQ.0 ) THEN
            IF ( tag.NE.'MEMBER' .OR.
     &           storedIndex.NE.memberIndex .OR.
     &           storedName.NE.memberName ) ios=1
          ENDIF
          INQUIRE(FILE=memberName,EXIST=fileExists,SIZE=actualBytes,
     &            IOSTAT=localErrCount)
          IF ( localErrCount.NE.0 .OR. .NOT.fileExists .OR.
     &         actualBytes.NE.storedBytes ) ios=1
          IF ( ios.EQ.0 ) THEN
            CALL BOM_SHA256_FILE(memberName,actualDigest,localErrCount)
            IF ( localErrCount.NE.0 .OR.
     &           actualDigest.NE.storedDigest ) ios=1
          ENDIF
        ENDIF
      ENDDO
      IF ( ios.EQ.0 ) THEN
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.EQ.0 .AND. line.NE.'complete 1' ) ios=1
      ENDIF
      IF ( ios.EQ.0 ) THEN
        READ(ioUnit,'(A)',IOSTAT=ios) line
        IF ( ios.NE.-1 ) ios=1
      ENDIF
      CLOSE(ioUnit)
      IF ( ios.NE.-1 ) localErrCount=1
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P4_MEMBER_COUNT(
     I                 fileClass,hasP3,hasBio,
     O                 memberCount)
      IMPLICIT NONE
#include "SIZE.h"
      INTEGER fileClass,memberCount,globalMembers,tileComponents
      LOGICAL hasP3,hasBio
      memberCount=0
      IF ( fileClass.LT.1 .OR. fileClass.GT.2 ) RETURN
      globalMembers=2
      IF ( fileClass.EQ.2 ) globalMembers=globalMembers+2
      IF ( hasP3 ) globalMembers=globalMembers+2
      tileComponents=2
      IF ( fileClass.EQ.2 ) tileComponents=tileComponents+1
      IF ( hasP3 ) tileComponents=tileComponents+1
      IF ( fileClass.EQ.2 .AND. hasBio )
     &     tileComponents=tileComponents+1
      memberCount=globalMembers+2*nSx*nPx*nSy*nPy*tileComponents
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P4_MEMBER_NAME(
     I                 fileName,fileClass,hasP3,hasBio,memberIndex,
     O                 memberName,localErrCount)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
      CHARACTER*(*) fileName,memberName
      INTEGER fileClass,memberIndex,localErrCount
      LOGICAL hasP3,hasBio
      CHARACTER*(MAX_LEN_FNAM) baseName,physicalName
      INTEGER globalMembers,tileComponents,relativeIndex
      INTEGER tileOrdinal,componentOrdinal,fileOrdinal,iTile,jTile
      INTEGER nameLength,localDirLength
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

      localErrCount=0
      memberName=' '
      globalMembers=2
      IF ( fileClass.EQ.2 ) globalMembers=globalMembers+2
      IF ( hasP3 ) globalMembers=globalMembers+2
      IF ( memberIndex.LE.0 ) THEN
        localErrCount=1
        RETURN
      ENDIF
      IF ( memberIndex.LE.globalMembers ) THEN
        IF ( memberIndex.LE.2 ) THEN
          WRITE(baseName,'(A,A)') fileName(1:ILNBLNK(fileName)),
     &         '.p4sig'
          fileOrdinal=memberIndex
        ELSEIF ( fileClass.EQ.2 .AND. memberIndex.LE.4 ) THEN
          baseName=fileName
          WRITE(baseName,'(A,A)') fileName(1:ILNBLNK(fileName)),
     &         '.sig'
          fileOrdinal=memberIndex-2
        ELSE
          WRITE(baseName,'(A,A)') fileName(1:ILNBLNK(fileName)),
     &         '.p3sig'
          fileOrdinal=memberIndex-globalMembers+2
        ENDIF
        IF ( MOD(fileOrdinal,2).EQ.1 ) THEN
          WRITE(memberName,'(A,A)')
     &         baseName(1:ILNBLNK(baseName)),'.data'
        ELSE
          WRITE(memberName,'(A,A)')
     &         baseName(1:ILNBLNK(baseName)),'.meta'
        ENDIF
        RETURN
      ENDIF

      tileComponents=2
      IF ( fileClass.EQ.2 ) tileComponents=tileComponents+1
      IF ( hasP3 ) tileComponents=tileComponents+1
      IF ( fileClass.EQ.2 .AND. hasBio )
     &     tileComponents=tileComponents+1
      relativeIndex=memberIndex-globalMembers-1
      tileOrdinal=relativeIndex/(2*tileComponents)
      componentOrdinal=MOD(relativeIndex,2*tileComponents)/2+1
      fileOrdinal=MOD(relativeIndex,2)+1
      IF ( tileOrdinal.LT.0 .OR.
     &     tileOrdinal.GE.nSx*nPx*nSy*nPy ) THEN
        localErrCount=1
        RETURN
      ENDIF
      iTile=MOD(tileOrdinal,nSx*nPx)+1
      jTile=tileOrdinal/(nSx*nPx)+1
      baseName=fileName
      IF ( fileClass.EQ.2 ) THEN
        IF ( componentOrdinal.EQ.2 ) THEN
          WRITE(baseName,'(A,A)') fileName(1:ILNBLNK(fileName)),
     &         '.env'
        ELSEIF ( componentOrdinal.GT.2 ) THEN
          componentOrdinal=componentOrdinal-1
        ENDIF
      ENDIF
      IF ( baseName.EQ.fileName .AND. hasP3 .AND.
     &     componentOrdinal.EQ.2 ) THEN
        WRITE(baseName,'(A,A)') fileName(1:ILNBLNK(fileName)),
     &       '.p3'
      ELSEIF ( baseName.EQ.fileName .AND.
     &         componentOrdinal.EQ.MERGE(3,2,hasP3) ) THEN
        WRITE(baseName,'(A,A)') fileName(1:ILNBLNK(fileName)),
     &       '.p4'
      ELSEIF ( baseName.EQ.fileName .AND. fileClass.EQ.2 .AND.
     &         hasBio .AND.
     &         componentOrdinal.EQ.MERGE(4,3,hasP3) ) THEN
        WRITE(baseName,'(A,A)') fileName(1:ILNBLNK(fileName)),
     &       '.p4bio'
      ENDIF
      nameLength=ILNBLNK(baseName)
      physicalName=' '
      IF ( mdsioLocalDir.NE.' ' ) THEN
        localDirLength=ILNBLNK(mdsioLocalDir)
        WRITE(physicalName,'(A,A)')
     &       mdsioLocalDir(1:localDirLength),baseName(1:nameLength)
      ELSE
        physicalName=baseName
      ENDIF
      IF ( fileOrdinal.EQ.1 ) THEN
        WRITE(memberName,'(A,A,I3.3,A,I3.3,A)')
     &       physicalName(1:ILNBLNK(physicalName)),'.',
     &       iTile,'.',jTile,'.data'
      ELSE
        WRITE(memberName,'(A,A,I3.3,A,I3.3,A)')
     &       physicalName(1:ILNBLNK(physicalName)),'.',
     &       iTile,'.',jTile,'.meta'
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P4_ATOMIC_RENAME(
     I                 tempName,finalName,
     O                 localErrCount)
      IMPLICIT NONE
#include "EEPARAMS.h"
      CHARACTER*(*) tempName,finalName
      CHARACTER*(2*MAX_LEN_FNAM+32) command
      INTEGER localErrCount,cmdStat,exitStat,k
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK
      localErrCount=0
      DO k=1,ILNBLNK(tempName)
        IF ( tempName(k:k).EQ.'''' ) localErrCount=1
      ENDDO
      DO k=1,ILNBLNK(finalName)
        IF ( finalName(k:k).EQ.'''' ) localErrCount=1
      ENDDO
      IF ( localErrCount.NE.0 ) RETURN
      WRITE(command,'(A,A,A,A,A)') 'mv -f -- ''',
     &     tempName(1:ILNBLNK(tempName)),''' ''',
     &     finalName(1:ILNBLNK(finalName)),''''
      CALL EXECUTE_COMMAND_LINE(command,WAIT=.TRUE.,EXITSTAT=exitStat,
     &     CMDSTAT=cmdStat)
      IF ( cmdStat.NE.0 .OR. exitStat.NE.0 ) localErrCount=1
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
