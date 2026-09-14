#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_WRITE_TRAJECTORY_ARCHIVE
C !INTERFACE:
      SUBROUTINE BOM_WRITE_TRAJECTORY_ARCHIVE(
     I                 sampleTime, scheduledTime, myIter, myThid )

C !DESCRIPTION:
C     Append one committed trajectory frame to a fixed set of tiled MDS
C     files.  A model startup owns one segment named by nIter0.  Each tile
C     contains repeated header/owner/commit blocks and a global index is
C     published last.  Existing segments are rejected rather than overwritten.
C
C     Owner words 1:48 retain the legacy core mapping, 49:56 retain P3,
C     57:60 retain P4, and 61:64 are reserved zero words.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL sampleTime, scheduledTime
      INTEGER myIter, myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_FNAM) segmentName, indexName
      CHARACTER*(MAX_LEN_FNAM) physicalPrefix
      CHARACTER*(MAX_LEN_FNAM) dataName, metaName, claimName
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      _RL record(bomArchiveFields)
      _RL signatureRecord(bomPickupChunkFields)
      _RL p3Signature(
     &     bomP3SigBase+bomPickup2SigBase
     &     +2*MAX_LEN_FNAM+256)
      _RL p4Signature(bomP4SigFields)
      _RL nextTime
      _RS dummyRS(1)
      INTEGER bi, bj, ip, k, iDiag, ioUnit, iRecord, writeRecord
      INTEGER sigIndex, p3Fields, p2Fields, p3Records, p4Records, ios
      INTEGER iGlobal, jGlobal, prefixLen, localDirLen
      INTEGER segmentLen, activeSchema, activeFields
      INTEGER localErrCount, globalErrCount, syncCount
      INTEGER modeCode, equationCode, currentCode
      INTEGER windCode, stokesCode, integratorCode
      INTEGER nextFrame, globalTiles, archiveLiveCount
      INTEGER*8 previous8, start8, ownerStart8, end8
      INTEGER*8 wordHi, wordLo, idHi8, idLo8
      INTEGER*8 raftHi8, raftLo8, parentHi8, parentLo8
      LOGICAL codesValid, useSchema3, useSchema4
      LOGICAL wordValid, fileExists, p3Valid, p4Valid
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

      nextTime = bomNextOutputTime + bomOutputFreq
      nextFrame = 0
      IF ( bomArchiveFrameCount.GE.0 .AND.
     &     bomArchiveFrameCount.LT.HUGE(nextFrame)-1 )
     &     nextFrame = bomArchiveFrameCount + 1
      globalTiles = nPx*nPy*nSx*nSy
      activeSchema = bomOutputSchema
      activeFields = bomOutputFields
      modeCode = 1
      equationCode = 0
      currentCode = 0
      windCode = 0
      stokesCode = 0
      integratorCode = 0
      codesValid = .TRUE.
      useSchema3 = .FALSE.
      useSchema4 = .FALSE.
      IF ( bomMode.EQ.'BOM' ) THEN
        activeSchema = bomOutputSchema2
        activeFields = bomOutputFields2
        CALL BOM_PICKUP2_CODES(
     O       modeCode, equationCode, currentCode,
     O       windCode, stokesCode, integratorCode,
     O       codesValid )
        useSchema3 = bomSpringLaw.NE.'NONE'
        useSchema4 = bomUseLand .OR. bomUseBiology
      ENDIF
      archiveLiveCount = bomNPartExpected
      IF ( useSchema4 ) archiveLiveCount = bomNPartLiveExpected
      IF ( .NOT.codesValid .OR. nextFrame.LT.1 ) THEN
        WRITE(msgBuf,'(A,I12)')
     &       'BOM_WRITE_TRAJECTORY_ARCHIVE: invalid frame=',nextFrame
        CALL PRINT_ERROR( msgBuf, myThid )
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: BOM_WRITE_TRAJECTORY_ARCHIVE CODES'
      ENDIF

