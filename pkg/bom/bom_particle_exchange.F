#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_PARTICLE_EXCHANGE

C !INTERFACE:
      SUBROUTINE BOM_PARTICLE_EXCHANGE(
     I                 exchangeTime, exchangeIter, exchangeSubstep,
     I                 myThid )

C !DESCRIPTION:
C     Complete the owner transaction after one nominal substep.
C     Cross-rank records use exact two-word IDs and a minimal real packet.
C     No owner array is replaced until global plan, capacity, packet, and
C     target-owner refresh checks have all succeeded.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL exchangeTime
      INTEGER exchangeIter, exchangeSubstep, myThid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, ip, jp, slot, rankIndex, packetIndex, iDiag
      INTEGER localErrCount, globalErrCount
      INTEGER localMoveCount, globalMoveCount
      INTEGER localRemoteCount, globalRemoteCount
      INTEGER sendTotal, recvTotal, rhsFailCode
#ifdef ALLOW_USE_MPI
      INTEGER mpiRC
#endif
      INTEGER targetCount(nSx,nSy)
      INTEGER planRank(bomMaxPartTile,nSx,nSy)
      INTEGER planBi(bomMaxPartTile,nSx,nSy)
      INTEGER planBj(bomMaxPartTile,nSx,nSy)
      INTEGER planHop(bomMaxPartTile,nSx,nSy)
      _RL planX(bomMaxPartTile,nSx,nSy)
      _RL planY(bomMaxPartTile,nSx,nSy)
      INTEGER sendCounts(nPx*nPy), recvCounts(nPx*nPy)
      INTEGER sendDispls(nPx*nPy), recvDispls(nPx*nPy)
      INTEGER sendCountsI(nPx*nPy), recvCountsI(nPx*nPy)
      INTEGER sendDisplsI(nPx*nPy), recvDisplsI(nPx*nPy)
      INTEGER sendCountsR(nPx*nPy), recvCountsR(nPx*nPy)
      INTEGER sendDisplsR(nPx*nPy), recvDisplsR(nPx*nPy)
      INTEGER packetCursor(nPx*nPy)
      INTEGER sendInt(bomPacketInts,bomMaxExchange)
      INTEGER recvInt(bomPacketInts,bomMaxExchange)
      _RL sendReal(bomPacketReals,bomMaxExchange)
      _RL recvReal(bomPacketReals,bomMaxExchange)
      INTEGER workCount(nSx,nSy)
      INTEGER workStatus(bomMaxPartTile,nSx,nSy)
      INTEGER workNeighbor(bomMaxPartTile,nSx,nSy)
      INTEGER workRaftSize(bomMaxPartTile,nSx,nSy)
      INTEGER*8 workId(bomMaxPartTile,nSx,nSy)
      INTEGER*8 workRaftId(bomMaxPartTile,nSx,nSy)
      _RL workX(bomMaxPartTile,nSx,nSy)
      _RL workY(bomMaxPartTile,nSx,nSy)
      _RL workRelease(bomMaxPartTile,nSx,nSy)
      _RL workAge(bomMaxPartTile,nSx,nSy)
      _RL workI(bomMaxPartTile,nSx,nSy)
      _RL workJ(bomMaxPartTile,nSx,nSy)
      _RL workVEast(bomMaxPartTile,nSx,nSy)
      _RL workVNorth(bomMaxPartTile,nSx,nSy)
      _RL workWindEast(bomMaxPartTile,nSx,nSy)
      _RL workWindNorth(bomMaxPartTile,nSx,nSy)
      _RL workDriftEast(bomMaxPartTile,nSx,nSy)
      _RL workDriftNorth(bomMaxPartTile,nSx,nSy)
      _RL workSpringEast(bomMaxPartTile,nSx,nSy)
      _RL workSpringNorth(bomMaxPartTile,nSx,nSy)
      _RL workRhsDiag(
     &     BOM_RHS_NDIAG,bomMaxPartTile,nSx,nSy)
      LOGICAL workRefresh(bomMaxPartTile,nSx,nSy)
      INTEGER*8 idRadix, idHi8, idLo8, recvId, keyId
      INTEGER*8 raftHi8, raftLo8, recvRaftId, keyRaftId
      INTEGER keyStatus, keyNeighbor, keyRaftSize
      _RL keyX, keyY, keyRelease, keyAge, keyI, keyJ
      _RL keyVEast, keyVNorth, keyWindEast, keyWindNorth
      _RL keyDriftEast, keyDriftNorth
      _RL keySpringEast, keySpringNorth
      _RL keyRhsDiag(BOM_RHS_NDIAG)
      LOGICAL keyRefresh, locateValid, rhsOwner, rhsValid
      LOGICAL springEastValid, springNorthValid
      _RL rhsX, rhsY, wetWeight, stageCFL
      INTEGER rhsFailStage

