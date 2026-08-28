#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VALIDATE_P3_IO_STATE(
     I                 myTime, myIter, nextOutput,
     O                 localErrCount,
     I                 myThid )
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL myTime,nextOutput
      INTEGER myIter,localErrCount,myThid
      INTEGER bi,bj,ip,p3Fields,p2Fields
      _RL signature(
     &     bomP3SigBase+bomPickup2SigBase
     &     +2*MAX_LEN_FNAM+256)
      LOGICAL signatureValid
      localErrCount=0
      IF ( bomMode.NE.'BOM' .OR. bomSpringLaw.EQ.'NONE' ) RETURN
      CALL BOM_BUILD_P3_SIGNATURE(
     I     myTime,myIter,bomNPartExpected,nextOutput,
     O     signature,p3Fields,p2Fields,signatureValid,myThid)
      IF ( .NOT.signatureValid ) localErrCount=localErrCount+1
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO ip=1,bomNPartTile(bi,bj)
          IF ( .NOT.IEEE_IS_FINITE(bomSpringEast(ip,bi,bj)) .OR.
     &         .NOT.IEEE_IS_FINITE(bomSpringNorth(ip,bi,bj)) .OR.
     &         bomNeighborCount(ip,bi,bj).LT.0 .OR.
     &         bomNeighborCount(ip,bi,bj).GT.bomMaxNeighbor )
     &         localErrCount=localErrCount+1
          IF ( bomStatus(ip,bi,bj).EQ.BOM_ALIVE ) THEN
            IF ( bomRaftDiagnostics ) THEN
              IF ( bomRaftId(ip,bi,bj).LE.0_8 .OR.
     &             bomRaftId(ip,bi,bj).GT.bomId(ip,bi,bj) .OR.
     &             bomRaftSize(ip,bi,bj).LT.1 .OR.
     &             bomRaftSize(ip,bi,bj).GT.bomNPartExpected )
     &             localErrCount=localErrCount+1
            ELSEIF ( bomRaftId(ip,bi,bj).NE.0_8 .OR.
     &               bomRaftSize(ip,bi,bj).NE.0 ) THEN
              localErrCount=localErrCount+1
            ENDIF
          ELSEIF ( bomStatus(ip,bi,bj).EQ.BOM_WAITING ) THEN
            IF ( bomSpringEast(ip,bi,bj).NE.0. _d 0 .OR.
     &           bomSpringNorth(ip,bi,bj).NE.0. _d 0 .OR.
     &           bomNeighborCount(ip,bi,bj).NE.0 .OR.
     &           bomRaftId(ip,bi,bj).NE.0_8 .OR.
     &           bomRaftSize(ip,bi,bj).NE.0 )
     &           localErrCount=localErrCount+1
          ELSE
            localErrCount=localErrCount+1
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VALIDATE_P3_RESTART_GRAPH
C !INTERFACE:
      SUBROUTINE BOM_VALIDATE_P3_RESTART_GRAPH(
     I                 scratchCount, scratchId, scratchStatus,
     I                 scratchReal, scratchSpringEast,
     I                 scratchSpringNorth, scratchNeighbor,
     I                 scratchRaftId, scratchRaftSize,
     O                 localErrCount,
     I                 myThid )
