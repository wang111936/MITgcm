#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_COMPONENT_LABEL_EXCHANGE
C !INTERFACE:
      SUBROUTINE BOM_COMPONENT_LABEL_EXCHANGE(
     I                 nOwner, ownerId, ownerStatus,
     I                 ownerX, ownerY, ownerLabel,
     I                 graphStage, graphEpoch, graphSubstep,
     I                 labelIteration,
     O                 nRemote, remoteId, remoteLabel,
     O                 failCode, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Exchange one synchronous minimum-label iteration only along the same
C     bounded rank-relevance routes used by the successful ghost graph.
C     Exact owner and label IDs remain split into signed 32-bit words.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"

      INTEGER nOwner, graphStage, graphEpoch, graphSubstep
      INTEGER labelIteration, nRemote, failCode, myThid
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER ownerStatus(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord), ownerY(bomMaxOwnerRecord)
      INTEGER*8 ownerLabel(bomMaxOwnerRecord)
      INTEGER*8 remoteId(bomMaxGhostExchange)
      INTEGER*8 remoteLabel(bomMaxGhostExchange)
      LOGICAL isValid
CEOP

#ifdef ALLOW_BOM
      INTEGER rankIndex, owner, packetIndex, cursor, sourceRank
      INTEGER sendTotal, recvTotal, localErr, globalErr
      INTEGER sendCounts(nPx*nPy), recvCounts(nPx*nPy)
      INTEGER sendDispls(nPx*nPy), recvDispls(nPx*nPy)
      INTEGER sendCountsI(nPx*nPy), recvCountsI(nPx*nPy)
      INTEGER sendDisplsI(nPx*nPy), recvDisplsI(nPx*nPy)
      INTEGER packetCursor(nPx*nPy)
      INTEGER sendInt(
     &     bomComponentLabelPacketInts,bomMaxGhostExchange)
      INTEGER recvInt(
     &     bomComponentLabelPacketInts,bomMaxGhostExchange)
      INTEGER*8 remoteIdWork(bomMaxGhostExchange)
      INTEGER*8 remoteLabelWork(bomMaxGhostExchange)
      INTEGER*8 idRadix, idHi8, idLo8, labelHi8, labelLo8
      INTEGER*8 packetId, packetLabel
      LOGICAL rankRelevant, routeValid, sortValid, packetValid
#ifdef ALLOW_USE_MPI
      INTEGER mpiRC
#endif
      SAVE sendInt, recvInt, remoteIdWork, remoteLabelWork
#endif

      nRemote = 0
      failCode = BOM_FAIL_COMPONENT
      isValid = .FALSE.

#ifdef ALLOW_BOM
      idRadix = 4294967296_8
      localErr = 0
      sendTotal = 0
      recvTotal = 0
      DO rankIndex=1,nPx*nPy
        sendCounts(rankIndex) = 0
        recvCounts(rankIndex) = 0
        sendDispls(rankIndex) = 0
        recvDispls(rankIndex) = 0
        packetCursor(rankIndex) = 0
      ENDDO

      IF ( nOwner.LT.0 .OR. nOwner.GT.bomMaxOwnerRecord .OR.
     &     graphStage.NE.BOM_STAGE_FINAL .OR.
     &     graphEpoch.LE.0 .OR. graphSubstep.LE.0 .OR.
     &     labelIteration.LE.0 ) localErr = localErr+1

      DO owner=1,MAX(0,MIN(nOwner,bomMaxOwnerRecord))
        IF ( ownerId(owner).LE.0_8 .OR.
     &       .NOT.IEEE_IS_FINITE(ownerX(owner)) .OR.
     &       .NOT.IEEE_IS_FINITE(ownerY(owner)) ) THEN
          localErr = localErr+1
        ELSEIF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
          IF ( ownerLabel(owner).LE.0_8 .OR.
     &         ownerLabel(owner).GT.ownerId(owner) )
     &         localErr = localErr+1
          DO rankIndex=1,nPx*nPy
            IF ( rankIndex-1.NE.myProcId ) THEN
              CALL BOM_GHOST_RANK_RELEVANT(
     I             ownerX(owner),ownerY(owner),rankIndex-1,
     O             rankRelevant,routeValid,myThid)
              IF ( .NOT.routeValid ) THEN
                localErr = localErr+1
              ELSEIF ( rankRelevant ) THEN
                sendCounts(rankIndex) = sendCounts(rankIndex)+1
              ENDIF
            ENDIF
          ENDDO
        ELSEIF ( ownerStatus(owner).EQ.BOM_WAITING ) THEN
          IF ( ownerLabel(owner).NE.0_8 ) localErr=localErr+1
        ELSE
          localErr = localErr+1
        ENDIF
      ENDDO

      DO rankIndex=1,nPx*nPy
        sendDispls(rankIndex) = sendTotal
        IF ( sendCounts(rankIndex).LT.0 .OR.
     &       sendCounts(rankIndex).GT.
     &       bomMaxGhostExchange-sendTotal ) THEN
          localErr = localErr+1
        ELSE
          sendTotal = sendTotal+sendCounts(rankIndex)
        ENDIF
      ENDDO
      IF ( sendTotal.GT.bomMaxGhostExchange ) localErr=localErr+1
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN

#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Alltoall(
     I       sendCounts,1,MPI_INTEGER,
     O       recvCounts,1,MPI_INTEGER,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) localErr=localErr+1
      ELSE