C--   Build a deterministic per-startup segment.  The global index must be
C     passed its physical path because global MDS vectors ignore localDir.
      prefixLen = ILNBLNK(bomTrajectoryFile)
      localDirLen = ILNBLNK(mdsioLocalDir)
      WRITE(segmentName,'(A,A,I10.10)')
     &     bomTrajectoryFile(1:prefixLen),'.s',nIter0
      segmentLen = ILNBLNK(segmentName)
      IF ( localDirLen.GT.0 ) THEN
        WRITE(physicalPrefix,'(2A)')
     &       mdsioLocalDir(1:localDirLen),segmentName(1:segmentLen)
        WRITE(indexName,'(3A)')
     &       mdsioLocalDir(1:localDirLen),segmentName(1:segmentLen),
     &       '.index'
      ELSE
        physicalPrefix = segmentName
        WRITE(indexName,'(2A)') segmentName(1:segmentLen),'.index'
      ENDIF
      WRITE(claimName,'(A,A)')
     &     physicalPrefix(1:ILNBLNK(physicalPrefix)),'.claim'

C--   Retain the existing schema-3 state gate before any archive member is
C     created.  P4 event/state budgets have already run in BOM_OUTPUT.
      IF ( useSchema3 ) THEN
        CALL BOM_VALIDATE_P3_IO_STATE(
     I       sampleTime, myIter, nextTime,
     O       localErrCount,
     I       myThid )
        globalErrCount = localErrCount
        CALL GLOBAL_SUM_INT( globalErrCount, myThid )
        IF ( globalErrCount.GT.0 ) THEN
          CALL ALL_PROC_DIE( 0 )
          STOP 'ABNORMAL END: BOM_WRITE_TRAJECTORY_ARCHIVE P3'
        ENDIF
      ENDIF

C--   Preflight every exact word and record offset before the first write.
      localErrCount = 0
      _BEGIN_MASTER(myThid)
      p3Fields = 0
      p2Fields = 0
      p3Records = 0
      p4Records = 0
      p3Valid = .TRUE.
      p4Valid = .TRUE.
      IF ( useSchema3 ) THEN
        CALL BOM_BUILD_P3_SIGNATURE(
     I       sampleTime,myIter,bomNPartExpected,nextTime,
     O       p3Signature,p3Fields,p2Fields,p3Valid,myThid)
        p3Records=(p3Fields+bomPickupChunkFields-1)
     &       /bomPickupChunkFields
        IF ( .NOT.p3Valid .OR. p3Records.LE.0 .OR.
     &       nextFrame.GT.HUGE(iRecord)/p3Records )
     &       localErrCount=localErrCount+1
      ENDIF
      IF ( useSchema4 ) THEN
        CALL BOM_BUILD_P4_SIGNATURE(
     I       1,bomOutputFields2,sampleTime,scheduledTime,
     I       nextTime,myIter,
     O       p4Signature,p4Valid,
     I       myThid)
        p4Records=(bomP4SigFields+bomPickupChunkFields-1)
     &       /bomPickupChunkFields
        IF ( .NOT.p4Valid .OR. p4Records.LE.0 .OR.
     &       nextFrame.GT.HUGE(iRecord)/p4Records )
     &       localErrCount=localErrCount+1
      ENDIF
      DO bj=1,nSy
       DO bi=1,nSx
        previous8 = bomArchiveTileRecords(bi,bj)
        IF ( previous8.LT.0_8 .OR.
     &       previous8.GT.INT(HUGE(iRecord),8)-
     &       INT(bomNPartTile(bi,bj)+2,8) ) THEN
          localErrCount = localErrCount + 1
        ENDIF
        DO ip=1,bomNPartTile(bi,bj)
          CALL BOM_P4_I8_WORDS(
     I         bomId(ip,bi,bj),wordHi,wordLo,wordValid)
          IF ( .NOT.wordValid ) localErrCount=localErrCount+1
          IF ( useSchema3 ) THEN
            CALL BOM_P4_I8_WORDS(
     I           bomRaftId(ip,bi,bj),wordHi,wordLo,wordValid)
            IF ( .NOT.wordValid ) localErrCount=localErrCount+1
          ENDIF
          IF ( useSchema4 ) THEN
            CALL BOM_P4_I8_WORDS(
     I           bomParentId(ip,bi,bj),wordHi,wordLo,wordValid)
            IF ( .NOT.wordValid ) localErrCount=localErrCount+1
          ENDIF
        ENDDO
       ENDDO
      ENDDO