C--   Non-zero Phase-1 state rejects threading; explicit SAVE makes the
C     bounded packet storage lifetime independent of compiler stack limits.
      SAVE sendInt, recvInt, sendReal, recvReal
#endif

#ifdef ALLOW_BOM
      idRadix = 4294967296_8
      localErrCount = 0
      localMoveCount = 0
      localRemoteCount = 0

      DO rankIndex=1,nPx*nPy
        sendCounts(rankIndex) = 0
        recvCounts(rankIndex) = 0
        sendDispls(rankIndex) = 0
        recvDispls(rankIndex) = 0
        packetCursor(rankIndex) = 0
      ENDDO

C--   Plan every destination without changing compact owner state.
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          CALL BOM_LOCATE_OWNER(
     I         bomX(ip,bi,bj), bomY(ip,bi,bj), bi, bj,
     O         planX(ip,bi,bj), planY(ip,bi,bj),
     O         planRank(ip,bi,bj),
     O         planBi(ip,bi,bj), planBj(ip,bi,bj),
     O         planHop(ip,bi,bj), locateValid,
     I         myThid )
          IF ( .NOT.locateValid ) THEN
            IF ( localErrCount.LT.8 ) THEN
              WRITE(msgBuf,1000)
     &             'BOM_PARTICLE_EXCHANGE: invalid owner id=',
     &             bomId(ip,bi,bj), ' rank/source=',
     &             myProcId, bi, bj, ' iter/sub=',
     &             exchangeIter, exchangeSubstep,
     &             ' time=', exchangeTime
              CALL PRINT_ERROR( msgBuf, myThid )
            ENDIF
            localErrCount = localErrCount + 1
          ELSEIF ( planHop(ip,bi,bj).GT.bomMaxHop ) THEN
            IF ( localErrCount.LT.8 ) THEN
              WRITE(msgBuf,1001)
     &             'BOM_PARTICLE_EXCHANGE: hop limit id=',
     &             bomId(ip,bi,bj), ' rank/source=',
     &             myProcId, bi, bj, ' target/hop/limit=',
     &             planRank(ip,bi,bj), planBi(ip,bi,bj),
     &             planBj(ip,bi,bj), planHop(ip,bi,bj),
     &             bomMaxHop
              CALL PRINT_ERROR( msgBuf, myThid )
            ENDIF
            localErrCount = localErrCount + 1
          ELSE
            IF ( planRank(ip,bi,bj).NE.myProcId .OR.
     &           planBi(ip,bi,bj).NE.bi .OR.
     &           planBj(ip,bi,bj).NE.bj .OR.
     &           planX(ip,bi,bj).NE.bomX(ip,bi,bj) .OR.
     &           planY(ip,bi,bj).NE.bomY(ip,bi,bj) ) THEN
              localMoveCount = localMoveCount + 1
            ENDIF
            IF ( planRank(ip,bi,bj).NE.myProcId ) THEN
              localRemoteCount = localRemoteCount + 1
              rankIndex = planRank(ip,bi,bj) + 1
              IF ( rankIndex.GE.1 .AND.
     &             rankIndex.LE.nPx*nPy ) THEN
                sendCounts(rankIndex) = sendCounts(rankIndex) + 1
              ELSE
                localErrCount = localErrCount + 1
              ENDIF
            ENDIF
          ENDIF
        ENDDO
       ENDDO
      ENDDO

      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I10,A,2I12,A,1PE24.16)')
     &         'BOM_PARTICLE_EXCHANGE: fatal owner/hop errors=',
     &         globalErrCount, ' iter/sub=',
     &         exchangeIter, exchangeSubstep, ' time=', exchangeTime
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_PARTICLE_EXCHANGE'
      ENDIF

      globalMoveCount = localMoveCount
      CALL GLOBAL_SUM_INT( globalMoveCount, myThid )
      IF ( globalMoveCount.EQ.0 ) RETURN

C--   Count exchange precedes packet allocation and authoritative writes.
      globalRemoteCount = localRemoteCount
      CALL GLOBAL_SUM_INT( globalRemoteCount, myThid )
#ifdef ALLOW_USE_MPI
      IF ( globalRemoteCount.GT.0 .AND. usingMPI ) THEN
        CALL MPI_Alltoall(
     I       sendCounts, 1, MPI_INTEGER,
     O       recvCounts, 1, MPI_INTEGER,
     I       MPI_COMM_MODEL, mpiRC )
        IF ( mpiRC.NE.MPI_SUCCESS ) localErrCount=localErrCount+1
      ELSEIF ( globalRemoteCount.GT.0 ) THEN
        localErrCount = localErrCount + 1
      ENDIF
#else
      IF ( globalRemoteCount.GT.0 ) localErrCount=localErrCount+1
