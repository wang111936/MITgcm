#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BIRTH_PARENT_ORDER
C !INTERFACE:
      SUBROUTINE BOM_BIRTH_PARENT_ORDER(
     I                 nLocal,localParentId,
     I                 localBi,localBj,localSlot,
     O                 localOrdinal,nGlobal,
     O                 failCode,p4FailPhase,failRank,
     O                 failBi,failBj,failSlot,failId,isValid,
     I                 myThid )

C !DESCRIPTION:
C     Gather only bounded prospective-birth metadata, reject duplicate
C     parents, and return the exact global parent-ID order.  No live owner
C     record or owner-state array enters this collective.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nLocal,nGlobal,localBi(bomMaxEventBuffer)
      INTEGER localBj(bomMaxEventBuffer),localSlot(bomMaxEventBuffer)
      INTEGER localOrdinal(bomMaxEventBuffer)
      INTEGER failCode,p4FailPhase,failRank,failBi,failBj,failSlot
      INTEGER*8 localParentId(bomMaxEventBuffer),failId
      LOGICAL isValid
      INTEGER myThid

#ifdef ALLOW_BOM
      INTEGER metaInts
      PARAMETER ( metaInts=6 )
      INTEGER safeLocal,ip,jp,rankIndex,totalCount,packetIndex
      INTEGER localFailCode,localFailPhase,localFailBi,localFailBj
      INTEGER localFailSlot,mpiRC
      INTEGER sendCountI(nPx*nPy),recvCountI(nPx*nPy)
      INTEGER sendDisplI(nPx*nPy),recvDisplI(nPx*nPy)
      INTEGER rankCount(nPx*nPy),rankDispl(nPx*nPy)
      INTEGER sendInt(metaInts,bomMaxEventBuffer)
      INTEGER recvInt(metaInts,bomMaxEventBuffer)
      INTEGER*8 parentId,sortId(bomMaxEventBuffer)
      INTEGER*8 sortIndex(bomMaxEventBuffer),keyId,keyIndex
      INTEGER*8 idRadix,idHi,idLo,localFailId
      LOGICAL packetValid
      SAVE sendInt,recvInt
#endif

      nGlobal=0
      failCode=BOM_FAIL_BIRTH_ID
      p4FailPhase=BOM_P4_PHASE_BIRTH_ORDER
      failRank=myProcId
      failBi=0
      failBj=0
      failSlot=0
      failId=0_8
      isValid=.FALSE.
#ifdef ALLOW_BOM
      idRadix=4294967296_8
      localFailCode=BOM_FAIL_NONE
      localFailPhase=BOM_P4_PHASE_NONE
      localFailBi=0
      localFailBj=0
      localFailSlot=0
      localFailId=0_8
      safeLocal=MAX(0,MIN(bomMaxEventBuffer,nLocal))
      IF ( nLocal.NE.safeLocal ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_CAPACITY,BOM_FAIL_EVENT_CAPACITY,
     I     myProcId,0,0,0,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)
      DO ip=1,bomMaxEventBuffer
        localOrdinal(ip)=0
      ENDDO
      DO rankIndex=1,nPx*nPy
        rankCount(rankIndex)=0
        rankDispl(rankIndex)=0
      ENDDO

#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allgather(
     I       safeLocal,1,MPI_INTEGER,
     O       rankCount,1,MPI_INTEGER,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ELSE
#endif
        rankCount(1)=safeLocal
#ifdef ALLOW_USE_MPI
      ENDIF