C--   First-frame collision detection is fail-closed.  SAFE_IO does not
C     guarantee that an existing direct-access record 1 is preserved.
      IF ( .NOT.bomArchiveStarted ) THEN
        DO bj=1,nSy
         DO bi=1,nSx
          iGlobal = bi + (myXGlobalLo-1)/sNx
          jGlobal = bj + (myYGlobalLo-1)/sNy
          WRITE(dataName,'(A,A,I3.3,A,I3.3,A)')
     &         physicalPrefix(1:ILNBLNK(physicalPrefix)),'.',
     &         iGlobal,'.',jGlobal,'.data'
          WRITE(metaName,'(A,A,I3.3,A,I3.3,A)')
     &         physicalPrefix(1:ILNBLNK(physicalPrefix)),'.',
     &         iGlobal,'.',jGlobal,'.meta'
          INQUIRE(FILE=dataName,EXIST=fileExists)
          IF ( fileExists ) localErrCount=localErrCount+1
          INQUIRE(FILE=metaName,EXIST=fileExists)
          IF ( fileExists ) localErrCount=localErrCount+1
         ENDDO
        ENDDO
        IF ( myProcId.EQ.0 ) THEN
          WRITE(dataName,'(A,A)')
     &         indexName(1:ILNBLNK(indexName)),'.data'
          WRITE(metaName,'(A,A)')
     &         indexName(1:ILNBLNK(indexName)),'.meta'
          INQUIRE(FILE=dataName,EXIST=fileExists)
          IF ( fileExists ) localErrCount=localErrCount+1
          INQUIRE(FILE=metaName,EXIST=fileExists)
          IF ( fileExists ) localErrCount=localErrCount+1
        ENDIF
        IF ( myProcId.EQ.0 .AND. useSchema3 ) THEN
          WRITE(dataName,'(A,A)')
     &         physicalPrefix(1:ILNBLNK(physicalPrefix)),'.p3sig.data'
          WRITE(metaName,'(A,A)')
     &         physicalPrefix(1:ILNBLNK(physicalPrefix)),'.p3sig.meta'
          INQUIRE(FILE=dataName,EXIST=fileExists)
          IF ( fileExists ) localErrCount=localErrCount+1
          INQUIRE(FILE=metaName,EXIST=fileExists)
          IF ( fileExists ) localErrCount=localErrCount+1
        ENDIF
        IF ( myProcId.EQ.0 .AND. useSchema4 ) THEN
          WRITE(dataName,'(A,A)')
     &         physicalPrefix(1:ILNBLNK(physicalPrefix)),'.p4sig.data'
          WRITE(metaName,'(A,A)')
     &         physicalPrefix(1:ILNBLNK(physicalPrefix)),'.p4sig.meta'
          INQUIRE(FILE=dataName,EXIST=fileExists)
          IF ( fileExists ) localErrCount=localErrCount+1
          INQUIRE(FILE=metaName,EXIST=fileExists)
          IF ( fileExists ) localErrCount=localErrCount+1
        ENDIF
      ENDIF
      _END_MASTER(myThid)
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I12,A,I12)')
     &         'BOM_WRITE_TRAJECTORY_ARCHIVE: preflight failed frame=',
     &         nextFrame,' errors=',globalErrCount
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: BOM_WRITE_TRAJECTORY_ARCHIVE PREFLIGHT'
      ENDIF

C--   Atomically claim the segment after read-only preflight and before any
C     MDS member is created.  STATUS='NEW' closes the concurrent-start race
C     left by INQUIRE.  The persistent claim deliberately makes a failed or
C     completed same-nIter0 rerun fail closed.
      localErrCount = 0
      _BEGIN_MASTER(myThid)
      IF ( .NOT.bomArchiveStarted .AND. myProcId.EQ.0 ) THEN
        CALL MDSFINDUNIT(ioUnit,myThid)
        OPEN(UNIT=ioUnit,FILE=claimName,STATUS='NEW',
     &       ACTION='WRITE',FORM='FORMATTED',IOSTAT=ios)
        IF ( ios.EQ.0 ) THEN
          WRITE(ioUnit,'(A,I0)',IOSTAT=ios)
     &         'MITGCM_BOM_ARCHIVE_CLAIM 1 nIter0 ',nIter0
          CLOSE(ioUnit,IOSTAT=iRecord)
          IF ( iRecord.NE.0 ) ios=iRecord
        ENDIF
        IF ( ios.NE.0 ) localErrCount=localErrCount+1
      ENDIF
      _END_MASTER(myThid)
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I12,A,I12)')
     &         'BOM_WRITE_TRAJECTORY_ARCHIVE: claim failed frame=',
     &         nextFrame,' errors=',globalErrCount
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: BOM_WRITE_TRAJECTORY_ARCHIVE CLAIM'
      ENDIF