C !DESCRIPTION:
C     Rebuild the exact FINAL graph from pickup scratch and compare every
C     derived spring/component field before authoritative state is committed.
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER scratchCount(nSx,nSy)
      INTEGER scratchStatus(bomMaxPartTile,nSx,nSy)
      INTEGER*8 scratchId(bomMaxPartTile,nSx,nSy)
      _RL scratchReal(12,bomMaxPartTile,nSx,nSy)
      _RL scratchSpringEast(bomMaxPartTile,nSx,nSy)
      _RL scratchSpringNorth(bomMaxPartTile,nSx,nSy)
      INTEGER scratchNeighbor(bomMaxPartTile,nSx,nSy)
      INTEGER*8 scratchRaftId(bomMaxPartTile,nSx,nSy)
      INTEGER scratchRaftSize(bomMaxPartTile,nSx,nSy)
      INTEGER localErrCount,myThid
      INTEGER nOwner,owner,ip,bi,bj,failCode,failPhase
      INTEGER graphErrors,globalGraphErrors,componentFail
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord)
      INTEGER ownerBj(bomMaxOwnerRecord)
      INTEGER ownerNeighbor(bomMaxOwnerRecord)
      INTEGER calcRaftSize(bomMaxOwnerRecord)
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER*8 calcRaftId(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord),ownerY(bomMaxOwnerRecord)
      _RL calcSpringEast(bomMaxOwnerRecord)
      _RL calcSpringNorth(bomMaxOwnerRecord)
      INTEGER*8 ownerRecords,ghostRecords,nonEmptyCells
      INTEGER*8 candidateComparisons,directedNeighbors
      INTEGER*8 undirectedEdges,maximumNeighbors
      LOGICAL exchangeValid,stageValid,componentValid

      localErrCount=0
      nOwner=0
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,scratchCount(bi,bj)
          nOwner=nOwner+1
          IF ( nOwner.LE.bomMaxOwnerRecord ) THEN
            ownerId(nOwner)=scratchId(ip,bi,bj)
            ownerStatus(nOwner)=scratchStatus(ip,bi,bj)
            ownerX(nOwner)=scratchReal(1,ip,bi,bj)
            ownerY(nOwner)=scratchReal(2,ip,bi,bj)
            ownerBi(nOwner)=bi
            ownerBj(nOwner)=bj
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      IF ( nOwner.GT.bomMaxOwnerRecord ) THEN
        localErrCount=localErrCount+1
        RETURN
      ENDIF
      DO owner=1,nOwner
        calcRaftId(owner)=0_8
        calcRaftSize(owner)=0
      ENDDO

      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,ownerBi,ownerBj,
     I     BOM_STAGE_FINAL,1,1,
     O     failCode,failPhase,exchangeValid,myThid)
      IF ( .NOT.exchangeValid ) localErrCount=localErrCount+1
      graphErrors=0
      IF ( exchangeValid ) THEN
        CALL BOM_SPRING_STAGE(
     I       nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I       BOM_STAGE_FINAL,1,1,0. _d 0,
     O       calcSpringEast,calcSpringNorth,ownerNeighbor,
     O       ownerRecords,ghostRecords,nonEmptyCells,
     O       candidateComparisons,directedNeighbors,
     O       undirectedEdges,maximumNeighbors,
     O       failCode,failPhase,stageValid,myThid)
        IF ( .NOT.stageValid ) graphErrors=graphErrors+1
      ELSE
        stageValid=.FALSE.
        graphErrors=graphErrors+1
      ENDIF
      globalGraphErrors=graphErrors
      CALL GLOBAL_SUM_INT(globalGraphErrors,myThid)
      IF ( globalGraphErrors.EQ.0 .AND. bomRaftDiagnostics ) THEN
        CALL BOM_COMPONENT_FETCH(
     I       nOwner,ownerId,BOM_STAGE_FINAL,1,1,
     O       calcRaftId,calcRaftSize,
     O       componentFail,componentValid,myThid)
        IF ( .NOT.componentValid ) localErrCount=localErrCount+1
      ELSEIF ( globalGraphErrors.NE.0 ) THEN
        localErrCount=localErrCount+globalGraphErrors
      ENDIF

      IF ( globalGraphErrors.EQ.0 ) THEN
        owner=0
        DO bj=1,nSy
         DO bi=1,nSx
          DO ip=1,scratchCount(bi,bj)
            owner=owner+1
            IF ( TRANSFER(calcSpringEast(owner),0_8).NE.
     &           TRANSFER(scratchSpringEast(ip,bi,bj),0_8) .OR.
     &           TRANSFER(calcSpringNorth(owner),0_8).NE.
     &           TRANSFER(scratchSpringNorth(ip,bi,bj),0_8) .OR.
     &           ownerNeighbor(owner).NE.
     &           scratchNeighbor(ip,bi,bj) .OR.
     &           calcRaftId(owner).NE.scratchRaftId(ip,bi,bj) .OR.
     &           calcRaftSize(owner).NE.scratchRaftSize(ip,bi,bj) )
     &           localErrCount=localErrCount+1
          ENDDO
         ENDDO
        ENDDO
      ENDIF
      CALL BOM_GHOST_INVALIDATE
      CALL BOM_COMPONENT_INVALIDATE
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_WRITE_P3_SIDECAR
C !INTERFACE:
      SUBROUTINE BOM_WRITE_P3_SIDECAR(
     I                 fileName, sampleTime, scheduledTime,
     I                 nextOutput, myIter, myThid )
