#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C     !ROUTINE: BOM_CHECK_STATE
C     !INTERFACE:
      SUBROUTINE BOM_CHECK_STATE(
     I                 checkTime, checkIter, checkContext, myThid )

C     !DESCRIPTION:
C     Validate the complete Phase-1.3 compact-owner budget.  Global
C     ID uniqueness is checked exactly after gathering the schema-1 high
C     and low 32-bit words as integers and sorting the word pairs.

C     !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE

C     !INCLUDES:
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C     !INPUT PARAMETERS:
      _RL checkTime
      INTEGER checkIter
      CHARACTER*(*) checkContext
      INTEGER myThid

C     !LOCAL VARIABLES:
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi, bj, ip, jp, iDiag
      INTEGER nTile, nSafe
      INTEGER localErrCount, globalErrCount
      INTEGER localOwnerCount, globalOwnerCount
      INTEGER expectedLiveCount
      INTEGER localIdCount, globalIdCount
      INTEGER idCounts(nPx*nPy)
      INTEGER idDispls(nPx*nPy)
      INTEGER idHiLocal(bomMaxInitRecords)
      INTEGER idLoLocal(bomMaxInitRecords)
      INTEGER idHiGlobal(bomMaxInitRecords)
      INTEGER idLoGlobal(bomMaxInitRecords)
      INTEGER mpiRC
      INTEGER mpiErrCount
      INTEGER*8 idRadix
      INTEGER*8 idHi8
      INTEGER*8 idLo8
      _RL xMap, ix, jy
      _RL sampleEast, sampleNorth, wetWeight
      _RL timeScale, timeTol
      LOGICAL timeValid, fieldsFinite
      LOGICAL isOwner, hasStencil, interpValid
      LOGICAL nearRelease, compareValid
