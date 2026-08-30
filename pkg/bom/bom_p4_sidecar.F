#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_WRITE_P4_SIDECAR
C !INTERFACE:
      SUBROUTINE BOM_WRITE_P4_SIDECAR(
     I                 fileName, sampleTime, scheduledTime,
     I                 nextOutput, myIter, myThid )

C !DESCRIPTION:
C     Write the required four-field schema-1 P4 owner sidecar.  Three
C     fixed-width header records precede owners so time, tile, rank and live
C     counts are independently checked without widening the schema-2 core.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) fileName
      _RL sampleTime,scheduledTime,nextOutput
      INTEGER myIter,myThid
      CHARACTER*(MAX_LEN_FNAM) sideName
      _RL record(bomP4SidecarFields)
      _RS dummyRS(1)
      INTEGER bi,bj,ip,ioUnit,iRecord
      INTEGER*8 idHi,idLo,parentHi,parentLo
      LOGICAL wordValid
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

      WRITE(sideName,'(A,A)')
     &     fileName(1:ILNBLNK(fileName)),'.p4'
      DO bj=1,nSy
       DO bi=1,nSx
        ioUnit=-1
        record(1)=DFLOAT(bomP4SidecarSchema)
        record(2)=DFLOAT(bomP4SidecarFields)
        record(3)=DFLOAT(bomP4ContainerSchema)
        record(4)=DFLOAT(bomNPartTile(bi,bj))
        CALL MDS_WRITEVEC_LOC(
     I       sideName,precFloat64,ioUnit,
     I       'RL',bomP4SidecarFields,record,dummyRS,
     I       bi,bj,-1,myIter,myThid)
        record(1)=DFLOAT(myIter)
        record(2)=sampleTime
        record(3)=scheduledTime
        record(4)=nextOutput
        CALL MDS_WRITEVEC_LOC(
     I       sideName,precFloat64,ioUnit,
     I       'RL',bomP4SidecarFields,record,dummyRS,
     I       bi,bj,-2,myIter,myThid)
        record(1)=DFLOAT(myProcId)
        record(2)=DFLOAT(bi)
        record(3)=DFLOAT(bj)
        record(4)=DFLOAT(bomNPartLiveExpected)
        iRecord=-3
        IF ( bomNPartTile(bi,bj).EQ.0 ) iRecord=3
        CALL MDS_WRITEVEC_LOC(
     I       sideName,precFloat64,ioUnit,
     I       'RL',bomP4SidecarFields,record,dummyRS,
     I       bi,bj,iRecord,myIter,myThid)
        DO ip=1,bomNPartTile(bi,bj)
          CALL BOM_P4_I8_WORDS(
     I         bomId(ip,bi,bj),idHi,idLo,wordValid)
          IF ( .NOT.wordValid ) THEN
            CALL ALL_PROC_DIE(0)
            STOP 'ABNORMAL END: BOM_WRITE_P4_SIDECAR ID'
          ENDIF
          CALL BOM_P4_I8_WORDS(
     I         bomParentId(ip,bi,bj),parentHi,parentLo,wordValid)
          IF ( .NOT.wordValid ) THEN
            CALL ALL_PROC_DIE(0)
            STOP 'ABNORMAL END: BOM_WRITE_P4_SIDECAR PARENT'
          ENDIF
C--       The owner ID is checked through the aligned core; the four frozen
C         logical P4 fields are parent high/low, amount and birth count.
          record(1)=DFLOAT(parentHi)
          record(2)=DFLOAT(parentLo)
          record(3)=bomS(ip,bi,bj)
          record(4)=DFLOAT(bomBirthCount(ip,bi,bj))
          iRecord=ip+bomP4SidecarHeaderRecords
          IF ( ip.NE.bomNPartTile(bi,bj) ) iRecord=-iRecord
          CALL MDS_WRITEVEC_LOC(
     I         sideName,precFloat64,ioUnit,
     I         'RL',bomP4SidecarFields,record,dummyRS,
     I         bi,bj,iRecord,myIter,myThid)
        ENDDO
        IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
       ENDDO
      ENDDO
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_READ_P4_SIDECAR
C !INTERFACE:
      SUBROUTINE BOM_READ_P4_SIDECAR(
     I                 fileName,sampleTime,scheduledTime,nextOutput,
     I                 storedIter,storedLive,scratchCount,
     I                 scratchId,scratchStatus,
     O                 scratchParent,scratchS,scratchBirthCount,
     O                 localErrCount,
     I                 myThid)