#endif
        recvCounts(1) = 0
#ifdef ALLOW_USE_MPI
      ENDIF
#endif

      DO rankIndex=1,nPx*nPy
        recvDispls(rankIndex) = recvTotal
        IF ( recvCounts(rankIndex).LT.0 .OR.
     &       recvCounts(rankIndex).GT.
     &       bomMaxGhostExchange-recvTotal ) THEN
          localErr = localErr+1
        ELSE
          recvTotal = recvTotal+recvCounts(rankIndex)
        ENDIF
      ENDDO
      IF ( recvTotal.GT.bomMaxGhostExchange ) localErr=localErr+1
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN

C--   Destination-rank then owner order is independent of MPI slot order.
      DO rankIndex=1,nPx*nPy
        packetCursor(rankIndex) = sendDispls(rankIndex)
      ENDDO
      DO owner=1,nOwner
        IF ( ownerStatus(owner).EQ.BOM_ALIVE ) THEN
          DO rankIndex=1,nPx*nPy
            IF ( rankIndex-1.NE.myProcId ) THEN
              CALL BOM_GHOST_RANK_RELEVANT(
     I             ownerX(owner),ownerY(owner),rankIndex-1,
     O             rankRelevant,routeValid,myThid)
              IF ( routeValid .AND. rankRelevant ) THEN
                packetIndex = packetCursor(rankIndex)+1
                packetCursor(rankIndex) = packetIndex
                idHi8 = ownerId(owner)/idRadix
                idLo8 = MOD(ownerId(owner),idRadix)
                labelHi8 = ownerLabel(owner)/idRadix
                labelLo8 = MOD(ownerLabel(owner),idRadix)
                sendInt(1,packetIndex) = bomComponentLabelSchema
                sendInt(2,packetIndex) = graphStage
                sendInt(3,packetIndex) = graphEpoch
                sendInt(4,packetIndex) = graphSubstep
                sendInt(5,packetIndex) = labelIteration
                sendInt(6,packetIndex) = myProcId
                sendInt(7,packetIndex) = INT(idHi8)
                IF ( idLo8.GT.2147483647_8 ) THEN
                  sendInt(8,packetIndex) = INT(idLo8-idRadix)
                ELSE
                  sendInt(8,packetIndex) = INT(idLo8)
                ENDIF
                sendInt(9,packetIndex) = INT(labelHi8)
                IF ( labelLo8.GT.2147483647_8 ) THEN
                  sendInt(10,packetIndex) = INT(labelLo8-idRadix)
                ELSE
                  sendInt(10,packetIndex) = INT(labelLo8)
                ENDIF
              ENDIF
            ENDIF
          ENDDO
        ENDIF
      ENDDO
      DO rankIndex=1,nPx*nPy
        IF ( packetCursor(rankIndex).NE.
     &       sendDispls(rankIndex)+sendCounts(rankIndex) )
     &       localErr=localErr+1
        sendCountsI(rankIndex) =
     &       bomComponentLabelPacketInts*sendCounts(rankIndex)
        recvCountsI(rankIndex) =
     &       bomComponentLabelPacketInts*recvCounts(rankIndex)
        sendDisplsI(rankIndex) =
     &       bomComponentLabelPacketInts*sendDispls(rankIndex)
        recvDisplsI(rankIndex) =
     &       bomComponentLabelPacketInts*recvDispls(rankIndex)
      ENDDO

#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Alltoallv(
     I       sendInt,sendCountsI,sendDisplsI,MPI_INTEGER,
     O       recvInt,recvCountsI,recvDisplsI,MPI_INTEGER,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) localErr=localErr+1
      ENDIF
#endif
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN

C--   Decode, validate, then sort the remote exact-ID directory.
      DO rankIndex=1,nPx*nPy
        sourceRank = rankIndex-1
        DO cursor=1,recvCounts(rankIndex)
          packetIndex = recvDispls(rankIndex)+cursor
          packetValid = .TRUE.
          IF ( recvInt(1,packetIndex).NE.
     &         bomComponentLabelSchema .OR.
     &         recvInt(2,packetIndex).NE.graphStage .OR.
     &         recvInt(3,packetIndex).NE.graphEpoch .OR.
     &         recvInt(4,packetIndex).NE.graphSubstep .OR.
     &         recvInt(5,packetIndex).NE.labelIteration .OR.
     &         recvInt(6,packetIndex).NE.sourceRank )
     &         packetValid = .FALSE.
          idHi8 = INT(recvInt(7,packetIndex),8)
          idLo8 = INT(recvInt(8,packetIndex),8)
          labelHi8 = INT(recvInt(9,packetIndex),8)
          labelLo8 = INT(recvInt(10,packetIndex),8)
          IF ( idLo8.LT.0_8 ) idLo8=idLo8+idRadix
          IF ( labelLo8.LT.0_8 ) labelLo8=labelLo8+idRadix
          IF ( idHi8.LT.0_8 .OR. labelHi8.LT.0_8 ) THEN
            packetId = 0_8
            packetLabel = 0_8
            packetValid = .FALSE.
          ELSE
            packetId = idHi8*idRadix+idLo8
            packetLabel = labelHi8*idRadix+labelLo8
            IF ( packetId.LE.0_8 .OR. packetLabel.LE.0_8 .OR.
     &           packetLabel.GT.packetId ) packetValid=.FALSE.
          ENDIF
          remoteIdWork(packetIndex) = packetId
          remoteLabelWork(packetIndex) = packetLabel
          IF ( .NOT.packetValid ) localErr=localErr+1
        ENDDO
      ENDDO
      CALL BOM_COMPONENT_SORT_PAIRS_I8(
     U     remoteIdWork,remoteLabelWork,
     I     recvTotal,bomMaxGhostExchange,
     O     sortValid)
      IF ( .NOT.sortValid ) THEN
        localErr = localErr+1
      ELSE
        DO packetIndex=2,recvTotal
          IF ( remoteIdWork(packetIndex).EQ.
     &         remoteIdWork(packetIndex-1) ) localErr=localErr+1
        ENDDO
      ENDIF
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN

      DO packetIndex=1,recvTotal
        remoteId(packetIndex) = remoteIdWork(packetIndex)
        remoteLabel(packetIndex) = remoteLabelWork(packetIndex)
      ENDDO
      nRemote = recvTotal
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
#endif /* ALLOW_BOM */
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_COMPONENT_SORT_PAIRS_I8(
     U                 values, companions,
     I                 nValue, capacity,
     O                 isValid )
      IMPLICIT NONE
      INTEGER nValue, capacity
      INTEGER*8 values(*), companions(*)
      LOGICAL isValid
      INTEGER start, finish, root, child

      isValid = .FALSE.
      IF ( capacity.LT.0 .OR. nValue.LT.0 .OR.
     &     nValue.GT.capacity ) RETURN
      DO start=nValue/2,1,-1
        root = start
        DO WHILE ( 2*root.LE.nValue )
          child = 2*root
          IF ( child.LT.nValue ) THEN
            IF ( values(child).LT.values(child+1) ) child=child+1
          ENDIF
          IF ( values(root).GE.values(child) ) GOTO 110
          CALL BOM_COMPONENT_SWAP_PAIR_I8(
     U         values,companions,root,child)
          root = child
        ENDDO
  110   CONTINUE
      ENDDO
      DO finish=nValue,2,-1
        CALL BOM_COMPONENT_SWAP_PAIR_I8(
     U       values,companions,1,finish)
        root = 1
        DO WHILE ( 2*root.LE.finish-1 )
          child = 2*root
          IF ( child.LT.finish-1 ) THEN
            IF ( values(child).LT.values(child+1) ) child=child+1
          ENDIF
          IF ( values(root).GE.values(child) ) GOTO 120
          CALL BOM_COMPONENT_SWAP_PAIR_I8(
     U         values,companions,root,child)
          root = child
        ENDDO
  120   CONTINUE
      ENDDO
      isValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_COMPONENT_SWAP_PAIR_I8(
     U                 values, companions,
     I                 slotA, slotB )
      IMPLICIT NONE
      INTEGER slotA, slotB
      INTEGER*8 values(*), companions(*), swapValue
      swapValue = values(slotA)
      values(slotA) = values(slotB)
      values(slotB) = swapValue
      swapValue = companions(slotA)
      companions(slotA) = companions(slotB)
      companions(slotB) = swapValue
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_COMPONENT_FIND_I8(
     I                 key, values, companions, nValue,
     O                 companion, found )
      IMPLICIT NONE
      INTEGER nValue, lo, hi, mid
      INTEGER*8 key, values(*), companions(*), companion
      LOGICAL found
      lo = 1
      hi = nValue
      found = .FALSE.
      companion = 0_8
      DO WHILE ( lo.LE.hi .AND. .NOT.found )
        mid = lo+(hi-lo)/2
        IF ( values(mid).EQ.key ) THEN
          companion = companions(mid)
          found = .TRUE.
        ELSEIF ( values(mid).LT.key ) THEN
          lo = mid+1
        ELSE
          hi = mid-1
        ENDIF
      ENDDO
      RETURN
      END