CEOP

      localErrCount = 0
      localOwnerCount = 0
      localIdCount = 0
      mpiErrCount = 0
      idRadix = 4294967296_8
      expectedLiveCount = bomNPartExpected
      IF ( bomUseLand .OR. bomUseBiology )
     &     expectedLiveCount=bomNPartLiveExpected
      DO ip=1,bomMaxInitRecords
        idHiLocal(ip) = 0
        idLoLocal(ip) = 0
        idHiGlobal(ip) = 0
        idLoGlobal(ip) = 0
      ENDDO
      DO ip=1,nPx*nPy
        idCounts(ip) = 0
        idDispls(ip) = 0
      ENDDO

      timeValid = IEEE_IS_FINITE(checkTime)
      IF ( .NOT.timeValid ) THEN
        WRITE(msgBuf,'(A,A,A,1PE24.16)')
     &       'BOM_CHECK_STATE: context=', checkContext,
     &       ' non-finite checkTime=', checkTime
        CALL PRINT_ERROR( msgBuf, myThid )
        localErrCount = localErrCount + 1
      ENDIF
      IF ( bomNPartExpected.LT.0 .OR.
     &     bomNPartExpected.GT.bomInitGlobalLimit .OR.
     &     bomNPartExpected.GT.bomMaxInitRecords ) THEN
        WRITE(msgBuf,'(A,A,A,3I10)')
     &       'BOM_CHECK_STATE: context=', checkContext,
     &       ' invalid expected/limits=', bomNPartExpected,
     &       bomInitGlobalLimit, bomMaxInitRecords
        CALL PRINT_ERROR( msgBuf, myThid )
        localErrCount = localErrCount + 1
      ENDIF
      IF ( expectedLiveCount.LT.0 .OR.
     &     expectedLiveCount.GT.bomInitGlobalLimit .OR.
     &     expectedLiveCount.GT.bomMaxInitRecords )
     &     localErrCount=localErrCount+1
      IF ( .NOT.bomFieldsReady ) THEN
        WRITE(msgBuf,'(A,A,A)')
     &       'BOM_CHECK_STATE: context=', checkContext,
     &       ' frozen fields are not ready'
        CALL PRINT_ERROR( msgBuf, myThid )
        localErrCount = localErrCount + 1
      ENDIF

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        nTile = bomNPartTile(bi,bj)
        nSafe = MAX(0,MIN(bomMaxPartTile,nTile))
        IF ( nTile.LT.0 .OR. nTile.GT.bomMaxPartTile ) THEN
          IF ( localErrCount.LT.8 ) THEN
            WRITE(msgBuf,'(A,A,A,I6,A,2I5,A,I8)')
     &           'BOM_CHECK_STATE: context=', checkContext,
     &           ' rank=', myProcId, ' tile=', bi, bj,
     &           ' invalid count=', nTile
            CALL PRINT_ERROR( msgBuf, myThid )
          ENDIF
          localErrCount = localErrCount + 1
        ENDIF

        DO ip=1,bomMaxPartTile
          IF ( ip.LE.nSafe ) THEN
            localOwnerCount = localOwnerCount + 1

            IF ( bomId(ip,bi,bj).LE.0 ) THEN
              IF ( localErrCount.LT.8 ) THEN
                WRITE(msgBuf,'(A,A,A,I6,A,3I5,A,I20)')
     &               'BOM_CHECK_STATE: context=', checkContext,
     &               ' rank=', myProcId, ' tile/slot=', bi, bj, ip,
     &               ' invalid id=', bomId(ip,bi,bj)
                CALL PRINT_ERROR( msgBuf, myThid )
              ENDIF
              localErrCount = localErrCount + 1
            ELSEIF ( localIdCount.GE.bomMaxInitRecords ) THEN
              localErrCount = localErrCount + 1
            ELSE
              localIdCount = localIdCount + 1
              idHi8 = bomId(ip,bi,bj)/idRadix
              idLo8 = MOD(bomId(ip,bi,bj),idRadix)
              idHiLocal(localIdCount) = INT(idHi8)
              IF ( idLo8.GT.2147483647_8 ) THEN
                idLoLocal(localIdCount) = INT(idLo8-idRadix)
              ELSE
                idLoLocal(localIdCount) = INT(idLo8)
              ENDIF
            ENDIF

            IF ( bomStatus(ip,bi,bj).NE.BOM_ALIVE .AND.
     &           bomStatus(ip,bi,bj).NE.BOM_WAITING ) THEN
              IF ( localErrCount.LT.8 ) THEN
                WRITE(msgBuf,'(A,A,A,I6,A,3I5,A,I5)')
     &               'BOM_CHECK_STATE: context=', checkContext,
     &               ' rank=', myProcId, ' tile/slot=', bi, bj, ip,
     &               ' invalid status=', bomStatus(ip,bi,bj)
                CALL PRINT_ERROR( msgBuf, myThid )
              ENDIF
              localErrCount = localErrCount + 1
            ENDIF

            fieldsFinite =
     &           IEEE_IS_FINITE(bomX(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomY(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomReleaseTime(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomAge(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomI(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomJ(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomVEast(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomVNorth(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomWindEast(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomWindNorth(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomDriftEast(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomDriftNorth(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomSpringEast(ip,bi,bj)) .AND.
     &           IEEE_IS_FINITE(bomSpringNorth(ip,bi,bj))
            DO iDiag=1,BOM_RHS_NDIAG
              fieldsFinite = fieldsFinite .AND.
     &             IEEE_IS_FINITE(bomRhsDiag(iDiag,ip,bi,bj))
            ENDDO
            IF ( .NOT.fieldsFinite .OR.
     &           bomAge(ip,bi,bj).LT.0. _d 0 .OR.
     &           bomReleaseTime(ip,bi,bj).LT.0. _d 0 ) THEN
              IF ( localErrCount.LT.8 ) THEN
                WRITE(msgBuf,'(A,A,A,I6,A,3I5,A,I20)')
     &               'BOM_CHECK_STATE: context=', checkContext,
     &               ' rank=', myProcId, ' tile/slot=', bi, bj, ip,
     &               ' non-finite/range id=', bomId(ip,bi,bj)
                CALL PRINT_ERROR( msgBuf, myThid )
              ENDIF
              localErrCount = localErrCount + 1
            ELSEIF ( timeValid ) THEN
              timeScale = MAX( oneRL, ABS(checkTime),
     &                         ABS(bomReleaseTime(ip,bi,bj)) )
              timeTol = 16. _d 0*EPSILON(oneRL)*timeScale
              CALL BOM_TIME_NEAR(
     I             bomReleaseTime(ip,bi,bj), checkTime, timeTol,
     O             nearRelease, compareValid )
              IF ( .NOT.compareValid ) THEN
                localErrCount = localErrCount + 1
              ELSEIF ( bomStatus(ip,bi,bj).EQ.BOM_WAITING ) THEN
                IF ( bomAge(ip,bi,bj).NE.0. _d 0 .OR.
     &               bomReleaseTime(ip,bi,bj).LT.checkTime .OR.
     &               nearRelease ) THEN
                  IF ( localErrCount.LT.8 ) THEN
                    WRITE(msgBuf,'(A,A,A,I20,A,3(1X,1PE24.16))')
     &                   'BOM_CHECK_STATE: context=', checkContext,
     &                   ' invalid WAITING id=', bomId(ip,bi,bj),
     &                   ' release/time/age=',
     &                   bomReleaseTime(ip,bi,bj), checkTime,
     &                   bomAge(ip,bi,bj)
                    CALL PRINT_ERROR( msgBuf, myThid )
                  ENDIF
                  localErrCount = localErrCount + 1
                ENDIF
              ELSEIF ( bomStatus(ip,bi,bj).EQ.BOM_ALIVE ) THEN
                IF ( bomReleaseTime(ip,bi,bj).GT.checkTime .AND.
     &               .NOT.nearRelease ) THEN
                  IF ( localErrCount.LT.8 ) THEN
                    WRITE(msgBuf,'(A,A,A,I20,A,2(1X,1PE24.16))')
     &                   'BOM_CHECK_STATE: context=', checkContext,
     &                   ' future ALIVE id=', bomId(ip,bi,bj),
     &                   ' release/time=',
     &                   bomReleaseTime(ip,bi,bj), checkTime
                    CALL PRINT_ERROR( msgBuf, myThid )
                  ENDIF
                  localErrCount = localErrCount + 1
                ENDIF
              ENDIF
            ENDIF

C--         Phase-3 owner fields are bounded even before P3.4 activates
C           nonzero raft labels.  The NONE path must remain all-zero.
            IF ( bomNeighborCount(ip,bi,bj).LT.0 .OR.
     &           bomNeighborCount(ip,bi,bj).GT.bomMaxNeighbor .OR.
     &           bomRaftId(ip,bi,bj).LT.0_8 .OR.
     &           bomRaftSize(ip,bi,bj).LT.0 .OR.
     &           (bomRaftId(ip,bi,bj).EQ.0_8 .AND.
     &            bomRaftSize(ip,bi,bj).NE.0) .OR.
     &           (bomRaftId(ip,bi,bj).GT.0_8 .AND.
     &            bomRaftSize(ip,bi,bj).LT.1) ) THEN
              localErrCount = localErrCount+1
            ENDIF
            IF ( bomSpringLaw.EQ.'NONE' ) THEN
              IF ( bomSpringEast(ip,bi,bj).NE.0. _d 0 .OR.
     &             bomSpringNorth(ip,bi,bj).NE.0. _d 0 .OR.
     &             bomNeighborCount(ip,bi,bj).NE.0 .OR.
     &             bomRaftId(ip,bi,bj).NE.0_8 .OR.
     &             bomRaftSize(ip,bi,bj).NE.0 )
     &             localErrCount = localErrCount+1
            ENDIF

C--         Mapping ownership and the wet pair must still be valid.
            xMap = bomX(ip,bi,bj)
            ix = -1. _d 0
            jy = -1. _d 0
            isOwner = .FALSE.
            hasStencil = .FALSE.
            interpValid = .FALSE.
            sampleEast = 0. _d 0
            sampleNorth = 0. _d 0
            wetWeight = 0. _d 0
            CALL BOM_MAP_XY2IJLOCAL(
     I           bomX(ip,bi,bj), bomY(ip,bi,bj), bi, bj,
     O           xMap, ix, jy, isOwner, hasStencil,
     I           myThid )
            IF ( isOwner .AND. hasStencil .AND.
     &           bomFieldsReady ) THEN
              CALL BOM_INTERP_WET_PAIR(
     I             ix, jy, bi, bj,
     I             bomGridVEast, bomGridVNorth,
     O             sampleEast, sampleNorth,
     O             wetWeight, interpValid,
     I             myThid )
            ENDIF
            IF ( .NOT.isOwner .OR. .NOT.hasStencil .OR.
     &           .NOT.interpValid .OR.
     &           bomI(ip,bi,bj).NE.ix .OR.
     &           bomJ(ip,bi,bj).NE.jy ) THEN
              IF ( localErrCount.LT.8 ) THEN
                WRITE(msgBuf,'(A,A,A,I6,A,3I5,A,I20)')
     &               'BOM_CHECK_STATE: context=', checkContext,
     &               ' rank=', myProcId, ' tile/slot=', bi, bj, ip,
     &               ' owner/stencil failure id=', bomId(ip,bi,bj)
                CALL PRINT_ERROR( msgBuf, myThid )
                WRITE(msgBuf,'(A,4(1X,1PE24.16),3L3)')
     &               'BOM_CHECK_STATE: stored/mapped ij wet flags=',
     &               bomI(ip,bi,bj), bomJ(ip,bi,bj), ix, jy,
     &               isOwner, hasStencil, interpValid
                CALL PRINT_ERROR( msgBuf, myThid )
              ENDIF
              localErrCount = localErrCount + 1
            ENDIF
          ELSE
C--         Compact tails retain the authoritative UNUSED/id=0 rule.
            IF ( bomStatus(ip,bi,bj).NE.BOM_UNUSED .OR.
     &           bomId(ip,bi,bj).NE.0 .OR.
     &           bomSpringEast(ip,bi,bj).NE.0. _d 0 .OR.
     &           bomSpringNorth(ip,bi,bj).NE.0. _d 0 .OR.
     &           bomNeighborCount(ip,bi,bj).NE.0 .OR.
     &           bomRaftId(ip,bi,bj).NE.0_8 .OR.
     &           bomRaftSize(ip,bi,bj).NE.0 ) THEN
              IF ( localErrCount.LT.8 ) THEN
                WRITE(msgBuf,'(A,A,A,I6,A,3I5,A,I20,A,I5)')
     &               'BOM_CHECK_STATE: context=', checkContext,
     &               ' rank=', myProcId, ' tail tile/slot=', bi, bj, ip,
     &               ' id=', bomId(ip,bi,bj),
     &               ' status=', bomStatus(ip,bi,bj)
                CALL PRINT_ERROR( msgBuf, myThid )
              ENDIF
              localErrCount = localErrCount + 1
            ENDIF
          ENDIF
        ENDDO
       ENDDO
      ENDDO

      globalErrCount = localErrCount
      globalOwnerCount = localOwnerCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      CALL GLOBAL_SUM_INT( globalOwnerCount, myThid )
      IF ( globalOwnerCount.NE.expectedLiveCount ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,A,A,2I12)')
     &         'BOM_CHECK_STATE: context=', checkContext,
     &         ' owner/expected mismatch=',
     &         globalOwnerCount, expectedLiveCount
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        globalErrCount = globalErrCount + 1
      ENDIF
      IF ( globalErrCount.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,A,A,I12,A,I12)')
     &         'BOM_CHECK_STATE: context=', checkContext,
     &         ' fatal basic errors=', globalErrCount,
     &         ' iter=', checkIter
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_CHECK_STATE'
      ENDIF

C--   Gather exact integer words after all local bounds are trusted.
      _BARRIER
      _BEGIN_MASTER(myThid)
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allgather(
     I       localIdCount, 1, MPI_INTEGER,
     O       idCounts, 1, MPI_INTEGER,
     I       MPI_COMM_MODEL, mpiRC )
        IF ( mpiRC.NE.0 ) mpiErrCount = mpiErrCount + 1
      ELSE
#endif
        idCounts(1) = localIdCount
#ifdef ALLOW_USE_MPI
      ENDIF
#endif
      idDispls(1) = 0
      globalIdCount = idCounts(1)
      DO jp=2,nPx*nPy
        IF ( idCounts(jp).LT.0 ) mpiErrCount = mpiErrCount + 1
        idDispls(jp) = globalIdCount
        IF ( idCounts(jp).GT.bomMaxInitRecords-globalIdCount ) THEN
          mpiErrCount = mpiErrCount + 1
        ELSE
          globalIdCount = globalIdCount + idCounts(jp)
        ENDIF
      ENDDO
      IF ( globalIdCount.GT.bomMaxInitRecords )
     &     mpiErrCount = mpiErrCount + 1

      IF ( mpiErrCount.EQ.0 ) THEN
#ifdef ALLOW_USE_MPI
        IF ( usingMPI ) THEN
          CALL MPI_Allgatherv(
     I         idHiLocal, localIdCount, MPI_INTEGER,
     O         idHiGlobal, idCounts, idDispls, MPI_INTEGER,
     I         MPI_COMM_MODEL, mpiRC )
          IF ( mpiRC.NE.0 ) mpiErrCount = mpiErrCount + 1
          CALL MPI_Allgatherv(
     I         idLoLocal, localIdCount, MPI_INTEGER,
     O         idLoGlobal, idCounts, idDispls, MPI_INTEGER,
     I         MPI_COMM_MODEL, mpiRC )
          IF ( mpiRC.NE.0 ) mpiErrCount = mpiErrCount + 1
        ELSE
#endif
          DO ip=1,localIdCount
            idHiGlobal(ip) = idHiLocal(ip)
            idLoGlobal(ip) = idLoLocal(ip)
          ENDDO
#ifdef ALLOW_USE_MPI
        ENDIF
#endif
      ENDIF

      IF ( mpiErrCount.EQ.0 ) THEN
        IF ( globalIdCount.NE.expectedLiveCount ) THEN
          mpiErrCount = mpiErrCount + 1
        ELSE
          CALL BOM_SORT_ID_WORDS(
     U         globalIdCount, idHiGlobal, idLoGlobal )
          DO ip=2,globalIdCount
            IF ( idHiGlobal(ip).EQ.idHiGlobal(ip-1) .AND.
     &           idLoGlobal(ip).EQ.idLoGlobal(ip-1) ) THEN
              IF ( mpiErrCount.LT.8 ) THEN
                WRITE(msgBuf,'(A,A,A,2I14,A,2I12)')
     &               'BOM_CHECK_STATE: context=', checkContext,
     &               ' duplicate ID words=',
     &               idHiGlobal(ip), idLoGlobal(ip),
     &               ' sorted slots=', ip-1, ip
                CALL PRINT_ERROR( msgBuf, myThid )
              ENDIF
              mpiErrCount = mpiErrCount + 1
            ENDIF
          ENDDO
        ENDIF
      ENDIF
      _END_MASTER(myThid)
      _BARRIER

      globalErrCount = mpiErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,A,A,I12,A,I12)')
     &         'BOM_CHECK_STATE: context=', checkContext,
     &         ' fatal ID-budget errors=', globalErrCount,
     &         ' iter=', checkIter
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_CHECK_STATE'
      ENDIF

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SORT_ID_WORDS( nId, idHi, idLo )

      IMPLICIT NONE
#include "BOM_SIZE.h"
      INTEGER nId
      INTEGER idHi(bomMaxInitRecords)
      INTEGER idLo(bomMaxInitRecords)
      INTEGER start, finish
      INTEGER tempHi, tempLo

C--   In-place heapsort by the exact (high-word, signed-low-word) pair.
      DO start=nId/2,1,-1
        CALL BOM_SIFT_ID_WORDS(
     U       idHi, idLo,
     I       start, nId )
      ENDDO
      DO finish=nId,2,-1
        tempHi = idHi(1)
        tempLo = idLo(1)
        idHi(1) = idHi(finish)
        idLo(1) = idLo(finish)
        idHi(finish) = tempHi
        idLo(finish) = tempLo
        CALL BOM_SIFT_ID_WORDS(
     U       idHi, idLo,
     I       1, finish-1 )
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_SIFT_ID_WORDS(
     U                 idHi, idLo,
     I                 rootIn, finish )

      IMPLICIT NONE
#include "BOM_SIZE.h"
      INTEGER idHi(bomMaxInitRecords)
      INTEGER idLo(bomMaxInitRecords)
      INTEGER rootIn
      INTEGER finish
      INTEGER root, child, swapIndex
      INTEGER tempHi, tempLo
      LOGICAL childGreater
      LOGICAL swapGreater

      root = rootIn
 10   CONTINUE
      child = 2*root
      IF ( child.GT.finish ) GOTO 20
      swapIndex = root
      swapGreater = idHi(child).GT.idHi(swapIndex) .OR.
     &     ( idHi(child).EQ.idHi(swapIndex) .AND.
     &       idLo(child).GT.idLo(swapIndex) )
      IF ( swapGreater ) swapIndex = child
      IF ( child+1.LE.finish ) THEN
        childGreater = idHi(child+1).GT.idHi(swapIndex) .OR.
     &       ( idHi(child+1).EQ.idHi(swapIndex) .AND.
     &         idLo(child+1).GT.idLo(swapIndex) )
        IF ( childGreater ) swapIndex = child+1
      ENDIF
      IF ( swapIndex.EQ.root ) GOTO 20
      tempHi = idHi(root)
      tempLo = idLo(root)
      idHi(root) = idHi(swapIndex)
      idLo(root) = idLo(swapIndex)
      idHi(swapIndex) = tempHi
      idLo(swapIndex) = tempLo
      root = swapIndex
      GOTO 10
 20   CONTINUE

      RETURN
      END