C !DESCRIPTION:
C     Preflight and decode the four-field owner sidecar into caller scratch.
C     The schema-2 owner order is the alignment key and the frame manifest
C     protects its exact byte order before this routine is entered.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) fileName
      _RL sampleTime,scheduledTime,nextOutput
      INTEGER storedIter,storedLive
      INTEGER scratchCount(nSx,nSy)
      INTEGER scratchStatus(bomMaxPartTile,nSx,nSy)
      INTEGER*8 scratchId(bomMaxPartTile,nSx,nSy)
      INTEGER*8 scratchParent(bomMaxPartTile,nSx,nSy)
      _RL scratchS(bomMaxPartTile,nSx,nSy)
      INTEGER scratchBirthCount(bomMaxPartTile,nSx,nSy)
      INTEGER localErrCount,myThid
      CHARACTER*(MAX_LEN_FNAM) sideName,physicalPrefix
      CHARACTER*(MAX_LEN_FNAM) tilePrefix,dataName,metaName
      CHARACTER*(MAX_LEN_MBUF) metaSimulation,metaTitle
      CHARACTER*8 metaFieldList(1)
      _RL record(bomP4SidecarFields)
      _RL metaTimList(1),metaMissingValue
      _RS dummyRS(1)
      INTEGER metaDimList(3,3)
      INTEGER bi,bj,ip,k,ioUnit,iTile,jTile,iGlobal,jGlobal
      INTEGER prefixLen,localDirLen,metaFilePrec,metaNDims
      INTEGER metaNFlds,metaNTimRec,metaNRecords,metaFileIter
      INTEGER birthValue
      INTEGER*8 expectedBytes,tileBytes,parentId
      LOGICAL dataExists,metaExists,useCurrentDir,recordFinite
      LOGICAL wordValid

      localErrCount=0
      WRITE(sideName,'(A,A)') fileName(1:LEN_TRIM(fileName)),'.p4'
      prefixLen=LEN_TRIM(sideName)
      localDirLen=LEN_TRIM(mdsioLocalDir)
      IF ( localDirLen.GT.0 ) THEN
        WRITE(physicalPrefix,'(A,A)')
     &       mdsioLocalDir(1:localDirLen),sideName(1:prefixLen)
      ELSE
        physicalPrefix=sideName
      ENDIF
      DO bj=1,nSy
       DO bi=1,nSx
        expectedBytes=INT(scratchCount(bi,bj)+
     &       bomP4SidecarHeaderRecords,8)*
     &       INT(bomP4SidecarFields,8)*8_8
        iTile=bi+(myXGlobalLo-1)/sNx
        jTile=bj+(myYGlobalLo-1)/sNy
        WRITE(tilePrefix,'(A,A,I3.3,A,I3.3)')
     &       physicalPrefix(1:LEN_TRIM(physicalPrefix)),'.',
     &       iTile,'.',jTile
        WRITE(dataName,'(A,A)')
     &       tilePrefix(1:LEN_TRIM(tilePrefix)),'.data'
        WRITE(metaName,'(A,A)')
     &       tilePrefix(1:LEN_TRIM(tilePrefix)),'.meta'
        tileBytes=-1_8
        INQUIRE(FILE=dataName,EXIST=dataExists,SIZE=tileBytes)
        INQUIRE(FILE=metaName,EXIST=metaExists)
        IF ( .NOT.dataExists .OR. .NOT.metaExists .OR.
     &       tileBytes.NE.expectedBytes ) localErrCount=localErrCount+1
       ENDDO
      ENDDO
      IF ( localErrCount.GT.0 ) RETURN

      DO bj=1,nSy
       DO bi=1,nSx
        iTile=bi+(myXGlobalLo-1)/sNx
        jTile=bj+(myYGlobalLo-1)/sNy
        WRITE(tilePrefix,'(A,A,I3.3,A,I3.3)')
     &       physicalPrefix(1:LEN_TRIM(physicalPrefix)),'.',
     &       iTile,'.',jTile
        metaNDims=3
        metaNFlds=1
        metaNTimRec=1
        useCurrentDir=.TRUE.
        CALL MDS_READ_META(
     I       tilePrefix,
     O       metaSimulation,metaTitle,metaFilePrec,
     U       metaNDims,metaNFlds,metaNTimRec,
     O       metaDimList,metaFieldList,metaTimList,
     O       metaMissingValue,metaNRecords,metaFileIter,
     I       useCurrentDir,myThid)
        ioUnit=-1
        CALL MDS_READVEC_LOC(
     I       sideName,precFloat64,ioUnit,
     I       'RL',bomP4SidecarFields,record,dummyRS,
     I       bi,bj,1,myThid)
        IF ( record(1).NE.DFLOAT(bomP4SidecarSchema) .OR.
     &       record(2).NE.DFLOAT(bomP4SidecarFields) .OR.
     &       record(3).NE.DFLOAT(bomP4ContainerSchema) .OR.
     &       record(4).NE.DFLOAT(scratchCount(bi,bj)) )
     &       localErrCount=localErrCount+1
        CALL MDS_READVEC_LOC(
     I       sideName,precFloat64,ioUnit,
     I       'RL',bomP4SidecarFields,record,dummyRS,
     I       bi,bj,2,myThid)
        IF ( record(1).NE.DFLOAT(storedIter) .OR.
     &       TRANSFER(record(2),0_8).NE.TRANSFER(sampleTime,0_8)
     &       .OR. TRANSFER(record(3),0_8).NE.
     &       TRANSFER(scheduledTime,0_8)
     &       .OR. TRANSFER(record(4),0_8).NE.
     &       TRANSFER(nextOutput,0_8) )
     &       localErrCount=localErrCount+1
        CALL MDS_READVEC_LOC(
     I       sideName,precFloat64,ioUnit,
     I       'RL',bomP4SidecarFields,record,dummyRS,
     I       bi,bj,3,myThid)
        IF ( record(1).NE.DFLOAT(myProcId) .OR.
     &       record(2).NE.DFLOAT(bi) .OR.
     &       record(3).NE.DFLOAT(bj) .OR.
     &       record(4).NE.DFLOAT(storedLive) )
     &       localErrCount=localErrCount+1
        iGlobal=myXGlobalLo+(bi-1)*sNx
        jGlobal=myYGlobalLo+(bj-1)*sNy
        IF ( metaFilePrec.NE.precFloat64 .OR. metaNDims.NE.3 .OR.
     &       metaNRecords.NE.scratchCount(bi,bj)+
     &       bomP4SidecarHeaderRecords .OR.
     &       metaFileIter.NE.storedIter .OR.
     &       metaDimList(1,1).NE.nSx*nPx .OR.
     &       metaDimList(2,1).NE.iTile .OR.
     &       metaDimList(3,1).NE.iTile .OR.
     &       metaDimList(1,2).NE.nSy*nPy .OR.
     &       metaDimList(2,2).NE.jTile .OR.
     &       metaDimList(3,2).NE.jTile .OR.
     &       metaDimList(1,3).NE.bomP4SidecarFields .OR.
     &       metaDimList(2,3).NE.1 .OR.
     &       metaDimList(3,3).NE.bomP4SidecarFields )
     &       localErrCount=localErrCount+1
        DO ip=1,scratchCount(bi,bj)
          CALL MDS_READVEC_LOC(
     I         sideName,precFloat64,ioUnit,
     I         'RL',bomP4SidecarFields,record,dummyRS,
     I         bi,bj,ip+bomP4SidecarHeaderRecords,myThid)
          recordFinite=.TRUE.
          DO k=1,bomP4SidecarFields
            IF ( .NOT.IEEE_IS_FINITE(record(k)) )
     &           recordFinite=.FALSE.
          ENDDO
          parentId=0_8
          CALL BOM_P4_I8_FROM_WORDS(
     I         record(1),record(2),
     O         parentId,wordValid)
          birthValue=-1
          IF ( record(4).EQ.DNINT(record(4)) .AND.
     &         record(4).GE.0. _d 0 .AND.
     &         record(4).LE.DFLOAT(HUGE(birthValue)) )
     &         birthValue=NINT(record(4))
          IF ( .NOT.recordFinite .OR. .NOT.wordValid .OR.
     &         parentId.EQ.scratchId(ip,bi,bj) .OR.
     &         birthValue.LT.0 .OR.
     &         ( bomUseBiology .AND.
     &           ( record(3).LT.bomSMin .OR.
     &             record(3).GT.bomSMax ) ) .OR.
     &         ( scratchStatus(ip,bi,bj).NE.BOM_ALIVE .AND.
     &           scratchStatus(ip,bi,bj).NE.BOM_WAITING ) )
     &         localErrCount=localErrCount+1
          scratchParent(ip,bi,bj)=parentId
          scratchS(ip,bi,bj)=record(3)
          scratchBirthCount(ip,bi,bj)=birthValue
        ENDDO
        IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
        DO ip=scratchCount(bi,bj)+1,bomMaxPartTile
          scratchParent(ip,bi,bj)=0_8
          scratchS(ip,bi,bj)=0. _d 0
          scratchBirthCount(ip,bi,bj)=0
        ENDDO
       ENDDO
      ENDDO
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
