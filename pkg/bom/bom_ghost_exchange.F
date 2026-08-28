#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_GHOST_EXCHANGE
C !INTERFACE:
      SUBROUTINE BOM_GHOST_EXCHANGE(
     I                 nOwner, ownerId, ownerStatus,
     I                 ownerX, ownerY, ownerBi, ownerBj,
     I                 ghostStage, ghostEpoch, ghostSubstep,
     O                 failCode, p3FailPhase, exchangeValid,
     I                 myThid )

C !DESCRIPTION:
C     Publish one versioned, one-stage read-only ghost set.  Remote owners
C     are sent once per relevant rank; the receiver independently routes a
C     validated packet to every intersecting local tile.  No count or ready
C     flag is published until all ranks validate the complete transaction.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER nOwner
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      INTEGER ownerStatus(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord), ownerY(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord)
      INTEGER ownerBj(bomMaxOwnerRecord)
      INTEGER ghostStage, ghostEpoch, ghostSubstep, myThid

C !OUTPUT PARAMETERS:
      INTEGER failCode, p3FailPhase
      LOGICAL exchangeValid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER bi, bj, ip, ig, rankIndex, packetIndex
      INTEGER sendTotal, recvTotal, sourceRank, cursor
      INTEGER capacityErrors, packetErrors
      INTEGER globalCapacityErrors, globalPacketErrors
      INTEGER sendCounts(nPx*nPy), recvCounts(nPx*nPy)
      INTEGER sendDispls(nPx*nPy), recvDispls(nPx*nPy)
      INTEGER sendCountsI(nPx*nPy), recvCountsI(nPx*nPy)
      INTEGER sendDisplsI(nPx*nPy), recvDisplsI(nPx*nPy)
      INTEGER sendCountsR(nPx*nPy), recvCountsR(nPx*nPy)
      INTEGER sendDisplsR(nPx*nPy), recvDisplsR(nPx*nPy)
      INTEGER packetCursor(nPx*nPy)
      INTEGER sendInt(bomGhostPacketInts,bomMaxGhostExchange)
      INTEGER recvInt(bomGhostPacketInts,bomMaxGhostExchange)
      _RL sendReal(bomGhostPacketReals,bomMaxGhostExchange)
      _RL recvReal(bomGhostPacketReals,bomMaxGhostExchange)
      INTEGER ghostCountWork(nSx,nSy)
      INTEGER ghostStatusWork(bomMaxGhostTile,nSx,nSy)
      INTEGER ghostRankWork(bomMaxGhostTile,nSx,nSy)
      INTEGER ghostBiWork(bomMaxGhostTile,nSx,nSy)
      INTEGER ghostBjWork(bomMaxGhostTile,nSx,nSy)
      INTEGER*8 ghostIdWork(bomMaxGhostTile,nSx,nSy)
      _RL ghostXWork(bomMaxGhostTile,nSx,nSy)
      _RL ghostYWork(bomMaxGhostTile,nSx,nSy)
      INTEGER*8 ownerIdSort(bomMaxOwnerRecord)
      INTEGER*8 recvIdSort(bomMaxGhostExchange)
      INTEGER*8 transactionIdSort(
     &     bomMaxOwnerRecord+bomMaxGhostExchange)
      INTEGER*8 idRadix, idHi8, idLo8, packetId
      INTEGER targetTileX, targetTileY
      LOGICAL relevant, routeValid, rankRelevant, sortValid
      LOGICAL packetValid, anyRelevant
#ifdef ALLOW_USE_MPI
      INTEGER mpiRC
#endif
      SAVE sendInt, recvInt, sendReal, recvReal
      SAVE ghostStatusWork, ghostRankWork
      SAVE ghostBiWork, ghostBjWork
      SAVE ghostIdWork, ghostXWork, ghostYWork
      SAVE transactionIdSort
#endif

      failCode = BOM_FAIL_GHOST_PACKET
      p3FailPhase = BOM_P3_PHASE_GHOST
      exchangeValid = .FALSE.