C--   Append every local tile block.  Only the final commit record is
C     positive, so the tile meta high-water advances after the full block.
      _BEGIN_MASTER(myThid)
      DO bj=1,nSy
       DO bi=1,nSx
        previous8 = bomArchiveTileRecords(bi,bj)
        start8 = previous8 + 1_8
        ownerStart8 = start8 + 1_8
        end8 = ownerStart8 + INT(bomNPartTile(bi,bj),8)
        iGlobal = myXGlobalLo + (bi-1)*sNx
        jGlobal = myYGlobalLo + (bj-1)*sNy
        DO k=1,bomArchiveFields
          record(k) = 0. _d 0
        ENDDO
        record(1) = DFLOAT(bomArchiveSchema)
        record(2) = DFLOAT(bomArchiveFields)
        record(3) = DFLOAT(bomArchiveHeaderType)
        record(4) = DFLOAT(nextFrame)
        record(5) = DFLOAT(nIter0)
        record(6) = DFLOAT(myIter)
        record(7) = sampleTime
        record(8) = scheduledTime
        record(9) = nextTime
        record(10) = DFLOAT(bomNPartTile(bi,bj))
        record(11) = DFLOAT(bomNPartExpected)
        record(12) = DFLOAT(archiveLiveCount)
        record(13) = DFLOAT(activeSchema)
        record(14) = DFLOAT(activeFields)
        record(15) = DFLOAT(modeCode)
        record(16) = DFLOAT(equationCode)
        record(17) = DFLOAT(currentCode)
        record(18) = DFLOAT(windCode)
        record(19) = DFLOAT(stokesCode)
        record(20) = DFLOAT(integratorCode)
        IF ( useSchema3 ) record(21) = 1. _d 0
        record(22) = DFLOAT(bomP3ContainerSchema)
        record(23) = DFLOAT(bomP3SidecarSchema)
        record(24) = 49. _d 0
        record(25) = 56. _d 0
        IF ( useSchema4 ) record(26) = 1. _d 0
        record(27) = DFLOAT(bomP4ContainerSchema)
        record(28) = DFLOAT(bomP4SidecarSchema)
        record(29) = 57. _d 0
        record(30) = 60. _d 0
        record(31) = 1. _d 0
        record(32) = 48. _d 0
        record(33) = 61. _d 0
        record(34) = 64. _d 0
        IF ( activeSchema.EQ.bomOutputSchema2 ) THEN
          record(35) = DFLOAT(BOM_RHS_NDIAG)
          record(36) = 22. _d 0
          record(37) = 48. _d 0
        ENDIF
        record(38) = 64. _d 0
        record(39) = DFLOAT(nPx)
        record(40) = DFLOAT(nPy)
        record(41) = DFLOAT(nSx)
        record(42) = DFLOAT(nSy)
        record(43) = DFLOAT(sNx)
        record(44) = DFLOAT(sNy)
        record(45) = DFLOAT(Nx)
        record(46) = DFLOAT(Ny)
        record(47) = DFLOAT(iGlobal)
        record(48) = DFLOAT(jGlobal)
        record(49) = DFLOAT(myProcId)
        record(50) = DFLOAT(bi)
        record(51) = DFLOAT(bj)
        CALL BOM_P4_I8_WORDS(
     I       previous8,wordHi,wordLo,wordValid)
        record(52) = DFLOAT(wordHi)
        record(53) = DFLOAT(wordLo)
        CALL BOM_P4_I8_WORDS(start8,wordHi,wordLo,wordValid)
        record(54) = DFLOAT(wordHi)
        record(55) = DFLOAT(wordLo)
        CALL BOM_P4_I8_WORDS(ownerStart8,wordHi,wordLo,wordValid)
        record(56) = DFLOAT(wordHi)
        record(57) = DFLOAT(wordLo)
        CALL BOM_P4_I8_WORDS(end8,wordHi,wordLo,wordValid)
        record(58) = DFLOAT(wordHi)
        record(59) = DFLOAT(wordLo)
        record(60) = DFLOAT(bomMaxPartTile)
        record(61) = DFLOAT(bomP3SidecarFields)
        record(62) = DFLOAT(bomP4SidecarFields)
        ioUnit = -1
        iRecord = -INT(start8)
        CALL MDS_WRITEVEC_LOC(
     I       segmentName,precFloat64,ioUnit,
     I       'RL',bomArchiveFields,record,dummyRS,
     I       bi,bj,iRecord,myIter,myThid)

        DO ip=1,bomNPartTile(bi,bj)
          DO k=1,bomArchiveFields
            record(k) = 0. _d 0
          ENDDO
          CALL BOM_P4_I8_WORDS(
     I         bomId(ip,bi,bj),idHi8,idLo8,wordValid)
          record(1) = DFLOAT(idHi8)
          record(2) = DFLOAT(idLo8)
          record(3) = DFLOAT(bomStatus(ip,bi,bj))
          record(4) = sampleTime
          record(5) = DFLOAT(myIter)
          record(6) = bomX(ip,bi,bj)
          record(7) = bomY(ip,bi,bj)
          record(8) = bomReleaseTime(ip,bi,bj)
          record(9) = bomAge(ip,bi,bj)
          record(10) = bomI(ip,bi,bj)
          record(11) = bomJ(ip,bi,bj)
          record(12) = bomVEast(ip,bi,bj)
          record(13) = bomVNorth(ip,bi,bj)
          record(14) = bomWindEast(ip,bi,bj)
          record(15) = bomWindNorth(ip,bi,bj)
          record(16) = bomDriftEast(ip,bi,bj)
          record(17) = bomDriftNorth(ip,bi,bj)
          record(18) = DFLOAT(myProcId)
          record(19) = DFLOAT(bi)
          record(20) = DFLOAT(bj)
          record(21) = 1. _d 0
          IF ( activeSchema.EQ.bomOutputSchema2 ) THEN
            DO iDiag=1,BOM_RHS_NDIAG
              record(21+iDiag)=bomRhsDiag(iDiag,ip,bi,bj)
            ENDDO
          ENDIF
          IF ( useSchema3 ) THEN
            CALL BOM_P4_I8_WORDS(
     I           bomRaftId(ip,bi,bj),raftHi8,raftLo8,wordValid)
            record(49) = DFLOAT(idHi8)
            record(50) = DFLOAT(idLo8)
            record(51) = DFLOAT(raftHi8)
            record(52) = DFLOAT(raftLo8)
            record(53) = DFLOAT(bomNeighborCount(ip,bi,bj))
            record(54) = DFLOAT(bomRaftSize(ip,bi,bj))
            record(55) = bomSpringEast(ip,bi,bj)
            record(56) = bomSpringNorth(ip,bi,bj)
          ENDIF
          IF ( useSchema4 ) THEN
            CALL BOM_P4_I8_WORDS(
     I           bomParentId(ip,bi,bj),
     O           parentHi8,parentLo8,wordValid)
            record(57) = DFLOAT(parentHi8)
            record(58) = DFLOAT(parentLo8)
            record(59) = bomS(ip,bi,bj)
            record(60) = DFLOAT(bomBirthCount(ip,bi,bj))
          ENDIF
          iRecord = -INT(start8+INT(ip,8))
          CALL MDS_WRITEVEC_LOC(
     I         segmentName,precFloat64,ioUnit,
     I         'RL',bomArchiveFields,record,dummyRS,
     I         bi,bj,iRecord,myIter,myThid)
        ENDDO