#endif
      totalCount=0
      DO rankIndex=1,nPx*nPy
        rankDispl(rankIndex)=totalCount
        IF ( rankCount(rankIndex).LT.0 .OR.
     &       rankCount(rankIndex).GT.bomMaxEventBuffer-totalCount ) THEN
          CALL BOM_P4_KEEP_FAILURE(
     I         BOM_P4_PHASE_CAPACITY,BOM_FAIL_EVENT_CAPACITY,
     I         myProcId,0,0,0,0_8,
     U         localFailPhase,localFailCode,localFailBi,localFailBj,
     U         localFailSlot,localFailId)
        ELSE
          totalCount=totalCount+rankCount(rankIndex)
        ENDIF
      ENDDO
      IF ( totalCount.GT.bomMaxEventBuffer ) totalCount=0
      nGlobal=totalCount

      DO ip=1,safeLocal
        packetValid=localParentId(ip).GT.0_8 .AND.
     &       localBi(ip).GE.1 .AND. localBi(ip).LE.nSx .AND.
     &       localBj(ip).GE.1 .AND. localBj(ip).LE.nSy .AND.
     &       localSlot(ip).GE.1 .AND.
     &       localSlot(ip).LE.bomMaxPartTile
        IF ( .NOT.packetValid ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,localBi(ip),localBj(ip),localSlot(ip),
     I       localParentId(ip),
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
        idHi=localParentId(ip)/idRadix
        idLo=MOD(localParentId(ip),idRadix)
        sendInt(1,ip)=INT(idHi)
        IF ( idLo.GT.2147483647_8 ) THEN
          sendInt(2,ip)=INT(idLo-idRadix)
        ELSE
          sendInt(2,ip)=INT(idLo)
        ENDIF
        sendInt(3,ip)=myProcId
        sendInt(4,ip)=localBi(ip)
        sendInt(5,ip)=localBj(ip)
        sendInt(6,ip)=localSlot(ip)
      ENDDO
      DO rankIndex=1,nPx*nPy
        sendCountI(rankIndex)=metaInts*safeLocal
        recvCountI(rankIndex)=metaInts*rankCount(rankIndex)
        sendDisplI(rankIndex)=0
        recvDisplI(rankIndex)=metaInts*rankDispl(rankIndex)
      ENDDO
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allgatherv(
     I       sendInt,metaInts*safeLocal,MPI_INTEGER,
     O       recvInt,recvCountI,recvDisplI,MPI_INTEGER,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ELSE
#endif
        DO jp=1,safeLocal
         DO ip=1,metaInts
          recvInt(ip,jp)=sendInt(ip,jp)
         ENDDO
        ENDDO
#ifdef ALLOW_USE_MPI
      ENDIF
#endif

      DO packetIndex=1,nGlobal
        idHi=INT(recvInt(1,packetIndex),8)
        idLo=INT(recvInt(2,packetIndex),8)
        IF ( idLo.LT.0_8 ) idLo=idLo+idRadix
        IF ( idHi.LT.0_8 ) THEN
          parentId=0_8
        ELSE
          parentId=idHi*idRadix+idLo
        ENDIF
        sortId(packetIndex)=parentId
        sortIndex(packetIndex)=INT(packetIndex,8)
        packetValid=parentId.GT.0_8 .AND.
     &       recvInt(3,packetIndex).GE.0 .AND.
     &       recvInt(3,packetIndex).LT.nPx*nPy .AND.
     &       recvInt(4,packetIndex).GE.1 .AND.
     &       recvInt(4,packetIndex).LE.nSx .AND.
     &       recvInt(5,packetIndex).GE.1 .AND.
     &       recvInt(5,packetIndex).LE.nSy .AND.
     &       recvInt(6,packetIndex).GE.1 .AND.
     &       recvInt(6,packetIndex).LE.bomMaxPartTile
        IF ( .NOT.packetValid ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       recvInt(3,packetIndex),recvInt(4,packetIndex),
     I       recvInt(5,packetIndex),recvInt(6,packetIndex),parentId,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ENDDO
      DO ip=2,nGlobal
        keyId=sortId(ip)
        keyIndex=sortIndex(ip)
        jp=ip-1
        DO WHILE ( jp.GE.1 )
          IF ( sortId(jp).LE.keyId ) GOTO 110
          sortId(jp+1)=sortId(jp)
          sortIndex(jp+1)=sortIndex(jp)
          jp=jp-1
        ENDDO
  110   CONTINUE
        sortId(jp+1)=keyId
        sortIndex(jp+1)=keyIndex
      ENDDO
      DO ip=2,nGlobal
        IF ( sortId(ip).EQ.sortId(ip-1) )
     &       CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,0,0,0,sortId(ip),
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ENDDO
      DO ip=1,nGlobal
        packetIndex=INT(sortIndex(ip))
        IF ( recvInt(3,packetIndex).EQ.myProcId ) THEN
          DO jp=1,safeLocal
            IF ( localParentId(jp).EQ.sortId(ip) .AND.
     &           localBi(jp).EQ.recvInt(4,packetIndex) .AND.
     &           localBj(jp).EQ.recvInt(5,packetIndex) .AND.
     &           localSlot(jp).EQ.recvInt(6,packetIndex) )
     &           localOrdinal(jp)=ip
          ENDDO
        ENDIF
      ENDDO
      DO ip=1,safeLocal
        IF ( localOrdinal(ip).LT.1 .OR.
     &       localOrdinal(ip).GT.nGlobal )
     &       CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,localBi(ip),localBj(ip),localSlot(ip),
     I       localParentId(ip),
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ENDDO

      CALL BOM_P4_SELECT_FAILURE(
     I     localFailPhase,localFailCode,myProcId,
     I     localFailBi,localFailBj,localFailSlot,localFailId,
     O     p4FailPhase,failCode,failRank,failBi,failBj,failSlot,
     O     failId,isValid,
     I     myThid)
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BIRTH_ACCEPT_ORDER
C !INTERFACE:
      SUBROUTINE BOM_BIRTH_ACCEPT_ORDER(
     I                 nLocal,localParentId,localBirthCount,
     I                 localEventIndex,localAttempt,
     I                 localSourceBi,localSourceBj,localSourceSlot,
     I                 localDestRank,localDestBi,localDestBj,
     I                 localX,localY,nextIdBefore,
     O                 localChildId,nGlobal,
     O                 globalParentId,globalChildId,
     O                 globalBirthCount,globalEventIndex,
     O                 globalAttempt,globalSourceRank,
     O                 globalSourceBi,globalSourceBj,globalSourceSlot,
     O                 globalDestRank,globalDestBi,globalDestBj,
     O                 globalX,globalY,nextIdAfter,
     O                 failCode,p4FailPhase,failRank,
     O                 failBi,failBj,failSlot,failId,isValid,
     I                 myThid )

C !DESCRIPTION:
C     Canonically sort accepted birth-event metadata by exact parent ID and
C     assign contiguous child IDs.  Every rank receives the same bounded
C     accepted-event list; live owner records are never gathered.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nLocal,nGlobal
      INTEGER localBirthCount(bomMaxEventBuffer)
      INTEGER localAttempt(bomMaxEventBuffer)
      INTEGER localSourceBi(bomMaxEventBuffer)
      INTEGER localSourceBj(bomMaxEventBuffer)
      INTEGER localSourceSlot(bomMaxEventBuffer)
      INTEGER localDestRank(bomMaxEventBuffer)
      INTEGER localDestBi(bomMaxEventBuffer)
      INTEGER localDestBj(bomMaxEventBuffer)
      INTEGER globalBirthCount(bomMaxEventBuffer)
      INTEGER globalAttempt(bomMaxEventBuffer)
      INTEGER globalSourceRank(bomMaxEventBuffer)
      INTEGER globalSourceBi(bomMaxEventBuffer)
      INTEGER globalSourceBj(bomMaxEventBuffer)
      INTEGER globalSourceSlot(bomMaxEventBuffer)
      INTEGER globalDestRank(bomMaxEventBuffer)
      INTEGER globalDestBi(bomMaxEventBuffer)
      INTEGER globalDestBj(bomMaxEventBuffer)
      INTEGER failCode,p4FailPhase,failRank,failBi,failBj,failSlot
      INTEGER*8 localParentId(bomMaxEventBuffer)
      INTEGER*8 localEventIndex(bomMaxEventBuffer)
      INTEGER*8 localChildId(bomMaxEventBuffer)
      INTEGER*8 globalParentId(bomMaxEventBuffer)
      INTEGER*8 globalChildId(bomMaxEventBuffer)
      INTEGER*8 globalEventIndex(bomMaxEventBuffer)
      INTEGER*8 nextIdBefore,nextIdAfter,failId
      _RL localX(bomMaxEventBuffer),localY(bomMaxEventBuffer)
      _RL globalX(bomMaxEventBuffer),globalY(bomMaxEventBuffer)
      LOGICAL isValid
      INTEGER myThid

#ifdef ALLOW_BOM
      INTEGER metaInts,metaReals
      PARAMETER ( metaInts=13,metaReals=2 )
      INTEGER safeLocal,ip,jp,rankIndex,totalCount,packetIndex
      INTEGER localFailCode,localFailPhase,localFailBi,localFailBj
      INTEGER localFailSlot,mpiRC
      INTEGER rankCount(nPx*nPy),rankDispl(nPx*nPy)
      INTEGER recvCountI(nPx*nPy),recvDisplI(nPx*nPy)
      INTEGER recvCountR(nPx*nPy),recvDisplR(nPx*nPy)
      INTEGER sendInt(metaInts,bomMaxEventBuffer)
      INTEGER recvInt(metaInts,bomMaxEventBuffer)
      _RL sendReal(metaReals,bomMaxEventBuffer)
      _RL recvReal(metaReals,bomMaxEventBuffer)
      INTEGER*8 sortId(bomMaxEventBuffer)
      INTEGER*8 sortIndex(bomMaxEventBuffer),keyId,keyIndex
      INTEGER*8 idRadix,idHi,idLo,parentId,eventIndex,childId
      INTEGER*8 localFailId
      LOGICAL packetValid
      SAVE sendInt,recvInt,sendReal,recvReal
#endif

      nGlobal=0
      nextIdAfter=nextIdBefore
      failCode=BOM_FAIL_BIRTH_ID
      p4FailPhase=BOM_P4_PHASE_BIRTH_ORDER
      failRank=myProcId
      failBi=0
      failBj=0
      failSlot=0
      failId=0_8
      isValid=.FALSE.
#ifdef ALLOW_BOM
      idRadix=4294967296_8
      localFailCode=BOM_FAIL_NONE
      localFailPhase=BOM_P4_PHASE_NONE
      localFailBi=0
      localFailBj=0
      localFailSlot=0
      localFailId=0_8
      safeLocal=MAX(0,MIN(bomMaxEventBuffer,nLocal))
      IF ( nLocal.NE.safeLocal ) CALL BOM_P4_KEEP_FAILURE(
     I     BOM_P4_PHASE_CAPACITY,BOM_FAIL_EVENT_CAPACITY,
     I     myProcId,0,0,0,0_8,
     U     localFailPhase,localFailCode,localFailBi,localFailBj,
     U     localFailSlot,localFailId)
      DO ip=1,bomMaxEventBuffer
        localChildId(ip)=0_8
        globalParentId(ip)=0_8
        globalChildId(ip)=0_8
        globalBirthCount(ip)=0
        globalEventIndex(ip)=0_8
        globalAttempt(ip)=0
        globalSourceRank(ip)=0
        globalSourceBi(ip)=0
        globalSourceBj(ip)=0
        globalSourceSlot(ip)=0
        globalDestRank(ip)=0
        globalDestBi(ip)=0
        globalDestBj(ip)=0
        globalX(ip)=0. _d 0
        globalY(ip)=0. _d 0
      ENDDO
      DO rankIndex=1,nPx*nPy
        rankCount(rankIndex)=0
        rankDispl(rankIndex)=0
      ENDDO
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allgather(
     I       safeLocal,1,MPI_INTEGER,
     O       rankCount,1,MPI_INTEGER,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ELSE
#endif
        rankCount(1)=safeLocal
#ifdef ALLOW_USE_MPI
      ENDIF
#endif
      totalCount=0
      DO rankIndex=1,nPx*nPy
        rankDispl(rankIndex)=totalCount
        IF ( rankCount(rankIndex).LT.0 .OR.
     &       rankCount(rankIndex).GT.bomMaxEventBuffer-totalCount ) THEN
          CALL BOM_P4_KEEP_FAILURE(
     I         BOM_P4_PHASE_CAPACITY,BOM_FAIL_EVENT_CAPACITY,
     I         myProcId,0,0,0,0_8,
     U         localFailPhase,localFailCode,localFailBi,localFailBj,
     U         localFailSlot,localFailId)
        ELSE
          totalCount=totalCount+rankCount(rankIndex)
        ENDIF
      ENDDO
      IF ( totalCount.GT.bomMaxEventBuffer ) totalCount=0
      nGlobal=totalCount

      DO ip=1,safeLocal
        packetValid=localParentId(ip).GT.0_8 .AND.
     &       localBirthCount(ip).GE.0 .AND.
     &       localEventIndex(ip).EQ.bomEventTimeIndex .AND.
     &       localAttempt(ip).GE.0 .AND.
     &       localAttempt(ip).LT.bomBirthMaxTry .AND.
     &       localSourceBi(ip).GE.1 .AND.
     &       localSourceBi(ip).LE.nSx .AND.
     &       localSourceBj(ip).GE.1 .AND.
     &       localSourceBj(ip).LE.nSy .AND.
     &       localSourceSlot(ip).GE.1 .AND.
     &       localSourceSlot(ip).LE.bomMaxPartTile .AND.
     &       localDestRank(ip).GE.0 .AND.
     &       localDestRank(ip).LT.nPx*nPy .AND.
     &       localDestBi(ip).GE.1 .AND.
     &       localDestBi(ip).LE.nSx .AND.
     &       localDestBj(ip).GE.1 .AND.
     &       localDestBj(ip).LE.nSy .AND.
     &       IEEE_IS_FINITE(localX(ip)) .AND.
     &       IEEE_IS_FINITE(localY(ip))
        IF ( .NOT.packetValid ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,localSourceBi(ip),localSourceBj(ip),
     I       localSourceSlot(ip),localParentId(ip),
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
        idHi=localParentId(ip)/idRadix
        idLo=MOD(localParentId(ip),idRadix)
        sendInt(1,ip)=INT(idHi)
        IF ( idLo.GT.2147483647_8 ) THEN
          sendInt(2,ip)=INT(idLo-idRadix)
        ELSE
          sendInt(2,ip)=INT(idLo)
        ENDIF
        sendInt(3,ip)=localBirthCount(ip)
        idHi=localEventIndex(ip)/idRadix
        idLo=MOD(localEventIndex(ip),idRadix)
        sendInt(4,ip)=INT(idHi)
        IF ( idLo.GT.2147483647_8 ) THEN
          sendInt(5,ip)=INT(idLo-idRadix)
        ELSE
          sendInt(5,ip)=INT(idLo)
        ENDIF
        sendInt(6,ip)=localAttempt(ip)
        sendInt(7,ip)=myProcId
        sendInt(8,ip)=localSourceBi(ip)
        sendInt(9,ip)=localSourceBj(ip)
        sendInt(10,ip)=localSourceSlot(ip)
        sendInt(11,ip)=localDestRank(ip)
        sendInt(12,ip)=localDestBi(ip)
        sendInt(13,ip)=localDestBj(ip)
        sendReal(1,ip)=localX(ip)
        sendReal(2,ip)=localY(ip)
      ENDDO
      DO rankIndex=1,nPx*nPy
        recvCountI(rankIndex)=metaInts*rankCount(rankIndex)
        recvDisplI(rankIndex)=metaInts*rankDispl(rankIndex)
        recvCountR(rankIndex)=metaReals*rankCount(rankIndex)
        recvDisplR(rankIndex)=metaReals*rankDispl(rankIndex)
      ENDDO
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allgatherv(
     I       sendInt,metaInts*safeLocal,MPI_INTEGER,
     O       recvInt,recvCountI,recvDisplI,MPI_INTEGER,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
        CALL MPI_Allgatherv(
     I       sendReal,metaReals*safeLocal,_MPI_TYPE_RL,
     O       recvReal,recvCountR,recvDisplR,_MPI_TYPE_RL,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,0,0,0,0_8,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ELSE
#endif
        DO jp=1,safeLocal
         DO ip=1,metaInts
          recvInt(ip,jp)=sendInt(ip,jp)
         ENDDO
        ENDDO
        DO jp=1,safeLocal
         DO ip=1,metaReals
          recvReal(ip,jp)=sendReal(ip,jp)
         ENDDO
        ENDDO
#ifdef ALLOW_USE_MPI
      ENDIF
#endif

      DO packetIndex=1,nGlobal
        idHi=INT(recvInt(1,packetIndex),8)
        idLo=INT(recvInt(2,packetIndex),8)
        IF ( idLo.LT.0_8 ) idLo=idLo+idRadix
        IF ( idHi.LT.0_8 ) THEN
          parentId=0_8
        ELSE
          parentId=idHi*idRadix+idLo
        ENDIF
        idHi=INT(recvInt(4,packetIndex),8)
        idLo=INT(recvInt(5,packetIndex),8)
        IF ( idLo.LT.0_8 ) idLo=idLo+idRadix
        IF ( idHi.LT.0_8 ) THEN
          eventIndex=-1_8
        ELSE
          eventIndex=idHi*idRadix+idLo
        ENDIF
        sortId(packetIndex)=parentId
        sortIndex(packetIndex)=INT(packetIndex,8)
        packetValid=parentId.GT.0_8 .AND.
     &       recvInt(3,packetIndex).GE.0 .AND.
     &       eventIndex.EQ.bomEventTimeIndex .AND.
     &       recvInt(6,packetIndex).GE.0 .AND.
     &       recvInt(6,packetIndex).LT.bomBirthMaxTry .AND.
     &       recvInt(7,packetIndex).GE.0 .AND.
     &       recvInt(7,packetIndex).LT.nPx*nPy .AND.
     &       recvInt(8,packetIndex).GE.1 .AND.
     &       recvInt(8,packetIndex).LE.nSx .AND.
     &       recvInt(9,packetIndex).GE.1 .AND.
     &       recvInt(9,packetIndex).LE.nSy .AND.
     &       recvInt(10,packetIndex).GE.1 .AND.
     &       recvInt(10,packetIndex).LE.bomMaxPartTile .AND.
     &       recvInt(11,packetIndex).GE.0 .AND.
     &       recvInt(11,packetIndex).LT.nPx*nPy .AND.
     &       recvInt(12,packetIndex).GE.1 .AND.
     &       recvInt(12,packetIndex).LE.nSx .AND.
     &       recvInt(13,packetIndex).GE.1 .AND.
     &       recvInt(13,packetIndex).LE.nSy .AND.
     &       IEEE_IS_FINITE(recvReal(1,packetIndex)) .AND.
     &       IEEE_IS_FINITE(recvReal(2,packetIndex))
        IF ( .NOT.packetValid ) CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       recvInt(7,packetIndex),recvInt(8,packetIndex),
     I       recvInt(9,packetIndex),recvInt(10,packetIndex),parentId,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ENDDO
      DO ip=2,nGlobal
        keyId=sortId(ip)
        keyIndex=sortIndex(ip)
        jp=ip-1
        DO WHILE ( jp.GE.1 )
          IF ( sortId(jp).LE.keyId ) GOTO 210
          sortId(jp+1)=sortId(jp)
          sortIndex(jp+1)=sortIndex(jp)
          jp=jp-1
        ENDDO
  210   CONTINUE
        sortId(jp+1)=keyId
        sortIndex(jp+1)=keyIndex
      ENDDO
      DO ip=2,nGlobal
        IF ( sortId(ip).EQ.sortId(ip-1) )
     &       CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,0,0,0,sortId(ip),
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ENDDO
      IF ( nextIdBefore.LE.0_8 .OR.
     &     INT(nGlobal,8).GT.HUGE(nextIdBefore)-nextIdBefore )
     &     CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,0,0,0,nextIdBefore,
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)

      IF ( localFailCode.EQ.BOM_FAIL_NONE ) THEN
        nextIdAfter=nextIdBefore+INT(nGlobal,8)
        DO ip=1,nGlobal
          packetIndex=INT(sortIndex(ip))
          childId=nextIdBefore+INT(ip-1,8)
          globalParentId(ip)=sortId(ip)
          globalChildId(ip)=childId
          globalBirthCount(ip)=recvInt(3,packetIndex)
          idHi=INT(recvInt(4,packetIndex),8)
          idLo=INT(recvInt(5,packetIndex),8)
          IF ( idLo.LT.0_8 ) idLo=idLo+idRadix
          globalEventIndex(ip)=idHi*idRadix+idLo
          globalAttempt(ip)=recvInt(6,packetIndex)
          globalSourceRank(ip)=recvInt(7,packetIndex)
          globalSourceBi(ip)=recvInt(8,packetIndex)
          globalSourceBj(ip)=recvInt(9,packetIndex)
          globalSourceSlot(ip)=recvInt(10,packetIndex)
          globalDestRank(ip)=recvInt(11,packetIndex)
          globalDestBi(ip)=recvInt(12,packetIndex)
          globalDestBj(ip)=recvInt(13,packetIndex)
          globalX(ip)=recvReal(1,packetIndex)
          globalY(ip)=recvReal(2,packetIndex)
          IF ( globalSourceRank(ip).EQ.myProcId ) THEN
            DO jp=1,safeLocal
              IF ( localParentId(jp).EQ.sortId(ip) .AND.
     &             localSourceBi(jp).EQ.globalSourceBi(ip) .AND.
     &             localSourceBj(jp).EQ.globalSourceBj(ip) .AND.
     &             localSourceSlot(jp).EQ.globalSourceSlot(ip) )
     &             localChildId(jp)=childId
            ENDDO
          ENDIF
        ENDDO
      ENDIF
      DO ip=1,safeLocal
        IF ( localChildId(ip).LT.nextIdBefore .OR.
     &       localChildId(ip).GE.nextIdAfter )
     &       CALL BOM_P4_KEEP_FAILURE(
     I       BOM_P4_PHASE_BIRTH_ORDER,BOM_FAIL_BIRTH_ID,
     I       myProcId,localSourceBi(ip),localSourceBj(ip),
     I       localSourceSlot(ip),localParentId(ip),
     U       localFailPhase,localFailCode,localFailBi,localFailBj,
     U       localFailSlot,localFailId)
      ENDDO

      CALL BOM_P4_SELECT_FAILURE(
     I     localFailPhase,localFailCode,myProcId,
     I     localFailBi,localFailBj,localFailSlot,localFailId,
     O     p4FailPhase,failCode,failRank,failBi,failBj,failSlot,
     O     failId,isValid,
     I     myThid)
#endif
      RETURN
      END