#ifdef ALLOW_BOM
C--   Invalidate the previous stage before constructing any candidate.
      bomGhostStage = BOM_STAGE_NONE
      bomGhostEpoch = 0
      bomGhostSubstep = 0
      bomGhostRecordsSent = 0_8
      bomGhostRecordsReceived = 0_8
      bomGhostBytesSent = 0_8
      bomGhostBytesReceived = 0_8
      DO bj=1,nSy
       DO bi=1,nSx
        bomNGhostTile(bi,bj) = 0
        bomGhostReady(bi,bj) = .FALSE.
        ghostCountWork(bi,bj) = 0
       ENDDO
      ENDDO

      capacityErrors = 0
      packetErrors = 0
      sendTotal = 0
      recvTotal = 0
      idRadix = 4294967296_8
      DO rankIndex=1,nPx*nPy
        sendCounts(rankIndex) = 0
        recvCounts(rankIndex) = 0
        sendDispls(rankIndex) = 0
        recvDispls(rankIndex) = 0
        packetCursor(rankIndex) = 0
      ENDDO

      IF ( nOwner.LT.0 .OR.
     &     nOwner.GT.bomMaxOwnerRecord ) THEN
        capacityErrors = capacityErrors+1
      ENDIF
      IF ( ghostStage.LT.BOM_STAGE_K1 .OR.
     &     ghostStage.GT.BOM_STAGE_FINAL .OR.
     &     ghostEpoch.LE.0 .OR. ghostSubstep.LE.0 ) THEN
        packetErrors = packetErrors+1
      ENDIF

C--   Validate every source and build same-rank tile ghosts in scratch.
      DO ip=1,MAX(0,MIN(nOwner,bomMaxOwnerRecord))
        ownerIdSort(ip) = ownerId(ip)
        IF ( ownerId(ip).LE.0_8 .OR.
     &       (ownerStatus(ip).NE.BOM_ALIVE .AND.
     &        ownerStatus(ip).NE.BOM_WAITING) .OR.
     &       ownerBi(ip).LT.1 .OR. ownerBi(ip).GT.nSx .OR.
     &       ownerBj(ip).LT.1 .OR. ownerBj(ip).GT.nSy .OR.
     &       .NOT.IEEE_IS_FINITE(ownerX(ip)) .OR.
     &       .NOT.IEEE_IS_FINITE(ownerY(ip)) ) THEN
          packetErrors = packetErrors+1
        ELSEIF ( ownerStatus(ip).EQ.BOM_ALIVE ) THEN
          DO bj=1,nSy
           DO bi=1,nSx
            IF ( bi.NE.ownerBi(ip) .OR.
     &           bj.NE.ownerBj(ip) ) THEN
              targetTileX = (myXGlobalLo-1)/sNx+bi-1
              targetTileY = (myYGlobalLo-1)/sNy+bj-1
              CALL BOM_GHOST_TILE_RELEVANT(
     I             ownerX(ip),ownerY(ip),
     I             targetTileX,targetTileY,
     O             relevant,routeValid,myThid)
              IF ( .NOT.routeValid ) THEN
                packetErrors = packetErrors+1
              ELSEIF ( relevant ) THEN
                ig = ghostCountWork(bi,bj)+1
                IF ( ig.GT.bomMaxGhostTile ) THEN
                  capacityErrors = capacityErrors+1
                ELSE
                  ghostCountWork(bi,bj) = ig
                  ghostIdWork(ig,bi,bj) = ownerId(ip)
                  ghostStatusWork(ig,bi,bj) = BOM_ALIVE
                  ghostRankWork(ig,bi,bj) = myProcId
                  ghostBiWork(ig,bi,bj) = ownerBi(ip)
                  ghostBjWork(ig,bi,bj) = ownerBj(ip)
                  ghostXWork(ig,bi,bj) = ownerX(ip)
                  ghostYWork(ig,bi,bj) = ownerY(ip)
                ENDIF
              ENDIF
            ENDIF
           ENDDO
          ENDDO

C--       One packet is sent to each rank with any relevant tile.
          DO rankIndex=1,nPx*nPy
            IF ( rankIndex-1.NE.myProcId ) THEN
              CALL BOM_GHOST_RANK_RELEVANT(
     I             ownerX(ip),ownerY(ip),rankIndex-1,
     O             rankRelevant,routeValid,myThid)
              IF ( .NOT.routeValid ) THEN
                packetErrors = packetErrors+1
              ELSEIF ( rankRelevant ) THEN
                sendCounts(rankIndex) =
     &               sendCounts(rankIndex)+1
              ENDIF
            ENDIF
          ENDDO
        ENDIF
      ENDDO

      IF ( nOwner.GT.1 .AND.
     &     nOwner.LE.bomMaxOwnerRecord ) THEN
        CALL BOM_GHOST_SORT_IDS(
     U       ownerIdSort,nOwner,bomMaxOwnerRecord,
     O       sortValid)
        IF ( .NOT.sortValid ) THEN
          packetErrors = packetErrors+1
        ELSE
          DO ip=2,nOwner
            IF ( ownerIdSort(ip).EQ.ownerIdSort(ip-1) )
     &           packetErrors = packetErrors+1
          ENDDO
        ENDIF
      ENDIF

      DO rankIndex=1,nPx*nPy
        sendDispls(rankIndex) = sendTotal
        IF ( sendCounts(rankIndex).LT.0 .OR.
     &       sendCounts(rankIndex).GT.
     &       bomMaxGhostExchange-sendTotal ) THEN
          capacityErrors = capacityErrors+1
        ELSE
          sendTotal = sendTotal+sendCounts(rankIndex)
        ENDIF
      ENDDO
      IF ( sendTotal.GT.bomMaxGhostExchange )
     &     capacityErrors = capacityErrors+1

      globalCapacityErrors = capacityErrors
      globalPacketErrors = packetErrors
      CALL GLOBAL_SUM_INT( globalCapacityErrors, myThid )
      CALL GLOBAL_SUM_INT( globalPacketErrors, myThid )
      IF ( globalCapacityErrors.GT.0 ) THEN
        failCode = BOM_FAIL_GHOST_CAPACITY
        RETURN
      ELSEIF ( globalPacketErrors.GT.0 ) THEN
        failCode = BOM_FAIL_GHOST_PACKET
        RETURN
      ENDIF