C--     The tile commit is written after every owner and advances meta.
        DO k=1,bomArchiveFields
          record(k) = 0. _d 0
        ENDDO
        record(1) = DFLOAT(bomArchiveSchema)
        record(2) = DFLOAT(bomArchiveFields)
        record(3) = DFLOAT(bomArchiveCommitType)
        record(4) = DFLOAT(nextFrame)
        record(5) = DFLOAT(nIter0)
        record(6) = DFLOAT(myIter)
        record(7) = sampleTime
        record(8) = scheduledTime
        record(9) = nextTime
        record(10) = DFLOAT(bomNPartTile(bi,bj))
        record(11) = DFLOAT(bomNPartExpected)
        record(12) = DFLOAT(archiveLiveCount)
        CALL BOM_P4_I8_WORDS(
     I       previous8,wordHi,wordLo,wordValid)
        record(13) = DFLOAT(wordHi)
        record(14) = DFLOAT(wordLo)
        CALL BOM_P4_I8_WORDS(start8,wordHi,wordLo,wordValid)
        record(15) = DFLOAT(wordHi)
        record(16) = DFLOAT(wordLo)
        CALL BOM_P4_I8_WORDS(ownerStart8,wordHi,wordLo,wordValid)
        record(17) = DFLOAT(wordHi)
        record(18) = DFLOAT(wordLo)
        CALL BOM_P4_I8_WORDS(end8,wordHi,wordLo,wordValid)
        record(19) = DFLOAT(wordHi)
        record(20) = DFLOAT(wordLo)
        record(21) = DFLOAT(iGlobal)
        record(22) = DFLOAT(jGlobal)
        record(23) = DFLOAT(myProcId)
        record(24) = DFLOAT(bi)
        record(25) = DFLOAT(bj)
        IF ( useSchema3 ) record(26) = 1. _d 0
        IF ( useSchema4 ) record(27) = 1. _d 0
        record(28) = 1. _d 0
        iRecord = INT(end8)
        CALL MDS_WRITEVEC_LOC(
     I       segmentName,precFloat64,ioUnit,
     I       'RL',bomArchiveFields,record,dummyRS,
     I       bi,bj,iRecord,myIter,myThid)
        IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
       ENDDO
      ENDDO
      _END_MASTER(myThid)