#endif

      sendTotal = 0
      recvTotal = 0
      DO rankIndex=1,nPx*nPy
        IF ( sendCounts(rankIndex).LT.0 .OR.
     &       recvCounts(rankIndex).LT.0 ) THEN
          localErrCount = localErrCount + 1
        ENDIF
        sendDispls(rankIndex) = sendTotal
        recvDispls(rankIndex) = recvTotal
        sendTotal = sendTotal + sendCounts(rankIndex)
        recvTotal = recvTotal + recvCounts(rankIndex)
      ENDDO
      IF ( sendTotal.GT.bomMaxExchange ) THEN
        WRITE(msgBuf,1002)
     &       'BOM_PARTICLE_EXCHANGE: rank/direction=',
     &       myProcId, 'SEND', ' needed/limit=',
     &       sendTotal, bomMaxExchange
        CALL PRINT_ERROR( msgBuf, myThid )
        localErrCount = localErrCount + 1
      ENDIF
      IF ( recvTotal.GT.bomMaxExchange ) THEN
        WRITE(msgBuf,1002)
     &       'BOM_PARTICLE_EXCHANGE: rank/direction=',
     &       myProcId, 'RECV', ' needed/limit=',
     &       recvTotal, bomMaxExchange
        CALL PRINT_ERROR( msgBuf, myThid )
        localErrCount = localErrCount + 1
      ENDIF
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I10,A,2I12)')
     &         'BOM_PARTICLE_EXCHANGE: fatal count/capacity errors=',
     &         globalErrCount, ' iter/sub=',
     &         exchangeIter, exchangeSubstep
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_PARTICLE_EXCHANGE'
      ENDIF

C--   Pack remote migrants in destination-rank order.
      DO rankIndex=1,nPx*nPy
        packetCursor(rankIndex) = sendDispls(rankIndex)
      ENDDO
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          IF ( planRank(ip,bi,bj).NE.myProcId ) THEN
            rankIndex = planRank(ip,bi,bj) + 1
            packetIndex = packetCursor(rankIndex) + 1
            packetCursor(rankIndex) = packetIndex
            idHi8 = bomId(ip,bi,bj)/idRadix
            idLo8 = MOD(bomId(ip,bi,bj),idRadix)
            sendInt(1,packetIndex) = bomPacketSchema
            sendInt(2,packetIndex) = INT(idHi8)
            IF ( idLo8.GT.2147483647_8 ) THEN
              sendInt(3,packetIndex) = INT(idLo8-idRadix)
            ELSE
              sendInt(3,packetIndex) = INT(idLo8)
            ENDIF
            sendInt(4,packetIndex) = bomStatus(ip,bi,bj)
            sendInt(5,packetIndex) = planBi(ip,bi,bj)
            sendInt(6,packetIndex) = planBj(ip,bi,bj)
            sendInt(7,packetIndex) =
     &           bomNeighborCount(ip,bi,bj)
            raftHi8 = bomRaftId(ip,bi,bj)/idRadix
            raftLo8 = MOD(bomRaftId(ip,bi,bj),idRadix)
            sendInt(8,packetIndex) = INT(raftHi8)
            IF ( raftLo8.GT.2147483647_8 ) THEN
              sendInt(9,packetIndex) = INT(raftLo8-idRadix)
            ELSE
              sendInt(9,packetIndex) = INT(raftLo8)
            ENDIF
            sendInt(10,packetIndex) = bomRaftSize(ip,bi,bj)
            sendReal(1,packetIndex) = planX(ip,bi,bj)
            sendReal(2,packetIndex) = planY(ip,bi,bj)
            sendReal(3,packetIndex) = bomReleaseTime(ip,bi,bj)
            sendReal(4,packetIndex) = bomAge(ip,bi,bj)
            sendReal(5,packetIndex) = bomSpringEast(ip,bi,bj)
            sendReal(6,packetIndex) = bomSpringNorth(ip,bi,bj)
          ENDIF
        ENDDO
       ENDDO
      ENDDO

      DO rankIndex=1,nPx*nPy
        sendCountsI(rankIndex) = bomPacketInts*sendCounts(rankIndex)
        recvCountsI(rankIndex) = bomPacketInts*recvCounts(rankIndex)
        sendDisplsI(rankIndex) = bomPacketInts*sendDispls(rankIndex)
        recvDisplsI(rankIndex) = bomPacketInts*recvDispls(rankIndex)
        sendCountsR(rankIndex) = bomPacketReals*sendCounts(rankIndex)
        recvCountsR(rankIndex) = bomPacketReals*recvCounts(rankIndex)
        sendDisplsR(rankIndex) = bomPacketReals*sendDispls(rankIndex)
        recvDisplsR(rankIndex) = bomPacketReals*recvDispls(rankIndex)
      ENDDO