C !DESCRIPTION:
C     Write the required fixed-width schema-1 P3 sidecar.  Every particle
C     record is keyed by the exact core ID and retains the core tile order.
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
      _RL record(bomP3SidecarFields)
      _RS dummyRS(1)
      INTEGER bi,bj,ip,k,ioUnit,iRecord
      INTEGER*8 idRadix,idHi8,idLo8,raftHi8,raftLo8
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK
      idRadix=4294967296_8
      WRITE(sideName,'(A,A)')
     &     fileName(1:ILNBLNK(fileName)),'.p3'
      DO bj=1,nSy
       DO bi=1,nSx
        DO k=1,bomP3SidecarFields
          record(k)=0. _d 0
        ENDDO
        record(1)=DFLOAT(bomP3SidecarSchema)
        record(2)=DFLOAT(bomP3SidecarFields)
        record(3)=DFLOAT(bomP3ContainerSchema)
        record(4)=DFLOAT(bomNPartTile(bi,bj))
        record(5)=DFLOAT(myIter)
        record(6)=sampleTime
        record(7)=scheduledTime
        record(8)=nextOutput
        ioUnit=-1
        iRecord=-1
        IF ( bomNPartTile(bi,bj).EQ.0 ) iRecord=1
        CALL MDS_WRITEVEC_LOC(
     I       sideName,precFloat64,ioUnit,
     I       'RL',bomP3SidecarFields,record,dummyRS,
     I       bi,bj,iRecord,myIter,myThid)
        DO ip=1,bomNPartTile(bi,bj)
          idHi8=bomId(ip,bi,bj)/idRadix
          idLo8=MOD(bomId(ip,bi,bj),idRadix)
          raftHi8=bomRaftId(ip,bi,bj)/idRadix
          raftLo8=MOD(bomRaftId(ip,bi,bj),idRadix)
          record(1)=DFLOAT(idHi8)
          record(2)=DFLOAT(idLo8)
          record(3)=DFLOAT(raftHi8)
          record(4)=DFLOAT(raftLo8)
          record(5)=DFLOAT(bomNeighborCount(ip,bi,bj))
          record(6)=DFLOAT(bomRaftSize(ip,bi,bj))
          record(7)=bomSpringEast(ip,bi,bj)
          record(8)=bomSpringNorth(ip,bi,bj)
          iRecord=ip+1
          IF ( ip.NE.bomNPartTile(bi,bj) ) iRecord=-iRecord
          CALL MDS_WRITEVEC_LOC(
     I         sideName,precFloat64,ioUnit,
     I         'RL',bomP3SidecarFields,record,dummyRS,
     I         bi,bj,iRecord,myIter,myThid)
        ENDDO
        IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
       ENDDO
      ENDDO
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_READ_P3_SIDECAR
C !INTERFACE:
      SUBROUTINE BOM_READ_P3_SIDECAR(
     I                 fileName, storedTime, storedScheduled,
     I                 storedNext, storedIter,
     I                 scratchCount, scratchId, scratchStatus,
     O                 scratchSpringEast, scratchSpringNorth,
     O                 scratchNeighbor, scratchRaftId,
     O                 scratchRaftSize, localErrCount,
     I                 myThid )