C--   GLOBAL_SUM_INT is used as the MPI/thread publication fence.  Rank zero
C     writes the segment descriptor once, then the one authoritative frame
C     commit.  Consumers ignore any tile tail beyond committed index frames.
      syncCount = 0
      CALL GLOBAL_SUM_INT( syncCount, myThid )
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        IF ( useSchema3 ) THEN
          WRITE(dataName,'(A,A)')
     &         physicalPrefix(1:ILNBLNK(physicalPrefix)),'.p3sig'
          ioUnit = -1
          DO iRecord=1,p3Records
            DO k=1,bomPickupChunkFields
              sigIndex=(iRecord-1)*bomPickupChunkFields+k
              signatureRecord(k)=0. _d 0
              IF ( sigIndex.LE.p3Fields )
     &             signatureRecord(k)=p3Signature(sigIndex)
            ENDDO
            writeRecord=(nextFrame-1)*p3Records+iRecord
            IF ( iRecord.LT.p3Records ) writeRecord=-writeRecord
            CALL MDS_WRITEVEC_LOC(
     I           dataName,precFloat64,ioUnit,
     I           'RL',bomPickupChunkFields,signatureRecord,dummyRS,
     I           0,0,writeRecord,myIter,myThid)
          ENDDO
          IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
        ENDIF
        IF ( useSchema4 ) THEN
          WRITE(dataName,'(A,A)')
     &         physicalPrefix(1:ILNBLNK(physicalPrefix)),'.p4sig'
          ioUnit = -1
          DO iRecord=1,p4Records
            DO k=1,bomPickupChunkFields
              sigIndex=(iRecord-1)*bomPickupChunkFields+k
              signatureRecord(k)=0. _d 0
              IF ( sigIndex.LE.bomP4SigFields )
     &             signatureRecord(k)=p4Signature(sigIndex)
            ENDDO
            writeRecord=(nextFrame-1)*p4Records+iRecord
            IF ( iRecord.LT.p4Records ) writeRecord=-writeRecord
            CALL MDS_WRITEVEC_LOC(
     I           dataName,precFloat64,ioUnit,
     I           'RL',bomPickupChunkFields,signatureRecord,dummyRS,
     I           0,0,writeRecord,myIter,myThid)
          ENDDO
          IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
        ENDIF
        ioUnit = -1
        IF ( nextFrame.EQ.1 ) THEN
          CALL BOM_ARCHIVE_INDEX_DESCRIPTOR(
     I         activeSchema,activeFields,
     I         modeCode,equationCode,currentCode,
     I         windCode,stokesCode,integratorCode,
     I         useSchema3,useSchema4,
     I         p3Fields,p3Records,p4Records,
     O         record )
          CALL MDS_WRITEVEC_LOC(
     I         indexName,precFloat64,ioUnit,
     I         'RL',bomArchiveIndexFields,record,dummyRS,
     I         0,0,-1,myIter,myThid)
        ENDIF
        CALL BOM_ARCHIVE_INDEX_COMMIT(
     I       nextFrame,sampleTime,scheduledTime,nextTime,myIter,
     I       activeSchema,activeFields,
     I       modeCode,equationCode,currentCode,
     I       windCode,stokesCode,integratorCode,
     I       useSchema3,useSchema4,
     I       p3Records,p4Records,
     O       record )
        iRecord = nextFrame + 1
        CALL MDS_WRITEVEC_LOC(
     I       indexName,precFloat64,ioUnit,
     I       'RL',bomArchiveIndexFields,record,dummyRS,
     I       0,0,iRecord,myIter,myThid)
        IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
      ENDIF
      _END_MASTER(myThid)
      syncCount = 0
      CALL GLOBAL_SUM_INT( syncCount, myThid )