#ifdef ALLOW_USE_MPI
      IF ( globalRemoteCount.GT.0 .AND. usingMPI ) THEN
        CALL MPI_Alltoallv(
     I       sendInt, sendCountsI, sendDisplsI, MPI_INTEGER,
     O       recvInt, recvCountsI, recvDisplsI, MPI_INTEGER,
     I       MPI_COMM_MODEL, mpiRC )
        IF ( mpiRC.NE.MPI_SUCCESS ) localErrCount=localErrCount+1
        CALL MPI_Alltoallv(
     I       sendReal, sendCountsR, sendDisplsR, _MPI_TYPE_RL,
     O       recvReal, recvCountsR, recvDisplsR, _MPI_TYPE_RL,
     I       MPI_COMM_MODEL, mpiRC )
        IF ( mpiRC.NE.MPI_SUCCESS ) localErrCount=localErrCount+1
      ENDIF
#endif
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I10,A,2I12)')
     &         'BOM_PARTICLE_EXCHANGE: fatal MPI packet errors=',
     &         globalErrCount, ' iter/sub=',
     &         exchangeIter, exchangeSubstep
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_PARTICLE_EXCHANGE'
      ENDIF

C--   Validate packet metadata and final per-tile capacity before commit.
      DO bj=1,nSy
       DO bi=1,nSx
        targetCount(bi,bj) = 0
       ENDDO
      ENDDO
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          IF ( planRank(ip,bi,bj).EQ.myProcId ) THEN
            targetCount(planBi(ip,bi,bj),planBj(ip,bi,bj)) =
     &      targetCount(planBi(ip,bi,bj),planBj(ip,bi,bj)) + 1
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      DO packetIndex=1,recvTotal
        bi = recvInt(5,packetIndex)
        bj = recvInt(6,packetIndex)
        IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &       bj.LT.1 .OR. bj.GT.nSy ) THEN
          localErrCount = localErrCount + 1
        ELSE
          targetCount(bi,bj) = targetCount(bi,bj) + 1
        ENDIF
        IF ( recvInt(1,packetIndex).NE.bomPacketSchema )
     &       localErrCount = localErrCount+1
        idHi8 = INT(recvInt(2,packetIndex),8)
        idLo8 = INT(recvInt(3,packetIndex),8)
        IF ( idLo8.LT.0_8 ) idLo8 = idLo8 + idRadix
        IF ( idHi8.LT.0_8 ) THEN
          localErrCount = localErrCount + 1
          recvId = 0_8
        ELSE
          recvId = idHi8*idRadix + idLo8
          IF ( recvId.LE.0_8 ) localErrCount=localErrCount+1
        ENDIF
        IF ( recvInt(4,packetIndex).NE.BOM_ALIVE .AND.
     &       recvInt(4,packetIndex).NE.BOM_WAITING )
     &       localErrCount = localErrCount + 1
        IF ( recvInt(7,packetIndex).LT.0 .OR.
     &       recvInt(7,packetIndex).GT.bomMaxNeighbor )
     &       localErrCount = localErrCount+1
        raftHi8 = INT(recvInt(8,packetIndex),8)
        raftLo8 = INT(recvInt(9,packetIndex),8)
        IF ( raftLo8.LT.0_8 ) raftLo8=raftLo8+idRadix
        IF ( raftHi8.LT.0_8 ) THEN
          recvRaftId = 0_8
          localErrCount = localErrCount+1
        ELSE
          recvRaftId = raftHi8*idRadix+raftLo8
        ENDIF
        IF ( (recvRaftId.EQ.0_8 .AND.
     &        recvInt(10,packetIndex).NE.0) .OR.
     &       (recvRaftId.GT.0_8 .AND.
     &        recvInt(10,packetIndex).LT.1) )
     &       localErrCount = localErrCount+1
        IF ( .NOT.IEEE_IS_FINITE(recvReal(1,packetIndex)) .OR.
     &       .NOT.IEEE_IS_FINITE(recvReal(2,packetIndex)) .OR.
     &       .NOT.IEEE_IS_FINITE(recvReal(3,packetIndex)) .OR.
     &       .NOT.IEEE_IS_FINITE(recvReal(4,packetIndex)) .OR.
     &       .NOT.IEEE_IS_FINITE(recvReal(5,packetIndex)) .OR.
     &       .NOT.IEEE_IS_FINITE(recvReal(6,packetIndex)) .OR.
     &       recvReal(3,packetIndex).LT.0. _d 0 .OR.
     &       recvReal(4,packetIndex).LT.0. _d 0 )
     &       localErrCount = localErrCount + 1
        IF ( bi.GE.1 .AND. bi.LE.nSx .AND.
     &       bj.GE.1 .AND. bj.LE.nSy ) THEN
          CALL BOM_LOCATE_OWNER(
     I         recvReal(1,packetIndex), recvReal(2,packetIndex),
     I         bi, bj,
     O         keyX, keyY, rankIndex, ip, jp, slot, locateValid,
     I         myThid )
          IF ( .NOT.locateValid .OR. rankIndex.NE.myProcId .OR.
     &         ip.NE.bi .OR. jp.NE.bj .OR. slot.NE.0 .OR.
     &         keyX.NE.recvReal(1,packetIndex) .OR.
     &         keyY.NE.recvReal(2,packetIndex) )
     &         localErrCount = localErrCount + 1
        ENDIF
      ENDDO
      DO bj=1,nSy
       DO bi=1,nSx
        IF ( targetCount(bi,bj).GT.bomMaxPartTile ) THEN
          WRITE(msgBuf,1003)
     &         'BOM_PARTICLE_EXCHANGE: rank/tile=',
     &         myProcId, bi, bj, ' needed/limit=',
     &         targetCount(bi,bj), bomMaxPartTile
          CALL PRINT_ERROR( msgBuf, myThid )
          localErrCount = localErrCount + 1
        ENDIF
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I10,A,2I12)')
     &         'BOM_PARTICLE_EXCHANGE: fatal packet/tile errors=',
     &         globalErrCount, ' iter/sub=',
     &         exchangeIter, exchangeSubstep
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_PARTICLE_EXCHANGE'
      ENDIF