C--   Every MPI rank enters the count collective, including zero owners.
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Alltoall(
     I       sendCounts,1,MPI_INTEGER,
     O       recvCounts,1,MPI_INTEGER,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) packetErrors=packetErrors+1
      ELSE
#endif
        recvCounts(1) = 0
#ifdef ALLOW_USE_MPI
      ENDIF
#endif

      recvTotal = 0
      DO rankIndex=1,nPx*nPy
        recvDispls(rankIndex) = recvTotal
        IF ( recvCounts(rankIndex).LT.0 .OR.
     &       recvCounts(rankIndex).GT.
     &       bomMaxGhostExchange-recvTotal ) THEN
          capacityErrors = capacityErrors+1
        ELSE
          recvTotal = recvTotal+recvCounts(rankIndex)
        ENDIF
      ENDDO
      IF ( recvTotal.GT.bomMaxGhostExchange )
     &     capacityErrors = capacityErrors+1
      globalCapacityErrors = capacityErrors
      globalPacketErrors = packetErrors
      CALL GLOBAL_SUM_INT( globalCapacityErrors, myThid )
      CALL GLOBAL_SUM_INT( globalPacketErrors, myThid )
      IF ( globalCapacityErrors.GT.0 ) THEN
        failCode = BOM_FAIL_GHOST_CAPACITY
        RETURN
      ELSEIF ( globalPacketErrors.GT.0 ) THEN
        failCode = BOM_FAIL_GHOST_PACKET
        RETURN
      ENDIF

C--   Pack in destination-rank then input-owner order.
      DO rankIndex=1,nPx*nPy
        packetCursor(rankIndex) = sendDispls(rankIndex)
      ENDDO
      DO ip=1,nOwner
        IF ( ownerStatus(ip).EQ.BOM_ALIVE ) THEN
          DO rankIndex=1,nPx*nPy
            IF ( rankIndex-1.NE.myProcId ) THEN
              CALL BOM_GHOST_RANK_RELEVANT(
     I             ownerX(ip),ownerY(ip),rankIndex-1,
     O             rankRelevant,routeValid,myThid)
              IF ( routeValid .AND. rankRelevant ) THEN
                packetIndex = packetCursor(rankIndex)+1
                packetCursor(rankIndex) = packetIndex
                idHi8 = ownerId(ip)/idRadix
                idLo8 = MOD(ownerId(ip),idRadix)
                sendInt(1,packetIndex) = bomGhostSchema
                sendInt(2,packetIndex) = ghostStage
                sendInt(3,packetIndex) = ghostEpoch
                sendInt(4,packetIndex) = INT(idHi8)
                IF ( idLo8.GT.2147483647_8 ) THEN
                  sendInt(5,packetIndex) = INT(idLo8-idRadix)
                ELSE
                  sendInt(5,packetIndex) = INT(idLo8)
                ENDIF
                sendInt(6,packetIndex) = BOM_ALIVE
                sendInt(7,packetIndex) = myProcId
                sendInt(8,packetIndex) = ownerBi(ip)
                sendInt(9,packetIndex) = ownerBj(ip)
                sendReal(1,packetIndex) = ownerX(ip)
                sendReal(2,packetIndex) = ownerY(ip)
              ENDIF
            ENDIF
          ENDDO
        ENDIF
      ENDDO
      DO rankIndex=1,nPx*nPy
        IF ( packetCursor(rankIndex).NE.
     &       sendDispls(rankIndex)+sendCounts(rankIndex) )
     &       packetErrors = packetErrors+1
        sendCountsI(rankIndex) =
     &       bomGhostPacketInts*sendCounts(rankIndex)
        recvCountsI(rankIndex) =
     &       bomGhostPacketInts*recvCounts(rankIndex)
        sendDisplsI(rankIndex) =
     &       bomGhostPacketInts*sendDispls(rankIndex)
        recvDisplsI(rankIndex) =
     &       bomGhostPacketInts*recvDispls(rankIndex)
        sendCountsR(rankIndex) =
     &       bomGhostPacketReals*sendCounts(rankIndex)
        recvCountsR(rankIndex) =
     &       bomGhostPacketReals*recvCounts(rankIndex)
        sendDisplsR(rankIndex) =
     &       bomGhostPacketReals*sendDispls(rankIndex)
        recvDisplsR(rankIndex) =
     &       bomGhostPacketReals*recvDispls(rankIndex)
      ENDDO