C !DESCRIPTION:
C     Preflight and decode all tiled schema-3 sidecars into non-authoritative
C     scratch.  Missing, extra, truncated, reordered, or malformed records
C     are reported before the caller's single accepted-state commit.
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) fileName
      _RL storedTime,storedScheduled,storedNext
      INTEGER storedIter,myThid,localErrCount
      INTEGER scratchCount(nSx,nSy)
      INTEGER scratchStatus(bomMaxPartTile,nSx,nSy)
      INTEGER*8 scratchId(bomMaxPartTile,nSx,nSy)
      _RL scratchSpringEast(bomMaxPartTile,nSx,nSy)
      _RL scratchSpringNorth(bomMaxPartTile,nSx,nSy)
      INTEGER scratchNeighbor(bomMaxPartTile,nSx,nSy)
      INTEGER*8 scratchRaftId(bomMaxPartTile,nSx,nSy)
      INTEGER scratchRaftSize(bomMaxPartTile,nSx,nSy)
      CHARACTER*(MAX_LEN_FNAM) sideName,physicalPrefix,tilePrefix
      CHARACTER*(MAX_LEN_FNAM) dataName,metaName
      CHARACTER*(MAX_LEN_MBUF) metaSimulation,metaTitle
      CHARACTER*8 metaFieldList(1)
      _RL record(bomP3SidecarFields)
      _RL metaTimList(1),metaMissingValue
      _RS dummyRS(1)
      INTEGER metaDimList(3,3)
      INTEGER metaFilePrec,metaNDims,metaNFlds,metaNTimRec
      INTEGER metaNRecords,metaFileIter
      INTEGER bi,bj,ip,k,ioUnit,iTile,jTile,prefixLen,localDirLen
      INTEGER neighborValue,sizeValue,idError,raftError
      INTEGER*8 tileBytes,recordBytes,expectedBytes
      INTEGER*8 particleId,raftIdValue
      LOGICAL dataExists,metaExists,useCurrentDir,recordFinite
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

      localErrCount=0
      WRITE(sideName,'(A,A)')
     &     fileName(1:ILNBLNK(fileName)),'.p3'
      prefixLen=ILNBLNK(sideName)
      localDirLen=ILNBLNK(mdsioLocalDir)
      IF ( localDirLen.GT.0 ) THEN
        WRITE(physicalPrefix,'(2A)')
     &       mdsioLocalDir(1:localDirLen),sideName(1:prefixLen)
      ELSE
        physicalPrefix=sideName
      ENDIF
      recordBytes=INT(bomP3SidecarFields,8)*8_8
      DO bj=1,nSy
       DO bi=1,nSx
        iTile=bi+(myXGlobalLo-1)/sNx
        jTile=bj+(myYGlobalLo-1)/sNy
        WRITE(tilePrefix,'(A,A,I3.3,A,I3.3)')
     &       physicalPrefix(1:ILNBLNK(physicalPrefix)),'.',
     &       iTile,'.',jTile
        WRITE(dataName,'(A,A)')
     &       tilePrefix(1:ILNBLNK(tilePrefix)),'.data'
        WRITE(metaName,'(A,A)')
     &       tilePrefix(1:ILNBLNK(tilePrefix)),'.meta'
        tileBytes=-1_8
        INQUIRE(FILE=dataName,EXIST=dataExists,SIZE=tileBytes)
        INQUIRE(FILE=metaName,EXIST=metaExists)
        expectedBytes=INT(scratchCount(bi,bj)+1,8)*recordBytes
        IF ( .NOT.dataExists .OR. .NOT.metaExists .OR.
     &       tileBytes.NE.expectedBytes ) THEN
          localErrCount=localErrCount+1
        ENDIF
       ENDDO
      ENDDO
      IF ( localErrCount.GT.0 ) RETURN

      DO bj=1,nSy
       DO bi=1,nSx
        iTile=bi+(myXGlobalLo-1)/sNx
        jTile=bj+(myYGlobalLo-1)/sNy
        WRITE(tilePrefix,'(A,A,I3.3,A,I3.3)')
     &       physicalPrefix(1:ILNBLNK(physicalPrefix)),'.',
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
     I       'RL',bomP3SidecarFields,record,dummyRS,
     I       bi,bj,1,myThid)
        recordFinite=.TRUE.
        DO k=1,bomP3SidecarFields
          IF ( .NOT.IEEE_IS_FINITE(record(k)) )
     &         recordFinite=.FALSE.
        ENDDO
        IF ( .NOT.recordFinite .OR.
     &       record(1).NE.DFLOAT(bomP3SidecarSchema) .OR.
     &       record(2).NE.DFLOAT(bomP3SidecarFields) .OR.
     &       record(3).NE.DFLOAT(bomP3ContainerSchema) .OR.
     &       record(4).NE.DFLOAT(scratchCount(bi,bj)) .OR.
     &       record(5).NE.DFLOAT(storedIter) .OR.
     &       TRANSFER(record(6),0_8).NE.
     &       TRANSFER(storedTime,0_8) .OR.
     &       TRANSFER(record(7),0_8).NE.
     &       TRANSFER(storedScheduled,0_8) .OR.
     &       TRANSFER(record(8),0_8).NE.
     &       TRANSFER(storedNext,0_8) ) localErrCount=localErrCount+1
        IF ( metaFilePrec.NE.precFloat64 .OR. metaNDims.NE.3 .OR.
     &       metaNRecords.NE.scratchCount(bi,bj)+1 .OR.
     &       metaFileIter.NE.storedIter .OR.
     &       metaDimList(1,1).NE.nSx*nPx .OR.
     &       metaDimList(2,1).NE.iTile .OR.
     &       metaDimList(3,1).NE.iTile .OR.
     &       metaDimList(1,2).NE.nSy*nPy .OR.
     &       metaDimList(2,2).NE.jTile .OR.
     &       metaDimList(3,2).NE.jTile .OR.
     &       metaDimList(1,3).NE.bomP3SidecarFields .OR.
     &       metaDimList(2,3).NE.1 .OR.
     &       metaDimList(3,3).NE.bomP3SidecarFields )
     &       localErrCount=localErrCount+1
        DO ip=1,scratchCount(bi,bj)
          CALL MDS_READVEC_LOC(
     I         sideName,precFloat64,ioUnit,
     I         'RL',bomP3SidecarFields,record,dummyRS,
     I         bi,bj,ip+1,myThid)
          recordFinite=.TRUE.
          DO k=1,bomP3SidecarFields
            IF ( .NOT.IEEE_IS_FINITE(record(k)) )
     &           recordFinite=.FALSE.
          ENDDO
          particleId=0_8
          raftIdValue=0_8
          idError=1
          raftError=1
          IF ( recordFinite ) THEN
            CALL BOM_ID_FROM_WORDS(
     I           record(1),record(2),particleId,idError)
            IF ( record(3).EQ.0. _d 0 .AND.
     &           record(4).EQ.0. _d 0 ) THEN
              raftIdValue=0_8
              raftError=0
            ELSE
              CALL BOM_ID_FROM_WORDS(
     I             record(3),record(4),raftIdValue,raftError)
            ENDIF
          ENDIF
          neighborValue=-1
          sizeValue=-1
          IF ( recordFinite .AND.
     &         record(5).EQ.DNINT(record(5)) .AND.
     &         record(6).EQ.DNINT(record(6)) ) THEN
            neighborValue=NINT(record(5))
            sizeValue=NINT(record(6))
          ENDIF
          IF ( .NOT.recordFinite .OR. idError.NE.0 .OR.
     &         raftError.NE.0 .OR.
     &         particleId.NE.scratchId(ip,bi,bj) .OR.
     &         neighborValue.LT.0 .OR.
     &         neighborValue.GT.bomMaxNeighbor .OR.
     &         sizeValue.LT.0 ) localErrCount=localErrCount+1
          IF ( scratchStatus(ip,bi,bj).EQ.BOM_ALIVE ) THEN
            IF ( bomRaftDiagnostics ) THEN
              IF ( raftIdValue.LE.0_8 .OR.
     &             raftIdValue.GT.particleId .OR.
     &             sizeValue.LT.1 ) localErrCount=localErrCount+1
            ELSEIF ( raftIdValue.NE.0_8 .OR.
     &               sizeValue.NE.0 ) THEN
              localErrCount=localErrCount+1
            ENDIF
          ELSEIF ( scratchStatus(ip,bi,bj).EQ.BOM_WAITING ) THEN
            IF ( record(7).NE.0. _d 0 .OR.
     &           record(8).NE.0. _d 0 .OR.
     &           neighborValue.NE.0 .OR. raftIdValue.NE.0_8 .OR.
     &           sizeValue.NE.0 ) localErrCount=localErrCount+1
          ELSE
            localErrCount=localErrCount+1
          ENDIF
          scratchSpringEast(ip,bi,bj)=record(7)
          scratchSpringNorth(ip,bi,bj)=record(8)
          scratchNeighbor(ip,bi,bj)=neighborValue
          scratchRaftId(ip,bi,bj)=raftIdValue
          scratchRaftSize(ip,bi,bj)=sizeValue
        ENDDO
        IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
       ENDDO
      ENDDO
      RETURN
      END