C--   Build scratch owner arrays.  Retained records preserve diagnostics.
      DO bj=1,nSy
       DO bi=1,nSx
        workCount(bi,bj) = 0
        DO ip=1,bomMaxPartTile
          workId(ip,bi,bj) = 0_8
          workStatus(ip,bi,bj) = BOM_UNUSED
          workX(ip,bi,bj) = 0. _d 0
          workY(ip,bi,bj) = 0. _d 0
          workRelease(ip,bi,bj) = 0. _d 0
          workAge(ip,bi,bj) = 0. _d 0
          workI(ip,bi,bj) = 0. _d 0
          workJ(ip,bi,bj) = 0. _d 0
          workVEast(ip,bi,bj) = 0. _d 0
          workVNorth(ip,bi,bj) = 0. _d 0
          workWindEast(ip,bi,bj) = 0. _d 0
          workWindNorth(ip,bi,bj) = 0. _d 0
          workDriftEast(ip,bi,bj) = 0. _d 0
          workDriftNorth(ip,bi,bj) = 0. _d 0
          workSpringEast(ip,bi,bj) = 0. _d 0
          workSpringNorth(ip,bi,bj) = 0. _d 0
          workNeighbor(ip,bi,bj) = 0
          workRaftId(ip,bi,bj) = 0_8
          workRaftSize(ip,bi,bj) = 0
          DO iDiag=1,BOM_RHS_NDIAG
            workRhsDiag(iDiag,ip,bi,bj) = 0. _d 0
          ENDDO
          workRefresh(ip,bi,bj) = .FALSE.
        ENDDO
       ENDDO
      ENDDO

      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          IF ( planRank(ip,bi,bj).EQ.myProcId ) THEN
            jp = planBi(ip,bi,bj)
            slot = planBj(ip,bi,bj)
            workCount(jp,slot) = workCount(jp,slot) + 1
            rankIndex = workCount(jp,slot)
            workId(rankIndex,jp,slot) = bomId(ip,bi,bj)
            workStatus(rankIndex,jp,slot) = bomStatus(ip,bi,bj)
            workX(rankIndex,jp,slot) = planX(ip,bi,bj)
            workY(rankIndex,jp,slot) = planY(ip,bi,bj)
            workRelease(rankIndex,jp,slot) =
     &           bomReleaseTime(ip,bi,bj)
            workAge(rankIndex,jp,slot) = bomAge(ip,bi,bj)
            workI(rankIndex,jp,slot) = bomI(ip,bi,bj)
            workJ(rankIndex,jp,slot) = bomJ(ip,bi,bj)
            workVEast(rankIndex,jp,slot) = bomVEast(ip,bi,bj)
            workVNorth(rankIndex,jp,slot) = bomVNorth(ip,bi,bj)
            workWindEast(rankIndex,jp,slot) =
     &           bomWindEast(ip,bi,bj)
            workWindNorth(rankIndex,jp,slot) =
     &           bomWindNorth(ip,bi,bj)
            workDriftEast(rankIndex,jp,slot) =
     &           bomDriftEast(ip,bi,bj)
            workDriftNorth(rankIndex,jp,slot) =
     &           bomDriftNorth(ip,bi,bj)
            workSpringEast(rankIndex,jp,slot) =
     &           bomSpringEast(ip,bi,bj)
            workSpringNorth(rankIndex,jp,slot) =
     &           bomSpringNorth(ip,bi,bj)
            workNeighbor(rankIndex,jp,slot) =
     &           bomNeighborCount(ip,bi,bj)
            workRaftId(rankIndex,jp,slot) = bomRaftId(ip,bi,bj)
            workRaftSize(rankIndex,jp,slot) =
     &           bomRaftSize(ip,bi,bj)
            DO iDiag=1,BOM_RHS_NDIAG
              workRhsDiag(iDiag,rankIndex,jp,slot) =
     &             bomRhsDiag(iDiag,ip,bi,bj)
            ENDDO
            workRefresh(rankIndex,jp,slot) =
     &           jp.NE.bi .OR. slot.NE.bj .OR.
     &           planX(ip,bi,bj).NE.bomX(ip,bi,bj) .OR.
     &           planY(ip,bi,bj).NE.bomY(ip,bi,bj)
          ENDIF
        ENDDO
       ENDDO
      ENDDO

      DO packetIndex=1,recvTotal
        bi = recvInt(5,packetIndex)
        bj = recvInt(6,packetIndex)
        workCount(bi,bj) = workCount(bi,bj) + 1
        slot = workCount(bi,bj)
        idHi8 = INT(recvInt(2,packetIndex),8)
        idLo8 = INT(recvInt(3,packetIndex),8)
        IF ( idLo8.LT.0_8 ) idLo8 = idLo8 + idRadix
        workId(slot,bi,bj) = idHi8*idRadix + idLo8
        workStatus(slot,bi,bj) = recvInt(4,packetIndex)
        workX(slot,bi,bj) = recvReal(1,packetIndex)
        workY(slot,bi,bj) = recvReal(2,packetIndex)
        workRelease(slot,bi,bj) = recvReal(3,packetIndex)
        workAge(slot,bi,bj) = recvReal(4,packetIndex)
        workSpringEast(slot,bi,bj) = recvReal(5,packetIndex)
        workSpringNorth(slot,bi,bj) = recvReal(6,packetIndex)
        workNeighbor(slot,bi,bj) = recvInt(7,packetIndex)
        raftHi8 = INT(recvInt(8,packetIndex),8)
        raftLo8 = INT(recvInt(9,packetIndex),8)
        IF ( raftLo8.LT.0_8 ) raftLo8=raftLo8+idRadix
        workRaftId(slot,bi,bj) = raftHi8*idRadix+raftLo8
        workRaftSize(slot,bi,bj) = recvInt(10,packetIndex)
        workRefresh(slot,bi,bj) = .TRUE.
      ENDDO