#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Alltoallv(
     I       sendInt,sendCountsI,sendDisplsI,MPI_INTEGER,
     O       recvInt,recvCountsI,recvDisplsI,MPI_INTEGER,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) packetErrors=packetErrors+1
        CALL MPI_Alltoallv(
     I       sendReal,sendCountsR,sendDisplsR,_MPI_TYPE_RL,
     O       recvReal,recvCountsR,recvDisplsR,_MPI_TYPE_RL,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) packetErrors=packetErrors+1
      ENDIF
#endif
      globalPacketErrors = packetErrors
      CALL GLOBAL_SUM_INT( globalPacketErrors, myThid )
      IF ( globalPacketErrors.GT.0 ) THEN
        failCode = BOM_FAIL_GHOST_PACKET
        RETURN
      ENDIF

C--   Validate source-ranked packets and exact IDs before tile routing.
      DO rankIndex=1,nPx*nPy
        sourceRank = rankIndex-1
        DO cursor=1,recvCounts(rankIndex)
          packetIndex = recvDispls(rankIndex)+cursor
          packetValid = .TRUE.
          IF ( recvInt(1,packetIndex).NE.bomGhostSchema .OR.
     &         recvInt(2,packetIndex).NE.ghostStage .OR.
     &         recvInt(3,packetIndex).NE.ghostEpoch .OR.
     &         recvInt(6,packetIndex).NE.BOM_ALIVE .OR.
     &         recvInt(7,packetIndex).NE.sourceRank .OR.
     &         recvInt(8,packetIndex).LT.1 .OR.
     &         recvInt(8,packetIndex).GT.nSx .OR.
     &         recvInt(9,packetIndex).LT.1 .OR.
     &         recvInt(9,packetIndex).GT.nSy )
     &         packetValid = .FALSE.
          idHi8 = INT(recvInt(4,packetIndex),8)
          idLo8 = INT(recvInt(5,packetIndex),8)
          IF ( idLo8.LT.0_8 ) idLo8=idLo8+idRadix
          IF ( idHi8.LT.0_8 ) THEN
            packetValid = .FALSE.
            packetId = 0_8
          ELSE
            packetId = idHi8*idRadix+idLo8
            IF ( packetId.LE.0_8 ) packetValid=.FALSE.
          ENDIF
          IF ( .NOT.IEEE_IS_FINITE(recvReal(1,packetIndex))
     &         .OR.
     &         .NOT.IEEE_IS_FINITE(recvReal(2,packetIndex)) )
     &         packetValid = .FALSE.
          recvIdSort(packetIndex) = packetId
          IF ( .NOT.packetValid ) packetErrors=packetErrors+1
        ENDDO
      ENDDO
      IF ( recvTotal.GT.1 ) THEN
        CALL BOM_GHOST_SORT_IDS(
     U       recvIdSort,recvTotal,bomMaxGhostExchange,
     O       sortValid)
        IF ( .NOT.sortValid ) THEN
          packetErrors = packetErrors+1
        ELSE
          DO packetIndex=2,recvTotal
            IF ( recvIdSort(packetIndex).EQ.
     &           recvIdSort(packetIndex-1) )
     &           packetErrors = packetErrors+1
          ENDDO
        ENDIF
      ENDIF

C--   A relevant remote owner may not collide with any local owner ID.
C     Sorting the combined transaction avoids a quadratic validation path.
      DO ip=1,nOwner
        transactionIdSort(ip) = ownerId(ip)
      ENDDO
      DO packetIndex=1,recvTotal
        transactionIdSort(nOwner+packetIndex) =
     &       recvIdSort(packetIndex)
      ENDDO
      IF ( nOwner+recvTotal.GT.1 ) THEN
        CALL BOM_GHOST_SORT_IDS(
     U       transactionIdSort,nOwner+recvTotal,
     I       bomMaxOwnerRecord+bomMaxGhostExchange,
     O       sortValid)
        IF ( .NOT.sortValid ) THEN
          packetErrors = packetErrors+1
        ELSE
          DO packetIndex=2,nOwner+recvTotal
            IF ( transactionIdSort(packetIndex).EQ.
     &           transactionIdSort(packetIndex-1) )
     &           packetErrors = packetErrors+1
          ENDDO
        ENDIF
      ENDIF