C--   Publish in-memory cursors only after the global index commit returns.
      _BEGIN_MASTER(myThid)
      DO bj=1,nSy
       DO bi=1,nSx
        bomArchiveTileRecords(bi,bj)=
     &       bomArchiveTileRecords(bi,bj)
     &       +INT(bomNPartTile(bi,bj)+2,8)
       ENDDO
      ENDDO
      bomArchiveFrameCount = nextFrame
      bomArchiveStarted = .TRUE.
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,
     &       '(A,I10,A,I12,A,I12,A,I12,A,3(1X,1PE24.16))')
     &       'BOM trajectory archive frame=',nextFrame,
     &       ' iter=',myIter,' initial=',bomNPartExpected,
     &       ' live=',archiveLiveCount,
     &       ' sample/scheduled/next=',
     &       sampleTime,scheduledTime,nextTime
        CALL PRINT_MESSAGE( msgBuf,standardMessageUnit,
     &                      SQUEEZE_RIGHT,myThid )
      ENDIF
      _END_MASTER(myThid)
      _BARRIER
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_ARCHIVE_INDEX_DESCRIPTOR(
     I     activeSchema,activeFields,
     I     modeCode,equationCode,currentCode,
     I     windCode,stokesCode,integratorCode,
     I     useSchema3,useSchema4,
     I     p3Fields,p3Records,p4Records,
     O     record )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER activeSchema,activeFields
      INTEGER modeCode,equationCode,currentCode
      INTEGER windCode,stokesCode,integratorCode
      LOGICAL useSchema3,useSchema4
      INTEGER p3Fields,p3Records,p4Records
      _RL record(bomArchiveIndexFields)
      INTEGER k,archiveLiveCount
      archiveLiveCount=bomNPartExpected
      IF ( useSchema4 ) archiveLiveCount=bomNPartLiveExpected
      DO k=1,bomArchiveIndexFields
        record(k)=0. _d 0
      ENDDO
      record(1)=DFLOAT(bomArchiveIndexSchema)
      record(2)=DFLOAT(bomArchiveIndexFields)
      record(3)=DFLOAT(bomArchiveHeaderType)
      record(4)=DFLOAT(bomArchiveSchema)
      record(5)=DFLOAT(bomArchiveFields)
      record(6)=64. _d 0
      record(7)=DFLOAT(nIter0)
      record(8)=1. _d 0
      record(9)=DFLOAT(bomArchiveHeaderType)
      record(10)=DFLOAT(bomArchiveCommitType)
      record(11)=DFLOAT(activeSchema)
      record(12)=DFLOAT(activeFields)
      record(13)=DFLOAT(modeCode)
      record(14)=DFLOAT(equationCode)
      record(15)=DFLOAT(currentCode)
      record(16)=DFLOAT(windCode)
      record(17)=DFLOAT(stokesCode)
      record(18)=DFLOAT(integratorCode)
      IF ( useSchema3 ) record(19)=1. _d 0
      record(20)=DFLOAT(bomP3ContainerSchema)
      record(21)=DFLOAT(bomP3SidecarSchema)
      record(22)=DFLOAT(bomP3SidecarFields)
      record(23)=49. _d 0
      record(24)=56. _d 0
      IF ( useSchema4 ) record(25)=1. _d 0
      record(26)=DFLOAT(bomP4ContainerSchema)
      record(27)=DFLOAT(bomP4SidecarSchema)
      record(28)=DFLOAT(bomP4SidecarFields)
      record(29)=57. _d 0
      record(30)=60. _d 0
      record(31)=1. _d 0
      record(32)=48. _d 0
      record(33)=61. _d 0
      record(34)=64. _d 0
      IF ( activeSchema.EQ.bomOutputSchema2 ) THEN
        record(35)=DFLOAT(BOM_RHS_NDIAG)
        record(36)=22. _d 0
        record(37)=48. _d 0
      ENDIF
      record(38)=DFLOAT(nPx*nPy*nSx*nSy)
      record(39)=DFLOAT(bomMaxPartTile)
      record(40)=DFLOAT(bomNPartExpected)
      record(41)=DFLOAT(archiveLiveCount)
      record(42)=DFLOAT(nPx)
      record(43)=DFLOAT(nPy)
      record(44)=DFLOAT(nSx)
      record(45)=DFLOAT(nSy)
      record(46)=DFLOAT(sNx)
      record(47)=DFLOAT(sNy)
      record(48)=DFLOAT(Nx)
      record(49)=DFLOAT(Ny)
      record(50)=deltaTClock
      record(51)=bomOutputFreq
      record(52)=DFLOAT(nTx)
      record(53)=DFLOAT(nTy)
      record(54)=DFLOAT(bomInitialIter)
      record(55)=1. _d 0
      record(56)=DFLOAT(bomPickupChunkFields)
      IF ( useSchema3 ) THEN
        record(57)=DFLOAT(p3Fields)
        record(58)=DFLOAT(p3Records)
      ENDIF
      IF ( useSchema4 ) THEN
        record(59)=DFLOAT(bomP4SigFields)
        record(60)=DFLOAT(p4Records)
      ENDIF
      record(63)=1. _d 0
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_ARCHIVE_INDEX_COMMIT(
     I     frame,sampleTime,scheduledTime,nextTime,myIter,
     I     activeSchema,activeFields,
     I     modeCode,equationCode,currentCode,
     I     windCode,stokesCode,integratorCode,
     I     useSchema3,useSchema4,
     I     p3Records,p4Records,
     O     record )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER frame,myIter,activeSchema,activeFields
      INTEGER modeCode,equationCode,currentCode
      INTEGER windCode,stokesCode,integratorCode
      _RL sampleTime,scheduledTime,nextTime
      LOGICAL useSchema3,useSchema4
      INTEGER p3Records,p4Records
      _RL record(bomArchiveIndexFields)
      INTEGER k,globalTiles,archiveLiveCount
      globalTiles=nPx*nPy*nSx*nSy
      archiveLiveCount=bomNPartExpected
      IF ( useSchema4 ) archiveLiveCount=bomNPartLiveExpected
      DO k=1,bomArchiveIndexFields
        record(k)=0. _d 0
      ENDDO
      record(1)=DFLOAT(bomArchiveIndexSchema)
      record(2)=DFLOAT(bomArchiveIndexFields)
      record(3)=DFLOAT(bomArchiveCommitType)
      record(4)=DFLOAT(frame)
      record(5)=DFLOAT(nIter0)
      record(6)=DFLOAT(myIter)
      record(7)=sampleTime
      record(8)=scheduledTime
      record(9)=nextTime
      record(10)=DFLOAT(archiveLiveCount)
      record(11)=DFLOAT(bomNPartExpected)
      record(12)=DFLOAT(archiveLiveCount)
      record(13)=DFLOAT(globalTiles)
      record(14)=DFLOAT(archiveLiveCount+2*globalTiles)
      record(15)=DFLOAT(modeCode)
      record(16)=DFLOAT(equationCode)
      record(17)=DFLOAT(currentCode)
      record(18)=DFLOAT(windCode)
      record(19)=DFLOAT(stokesCode)
      record(20)=DFLOAT(integratorCode)
      IF ( useSchema3 ) record(21)=1. _d 0
      IF ( useSchema4 ) record(22)=1. _d 0
      record(23)=DFLOAT(activeSchema)
      record(24)=DFLOAT(activeFields)
      record(25)=DFLOAT(bomArchiveSchema)
      record(26)=DFLOAT(bomArchiveFields)
      record(27)=64. _d 0
      record(28)=1. _d 0
      record(29)=DFLOAT(nPx)
      record(30)=DFLOAT(nPy)
      record(31)=DFLOAT(nSx)
      record(32)=DFLOAT(nSy)
      record(33)=DFLOAT(p3Records)
      record(34)=DFLOAT(frame*p3Records)
      record(35)=DFLOAT(p4Records)
      record(36)=DFLOAT(frame*p4Records)
      record(37)=1. _d 0
      RETURN
      END