C--   Deterministic insertion sort by full positive INTEGER*8 ID.
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=2,workCount(bi,bj)
          keyId = workId(ip,bi,bj)
          keyStatus = workStatus(ip,bi,bj)
          keyX = workX(ip,bi,bj)
          keyY = workY(ip,bi,bj)
          keyRelease = workRelease(ip,bi,bj)
          keyAge = workAge(ip,bi,bj)
          keyI = workI(ip,bi,bj)
          keyJ = workJ(ip,bi,bj)
          keyVEast = workVEast(ip,bi,bj)
          keyVNorth = workVNorth(ip,bi,bj)
          keyWindEast = workWindEast(ip,bi,bj)
          keyWindNorth = workWindNorth(ip,bi,bj)
          keyDriftEast = workDriftEast(ip,bi,bj)
          keyDriftNorth = workDriftNorth(ip,bi,bj)
          keySpringEast = workSpringEast(ip,bi,bj)
          keySpringNorth = workSpringNorth(ip,bi,bj)
          keyNeighbor = workNeighbor(ip,bi,bj)
          keyRaftId = workRaftId(ip,bi,bj)
          keyRaftSize = workRaftSize(ip,bi,bj)
          DO iDiag=1,BOM_RHS_NDIAG
            keyRhsDiag(iDiag) = workRhsDiag(iDiag,ip,bi,bj)
          ENDDO
          keyRefresh = workRefresh(ip,bi,bj)
          jp = ip - 1
          DO WHILE ( jp.GE.1 )
            IF ( workId(jp,bi,bj).LE.keyId ) GOTO 110
            workId(jp+1,bi,bj) = workId(jp,bi,bj)
            workStatus(jp+1,bi,bj) = workStatus(jp,bi,bj)
            workX(jp+1,bi,bj) = workX(jp,bi,bj)
            workY(jp+1,bi,bj) = workY(jp,bi,bj)
            workRelease(jp+1,bi,bj) = workRelease(jp,bi,bj)
            workAge(jp+1,bi,bj) = workAge(jp,bi,bj)
            workI(jp+1,bi,bj) = workI(jp,bi,bj)
            workJ(jp+1,bi,bj) = workJ(jp,bi,bj)
            workVEast(jp+1,bi,bj) = workVEast(jp,bi,bj)
            workVNorth(jp+1,bi,bj) = workVNorth(jp,bi,bj)
            workWindEast(jp+1,bi,bj) = workWindEast(jp,bi,bj)
            workWindNorth(jp+1,bi,bj) = workWindNorth(jp,bi,bj)
            workDriftEast(jp+1,bi,bj) = workDriftEast(jp,bi,bj)
            workDriftNorth(jp+1,bi,bj) = workDriftNorth(jp,bi,bj)
            workSpringEast(jp+1,bi,bj) =
     &           workSpringEast(jp,bi,bj)
            workSpringNorth(jp+1,bi,bj) =
     &           workSpringNorth(jp,bi,bj)
            workNeighbor(jp+1,bi,bj) = workNeighbor(jp,bi,bj)
            workRaftId(jp+1,bi,bj) = workRaftId(jp,bi,bj)
            workRaftSize(jp+1,bi,bj) = workRaftSize(jp,bi,bj)
            DO iDiag=1,BOM_RHS_NDIAG
              workRhsDiag(iDiag,jp+1,bi,bj) =
     &             workRhsDiag(iDiag,jp,bi,bj)
            ENDDO
            workRefresh(jp+1,bi,bj) = workRefresh(jp,bi,bj)
            jp = jp - 1
          ENDDO
  110     CONTINUE
          workId(jp+1,bi,bj) = keyId
          workStatus(jp+1,bi,bj) = keyStatus
          workX(jp+1,bi,bj) = keyX
          workY(jp+1,bi,bj) = keyY
          workRelease(jp+1,bi,bj) = keyRelease
          workAge(jp+1,bi,bj) = keyAge
          workI(jp+1,bi,bj) = keyI
          workJ(jp+1,bi,bj) = keyJ
          workVEast(jp+1,bi,bj) = keyVEast
          workVNorth(jp+1,bi,bj) = keyVNorth
          workWindEast(jp+1,bi,bj) = keyWindEast
          workWindNorth(jp+1,bi,bj) = keyWindNorth
          workDriftEast(jp+1,bi,bj) = keyDriftEast
          workDriftNorth(jp+1,bi,bj) = keyDriftNorth
          workSpringEast(jp+1,bi,bj) = keySpringEast
          workSpringNorth(jp+1,bi,bj) = keySpringNorth
          workNeighbor(jp+1,bi,bj) = keyNeighbor
          workRaftId(jp+1,bi,bj) = keyRaftId
          workRaftSize(jp+1,bi,bj) = keyRaftSize
          DO iDiag=1,BOM_RHS_NDIAG
            workRhsDiag(iDiag,jp+1,bi,bj) = keyRhsDiag(iDiag)
          ENDDO
          workRefresh(jp+1,bi,bj) = keyRefresh
        ENDDO
        DO ip=2,workCount(bi,bj)
          IF ( workId(ip,bi,bj).EQ.workId(ip-1,bi,bj) )
     &         localErrCount = localErrCount + 1
        ENDDO
       ENDDO
      ENDDO

