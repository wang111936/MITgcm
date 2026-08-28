#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_COMPONENTS_FINAL
C !INTERFACE:
      SUBROUTINE BOM_COMPONENTS_FINAL(
     I                 nOwner, ownerId, ownerStatus,
     I                 ownerX, ownerY,
     I                 neighborCount, neighborId,
     I                 graphStage, graphEpoch, graphSubstep,
     O                 raftId, raftSize,
     O                 failCode, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Compute instantaneous connected components of the successful FINAL
C     cutoff graph.  Synchronous minimum-label propagation is bounded by the
C     exact global live-owner count.  Component sizes use a distributed
C     label rendezvous and never gather all owners on every rank.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"

      INTEGER nOwner, graphStage, graphEpoch, graphSubstep
      INTEGER failCode, myThid
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER ownerStatus(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord), ownerY(bomMaxOwnerRecord)
      INTEGER neighborCount(bomMaxOwnerRecord)
      INTEGER*8 neighborId(bomMaxNeighbor,bomMaxOwnerRecord)
      INTEGER*8 raftId(bomMaxOwnerRecord)
      INTEGER raftSize(bomMaxOwnerRecord)
      LOGICAL isValid
CEOP

#ifdef ALLOW_BOM
      INTEGER owner, neighbor, iteration, localAlive, globalAlive
      INTEGER localErr, globalErr, localChanged, globalChanged
      INTEGER nRemote, localIndex, sizeFail
      INTEGER*8 labelOld(bomMaxOwnerRecord)
      INTEGER*8 labelNext(bomMaxOwnerRecord)
      INTEGER*8 localIdSort(bomMaxOwnerRecord)
      INTEGER*8 localIndexSort(bomMaxOwnerRecord)
      INTEGER*8 remoteId(bomMaxGhostExchange)
      INTEGER*8 remoteLabel(bomMaxGhostExchange)
      INTEGER*8 candidate, neighborLabel, index8
      LOGICAL exchangeValid, sortValid, found, converged, sizeValid
      SAVE remoteId, remoteLabel
#endif

      failCode = BOM_FAIL_COMPONENT
      isValid = .FALSE.

#ifdef ALLOW_BOM
      localErr = 0
      localAlive = 0
      DO owner=1,bomMaxOwnerRecord
        raftId(owner) = 0_8
        raftSize(owner) = 0
      ENDDO
      IF ( nOwner.LT.0 .OR. nOwner.GT.bomMaxOwnerRecord .OR.
     &     graphStage.NE.BOM_STAGE_FINAL .OR.
     &     graphEpoch.LE.0 .OR. graphSubstep.LE.0 )
     &     localErr=localErr+1

      DO owner=1,MAX(0,MIN(nOwner,bomMaxOwnerRecord))
        localIdSort(owner) = ownerId(owner)
        localIndexSort(owner) = INT(owner,8)
        IF ( ownerId(owner).LE.0_8 .OR.
     &       .NOT.IEEE_IS_FINITE(ownerX(owner)) .OR.
     &       .NOT.IEEE_IS_FINITE(ownerY(owner)) .OR.
     &       neighborCount(owner).LT.0 .OR.
     &       neighborCount(owner).GT.bomMaxNeighbor ) THEN
          localErr = localErr+1
          labelOld(owner) = 0_8
        ELSEIF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
          localAlive = localAlive+1
          labelOld(owner) = ownerId(owner)
        ELSEIF ( ownerStatus(owner).EQ.BOM_WAITING ) THEN
          IF ( neighborCount(owner).NE.0 ) localErr=localErr+1
          labelOld(owner) = 0_8
        ELSE
          localErr = localErr+1
          labelOld(owner) = 0_8
        ENDIF
      ENDDO
      CALL BOM_COMPONENT_SORT_PAIRS_I8(
     U     localIdSort,localIndexSort,
     I     MAX(0,MIN(nOwner,bomMaxOwnerRecord)),bomMaxOwnerRecord,
     O     sortValid)
      IF ( .NOT.sortValid ) THEN
        localErr = localErr+1
      ELSE
        DO owner=2,nOwner
          IF ( localIdSort(owner).EQ.localIdSort(owner-1) )
     &         localErr=localErr+1
        ENDDO
      ENDIF
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN

      globalAlive = localAlive
      CALL GLOBAL_SUM_INT(globalAlive,myThid)
      IF ( globalAlive.LT.0 .OR.
     &     globalAlive.GT.bomMaxInitRecords ) RETURN
      IF ( globalAlive.EQ.0 ) THEN
        failCode = BOM_FAIL_NONE
        isValid = .TRUE.
        RETURN
      ENDIF

      converged = .FALSE.
      DO iteration=1,globalAlive
        CALL BOM_COMPONENT_LABEL_EXCHANGE(
     I       nOwner,ownerId,ownerStatus,ownerX,ownerY,labelOld,
     I       graphStage,graphEpoch,graphSubstep,iteration,
     O       nRemote,remoteId,remoteLabel,
     O       failCode,exchangeValid,myThid)
        IF ( .NOT.exchangeValid ) RETURN

        localErr = 0
        localChanged = 0
        DO owner=1,nOwner
          labelNext(owner) = labelOld(owner)
          IF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
            candidate = labelOld(owner)
            DO neighbor=1,neighborCount(owner)
              IF ( neighborId(neighbor,owner).LE.0_8 .OR.
     &             neighborId(neighbor,owner).EQ.ownerId(owner) ) THEN
                localErr = localErr+1
              ELSE
                CALL BOM_COMPONENT_FIND_I8(
     I               neighborId(neighbor,owner),
     I               localIdSort,localIndexSort,nOwner,
     O               index8,found)
                IF ( found ) THEN
                  localIndex = INT(index8)
                  IF ( localIndex.LT.1 .OR.
     &                 localIndex.GT.nOwner .OR.
     &                 ownerStatus(localIndex).NE.BOM_ALIVE ) THEN
                    localErr = localErr+1
                    neighborLabel = 0_8
                  ELSE
                    neighborLabel = labelOld(localIndex)
                  ENDIF
                ELSE
                  CALL BOM_COMPONENT_FIND_I8(
     I                 neighborId(neighbor,owner),
     I                 remoteId,remoteLabel,nRemote,
     O                 neighborLabel,found)
                  IF ( .NOT.found ) THEN
                    localErr = localErr+1
                    neighborLabel = 0_8
                  ENDIF
                ENDIF
                IF ( neighborLabel.LE.0_8 ) THEN
                  localErr = localErr+1
                ELSE
                  candidate = MIN(candidate,neighborLabel)
                ENDIF
              ENDIF
            ENDDO
            IF ( candidate.LE.0_8 .OR.
     &           candidate.GT.labelOld(owner) ) THEN
              localErr = localErr+1
            ELSE
              labelNext(owner) = candidate
              IF ( candidate.NE.labelOld(owner) )
     &             localChanged=localChanged+1
            ENDIF
          ELSEIF ( labelOld(owner).NE.0_8 ) THEN
            localErr = localErr+1
          ENDIF
        ENDDO
        globalErr = localErr
        CALL GLOBAL_SUM_INT(globalErr,myThid)
        IF ( globalErr.GT.0 ) RETURN
        DO owner=1,nOwner
          labelOld(owner) = labelNext(owner)
        ENDDO
        globalChanged = localChanged
        CALL GLOBAL_SUM_INT(globalChanged,myThid)
        IF ( globalChanged.EQ.0 ) THEN
          converged = .TRUE.
          GOTO 100
        ENDIF
      ENDDO
  100 CONTINUE
      IF ( .NOT.converged ) RETURN

      CALL BOM_COMPONENT_SIZES(
     I     nOwner,ownerId,ownerStatus,labelOld,
     O     raftSize,sizeFail,sizeValid,myThid)
      IF ( .NOT.sizeValid ) THEN
        failCode = sizeFail
        RETURN
      ENDIF
      localErr = 0
      DO owner=1,nOwner
        IF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
          IF ( labelOld(owner).LE.0_8 .OR.
     &         labelOld(owner).GT.ownerId(owner) .OR.
     &         raftSize(owner).LT.1 .OR.
     &         raftSize(owner).GT.globalAlive ) localErr=localErr+1
          raftId(owner) = labelOld(owner)
        ELSE
          IF ( labelOld(owner).NE.0_8 .OR.
     &         raftSize(owner).NE.0 ) localErr=localErr+1
          raftId(owner) = 0_8
        ENDIF
      ENDDO
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
#endif /* ALLOW_BOM */
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_COMPONENT_SIZES
C !INTERFACE:
      SUBROUTINE BOM_COMPONENT_SIZES(
     I                 nOwner, ownerId, ownerStatus, ownerLabel,
     O                 ownerSize, failCode, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Aggregate exact component counts at a deterministic hash rendezvous
C     rank, then return each size only to ranks that own that component.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nOwner, ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerSize(bomMaxOwnerRecord), failCode, myThid
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER*8 ownerLabel(bomMaxOwnerRecord)
      LOGICAL isValid
CEOP

#ifdef ALLOW_BOM
      INTEGER owner, i, rankIndex, destination, packetIndex, cursor
      INTEGER sourceRank, sendTotal, recvTotal, nLocal, nUnique
      INTEGER nAggregate, localErr, globalErr
      INTEGER sendCounts(nPx*nPy), recvCounts(nPx*nPy)
      INTEGER sendDispls(nPx*nPy), recvDispls(nPx*nPy)
      INTEGER sendCountsI(nPx*nPy), recvCountsI(nPx*nPy)
      INTEGER sendDisplsI(nPx*nPy), recvDisplsI(nPx*nPy)
      INTEGER resultSendCountsI(nPx*nPy)
      INTEGER resultRecvCountsI(nPx*nPy)
      INTEGER resultSendDisplsI(nPx*nPy)
      INTEGER resultRecvDisplsI(nPx*nPy)
      INTEGER packetCursor(nPx*nPy)
      INTEGER sendInt(
     &     bomComponentSizePacketInts,bomMaxOwnerRecord)
      INTEGER recvInt(
     &     bomComponentSizePacketInts,bomMaxInitRecords)
      INTEGER resultSendInt(
     &     bomComponentSizePacketInts,bomMaxInitRecords)
      INTEGER resultRecvInt(
     &     bomComponentSizePacketInts,bomMaxOwnerRecord)
      INTEGER*8 localLabel(bomMaxOwnerRecord)
      INTEGER*8 localCount8(bomMaxOwnerRecord)
      INTEGER*8 uniqueLabel(bomMaxOwnerRecord)
      INTEGER*8 uniqueCount8(bomMaxOwnerRecord)
      INTEGER*8 recvLabel(bomMaxInitRecords)
      INTEGER*8 recvCount8(bomMaxInitRecords)
      INTEGER*8 aggregateLabel(bomMaxInitRecords)
      INTEGER*8 aggregateCount8(bomMaxInitRecords)
      INTEGER*8 resultLabel(bomMaxOwnerRecord)
      INTEGER*8 resultSize8(bomMaxOwnerRecord)
      INTEGER*8 idRadix, idHi8, idLo8, packetLabel
      INTEGER*8 packetCount8, foundValue
      LOGICAL sortValid, found, packetValid
#ifdef ALLOW_USE_MPI
      INTEGER mpiRC
#endif
      SAVE sendInt,recvInt,resultSendInt,resultRecvInt
      SAVE recvLabel,recvCount8,aggregateLabel,aggregateCount8
#endif

      failCode = BOM_FAIL_COMPONENT
      isValid = .FALSE.
#ifdef ALLOW_BOM
      idRadix = 4294967296_8
      localErr = 0
      nLocal = 0
      DO owner=1,bomMaxOwnerRecord
        ownerSize(owner) = 0
      ENDDO
      IF ( nOwner.LT.0 .OR. nOwner.GT.bomMaxOwnerRecord )
     &     localErr=localErr+1
      DO owner=1,MAX(0,MIN(nOwner,bomMaxOwnerRecord))
        IF ( ownerId(owner).LE.0_8 ) localErr=localErr+1
        IF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
          IF ( ownerLabel(owner).LE.0_8 .OR.
     &         ownerLabel(owner).GT.ownerId(owner) ) THEN
            localErr = localErr+1
          ELSE
            nLocal = nLocal+1
            localLabel(nLocal) = ownerLabel(owner)
            localCount8(nLocal) = 1_8
          ENDIF
        ELSEIF ( ownerStatus(owner).EQ.BOM_WAITING ) THEN
          IF ( ownerLabel(owner).NE.0_8 ) localErr=localErr+1
        ELSE
          localErr = localErr+1
        ENDIF
      ENDDO
      CALL BOM_COMPONENT_SORT_PAIRS_I8(
     U     localLabel,localCount8,
     I     nLocal,bomMaxOwnerRecord,
     O     sortValid)
      IF ( .NOT.sortValid ) localErr=localErr+1
      nUnique = 0
      DO i=1,nLocal
        IF ( i.EQ.1 ) THEN
          nUnique = nUnique+1
          uniqueLabel(nUnique) = localLabel(i)
          uniqueCount8(nUnique) = localCount8(i)
        ELSEIF ( localLabel(i).NE.localLabel(i-1) ) THEN
          nUnique = nUnique+1
          uniqueLabel(nUnique) = localLabel(i)
          uniqueCount8(nUnique) = localCount8(i)
        ELSE
          uniqueCount8(nUnique) = uniqueCount8(nUnique)
     &         +localCount8(i)
        ENDIF
      ENDDO
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN

C--   A single-rank run already owns the exact complete counts.
      IF ( nPx*nPy.EQ.1 ) THEN
        DO owner=1,nOwner
          IF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
            CALL BOM_COMPONENT_FIND_I8(
     I           ownerLabel(owner),uniqueLabel,uniqueCount8,nUnique,
     O           foundValue,found)
            IF ( .NOT.found .OR. foundValue.LT.1_8 .OR.
     &           foundValue.GT.INT(HUGE(ownerSize(owner)),8) ) THEN
              localErr = localErr+1
            ELSE
              ownerSize(owner) = INT(foundValue)
            ENDIF
          ENDIF
        ENDDO
        globalErr = localErr
        CALL GLOBAL_SUM_INT(globalErr,myThid)
        IF ( globalErr.GT.0 ) RETURN
        failCode = BOM_FAIL_NONE
        isValid = .TRUE.
        RETURN
      ENDIF

#ifndef ALLOW_USE_MPI
      RETURN
#else
      IF ( .NOT.usingMPI ) RETURN
      sendTotal = 0
      recvTotal = 0
      DO rankIndex=1,nPx*nPy
        sendCounts(rankIndex) = 0
        recvCounts(rankIndex) = 0
        sendDispls(rankIndex) = 0
        recvDispls(rankIndex) = 0
        packetCursor(rankIndex) = 0
      ENDDO
      DO i=1,nUnique
        destination = 1+INT(MOD(uniqueLabel(i),INT(nPx*nPy,8)))
        sendCounts(destination) = sendCounts(destination)+1
      ENDDO
      DO rankIndex=1,nPx*nPy
        sendDispls(rankIndex) = sendTotal
        IF ( sendCounts(rankIndex).GT.
     &       bomMaxOwnerRecord-sendTotal ) THEN
          localErr = localErr+1
        ELSE
          sendTotal = sendTotal+sendCounts(rankIndex)
        ENDIF
      ENDDO
      CALL MPI_Alltoall(
     I     sendCounts,1,MPI_INTEGER,
     O     recvCounts,1,MPI_INTEGER,
     I     MPI_COMM_MODEL,mpiRC)
      IF ( mpiRC.NE.MPI_SUCCESS ) localErr=localErr+1
      DO rankIndex=1,nPx*nPy
        recvDispls(rankIndex) = recvTotal
        IF ( recvCounts(rankIndex).LT.0 .OR.
     &       recvCounts(rankIndex).GT.
     &       bomMaxInitRecords-recvTotal ) THEN
          localErr = localErr+1
        ELSE
          recvTotal = recvTotal+recvCounts(rankIndex)
        ENDIF
      ENDDO
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN

      DO rankIndex=1,nPx*nPy
        packetCursor(rankIndex) = sendDispls(rankIndex)
      ENDDO
      DO i=1,nUnique
        destination = 1+INT(MOD(uniqueLabel(i),INT(nPx*nPy,8)))
        packetIndex = packetCursor(destination)+1
        packetCursor(destination) = packetIndex
        idHi8 = uniqueLabel(i)/idRadix
        idLo8 = MOD(uniqueLabel(i),idRadix)
        sendInt(1,packetIndex) = bomComponentSizeSchema
        sendInt(2,packetIndex) = myProcId
        sendInt(3,packetIndex) = INT(idHi8)
        IF ( idLo8.GT.2147483647_8 ) THEN
          sendInt(4,packetIndex) = INT(idLo8-idRadix)
        ELSE
          sendInt(4,packetIndex) = INT(idLo8)
        ENDIF
        sendInt(5,packetIndex) = INT(uniqueCount8(i))
      ENDDO
      DO rankIndex=1,nPx*nPy
        sendCountsI(rankIndex) =
     &       bomComponentSizePacketInts*sendCounts(rankIndex)
        recvCountsI(rankIndex) =
     &       bomComponentSizePacketInts*recvCounts(rankIndex)
        sendDisplsI(rankIndex) =
     &       bomComponentSizePacketInts*sendDispls(rankIndex)
        recvDisplsI(rankIndex) =
     &       bomComponentSizePacketInts*recvDispls(rankIndex)
      ENDDO
      CALL MPI_Alltoallv(
     I     sendInt,sendCountsI,sendDisplsI,MPI_INTEGER,
     O     recvInt,recvCountsI,recvDisplsI,MPI_INTEGER,
     I     MPI_COMM_MODEL,mpiRC)
      IF ( mpiRC.NE.MPI_SUCCESS ) localErr=localErr+1

      DO rankIndex=1,nPx*nPy
        sourceRank = rankIndex-1
        DO cursor=1,recvCounts(rankIndex)
          packetIndex = recvDispls(rankIndex)+cursor
          packetValid = .TRUE.
          IF ( recvInt(1,packetIndex).NE.
     &         bomComponentSizeSchema .OR.
     &         recvInt(2,packetIndex).NE.sourceRank .OR.
     &         recvInt(5,packetIndex).LT.1 )
     &         packetValid=.FALSE.
          idHi8 = INT(recvInt(3,packetIndex),8)
          idLo8 = INT(recvInt(4,packetIndex),8)
          IF ( idLo8.LT.0_8 ) idLo8=idLo8+idRadix
          IF ( idHi8.LT.0_8 ) THEN
            packetLabel = 0_8
            packetValid = .FALSE.
          ELSE
            packetLabel = idHi8*idRadix+idLo8
            IF ( packetLabel.LE.0_8 .OR.
     &           MOD(packetLabel,INT(nPx*nPy,8)).NE.
     &           INT(myProcId,8) ) packetValid=.FALSE.
          ENDIF
          recvLabel(packetIndex) = packetLabel
          recvCount8(packetIndex) = INT(recvInt(5,packetIndex),8)
          IF ( .NOT.packetValid ) localErr=localErr+1
        ENDDO
      ENDDO
      DO i=1,recvTotal
        aggregateLabel(i) = recvLabel(i)
        aggregateCount8(i) = recvCount8(i)
      ENDDO
      CALL BOM_COMPONENT_SORT_PAIRS_I8(
     U     aggregateLabel,aggregateCount8,
     I     recvTotal,bomMaxInitRecords,
     O     sortValid)
      IF ( .NOT.sortValid ) localErr=localErr+1
      nAggregate = 0
      DO i=1,recvTotal
        IF ( i.EQ.1 ) THEN
          nAggregate = nAggregate+1
          aggregateLabel(nAggregate) = aggregateLabel(i)
          aggregateCount8(nAggregate) = aggregateCount8(i)
        ELSEIF ( aggregateLabel(i).NE.aggregateLabel(i-1) ) THEN
          nAggregate = nAggregate+1
          aggregateLabel(nAggregate) = aggregateLabel(i)
          aggregateCount8(nAggregate) = aggregateCount8(i)
        ELSE
          aggregateCount8(nAggregate) =
     &         aggregateCount8(nAggregate)+aggregateCount8(i)
        ENDIF
      ENDDO
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN

C--   Return the aggregate once for every contributing source record.
      DO rankIndex=1,nPx*nPy
        DO cursor=1,recvCounts(rankIndex)
          packetIndex = recvDispls(rankIndex)+cursor
          CALL BOM_COMPONENT_FIND_I8(
     I         recvLabel(packetIndex),aggregateLabel,
     I         aggregateCount8,nAggregate,
     O         packetCount8,found)
          IF ( .NOT.found .OR. packetCount8.LT.1_8 .OR.
     &         packetCount8.GT.INT(HUGE(i),8) ) THEN
            localErr = localErr+1
            packetCount8 = 0_8
          ENDIF
          idHi8 = recvLabel(packetIndex)/idRadix
          idLo8 = MOD(recvLabel(packetIndex),idRadix)
          resultSendInt(1,packetIndex) = bomComponentSizeSchema
          resultSendInt(2,packetIndex) = myProcId
          resultSendInt(3,packetIndex) = INT(idHi8)
          IF ( idLo8.GT.2147483647_8 ) THEN
            resultSendInt(4,packetIndex) = INT(idLo8-idRadix)
          ELSE
            resultSendInt(4,packetIndex) = INT(idLo8)
          ENDIF
          resultSendInt(5,packetIndex) = INT(packetCount8)
        ENDDO
        resultSendCountsI(rankIndex) =
     &       bomComponentSizePacketInts*recvCounts(rankIndex)
        resultRecvCountsI(rankIndex) =
     &       bomComponentSizePacketInts*sendCounts(rankIndex)
        resultSendDisplsI(rankIndex) =
     &       bomComponentSizePacketInts*recvDispls(rankIndex)
        resultRecvDisplsI(rankIndex) =
     &       bomComponentSizePacketInts*sendDispls(rankIndex)
      ENDDO
      CALL MPI_Alltoallv(
     I     resultSendInt,resultSendCountsI,resultSendDisplsI,
     I     MPI_INTEGER,
     O     resultRecvInt,resultRecvCountsI,resultRecvDisplsI,
     I     MPI_INTEGER,MPI_COMM_MODEL,mpiRC)
      IF ( mpiRC.NE.MPI_SUCCESS ) localErr=localErr+1

      DO rankIndex=1,nPx*nPy
        sourceRank = rankIndex-1
        DO cursor=1,sendCounts(rankIndex)
          packetIndex = sendDispls(rankIndex)+cursor
          packetValid = .TRUE.
          IF ( resultRecvInt(1,packetIndex).NE.
     &         bomComponentSizeSchema .OR.
     &         resultRecvInt(2,packetIndex).NE.sourceRank .OR.
     &         resultRecvInt(5,packetIndex).LT.1 )
     &         packetValid=.FALSE.
          idHi8 = INT(resultRecvInt(3,packetIndex),8)
          idLo8 = INT(resultRecvInt(4,packetIndex),8)
          IF ( idLo8.LT.0_8 ) idLo8=idLo8+idRadix
          packetLabel = idHi8*idRadix+idLo8
          IF ( idHi8.LT.0_8 .OR. packetLabel.LE.0_8 .OR.
     &         MOD(packetLabel,INT(nPx*nPy,8)).NE.
     &         INT(sourceRank,8) ) packetValid=.FALSE.
          resultLabel(packetIndex) = packetLabel
          resultSize8(packetIndex) =
     &         INT(resultRecvInt(5,packetIndex),8)
          IF ( .NOT.packetValid ) localErr=localErr+1
        ENDDO
      ENDDO
      CALL BOM_COMPONENT_SORT_PAIRS_I8(
     U     resultLabel,resultSize8,
     I     sendTotal,bomMaxOwnerRecord,
     O     sortValid)
      IF ( .NOT.sortValid .OR. sendTotal.NE.nUnique ) THEN
        localErr = localErr+1
      ELSE
        DO i=1,nUnique
          IF ( resultLabel(i).NE.uniqueLabel(i) .OR.
     &         resultSize8(i).LT.uniqueCount8(i) )
     &         localErr=localErr+1
        ENDDO
      ENDIF
      DO owner=1,nOwner
        IF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
          CALL BOM_COMPONENT_FIND_I8(
     I         ownerLabel(owner),resultLabel,resultSize8,nUnique,
     O         foundValue,found)
          IF ( .NOT.found .OR. foundValue.LT.1_8 .OR.
     &         foundValue.GT.INT(HUGE(ownerSize(owner)),8) ) THEN
            localErr = localErr+1
          ELSE
            ownerSize(owner) = INT(foundValue)
          ENDIF
        ENDIF
      ENDDO
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
#endif /* ALLOW_USE_MPI */
#endif /* ALLOW_BOM */
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_COMPONENT_INVALIDATE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER owner
      bomComponentReady = .FALSE.
      bomComponentNOwner = 0
      bomComponentStage = BOM_STAGE_NONE
      bomComponentEpoch = 0
      bomComponentSubstep = 0
      DO owner=1,bomMaxOwnerRecord
        bomComponentOwnerId(owner) = 0_8
        bomComponentRaftId(owner) = 0_8
        bomComponentRaftSize(owner) = 0
      ENDDO
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_COMPONENT_PUBLISH(
     I                 nOwner, ownerId, raftId, raftSize,
     I                 graphStage, graphEpoch, graphSubstep )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nOwner, graphStage, graphEpoch, graphSubstep, owner
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER*8 raftId(bomMaxOwnerRecord)
      INTEGER raftSize(bomMaxOwnerRecord)
      CALL BOM_COMPONENT_INVALIDATE
      IF ( nOwner.LT.0 .OR. nOwner.GT.bomMaxOwnerRecord .OR.
     &     graphStage.NE.BOM_STAGE_FINAL .OR.
     &     graphEpoch.LE.0 .OR. graphSubstep.LE.0 ) RETURN
      DO owner=1,nOwner
        bomComponentOwnerId(owner) = ownerId(owner)
        bomComponentRaftId(owner) = raftId(owner)
        bomComponentRaftSize(owner) = raftSize(owner)
      ENDDO
      bomComponentNOwner = nOwner
      bomComponentStage = graphStage
      bomComponentEpoch = graphEpoch
      bomComponentSubstep = graphSubstep
      bomComponentReady = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_COMPONENT_FETCH(
     I                 nOwner, ownerId,
     I                 graphStage, graphEpoch, graphSubstep,
     O                 raftId, raftSize,
     O                 failCode, isValid,
     I                 myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nOwner, graphStage, graphEpoch, graphSubstep
      INTEGER failCode, myThid, owner, localErr, globalErr
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER*8 raftId(bomMaxOwnerRecord)
      INTEGER raftSize(bomMaxOwnerRecord)
      LOGICAL isValid
      failCode = BOM_FAIL_COMPONENT
      isValid = .FALSE.
      localErr = 0
      IF ( nOwner.LT.0 .OR. nOwner.GT.bomMaxOwnerRecord )
     &     localErr=localErr+1
      IF ( .NOT.bomComponentReady .OR.
     &     bomComponentNOwner.NE.nOwner .OR.
     &     bomComponentStage.NE.graphStage .OR.
     &     bomComponentEpoch.NE.graphEpoch .OR.
     &     bomComponentSubstep.NE.graphSubstep ) localErr=localErr+1
      DO owner=1,MAX(0,MIN(nOwner,bomMaxOwnerRecord))
        IF ( bomComponentOwnerId(owner).NE.ownerId(owner) .OR.
     &       bomComponentRaftId(owner).LT.0_8 .OR.
     &       bomComponentRaftSize(owner).LT.0 ) localErr=localErr+1
      ENDDO
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN
      DO owner=1,nOwner
        raftId(owner) = bomComponentRaftId(owner)
        raftSize(owner) = bomComponentRaftSize(owner)
      ENDDO
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
      RETURN
      END
