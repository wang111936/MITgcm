#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_GET_P3_SIZES( p3Fields, p2Fields )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
      INTEGER p3Fields,p2Fields,envFields
      CALL BOM_GET_PICKUP2_SIZES(p2Fields,envFields)
      p3Fields=bomP3SigBase+p2Fields
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BUILD_P3_SIGNATURE
C !INTERFACE:
      SUBROUTINE BOM_BUILD_P3_SIGNATURE(
     I                 myTime, myIter, nExpected, nextOutput,
     O                 signature, p3Fields, p2Fields, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Build container-schema-3 metadata followed by a bitwise unchanged copy
C     of the complete schema-2 fingerprint.  The schema-2 core and endpoint
C     sidecars therefore retain their accepted byte contract.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      _RL myTime,nextOutput,signature(*)
      INTEGER myIter,nExpected,p3Fields,p2Fields,myThid
      LOGICAL isValid
      _RL p2Signature(
     &     bomPickup2SigBase+2*MAX_LEN_FNAM+256)
      INTEGER envFields,k,springCode,neighborCode,raftCode
      LOGICAL p2Valid

      isValid=.FALSE.
      CALL BOM_GET_P3_SIZES(p3Fields,p2Fields)
      DO k=1,p3Fields
        signature(k)=0. _d 0
      ENDDO
      IF ( bomMode.NE.'BOM' .OR. bomSpringLaw.EQ.'NONE' ) RETURN
      springCode=0
      IF ( bomSpringLaw.EQ.'HOOKE' ) springCode=1
      IF ( bomSpringLaw.EQ.'EBOMB' ) springCode=2
      neighborCode=0
      IF ( bomNeighborPolicy.EQ.'CUTOFF' ) neighborCode=1
      raftCode=0
      IF ( bomRaftDiagnostics ) raftCode=1
      IF ( springCode.EQ.0 .OR. neighborCode.EQ.0 ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(myTime) .OR.
     &     .NOT.IEEE_IS_FINITE(nextOutput) .OR.
     &     .NOT.IEEE_IS_FINITE(bomSpringL) .OR.
     &     .NOT.IEEE_IS_FINITE(bomHookeK) .OR.
     &     .NOT.IEEE_IS_FINITE(bomSpringA) .OR.
     &     .NOT.IEEE_IS_FINITE(bomSpringDelta) .OR.
     &     .NOT.IEEE_IS_FINITE(bomNeighborCutoff) .OR.
     &     .NOT.IEEE_IS_FINITE(bomPairDistanceMin) .OR.
     &     .NOT.IEEE_IS_FINITE(bomSpringCFL) .OR.
     &     .NOT.IEEE_IS_FINITE(bomTau) ) RETURN

      CALL BOM_BUILD_PICKUP2_SIGNATURE(
     I     myTime,myIter,nExpected,nextOutput,
     I     bomEnvTime(BOM_ENV_OLD),bomEnvTime(BOM_ENV_NEW),
     I     bomEnvIter(BOM_ENV_OLD),bomEnvIter(BOM_ENV_NEW),
     I     bomEnvReady,
     O     p2Signature,p2Fields,envFields,p2Valid,myThid)
      IF ( .NOT.p2Valid ) RETURN

      signature(1)=DFLOAT(bomP3ContainerSchema)
      signature(2)=DFLOAT(p3Fields)
      signature(3)=DFLOAT(bomP3SidecarSchema)
      signature(4)=DFLOAT(bomP3SidecarFields)
      signature(5)=DFLOAT(springCode)
      signature(6)=DFLOAT(neighborCode)
      signature(7)=DFLOAT(raftCode)
      signature(8)=2. _d 0
      signature(9)=DFLOAT(nPx)
      signature(10)=DFLOAT(nPy)
      signature(11)=DFLOAT(sNx)
      signature(12)=DFLOAT(sNy)
      signature(13)=DFLOAT(nSx)
      signature(14)=DFLOAT(nSy)
      signature(15)=DFLOAT(Nx)
      signature(16)=DFLOAT(Ny)
      signature(17)=DFLOAT(bomMaxPartTile)
      signature(18)=DFLOAT(bomMaxNeighbor)
      signature(19)=DFLOAT(bomMaxGhostTile)
      signature(20)=DFLOAT(bomMaxGhostExchange)
      signature(21)=DFLOAT(bomPacketSchema)
      signature(22)=DFLOAT(bomPacketInts)
      signature(23)=DFLOAT(bomPacketReals)
      signature(24)=DFLOAT(bomGhostSchema)
      signature(25)=DFLOAT(bomGhostPacketInts)
      signature(26)=DFLOAT(bomGhostPacketReals)
      signature(27)=DFLOAT(bomComponentLabelSchema)
      signature(28)=DFLOAT(bomComponentLabelPacketInts)
      signature(29)=DFLOAT(bomComponentSizeSchema)
      signature(30)=DFLOAT(bomComponentSizePacketInts)
      signature(31)=bomSpringL
      signature(32)=bomHookeK
      signature(33)=bomSpringA
      signature(34)=bomSpringDelta
      signature(35)=bomNeighborCutoff
      signature(36)=bomPairDistanceMin
      signature(37)=bomSpringCFL
      signature(38)=bomTau
      signature(39)=DFLOAT(nExpected)
      signature(40)=DFLOAT(myIter)
      signature(41)=myTime
      signature(42)=nextOutput
      signature(43)=DFLOAT(p2Fields)
      signature(44)=DFLOAT(bomP3SigBase+1)
      DO k=1,p2Fields
        signature(bomP3SigBase+k)=p2Signature(k)
      ENDDO
      isValid=.TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VALIDATE_P3_SIGNATURE(
     I                 signature, p3Fields, p2Signature, p2Fields,
     I                 myTime, myIter, nExpected, nextOutput,
     O                 isValid,
     I                 myThid )
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      _RL signature(*),p2Signature(*),myTime,nextOutput
      INTEGER p3Fields,p2Fields,myIter,nExpected,myThid
      INTEGER expectedFields,expectedP2Fields,k
      INTEGER springCode,neighborCode,raftCode
      LOGICAL isValid
      isValid=.FALSE.
      CALL BOM_GET_P3_SIZES(expectedFields,expectedP2Fields)
      IF ( p3Fields.NE.expectedFields .OR.
     &     p2Fields.NE.expectedP2Fields ) RETURN
      DO k=1,p3Fields
        IF ( .NOT.IEEE_IS_FINITE(signature(k)) ) RETURN
      ENDDO
      springCode=0
      IF ( bomSpringLaw.EQ.'HOOKE' ) springCode=1
      IF ( bomSpringLaw.EQ.'EBOMB' ) springCode=2
      neighborCode=0
      IF ( bomNeighborPolicy.EQ.'CUTOFF' ) neighborCode=1
      raftCode=0
      IF ( bomRaftDiagnostics ) raftCode=1
      IF ( bomMode.NE.'BOM' .OR. springCode.EQ.0 .OR.
     &     neighborCode.EQ.0 ) RETURN
      IF ( signature(1).NE.DFLOAT(bomP3ContainerSchema) .OR.
     &     signature(2).NE.DFLOAT(p3Fields) .OR.
     &     signature(3).NE.DFLOAT(bomP3SidecarSchema) .OR.
     &     signature(4).NE.DFLOAT(bomP3SidecarFields) .OR.
     &     signature(5).NE.DFLOAT(springCode) .OR.
     &     signature(6).NE.DFLOAT(neighborCode) .OR.
     &     signature(7).NE.DFLOAT(raftCode) .OR.
     &     signature(8).NE.2. _d 0 .OR.
     &     signature(9).NE.DFLOAT(nPx) .OR.
     &     signature(10).NE.DFLOAT(nPy) .OR.
     &     signature(11).NE.DFLOAT(sNx) .OR.
     &     signature(12).NE.DFLOAT(sNy) .OR.
     &     signature(13).NE.DFLOAT(nSx) .OR.
     &     signature(14).NE.DFLOAT(nSy) .OR.
     &     signature(15).NE.DFLOAT(Nx) .OR.
     &     signature(16).NE.DFLOAT(Ny) .OR.
     &     signature(17).NE.DFLOAT(bomMaxPartTile) .OR.
     &     signature(18).NE.DFLOAT(bomMaxNeighbor) .OR.
     &     signature(19).NE.DFLOAT(bomMaxGhostTile) .OR.
     &     signature(20).NE.DFLOAT(bomMaxGhostExchange) .OR.
     &     signature(21).NE.DFLOAT(bomPacketSchema) .OR.
     &     signature(22).NE.DFLOAT(bomPacketInts) .OR.
     &     signature(23).NE.DFLOAT(bomPacketReals) .OR.
     &     signature(24).NE.DFLOAT(bomGhostSchema) .OR.
     &     signature(25).NE.DFLOAT(bomGhostPacketInts) .OR.
     &     signature(26).NE.DFLOAT(bomGhostPacketReals) .OR.
     &     signature(27).NE.DFLOAT(bomComponentLabelSchema) .OR.
     &     signature(28).NE.
     &       DFLOAT(bomComponentLabelPacketInts) .OR.
     &     signature(29).NE.DFLOAT(bomComponentSizeSchema) .OR.
     &     signature(30).NE.
     &       DFLOAT(bomComponentSizePacketInts) .OR.
     &     signature(39).NE.DFLOAT(nExpected) .OR.
     &     signature(40).NE.DFLOAT(myIter) .OR.
     &     signature(43).NE.DFLOAT(p2Fields) .OR.
     &     signature(44).NE.DFLOAT(bomP3SigBase+1) ) RETURN
      IF ( TRANSFER(signature(31),0_8).NE.
     &     TRANSFER(bomSpringL,0_8) .OR.
     &     TRANSFER(signature(32),0_8).NE.
     &     TRANSFER(bomHookeK,0_8) .OR.
     &     TRANSFER(signature(33),0_8).NE.
     &     TRANSFER(bomSpringA,0_8) .OR.
     &     TRANSFER(signature(34),0_8).NE.
     &     TRANSFER(bomSpringDelta,0_8) .OR.
     &     TRANSFER(signature(35),0_8).NE.
     &     TRANSFER(bomNeighborCutoff,0_8) .OR.
     &     TRANSFER(signature(36),0_8).NE.
     &     TRANSFER(bomPairDistanceMin,0_8) .OR.
     &     TRANSFER(signature(37),0_8).NE.
     &     TRANSFER(bomSpringCFL,0_8) .OR.
     &     TRANSFER(signature(38),0_8).NE.
     &     TRANSFER(bomTau,0_8) .OR.
     &     TRANSFER(signature(41),0_8).NE.
     &     TRANSFER(myTime,0_8) .OR.
     &     TRANSFER(signature(42),0_8).NE.
     &     TRANSFER(nextOutput,0_8) ) RETURN
      DO k=1,p2Fields
        IF ( TRANSFER(signature(bomP3SigBase+k),0_8).NE.
     &       TRANSFER(p2Signature(k),0_8) ) RETURN
      ENDDO
      isValid=.TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_WRITE_P3_SIGNATURE(
     I                 fileName, myTime, myIter,
     I                 nExpected, nextOutput,
     O                 localErrCount,
     I                 myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
      CHARACTER*(*) fileName
      CHARACTER*(MAX_LEN_FNAM) p3Name
      _RL myTime,nextOutput
      _RL signature(
     &     bomP3SigBase+bomPickup2SigBase
     &     +2*MAX_LEN_FNAM+256)
      _RL record(bomPickupChunkFields)
      _RS dummyRS(1)
      INTEGER myIter,nExpected,localErrCount,myThid
      INTEGER p3Fields,p2Fields,nRecords,iRecord,k,index,ioUnit
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK
      LOGICAL isValid
      localErrCount=0
      CALL BOM_BUILD_P3_SIGNATURE(
     I     myTime,myIter,nExpected,nextOutput,
     O     signature,p3Fields,p2Fields,isValid,myThid)
      IF ( .NOT.isValid ) THEN
        localErrCount=1
        RETURN
      ENDIF
      WRITE(p3Name,'(A,A)')
     &     fileName(1:ILNBLNK(fileName)),'.p3sig'
      nRecords=(p3Fields+bomPickupChunkFields-1)
     &     /bomPickupChunkFields
      ioUnit=-1
      DO iRecord=1,nRecords
        DO k=1,bomPickupChunkFields
          index=(iRecord-1)*bomPickupChunkFields+k
          record(k)=0. _d 0
          IF ( index.LE.p3Fields ) record(k)=signature(index)
        ENDDO
        index=iRecord
        IF ( iRecord.LT.nRecords ) index=-iRecord
        CALL MDS_WRITEVEC_LOC(
     I       p3Name,precFloat64,ioUnit,
     I       'RL',bomPickupChunkFields,record,dummyRS,
     I       0,0,index,myIter,myThid)
      ENDDO
      IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_READ_P3_SIGNATURE(
     I                 fileName, p2Signature, p2Fields,
     I                 myTime, myIter,
     I                 nExpected, nextOutput,
     O                 localErrCount,
     I                 myThid )
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
      CHARACTER*(*) fileName
      CHARACTER*(MAX_LEN_FNAM) p3Name,dataName,metaName
      CHARACTER*(MAX_LEN_MBUF) metaSimulation,metaTitle
      CHARACTER*8 metaFieldList(1)
      _RL myTime,nextOutput
      _RL p2Signature(*)
      _RL signature(
     &     bomP3SigBase+bomPickup2SigBase
     &     +2*MAX_LEN_FNAM+256)
      _RL record(bomPickupChunkFields)
      _RL metaTimList(1),metaMissingValue
      _RS dummyRS(1)
      INTEGER myIter,nExpected,localErrCount,myThid
      INTEGER p3Fields,p2Fields,nRecords,iRecord,k,index,ioUnit
      INTEGER metaFilePrec,metaNDims,metaNFlds,metaNTimRec
      INTEGER metaNRecords,metaFileIter,metaDimList(3,3)
      INTEGER*8 actualBytes,expectedBytes
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK
      LOGICAL dataExists,metaExists,useCurrentDir,isValid
      CALL BOM_GET_P3_SIZES(p3Fields,p2Fields)
      localErrCount=0
      WRITE(p3Name,'(A,A)')
     &     fileName(1:ILNBLNK(fileName)),'.p3sig'
      WRITE(dataName,'(A,A)')p3Name(1:ILNBLNK(p3Name)),'.data'
      WRITE(metaName,'(A,A)')p3Name(1:ILNBLNK(p3Name)),'.meta'
      nRecords=(p3Fields+bomPickupChunkFields-1)
     &     /bomPickupChunkFields
      expectedBytes=INT(nRecords,8)
     &     *INT(bomPickupChunkFields,8)*8_8
      actualBytes=-1_8
      INQUIRE(FILE=dataName,EXIST=dataExists,SIZE=actualBytes)
      INQUIRE(FILE=metaName,EXIST=metaExists)
      IF ( .NOT.dataExists .OR. .NOT.metaExists .OR.
     &     actualBytes.NE.expectedBytes ) THEN
        localErrCount=localErrCount+1
        RETURN
      ENDIF
      metaNDims=3
      metaNFlds=1
      metaNTimRec=1
      useCurrentDir=.TRUE.
      CALL MDS_READ_META(
     I     p3Name,
     O     metaSimulation,metaTitle,metaFilePrec,
     U     metaNDims,metaNFlds,metaNTimRec,
     O     metaDimList,metaFieldList,metaTimList,
     O     metaMissingValue,metaNRecords,metaFileIter,
     I     useCurrentDir,myThid)
      ioUnit=-1
      DO iRecord=1,nRecords
        CALL MDS_READVEC_LOC(
     I       p3Name,precFloat64,ioUnit,
     I       'RL',bomPickupChunkFields,record,dummyRS,
     I       0,0,iRecord,myThid)
        DO k=1,bomPickupChunkFields
          index=(iRecord-1)*bomPickupChunkFields+k
          IF ( index.LE.p3Fields ) signature(index)=record(k)
        ENDDO
      ENDDO
      IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
      IF ( metaFilePrec.NE.precFloat64 .OR. metaNDims.NE.3 .OR.
     &     metaNRecords.NE.nRecords .OR. metaFileIter.NE.myIter .OR.
     &     metaDimList(1,1).NE.1 .OR.
     &     metaDimList(2,1).NE.1 .OR.
     &     metaDimList(3,1).NE.1 .OR.
     &     metaDimList(1,2).NE.1 .OR.
     &     metaDimList(2,2).NE.1 .OR.
     &     metaDimList(3,2).NE.1 .OR.
     &     metaDimList(1,3).NE.bomPickupChunkFields .OR.
     &     metaDimList(2,3).NE.1 .OR.
     &     metaDimList(3,3).NE.bomPickupChunkFields )
     &     localErrCount=localErrCount+1
      DO k=1,p3Fields
        IF ( .NOT.IEEE_IS_FINITE(signature(k)) )
     &       localErrCount=localErrCount+1
      ENDDO
      CALL BOM_VALIDATE_P3_SIGNATURE(
     I     signature,p3Fields,p2Signature,p2Fields,
     I     myTime,myIter,nExpected,nextOutput,
     O     isValid,myThid)
      IF ( .NOT.isValid ) localErrCount=localErrCount+1
      RETURN
      END