C--   Reconstruct every valid remote packet and route it independently.
      DO rankIndex=1,nPx*nPy
        sourceRank = rankIndex-1
        DO cursor=1,recvCounts(rankIndex)
          packetIndex = recvDispls(rankIndex)+cursor
          idHi8 = INT(recvInt(4,packetIndex),8)
          idLo8 = INT(recvInt(5,packetIndex),8)
          IF ( idLo8.LT.0_8 ) idLo8=idLo8+idRadix
          packetId = idHi8*idRadix+idLo8
          anyRelevant = .FALSE.
          DO bj=1,nSy
           DO bi=1,nSx
            targetTileX = (myXGlobalLo-1)/sNx+bi-1
            targetTileY = (myYGlobalLo-1)/sNy+bj-1
            CALL BOM_GHOST_TILE_RELEVANT(
     I           recvReal(1,packetIndex),
     I           recvReal(2,packetIndex),
     I           targetTileX,targetTileY,
     O           relevant,routeValid,myThid)
            IF ( .NOT.routeValid ) THEN
              packetErrors = packetErrors+1
            ELSEIF ( relevant ) THEN
              anyRelevant = .TRUE.
              ig = ghostCountWork(bi,bj)+1
              IF ( ig.GT.bomMaxGhostTile ) THEN
                capacityErrors = capacityErrors+1
              ELSE
                ghostCountWork(bi,bj) = ig
                ghostIdWork(ig,bi,bj) = packetId
                ghostStatusWork(ig,bi,bj) = BOM_ALIVE
                ghostRankWork(ig,bi,bj) = sourceRank
                ghostBiWork(ig,bi,bj) = recvInt(8,packetIndex)
                ghostBjWork(ig,bi,bj) = recvInt(9,packetIndex)
                ghostXWork(ig,bi,bj) = recvReal(1,packetIndex)
                ghostYWork(ig,bi,bj) = recvReal(2,packetIndex)
              ENDIF
            ENDIF
           ENDDO
          ENDDO
          IF ( .NOT.anyRelevant ) packetErrors=packetErrors+1
        ENDDO
      ENDDO

C--   Sort every tile by exact positive ID and reject duplicate ghosts.
      DO bj=1,nSy
       DO bi=1,nSx
        CALL BOM_GHOST_SORT_TILE(
     I       ghostCountWork(bi,bj),bi,bj,
     U       ghostIdWork,ghostStatusWork,ghostRankWork,
     U       ghostBiWork,ghostBjWork,ghostXWork,ghostYWork,
     O       sortValid)
        IF ( .NOT.sortValid ) THEN
          packetErrors = packetErrors+1
        ELSE
          DO ig=2,ghostCountWork(bi,bj)
            IF ( ghostIdWork(ig,bi,bj).EQ.
     &           ghostIdWork(ig-1,bi,bj) )
     &           packetErrors = packetErrors+1
          ENDDO
        ENDIF
       ENDDO
      ENDDO

      globalCapacityErrors = capacityErrors
      globalPacketErrors = packetErrors
      CALL GLOBAL_SUM_INT( globalCapacityErrors, myThid )
      CALL GLOBAL_SUM_INT( globalPacketErrors, myThid )
      IF ( globalCapacityErrors.GT.0 ) THEN
        failCode = BOM_FAIL_GHOST_CAPACITY
        RETURN
      ELSEIF ( globalPacketErrors.GT.0 ) THEN
        failCode = BOM_FAIL_GHOST_PACKET
        RETURN
      ENDIF