C--   Refresh only moved records; retained records remain bitwise intact.
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,workCount(bi,bj)
          IF ( workRefresh(ip,bi,bj) ) THEN
            IF ( bomMode.EQ.'BOM' ) THEN
              CALL BOM_RHS_SLOW_MANIFOLD(
     I             workX(ip,bi,bj), workY(ip,bi,bj),
     I             exchangeTime, 0. _d 0, bi, bj,
     I             BOM_STAGE_FINAL,
     O             rhsX, rhsY, workI(ip,bi,bj), workJ(ip,bi,bj),
     O             workRhsDiag(1,ip,bi,bj),
     O             wetWeight, stageCFL,
     O             rhsOwner, rhsValid, rhsFailCode, rhsFailStage,
     I             myThid )
              IF ( rhsValid ) THEN
                IF ( bomSpringLaw.NE.'NONE' ) THEN
                  CALL BOM_SAFE_ADD_RL(
     I                 workRhsDiag(BOM_RHS_DRIFT_E,ip,bi,bj),
     I                 workSpringEast(ip,bi,bj),
     O                 keyDriftEast,springEastValid)
                  CALL BOM_SAFE_ADD_RL(
     I                 workRhsDiag(BOM_RHS_DRIFT_N,ip,bi,bj),
     I                 workSpringNorth(ip,bi,bj),
     O                 keyDriftNorth,springNorthValid)
                  rhsValid = springEastValid.AND.springNorthValid
                  IF ( rhsValid ) THEN
                    workRhsDiag(BOM_RHS_DRIFT_E,ip,bi,bj) =
     &                   keyDriftEast
                    workRhsDiag(BOM_RHS_DRIFT_N,ip,bi,bj) =
     &                   keyDriftNorth
                  ELSE
                    rhsFailCode = BOM_FAIL_NONFINITE
                  ENDIF
                ENDIF
              ENDIF
              IF ( rhsValid ) THEN
                workVEast(ip,bi,bj) =
     &               workRhsDiag(BOM_RHS_VBASE_E,ip,bi,bj)
                workVNorth(ip,bi,bj) =
     &               workRhsDiag(BOM_RHS_VBASE_N,ip,bi,bj)
                workWindEast(ip,bi,bj) =
     &               workRhsDiag(BOM_RHS_VW_E,ip,bi,bj)
                workWindNorth(ip,bi,bj) =
     &               workRhsDiag(BOM_RHS_VW_N,ip,bi,bj)
                workDriftEast(ip,bi,bj) =
     &               workRhsDiag(BOM_RHS_DRIFT_E,ip,bi,bj)
                workDriftNorth(ip,bi,bj) =
     &               workRhsDiag(BOM_RHS_DRIFT_N,ip,bi,bj)
              ENDIF
            ELSE
              CALL BOM_RHS_LEEWAY(
     I             workX(ip,bi,bj), workY(ip,bi,bj), 0. _d 0,
     I             bi, bj,
     O             rhsX, rhsY, workI(ip,bi,bj), workJ(ip,bi,bj),
     O             workVEast(ip,bi,bj), workVNorth(ip,bi,bj),
     O             workWindEast(ip,bi,bj), workWindNorth(ip,bi,bj),
     O             workDriftEast(ip,bi,bj), workDriftNorth(ip,bi,bj),
     O             wetWeight, stageCFL,
     O             rhsOwner, rhsValid, rhsFailCode,
     I             myThid )
            ENDIF
            IF ( .NOT.rhsValid .OR. .NOT.rhsOwner ) THEN
              IF ( localErrCount.LT.8 ) THEN
                WRITE(msgBuf,1004)
     &               'BOM_PARTICLE_EXCHANGE: target refresh id=',
     &               workId(ip,bi,bj), ' rank/tile/slot=',
     &               myProcId, bi, bj, ip, ' fail=', rhsFailCode
                CALL PRINT_ERROR( msgBuf, myThid )
              ENDIF
              localErrCount = localErrCount + 1
            ENDIF
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I10,A,2I12)')
     &         'BOM_PARTICLE_EXCHANGE: fatal target refresh errors=',
     &         globalErrCount, ' iter/sub=',
     &         exchangeIter, exchangeSubstep
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_PARTICLE_EXCHANGE'
      ENDIF

C--   The only authoritative topology write in this routine.
      DO bj=1,nSy
       DO bi=1,nSx
        bomNPartTile(bi,bj) = workCount(bi,bj)
        DO ip=1,bomMaxPartTile
          bomId(ip,bi,bj) = workId(ip,bi,bj)
          bomStatus(ip,bi,bj) = workStatus(ip,bi,bj)
          bomX(ip,bi,bj) = workX(ip,bi,bj)
          bomY(ip,bi,bj) = workY(ip,bi,bj)
          bomReleaseTime(ip,bi,bj) = workRelease(ip,bi,bj)
          bomAge(ip,bi,bj) = workAge(ip,bi,bj)
          bomI(ip,bi,bj) = workI(ip,bi,bj)
          bomJ(ip,bi,bj) = workJ(ip,bi,bj)
          bomVEast(ip,bi,bj) = workVEast(ip,bi,bj)
          bomVNorth(ip,bi,bj) = workVNorth(ip,bi,bj)
          bomWindEast(ip,bi,bj) = workWindEast(ip,bi,bj)
          bomWindNorth(ip,bi,bj) = workWindNorth(ip,bi,bj)
          bomDriftEast(ip,bi,bj) = workDriftEast(ip,bi,bj)
          bomDriftNorth(ip,bi,bj) = workDriftNorth(ip,bi,bj)
          bomSpringEast(ip,bi,bj) = workSpringEast(ip,bi,bj)
          bomSpringNorth(ip,bi,bj) = workSpringNorth(ip,bi,bj)
          bomNeighborCount(ip,bi,bj) = workNeighbor(ip,bi,bj)
          bomRaftId(ip,bi,bj) = workRaftId(ip,bi,bj)
          bomRaftSize(ip,bi,bj) = workRaftSize(ip,bi,bj)
          DO iDiag=1,BOM_RHS_NDIAG
            bomRhsDiag(iDiag,ip,bi,bj) =
     &           workRhsDiag(iDiag,ip,bi,bj)
          ENDDO
        ENDDO
       ENDDO
      ENDDO

 1000 FORMAT(A,I20,A,3I6,A,2I12,A,1PE24.16)
 1001 FORMAT(A,I20,A,3I6,A,5I8)
 1002 FORMAT(A,I6,1X,A4,A,2I12)
 1003 FORMAT(A,3I6,A,2I12)
 1004 FORMAT(A,I20,A,4I6,A,I6)
#endif /* ALLOW_BOM */

      RETURN
      END