C--   The only publication point in the transaction.
      DO bj=1,nSy
       DO bi=1,nSx
        bomNGhostTile(bi,bj) = ghostCountWork(bi,bj)
        DO ig=1,ghostCountWork(bi,bj)
          bomGhostId(ig,bi,bj) = ghostIdWork(ig,bi,bj)
          bomGhostStatus(ig,bi,bj) = ghostStatusWork(ig,bi,bj)
          bomGhostSourceRank(ig,bi,bj) =
     &         ghostRankWork(ig,bi,bj)
          bomGhostSourceBi(ig,bi,bj) = ghostBiWork(ig,bi,bj)
          bomGhostSourceBj(ig,bi,bj) = ghostBjWork(ig,bi,bj)
          bomGhostX(ig,bi,bj) = ghostXWork(ig,bi,bj)
          bomGhostY(ig,bi,bj) = ghostYWork(ig,bi,bj)
        ENDDO
        bomGhostReady(bi,bj) = .TRUE.
       ENDDO
      ENDDO
      bomGhostStage = ghostStage
      bomGhostEpoch = ghostEpoch
      bomGhostSubstep = ghostSubstep
      bomGhostRecordsSent = INT(sendTotal,8)
      bomGhostRecordsReceived = INT(recvTotal,8)
      bomGhostBytesSent = INT(sendTotal,8)
     &     *INT(bomGhostPacketBytes,8)
      bomGhostBytesReceived = INT(recvTotal,8)
     &     *INT(bomGhostPacketBytes,8)
      failCode = BOM_FAIL_NONE
      p3FailPhase = BOM_P3_PHASE_NONE
      exchangeValid = .TRUE.
#endif /* ALLOW_BOM */

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_GHOST_INVALIDATE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER bi, bj
      bomGhostStage = BOM_STAGE_NONE
      bomGhostEpoch = 0
      bomGhostSubstep = 0
      DO bj=1,nSy
       DO bi=1,nSx
        bomNGhostTile(bi,bj) = 0
        bomGhostReady(bi,bj) = .FALSE.
       ENDDO
      ENDDO
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_GHOST_RANK_RELEVANT(
     I                 xx, yy, targetRank,
     O                 relevant, isValid, myThid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
      _RL xx, yy
      INTEGER targetRank, myThid
      LOGICAL relevant, isValid
      INTEGER bi, bj, tileX, tileY, xGlobalLo, yGlobalLo
      LOGICAL tileRelevant, tileValid

      relevant = .FALSE.
      isValid = .FALSE.
      IF ( targetRank.LT.0 .OR.
     &     targetRank.GE.nPx*nPy ) RETURN
      IF ( targetRank.EQ.myProcId ) THEN
        xGlobalLo = myXGlobalLo
        yGlobalLo = myYGlobalLo
      ELSE
#ifdef ALLOW_USE_MPI
        IF ( .NOT.usingMPI ) RETURN
        xGlobalLo = mpi_myXGlobalLo(targetRank+1)
        yGlobalLo = mpi_myYGlobalLo(targetRank+1)
#else
        RETURN
#endif
      ENDIF
      IF ( xGlobalLo.LT.1 .OR. yGlobalLo.LT.1 ) RETURN
      DO bj=1,nSy
       DO bi=1,nSx
        tileX = (xGlobalLo-1)/sNx+bi-1
        tileY = (yGlobalLo-1)/sNy+bj-1
        CALL BOM_GHOST_TILE_RELEVANT(
     I       xx,yy,tileX,tileY,
     O       tileRelevant,tileValid,myThid)
        IF ( .NOT.tileValid ) RETURN
        relevant = relevant.OR.tileRelevant
       ENDDO
      ENDDO
      isValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_GHOST_TILE_RELEVANT(
     I                 xx, yy, tileX, tileY,
     O                 relevant, isValid, myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL xx, yy
      INTEGER tileX, tileY, myThid
      LOGICAL relevant, isValid
      _RL xMap, xLo, xHi, yLo, yHi, dx, dy
      _RL xPlus, xMinus, testDistance, xPeriod
      _RL midLo, midHi, maxAbsMid, cosMin
      _RL metric, dxPhysical, dyPhysical, distance
      LOGICAL calcValid, normValid, insideX

      relevant = .FALSE.
      isValid = .FALSE.
      IF ( tileX.LT.0 .OR. tileX.GE.nPx*nSx .OR.
     &     tileY.LT.0 .OR. tileY.GE.nPy*nSy ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(xx) .OR.
     &     .NOT.IEEE_IS_FINITE(yy) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(bomNeighborCutoff) .OR.
     &     bomNeighborCutoff.LE.0. _d 0 ) RETURN
      CALL BOM_NORMALIZE_X(xx,xMap,insideX,myThid)
      IF ( .NOT.insideX ) RETURN
      IF ( yy.LT.bomMapYLo .OR. yy.GE.bomMapYHi ) RETURN
      xLo = bomMapXFace(tileX*sNx)
      xHi = bomMapXFace((tileX+1)*sNx)
      yLo = bomMapYFace(tileY*sNy)
      yHi = bomMapYFace((tileY+1)*sNy)
      IF ( xHi.LE.xLo .OR. yHi.LE.yLo ) RETURN

      IF ( xMap.LT.xLo ) THEN
        dx = xLo-xMap
      ELSEIF ( xMap.GT.xHi ) THEN
        dx = xMap-xHi
      ELSE
        dx = 0. _d 0
      ENDIF
      IF ( bomMapPeriodicX ) THEN
        xPeriod = bomMapXPeriod
        CALL BOM_SAFE_ADD_RL(xMap,xPeriod,xPlus,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_ADD_RL(xMap,-xPeriod,xMinus,calcValid)
        IF ( .NOT.calcValid ) RETURN
        IF ( xPlus.LT.xLo ) THEN
          testDistance = xLo-xPlus
        ELSEIF ( xPlus.GT.xHi ) THEN
          testDistance = xPlus-xHi
        ELSE
          testDistance = 0. _d 0
        ENDIF
        dx = MIN(dx,testDistance)
        IF ( xMinus.LT.xLo ) THEN
          testDistance = xLo-xMinus
        ELSEIF ( xMinus.GT.xHi ) THEN
          testDistance = xMinus-xHi
        ELSE
          testDistance = 0. _d 0
        ENDIF
        dx = MIN(dx,testDistance)
      ENDIF
      IF ( yy.LT.yLo ) THEN
        dy = yLo-yy
      ELSEIF ( yy.GT.yHi ) THEN
        dy = yy-yHi
      ELSE
        dy = 0. _d 0
      ENDIF

      IF ( usingCartesianGrid .AND.
     &     .NOT.usingSphericalPolarGrid ) THEN
        dxPhysical = dx
        dyPhysical = dy
      ELSEIF ( usingSphericalPolarGrid .AND.
     &         .NOT.usingCartesianGrid ) THEN
        IF ( .NOT.IEEE_IS_FINITE(rSphere) .OR.
     &       rSphere.LE.0. _d 0 ) RETURN
        CALL BOM_SAFE_ADD_RL(yy,yLo,midLo,calcValid)
        IF ( .NOT.calcValid ) RETURN
        midLo = halfRL*midLo
        CALL BOM_SAFE_ADD_RL(yy,yHi,midHi,calcValid)
        IF ( .NOT.calcValid ) RETURN
        midHi = halfRL*midHi
        maxAbsMid = MAX(ABS(midLo),ABS(midHi))
        IF ( maxAbsMid.GT.90. _d 0 ) RETURN
        cosMin = ABS(COS(deg2rad*maxAbsMid))
        IF ( .NOT.IEEE_IS_FINITE(cosMin) .OR.
     &       cosMin.LT.SQRT(EPSILON(oneRL)) ) RETURN
        CALL BOM_SAFE_MULT_RL(rSphere,deg2rad,metric,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_MULT_RL(metric,cosMin,
     O                        testDistance,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_MULT_RL(testDistance,dx,
     O                        dxPhysical,calcValid)
        IF ( .NOT.calcValid ) RETURN
        CALL BOM_SAFE_MULT_RL(metric,dy,
     O                        dyPhysical,calcValid)
        IF ( .NOT.calcValid ) RETURN
      ELSE
        RETURN
      ENDIF
      CALL BOM_SAFE_NORM2_RL(
     I     dxPhysical,dyPhysical,
     O     distance,normValid)
      IF ( .NOT.normValid ) RETURN
      relevant = distance.LE.bomNeighborCutoff
      isValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_GHOST_SORT_IDS(
     U                 values,
     I                 nValue, capacity,
     O                 isValid )
      IMPLICIT NONE
      INTEGER nValue, capacity
      INTEGER*8 values(*)
      LOGICAL isValid
      INTEGER start, finish, root, child
      INTEGER*8 swapValue

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
          swapValue = values(root)
          values(root) = values(child)
          values(child) = swapValue
          root = child
        ENDDO
  110   CONTINUE
      ENDDO
      DO finish=nValue,2,-1
        swapValue = values(1)
        values(1) = values(finish)
        values(finish) = swapValue
        root = 1
        DO WHILE ( 2*root.LE.finish-1 )
          child = 2*root
          IF ( child.LT.finish-1 ) THEN
            IF ( values(child).LT.values(child+1) ) child=child+1
          ENDIF
          IF ( values(root).GE.values(child) ) GOTO 120
          swapValue = values(root)
          values(root) = values(child)
          values(child) = swapValue
          root = child
        ENDDO
  120   CONTINUE
      ENDDO
      isValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_GHOST_SORT_TILE(
     I                 nGhost, bi, bj,
     U                 ghostId, ghostStatus, ghostRank,
     U                 ghostBi, ghostBj, ghostX, ghostY,
     O                 isValid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
      INTEGER nGhost, bi, bj
      INTEGER*8 ghostId(bomMaxGhostTile,nSx,nSy)
      INTEGER ghostStatus(bomMaxGhostTile,nSx,nSy)
      INTEGER ghostRank(bomMaxGhostTile,nSx,nSy)
      INTEGER ghostBi(bomMaxGhostTile,nSx,nSy)
      INTEGER ghostBj(bomMaxGhostTile,nSx,nSy)
      _RL ghostX(bomMaxGhostTile,nSx,nSy)
      _RL ghostY(bomMaxGhostTile,nSx,nSy)
      LOGICAL isValid
      INTEGER start, finish, root, child

      isValid = .FALSE.
      IF ( bi.LT.1 .OR. bi.GT.nSx .OR.
     &     bj.LT.1 .OR. bj.GT.nSy .OR.
     &     nGhost.LT.0 .OR. nGhost.GT.bomMaxGhostTile ) RETURN
      DO start=nGhost/2,1,-1
        root = start
        DO WHILE ( 2*root.LE.nGhost )
          child = 2*root
          IF ( child.LT.nGhost ) THEN
            IF ( ghostId(child,bi,bj).LT.
     &           ghostId(child+1,bi,bj) ) child=child+1
          ENDIF
          IF ( ghostId(root,bi,bj).GE.
     &         ghostId(child,bi,bj) ) GOTO 210
          CALL BOM_GHOST_SWAP(
     I         root,child,bi,bj,
     U         ghostId,ghostStatus,ghostRank,
     U         ghostBi,ghostBj,ghostX,ghostY)
          root = child
        ENDDO
  210   CONTINUE
      ENDDO
      DO finish=nGhost,2,-1
        CALL BOM_GHOST_SWAP(
     I       1,finish,bi,bj,
     U       ghostId,ghostStatus,ghostRank,
     U       ghostBi,ghostBj,ghostX,ghostY)
        root = 1
        DO WHILE ( 2*root.LE.finish-1 )
          child = 2*root
          IF ( child.LT.finish-1 ) THEN
            IF ( ghostId(child,bi,bj).LT.
     &           ghostId(child+1,bi,bj) ) child=child+1
          ENDIF
          IF ( ghostId(root,bi,bj).GE.
     &         ghostId(child,bi,bj) ) GOTO 220
          CALL BOM_GHOST_SWAP(
     I         root,child,bi,bj,
     U         ghostId,ghostStatus,ghostRank,
     U         ghostBi,ghostBj,ghostX,ghostY)
          root = child
        ENDDO
  220   CONTINUE
      ENDDO
      isValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_GHOST_SWAP(
     I                 slotA, slotB, bi, bj,
     U                 ghostId, ghostStatus, ghostRank,
     U                 ghostBi, ghostBj, ghostX, ghostY )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
      INTEGER slotA, slotB, bi, bj
      INTEGER*8 ghostId(bomMaxGhostTile,nSx,nSy), swapId
      INTEGER ghostStatus(bomMaxGhostTile,nSx,nSy)
      INTEGER ghostRank(bomMaxGhostTile,nSx,nSy)
      INTEGER ghostBi(bomMaxGhostTile,nSx,nSy)
      INTEGER ghostBj(bomMaxGhostTile,nSx,nSy)
      INTEGER swapInteger
      _RL ghostX(bomMaxGhostTile,nSx,nSy)
      _RL ghostY(bomMaxGhostTile,nSx,nSy), swapReal

      swapId = ghostId(slotA,bi,bj)
      ghostId(slotA,bi,bj) = ghostId(slotB,bi,bj)
      ghostId(slotB,bi,bj) = swapId
      swapInteger = ghostStatus(slotA,bi,bj)
      ghostStatus(slotA,bi,bj) = ghostStatus(slotB,bi,bj)
      ghostStatus(slotB,bi,bj) = swapInteger
      swapInteger = ghostRank(slotA,bi,bj)
      ghostRank(slotA,bi,bj) = ghostRank(slotB,bi,bj)
      ghostRank(slotB,bi,bj) = swapInteger
      swapInteger = ghostBi(slotA,bi,bj)
      ghostBi(slotA,bi,bj) = ghostBi(slotB,bi,bj)
      ghostBi(slotB,bi,bj) = swapInteger
      swapInteger = ghostBj(slotA,bi,bj)
      ghostBj(slotA,bi,bj) = ghostBj(slotB,bi,bj)
      ghostBj(slotB,bi,bj) = swapInteger
      swapReal = ghostX(slotA,bi,bj)
      ghostX(slotA,bi,bj) = ghostX(slotB,bi,bj)
      ghostX(slotB,bi,bj) = swapReal
      swapReal = ghostY(slotA,bi,bj)
      ghostY(slotA,bi,bj) = ghostY(slotB,bi,bj)
      ghostY(slotB,bi,bj) = swapReal
      RETURN
      END
