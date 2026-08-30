#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_READ_PICKUP
C !INTERFACE:
      SUBROUTINE BOM_READ_PICKUP( myThid )

C !DESCRIPTION:
C     Restore a same-decomposition pickup transactionally.  LEEW accepts
C     schema 1; BOM requires schema 2 plus the complete endpoint sidecar.
C     Spring-enabled BOM additionally requires the schema-3 signature and
C     exact-ID diagnostic sidecar, including a successful FINAL-graph rebuild.
C     Every component is validated before authoritative state is committed.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER myThid
CEOP

C !FUNCTIONS:
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      CHARACTER*10 suffix
      CHARACTER*(MAX_LEN_FNAM) fileName, sigName, physicalPrefix
      CHARACTER*(MAX_LEN_FNAM) tilePrefix, dataName, metaName
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*(MAX_LEN_MBUF) metaSimulation, metaTitle
      CHARACTER*8 metaFieldList(1)
      _RL signature(
     &     bomPickup2SigBase+2*MAX_LEN_FNAM+256)
      _RL record(bomPickupFields2)
      _RL scratchReal(12,bomMaxPartTile,nSx,nSy)
      _RL scratchDiag(
     &     BOM_RHS_NDIAG,bomMaxPartTile,nSx,nSy)
      _RL scratchSpringEast(bomMaxPartTile,nSx,nSy)
      _RL scratchSpringNorth(bomMaxPartTile,nSx,nSy)
      _RL scratchP4S(bomMaxPartTile,nSx,nSy)
      _RL storedBioTime(BOM_ENV_NEND)
      _RL storedShardTimeMin,storedShardTimeMax
      _RL metaTimList(1), metaMissingValue
      _RL xMap, mappedI, mappedJ
      _RL storedTime, storedFreq, storedNext
      _RL envTime0, envTime1
      _RS dummyRS(1)
      INTEGER scratchCount(nSx,nSy)
      INTEGER scratchStatus(bomMaxPartTile,nSx,nSy)
      INTEGER scratchNeighbor(bomMaxPartTile,nSx,nSy)
      INTEGER scratchRaftSize(bomMaxPartTile,nSx,nSy)
      INTEGER scratchBirthCount(bomMaxPartTile,nSx,nSy)
      INTEGER storedBioIter(BOM_ENV_NEND)
      INTEGER storedTempSource(BOM_ENV_NEND)
      INTEGER storedNSource(BOM_ENV_NEND)
      INTEGER*8 scratchId(bomMaxPartTile,nSx,nSy)
      INTEGER*8 scratchRaftId(bomMaxPartTile,nSx,nSy)
      INTEGER*8 scratchParent(bomMaxPartTile,nSx,nSy)
      INTEGER idCounts(nPx*nPy), idDispls(nPx*nPy)
      INTEGER idHiLocal(bomMaxInitRecords)
      INTEGER idLoLocal(bomMaxInitRecords)
      INTEGER idHiGlobal(bomMaxInitRecords)
      INTEGER idLoGlobal(bomMaxInitRecords)
      INTEGER metaDimList(3,3)
      INTEGER bi, bj, ip, jp, k, ioUnit, iRecord
      INTEGER iGlobal, jGlobal, iTile, jTile
      INTEGER prefixLen, localDirLen
      INTEGER localErrCount, globalErrCount, idError
      INTEGER localOwnerCount, globalOwnerCount, localIdCount
      INTEGER globalIdCount, mpiErrCount, mpiRC
      INTEGER storedExpected,storedLive,storedIter,statusValue
      INTEGER storedOwnerBudget,nFree
      INTEGER activeSchema, activeFields, sigFields, envFields
      INTEGER sigRecordFields, sigRecords, sigIndex
      INTEGER envIter0, envIter1
      INTEGER i, j, iEnd, iSource, iDiag
      INTEGER metaFilePrec, metaNDims, metaNFlds, metaNTimRec
      INTEGER metaNRecords, metaFileIter
      INTEGER*8 particleId, previousId, idRadix, idHi8, idLo8
      INTEGER*8 storedNextId,storedEventIndex
      INTEGER*8 storedBirth,storedDeath,storedBeach
      INTEGER*8 storedOutside,storedCancel,storedMissing
      INTEGER*8 storedShardRecords,storedShardBirth
      INTEGER*8 storedShardDeath,storedShardBeach
      INTEGER*8 storedShardOutside,storedShardCancel
      INTEGER*8 eventLocal(5),eventGlobal(5),globalMaxId
      INTEGER*8 tileBytes(nSx,nSy), recordBytes, expectedBytes
      LOGICAL dataExists, metaExists, useCurrentDir
      LOGICAL recordFinite, isOwner, hasStencil
      LOGICAL signatureValid, diagConsistent, reservedValid
      LOGICAL useSchema3,useSchema4,storedBioReady

      _BEGIN_MASTER(myThid)

      localErrCount = 0
      globalErrCount = 0
      localOwnerCount = 0
      globalOwnerCount = 0
      localIdCount = 0
      globalIdCount = 0
      mpiErrCount = 0
      activeSchema = bomPickupSchema
      activeFields = bomPickupFields
      sigFields = bomPickupSigFields
      sigRecordFields = sigFields
      envFields = 0
      useSchema3 = .FALSE.
      useSchema4 = .FALSE.
      IF ( bomMode.EQ.'BOM' ) THEN
        activeSchema = bomPickupSchema2
        activeFields = bomPickupFields2
        CALL BOM_GET_PICKUP2_SIZES(
     O       sigFields, envFields )
        sigRecordFields = bomPickupChunkFields
        useSchema3 = bomSpringLaw.NE.'NONE'
        useSchema4 = bomUseLand .OR. bomUseBiology
      ENDIF
      sigRecords = (sigFields+sigRecordFields-1)/sigRecordFields
      signatureValid = .TRUE.
      storedExpected = -1
      storedLive = -1
      storedOwnerBudget = -1
      storedIter = -1
      storedTime = 0. _d 0
      storedFreq = 0. _d 0
      storedNext = 0. _d 0
      envTime0 = 0. _d 0
      envTime1 = 0. _d 0
      envIter0 = 0
      envIter1 = 0
      storedNextId=0_8
      storedEventIndex=0_8
      storedBirth=0_8
      storedDeath=0_8
      storedBeach=0_8
      storedOutside=0_8
      storedCancel=0_8
      storedMissing=0_8
      storedBioReady=.FALSE.
      DO iEnd=1,BOM_ENV_NEND
        storedBioTime(iEnd)=0. _d 0
        storedBioIter(iEnd)=0
        storedTempSource(iEnd)=BOM_BIO_TEMP_NONE
        storedNSource(iEnd)=BOM_BIO_N_NONE
      ENDDO
      idRadix = 4294967296_8
      recordBytes = INT(activeFields,8)*8_8

      DO jp=1,nPx*nPy
        idCounts(jp) = 0
        idDispls(jp) = 0
      ENDDO
      DO ip=1,bomMaxInitRecords
        idHiLocal(ip) = 0
        idLoLocal(ip) = 0
        idHiGlobal(ip) = 0
        idLoGlobal(ip) = 0
      ENDDO
      DO bj=1,nSy
       DO bi=1,nSx
        scratchCount(bi,bj) = 0
        tileBytes(bi,bj) = -1_8
        DO ip=1,bomMaxPartTile
          scratchId(ip,bi,bj) = 0_8
          scratchStatus(ip,bi,bj) = BOM_UNUSED
          scratchSpringEast(ip,bi,bj) = 0. _d 0
          scratchSpringNorth(ip,bi,bj) = 0. _d 0
          scratchNeighbor(ip,bi,bj) = 0
          scratchRaftId(ip,bi,bj) = 0_8
          scratchRaftSize(ip,bi,bj) = 0
          scratchParent(ip,bi,bj) = 0_8
          scratchP4S(ip,bi,bj) = 0. _d 0
          scratchBirthCount(ip,bi,bj) = 0
          DO k=1,12
            scratchReal(k,ip,bi,bj) = 0. _d 0
          ENDDO
          DO iDiag=1,BOM_RHS_NDIAG
            scratchDiag(iDiag,ip,bi,bj) = 0. _d 0
          ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Resolve exactly the suffix used by the core pickup reader.
      IF ( pickupSuff.EQ.' ' ) THEN
        IF ( rwSuffixType.EQ.0 ) THEN
          WRITE(suffix,'(I10.10)') nIter0
        ELSE
          CALL RW_GET_SUFFIX( suffix, startTime, nIter0, myThid )
        ENDIF
      ELSE
        WRITE(suffix,'(A10)') pickupSuff
      ENDIF
      WRITE(fileName,'(A,A10)') 'pickup_bom.', suffix
      prefixLen = ILNBLNK(fileName)
      WRITE(sigName,'(A,A)') fileName(1:prefixLen), '.sig'

C--   Signature presence and physical length are checked collectively.
      WRITE(dataName,'(A,A)') sigName(1:ILNBLNK(sigName)), '.data'
      WRITE(metaName,'(A,A)') sigName(1:ILNBLNK(sigName)), '.meta'
      expectedBytes = -1_8
      INQUIRE(FILE=dataName,EXIST=dataExists,SIZE=expectedBytes)
      INQUIRE(FILE=metaName,EXIST=metaExists)
      IF ( .NOT.dataExists .OR. .NOT.metaExists .OR.
     &     expectedBytes.NE.INT(sigRecords,8)
     &                         *INT(sigRecordFields,8)*8_8 ) THEN
        localErrCount = localErrCount + 1
      ENDIF
      globalErrCount = localErrCount
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allreduce(localErrCount,globalErrCount,1,MPI_INTEGER,
     &       MPI_SUM,MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.0 ) globalErrCount = globalErrCount + 1
      ENDIF
#endif
      IF ( globalErrCount.GT.0 ) THEN
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,A,A,I4,A,L3,A,L3,A,I20)')
     &         'BOM_READ_PICKUP: signature preflight suffix=', suffix,
     &         ' code=', BOM_FAIL_PICKUP_SCHEMA,
     &         ' data=', dataExists, ' meta=', metaExists,
     &         ' bytes=', expectedBytes
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_READ_PICKUP'
      ENDIF

C--   Read and validate the global signature before touching tiled files.
      metaNDims = 3
      metaNFlds = 1
      metaNTimRec = 1
      useCurrentDir = .TRUE.
      CALL MDS_READ_META(
     I     sigName,
     O     metaSimulation, metaTitle, metaFilePrec,
     U     metaNDims, metaNFlds, metaNTimRec,
     O     metaDimList, metaFieldList, metaTimList,
     O     metaMissingValue, metaNRecords, metaFileIter,
     I     useCurrentDir, myThid )
      ioUnit = -1
      DO iRecord=1,sigRecords
        CALL MDS_READVEC_LOC(
     I       sigName, precFloat64, ioUnit,
     I       'RL', sigRecordFields, record, dummyRS,
     I       0, 0, iRecord, myThid )
        DO k=1,sigRecordFields
          sigIndex = (iRecord-1)*sigRecordFields+k
          IF ( sigIndex.LE.sigFields )
     &         signature(sigIndex) = record(k)
        ENDDO
      ENDDO
      CLOSE(ioUnit)

      recordFinite = .TRUE.
      DO k=1,sigFields
        IF ( .NOT.IEEE_IS_FINITE(signature(k)) )
     &       recordFinite = .FALSE.
      ENDDO
      IF ( .NOT.recordFinite ) localErrCount = localErrCount + 1
      IF ( metaFilePrec.NE.precFloat64 .OR. metaNDims.NE.3 .OR.
     &     metaNRecords.NE.sigRecords .OR. metaFileIter.NE.nIter0 .OR.
     &     metaDimList(1,1).NE.1 .OR.
     &     metaDimList(2,1).NE.1 .OR.
     &     metaDimList(3,1).NE.1 .OR.
     &     metaDimList(1,2).NE.1 .OR.
     &     metaDimList(2,2).NE.1 .OR.
     &     metaDimList(3,2).NE.1 .OR.
     &     metaDimList(1,3).NE.sigRecordFields .OR.
     &     metaDimList(2,3).NE.1 .OR.
     &     metaDimList(3,3).NE.sigRecordFields ) THEN
        localErrCount = localErrCount + 1
      ENDIF

      IF ( recordFinite ) THEN
        IF ( signature(12).EQ.DNINT(signature(12)) )
     &       storedExpected = NINT(signature(12))
        IF ( signature(13).EQ.DNINT(signature(13)) )
     &       storedIter = NINT(signature(13))
        storedTime = signature(14)
        storedFreq = signature(15)
        storedNext = signature(16)
        IF ( activeSchema.EQ.bomPickupSchema ) THEN
          IF ( signature(1).NE.DFLOAT(bomPickupSchema) .OR.
     &         signature(2).NE.DFLOAT(bomPickupSigFields) .OR.
     &         signature(3).NE.DFLOAT(nPx) .OR.
     &         signature(4).NE.DFLOAT(nPy) .OR.
     &         signature(5).NE.DFLOAT(sNx) .OR.
     &         signature(6).NE.DFLOAT(sNy) .OR.
     &         signature(7).NE.DFLOAT(nSx) .OR.
     &         signature(8).NE.DFLOAT(nSy) .OR.
     &         signature(9).NE.DFLOAT(Nx) .OR.
     &         signature(10).NE.DFLOAT(Ny) .OR.
     &         signature(11).NE.DFLOAT(bomMaxPartTile) .OR.
     &         storedExpected.LT.0 .OR.
     &         storedExpected.GT.bomMaxParticles .OR.
     &         storedExpected.GT.bomInitGlobalLimit .OR.
     &         storedExpected.GT.bomMaxInitRecords .OR.
     &         storedIter.NE.nIter0 .OR.
     &         storedTime.NE.startTime .OR.
     &         storedFreq.NE.bomOutputFreq )
     &         localErrCount = localErrCount + 1
        ELSE
          CALL BOM_VALIDATE_PICKUP2_SIGNATURE(
     I         signature, sigFields,
     O         storedExpected, storedNext,
     O         envTime0, envTime1, envIter0, envIter1,
     O         envFields, signatureValid,
     I         startTime, nIter0, myThid )
          IF ( .NOT.signatureValid )
     &         localErrCount = localErrCount + 1
          storedIter = nIter0
          storedTime = startTime
          storedFreq = bomOutputFreq
        ENDIF
        IF ( storedFreq.EQ.0. _d 0 ) THEN
          IF ( storedNext.NE.0. _d 0 )
     &         localErrCount = localErrCount + 1
        ELSEIF ( storedFreq.LT.0. _d 0 .OR.
     &           storedNext.LE.storedTime ) THEN
          localErrCount = localErrCount + 1
        ENDIF
      ENDIF

      globalErrCount = localErrCount
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allreduce(localErrCount,globalErrCount,1,MPI_INTEGER,
     &       MPI_SUM,MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.0 ) globalErrCount = globalErrCount + 1
      ENDIF
#endif
      IF ( globalErrCount.GT.0 ) THEN
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,A,A,I4,A,8(1X,1PE12.4))')
     &         'BOM_READ_PICKUP: signature mismatch suffix=', suffix,
     &         ' code=', BOM_FAIL_PICKUP_SCHEMA,
     &         ' stored schema/fields/nPx/nPy/sNx/sNy/nSx/nSy=',
     &         signature(1), signature(2), signature(3), signature(4),
     &         signature(5), signature(6), signature(7), signature(8)
          CALL PRINT_ERROR( msgBuf, myThid )
          WRITE(msgBuf,'(A,6I8)')
     &         'BOM_READ_PICKUP: current nPx/nPy/sNx/sNy/nSx/nSy=',
     &         nPx, nPy, sNx, sNy, nSx, nSy
          CALL PRINT_ERROR( msgBuf, myThid )
          WRITE(msgBuf,'(A,3I12,A,3(1X,1PE24.16))')
     &         'BOM_READ_PICKUP: stored expected/iter/currentIter=',
     &         storedExpected, storedIter, nIter0,
     &         ' time/freq/next=', storedTime, storedFreq, storedNext
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_READ_PICKUP'
      ENDIF

C--   Schema 4 is additive: validate its signature, the complete frame
C     manifest, and every rank event shard before any owner is published.
      IF ( useSchema4 ) THEN
        localErrCount=0
        CALL BOM_READ_P4_SIGNATURE(
     I       fileName,2,bomPickupFields2,
     I       storedTime,storedTime,storedNext,storedIter,
     O       storedOwnerBudget,storedLive,storedNextId,
     O       storedEventIndex,storedBirth,storedDeath,
     O       storedBeach,storedOutside,storedCancel,
     O       storedMissing,storedBioTime,storedBioIter,
     O       storedTempSource,storedNSource,storedBioReady,
     O       localErrCount,
     I       myThid)
        IF ( storedOwnerBudget.NE.storedExpected )
     &       localErrCount=localErrCount+1
        IF ( localErrCount.EQ.0 ) CALL BOM_VALIDATE_P4_MANIFEST(
     I       fileName,2,useSchema3,bomUseBiology,
     I       storedTime,storedTime,storedIter,
     I       storedExpected,storedLive,
     O       localErrCount,
     I       myThid)
        IF ( localErrCount.EQ.0 ) CALL BOM_LOAD_EVENT_SHARD_STATE(
     O       storedShardRecords,storedShardBirth,
     O       storedShardDeath,storedShardBeach,
     O       storedShardOutside,storedShardCancel,
     O       storedShardTimeMin,storedShardTimeMax,
     O       localErrCount,
     I       myThid)
        globalErrCount=localErrCount
#ifdef ALLOW_USE_MPI
        IF ( usingMPI ) THEN
          CALL MPI_Allreduce(localErrCount,globalErrCount,1,MPI_INTEGER,
     &         MPI_SUM,MPI_COMM_MODEL,mpiRC)
          IF ( mpiRC.NE.0 ) globalErrCount=globalErrCount+1
        ENDIF
#endif
        eventLocal(1)=storedShardBirth
        eventLocal(2)=storedShardDeath
        eventLocal(3)=storedShardBeach
        eventLocal(4)=storedShardOutside
        eventLocal(5)=storedShardCancel
        IF ( globalErrCount.EQ.0 ) CALL BOM_P4_GLOBAL_SUM_COUNTS(
     I       eventLocal,5,
     O       eventGlobal,localErrCount,
     I       myThid)
        IF ( globalErrCount.GT.0 ) localErrCount=localErrCount+1
        IF ( globalErrCount.EQ.0 .AND. localErrCount.EQ.0 ) THEN
          IF ( eventGlobal(1).NE.storedBirth .OR.
     &         eventGlobal(2).NE.storedDeath .OR.
     &         eventGlobal(3).NE.storedBeach .OR.
     &         eventGlobal(4).NE.storedOutside .OR.
     &         eventGlobal(5).NE.storedCancel )
     &         localErrCount=localErrCount+1
        ENDIF
        globalErrCount=localErrCount
#ifdef ALLOW_USE_MPI
        IF ( usingMPI ) THEN
          CALL MPI_Allreduce(localErrCount,globalErrCount,1,MPI_INTEGER,
     &         MPI_SUM,MPI_COMM_MODEL,mpiRC)
          IF ( mpiRC.NE.0 ) globalErrCount=globalErrCount+1
        ENDIF
#endif
        IF ( globalErrCount.GT.0 ) THEN
          IF ( myProcId.EQ.0 ) THEN
            WRITE(msgBuf,'(A,A,A,I4,A,I12)')
     &           'BOM_READ_PICKUP: schema-4 preflight suffix=',suffix,
     &           ' code=',BOM_FAIL_PICKUP_SCHEMA4,
     &           ' errors=',globalErrCount
            CALL PRINT_ERROR(msgBuf,myThid)
          ENDIF
          CALL ALL_PROC_DIE(0)
          STOP 'ABNORMAL END: S/R BOM_READ_PICKUP SCHEMA4'
        ENDIF
      ELSE
        storedLive=storedExpected
      ENDIF

C--   The schema-3 metadata embeds an unchanged bitwise copy of schema 2.
      IF ( useSchema3 ) THEN
        localErrCount = 0
        CALL BOM_READ_P3_SIGNATURE(
     I       fileName, signature, sigFields,
     I       storedTime, storedIter, storedExpected, storedNext,
     O       localErrCount,
     I       myThid )
        globalErrCount = localErrCount
#ifdef ALLOW_USE_MPI
        IF ( usingMPI ) THEN
          CALL MPI_Allreduce(localErrCount,globalErrCount,1,MPI_INTEGER,
     &         MPI_SUM,MPI_COMM_MODEL,mpiRC)
          IF ( mpiRC.NE.0 ) globalErrCount = globalErrCount + 1
        ENDIF
#endif
        IF ( globalErrCount.GT.0 ) THEN
          IF ( myProcId.EQ.0 ) THEN
            WRITE(msgBuf,'(A,A,A,I4,A,I12)')
     &           'BOM_READ_PICKUP: schema-3 signature suffix=',
     &           suffix, ' code=', BOM_FAIL_PICKUP_SCHEMA3,
     &           ' errors=', globalErrCount
            CALL PRINT_ERROR( msgBuf, myThid )
          ENDIF
          CALL ALL_PROC_DIE( 0 )
          STOP 'ABNORMAL END: S/R BOM_READ_PICKUP'
        ENDIF
      ENDIF

C--   BOM restores the complete endpoint sidecar into scratch first.
      IF ( activeSchema.EQ.bomPickupSchema2 ) THEN
        localErrCount = 0
        CALL BOM_READ_PICKUP_ENV(
     I       fileName, storedTime, storedIter,
     I       envTime0, envTime1, envIter0, envIter1,
     I       envFields,
     O       localErrCount,
     I       myThid )
        globalErrCount = localErrCount
#ifdef ALLOW_USE_MPI
        IF ( usingMPI ) THEN
          CALL MPI_Allreduce(localErrCount,globalErrCount,1,MPI_INTEGER,
     &         MPI_SUM,MPI_COMM_MODEL,mpiRC)
          IF ( mpiRC.NE.0 ) globalErrCount = globalErrCount + 1
        ENDIF
#endif
        IF ( globalErrCount.GT.0 ) THEN
          IF ( myProcId.EQ.0 ) THEN
            WRITE(msgBuf,'(A,A,A,I4,A,I12)')
     &           'BOM_READ_PICKUP: endpoint sidecar suffix=', suffix,
     &           ' code=', BOM_FAIL_PICKUP_SCHEMA,
     &           ' errors=', globalErrCount
            CALL PRINT_ERROR( msgBuf, myThid )
          ENDIF
          CALL ALL_PROC_DIE( 0 )
          STOP 'ABNORMAL END: S/R BOM_READ_PICKUP'
        ENDIF
      ENDIF

C--   Preflight every local tiled data/meta file before reading any tile.
      localErrCount = 0
      localDirLen = ILNBLNK(mdsioLocalDir)
      IF ( localDirLen.GT.0 ) THEN
        WRITE(physicalPrefix,'(2A)')
     &       mdsioLocalDir(1:localDirLen), fileName(1:prefixLen)
      ELSE
        physicalPrefix = fileName
      ENDIF
      DO bj=1,nSy
       DO bi=1,nSx
        iTile = bi + (myXGlobalLo-1)/sNx
        jTile = bj + (myYGlobalLo-1)/sNy
        WRITE(tilePrefix,'(A,A,I3.3,A,I3.3)')
     &       physicalPrefix(1:ILNBLNK(physicalPrefix)), '.',
     &       iTile, '.', jTile
        WRITE(dataName,'(A,A)')
     &       tilePrefix(1:ILNBLNK(tilePrefix)), '.data'
        WRITE(metaName,'(A,A)')
     &       tilePrefix(1:ILNBLNK(tilePrefix)), '.meta'
        INQUIRE(FILE=dataName,EXIST=dataExists,SIZE=tileBytes(bi,bj))
        INQUIRE(FILE=metaName,EXIST=metaExists)
        IF ( .NOT.dataExists .OR. .NOT.metaExists .OR.
     &       tileBytes(bi,bj).LT.recordBytes .OR.
     &       MOD(tileBytes(bi,bj),recordBytes).NE.0_8 .OR.
     &       tileBytes(bi,bj).GT.
     &       INT(bomMaxPartTile+1,8)*recordBytes ) THEN
          WRITE(msgBuf,'(A,A,A,I6,A,2I5,A,2L3,A,I20)')
     &         'BOM_READ_PICKUP: tiled preflight prefix=',
     &         fileName(1:prefixLen),
     &         ' rank=', myProcId, ' tile=', bi, bj,
     &         ' data/meta=', dataExists, metaExists,
     &         ' bytes=', tileBytes(bi,bj)
          CALL PRINT_ERROR( msgBuf, myThid )
          localErrCount = localErrCount + 1
        ENDIF
       ENDDO
      ENDDO
      globalErrCount = localErrCount
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allreduce(localErrCount,globalErrCount,1,MPI_INTEGER,
     &       MPI_SUM,MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.0 ) globalErrCount = globalErrCount + 1
      ENDIF
#endif
      IF ( globalErrCount.GT.0 ) THEN
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,A,A,I12)')
     &         'BOM_READ_PICKUP: tiled preflight failed suffix=',
     &         suffix, ' errors=', globalErrCount
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_READ_PICKUP'
      ENDIF

C--   Parse every tile into non-authoritative scratch storage.
      localErrCount = 0
      DO bj=1,nSy
       DO bi=1,nSx
        iTile = bi + (myXGlobalLo-1)/sNx
        jTile = bj + (myYGlobalLo-1)/sNy
        WRITE(tilePrefix,'(A,A,I3.3,A,I3.3)')
     &       physicalPrefix(1:ILNBLNK(physicalPrefix)), '.',
     &       iTile, '.', jTile
        metaNDims = 3
        metaNFlds = 1
        metaNTimRec = 1
        useCurrentDir = .TRUE.
        CALL MDS_READ_META(
     I       tilePrefix,
     O       metaSimulation, metaTitle, metaFilePrec,
     U       metaNDims, metaNFlds, metaNTimRec,
     O       metaDimList, metaFieldList, metaTimList,
     O       metaMissingValue, metaNRecords, metaFileIter,
     I       useCurrentDir, myThid )
        ioUnit = -1
        CALL MDS_READVEC_LOC(
     I       fileName, precFloat64, ioUnit,
     I       'RL', activeFields, record, dummyRS,
     I       bi, bj, 1, myThid )

        recordFinite = .TRUE.
        DO k=1,activeFields
          IF ( .NOT.IEEE_IS_FINITE(record(k)) )
     &         recordFinite = .FALSE.
        ENDDO
        IF ( recordFinite ) THEN
          IF ( record(3).EQ.DNINT(record(3)) ) THEN
            scratchCount(bi,bj) = NINT(record(3))
          ELSE
            scratchCount(bi,bj) = 0
            localErrCount = localErrCount + 1
          ENDIF
        ELSE
          scratchCount(bi,bj) = 0
          localErrCount = localErrCount + 1
        ENDIF
        IF ( scratchCount(bi,bj).LT.0 .OR.
     &       scratchCount(bi,bj).GT.bomMaxPartTile ) THEN
          localErrCount = localErrCount + 1
          scratchCount(bi,bj) = 0
        ENDIF
        iGlobal = myXGlobalLo + (bi-1)*sNx
        jGlobal = myYGlobalLo + (bj-1)*sNy
        IF ( .NOT.recordFinite .OR.
     &       record(1).NE.DFLOAT(activeSchema) .OR.
     &       record(2).NE.DFLOAT(activeFields) .OR.
     &       record(4).NE.DFLOAT(storedExpected) .OR.
     &       record(5).NE.1. _d 0 .OR.
     &       record(6).NE.1. _d 0 .OR.
     &       record(7).NE.64. _d 0 .OR.
     &       record(8).NE.DFLOAT(storedIter) .OR.
     &       record(9).NE.storedTime .OR.
     &       record(10).NE.storedNext .OR.
     &       record(11).NE.storedFreq .OR.
     &       record(12).NE.DFLOAT(nPx) .OR.
     &       record(13).NE.DFLOAT(nPy) .OR.
     &       record(14).NE.DFLOAT(sNx) .OR.
     &       record(15).NE.DFLOAT(sNy) .OR.
     &       record(16).NE.DFLOAT(nSx) .OR.
     &       record(17).NE.DFLOAT(nSy) .OR.
     &       record(18).NE.DFLOAT(iGlobal) .OR.
     &       record(19).NE.DFLOAT(jGlobal) .OR.
     &       record(20).NE.DFLOAT(myProcId) .OR.
     &       record(21).NE.DFLOAT(bi) .OR.
     &       record(22).NE.DFLOAT(bj) .OR.
     &       record(23).NE.DFLOAT(bomMaxPartTile) .OR.
     &       record(24).NE.
     &       DFLOAT((activeSchema-bomPickupSchema)*
     &              BOM_RHS_NDIAG) ) THEN
          WRITE(msgBuf,'(A,A,A,I6,A,2I5,A,I8)')
     &         'BOM_READ_PICKUP: invalid tile header prefix=',
     &         fileName(1:prefixLen),
     &         ' rank=', myProcId, ' tile=', bi, bj,
     &         ' count=', scratchCount(bi,bj)
          CALL PRINT_ERROR( msgBuf, myThid )
          localErrCount = localErrCount + 1
        ENDIF
        expectedBytes = INT(scratchCount(bi,bj)+1,8)*recordBytes
        IF ( tileBytes(bi,bj).NE.expectedBytes .OR.
     &       metaFilePrec.NE.precFloat64 .OR. metaNDims.NE.3 .OR.
     &       metaNRecords.NE.scratchCount(bi,bj)+1 .OR.
     &       metaFileIter.NE.storedIter .OR.
     &       metaDimList(1,1).NE.nSx*nPx .OR.
     &       metaDimList(2,1).NE.iTile .OR.
     &       metaDimList(3,1).NE.iTile .OR.
     &       metaDimList(1,2).NE.nSy*nPy .OR.
     &       metaDimList(2,2).NE.jTile .OR.
     &       metaDimList(3,2).NE.jTile .OR.
     &       metaDimList(1,3).NE.activeFields .OR.
     &       metaDimList(2,3).NE.1 .OR.
     &       metaDimList(3,3).NE.activeFields ) THEN
          WRITE(msgBuf,'(A,I6,A,2I5,A,2I12,A,2I20)')
     &         'BOM_READ_PICKUP: meta/length rank=', myProcId,
     &         ' tile=', bi, bj,
     &         ' records/expected=', metaNRecords,
     &         scratchCount(bi,bj)+1,
     &         ' bytes/expected=', tileBytes(bi,bj), expectedBytes
          CALL PRINT_ERROR( msgBuf, myThid )
          localErrCount = localErrCount + 1
        ENDIF

        previousId = 0_8
        DO ip=1,scratchCount(bi,bj)
          CALL MDS_READVEC_LOC(
     I         fileName, precFloat64, ioUnit,
     I         'RL', activeFields, record, dummyRS,
     I         bi, bj, ip+1, myThid )
          recordFinite = .TRUE.
          DO k=1,activeFields
            IF ( .NOT.IEEE_IS_FINITE(record(k)) )
     &           recordFinite = .FALSE.
          ENDDO
          particleId = 0_8
          idError = 0
          IF ( recordFinite ) THEN
            CALL BOM_ID_FROM_WORDS(
     I           record(1), record(2),
     O           particleId, idError )
          ELSE
            idError = 1
          ENDIF
          IF ( recordFinite ) THEN
            IF ( record(3).EQ.DNINT(record(3)) ) THEN
              statusValue = NINT(record(3))
            ELSE
              statusValue = BOM_INVALID
            ENDIF
          ELSE
            statusValue = BOM_INVALID
          ENDIF
          xMap = record(4)
          mappedI = 0. _d 0
          mappedJ = 0. _d 0
          isOwner = .FALSE.
          hasStencil = .FALSE.
          IF ( recordFinite ) THEN
            CALL BOM_MAP_XY2IJLOCAL(
     I           record(4), record(5), bi, bj,
     O           xMap, mappedI, mappedJ, isOwner, hasStencil,
     I           myThid )
          ENDIF
          diagConsistent = .TRUE.
          reservedValid = .TRUE.
          IF ( activeSchema.EQ.bomPickupSchema ) THEN
            DO k=19,bomPickupFields
              IF ( record(k).NE.0. _d 0 ) reservedValid = .FALSE.
            ENDDO
          ENDIF
          IF ( activeSchema.EQ.bomPickupSchema2 ) THEN
            IF ( record(10).NE.record(
     &           18+BOM_RHS_VBASE_E) .OR.
     &           record(11).NE.record(
     &           18+BOM_RHS_VBASE_N) .OR.
     &           record(12).NE.record(
     &           18+BOM_RHS_VW_E) .OR.
     &           record(13).NE.record(
     &           18+BOM_RHS_VW_N) .OR.
     &           record(14).NE.record(
     &           18+BOM_RHS_DRIFT_E) .OR.
     &           record(15).NE.record(
     &           18+BOM_RHS_DRIFT_N) )
     &           diagConsistent = .FALSE.
          ENDIF
          IF ( .NOT.recordFinite .OR. idError.NE.0 .OR.
     &         particleId.LE.previousId .OR.
     &         ( statusValue.NE.BOM_ALIVE .AND.
     &           statusValue.NE.BOM_WAITING ) .OR.
     &         record(6).LT.0. _d 0 .OR.
     &         record(7).LT.0. _d 0 .OR.
     &         ( statusValue.EQ.BOM_WAITING .AND.
     &           ( record(6).LE.storedTime .OR.
     &             record(7).NE.0. _d 0 ) ) .OR.
     &         ( statusValue.EQ.BOM_ALIVE .AND.
     &           record(6).GT.storedTime ) .OR.
     &         .NOT.isOwner .OR. .NOT.hasStencil .OR.
     &         record(8).NE.mappedI .OR.
     &         record(9).NE.mappedJ .OR.
     &         record(16).NE.DFLOAT(myProcId) .OR.
     &         record(17).NE.DFLOAT(bi) .OR.
     &         record(18).NE.DFLOAT(bj) .OR.
     &         .NOT.reservedValid .OR. .NOT.diagConsistent ) THEN
            WRITE(msgBuf,'(A,A,A,I6,A,3I5,A,I20,A,I5)')
     &           'BOM_READ_PICKUP: invalid record prefix=',
     &           fileName(1:prefixLen),
     &           ' rank=', myProcId, ' tile/record=', bi, bj, ip,
     &           ' id=', particleId, ' code=', idError
            CALL PRINT_ERROR( msgBuf, myThid )
            localErrCount = localErrCount + 1
          ENDIF

          scratchId(ip,bi,bj) = particleId
          scratchStatus(ip,bi,bj) = statusValue
          DO k=1,12
            scratchReal(k,ip,bi,bj) = record(k+3)
          ENDDO
          IF ( activeSchema.EQ.bomPickupSchema2 ) THEN
            DO iDiag=1,BOM_RHS_NDIAG
              scratchDiag(iDiag,ip,bi,bj) =
     &             record(18+iDiag)
            ENDDO
          ENDIF
          previousId = particleId
          IF ( localIdCount.LT.bomMaxInitRecords .AND.
     &         particleId.GT.0 ) THEN
            localIdCount = localIdCount + 1
            idHi8 = particleId/idRadix
            idLo8 = MOD(particleId,idRadix)
            idHiLocal(localIdCount) = INT(idHi8)
            IF ( idLo8.GT.2147483647_8 ) THEN
              idLoLocal(localIdCount) = INT(idLo8-idRadix)
            ELSE
              idLoLocal(localIdCount) = INT(idLo8)
            ENDIF
          ELSE
            localErrCount = localErrCount + 1
          ENDIF
        ENDDO
        CLOSE(ioUnit)
        localOwnerCount = localOwnerCount + scratchCount(bi,bj)
       ENDDO
      ENDDO

C--   Stop before global ID exchange if any rank has malformed scratch.
      globalErrCount = localErrCount
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allreduce(localErrCount,globalErrCount,1,MPI_INTEGER,
     &       MPI_SUM,MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.0 ) globalErrCount = globalErrCount + 1
      ENDIF
#endif
      IF ( globalErrCount.GT.0 ) THEN
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,A,A,I4,A,I12)')
     &         'BOM_READ_PICKUP: scratch validation failed suffix=',
     &         suffix, ' code=', BOM_FAIL_PICKUP_SCHEMA,
     &         ' errors=', globalErrCount
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_READ_PICKUP'
      ENDIF

C--   Decode the required P4 owner and biology sidecars only after the
C     checksum-complete frame and schema-2 owner records both validate.
      IF ( useSchema4 ) THEN
        localErrCount=0
        CALL BOM_READ_P4_SIDECAR(
     I       fileName,storedTime,storedTime,storedNext,
     I       storedIter,storedLive,scratchCount,
     I       scratchId,scratchStatus,
     O       scratchParent,scratchP4S,scratchBirthCount,
     O       localErrCount,
     I       myThid)
        IF ( localErrCount.EQ.0 .AND. bomUseBiology )
     &       CALL BOM_READ_P4_BIO_PICKUP(
     I       fileName,storedTime,storedIter,
     I       storedBioTime,storedBioIter,
     I       storedTempSource,storedNSource,storedBioReady,
     O       localErrCount,
     I       myThid)
        globalErrCount=localErrCount
#ifdef ALLOW_USE_MPI
        IF ( usingMPI ) THEN
          CALL MPI_Allreduce(localErrCount,globalErrCount,1,MPI_INTEGER,
     &         MPI_SUM,MPI_COMM_MODEL,mpiRC)
          IF ( mpiRC.NE.0 ) globalErrCount=globalErrCount+1
        ENDIF
#endif
        IF ( globalErrCount.GT.0 ) THEN
          IF ( myProcId.EQ.0 ) THEN
            WRITE(msgBuf,'(A,A,A,I4,A,I12)')
     &           'BOM_READ_PICKUP: P4 sidecar suffix=',suffix,
     &           ' code=',BOM_FAIL_PICKUP_SCHEMA4,
     &           ' errors=',globalErrCount
            CALL PRINT_ERROR(msgBuf,myThid)
          ENDIF
          CALL ALL_PROC_DIE(0)
          STOP 'ABNORMAL END: S/R BOM_READ_PICKUP P4 SIDECAR'
        ENDIF
      ENDIF

C--   Decode schema-3 diagnostics, then independently rebuild the FINAL graph.
      IF ( useSchema3 ) THEN
        localErrCount = 0
        CALL BOM_READ_P3_SIDECAR(
     I       fileName, storedTime, storedTime, storedNext, storedIter,
     I       scratchCount, scratchId, scratchStatus,
     O       scratchSpringEast, scratchSpringNorth,
     O       scratchNeighbor, scratchRaftId, scratchRaftSize,
     O       localErrCount,
     I       myThid )
        globalErrCount = localErrCount
#ifdef ALLOW_USE_MPI
        IF ( usingMPI ) THEN
          CALL MPI_Allreduce(localErrCount,globalErrCount,1,MPI_INTEGER,
     &         MPI_SUM,MPI_COMM_MODEL,mpiRC)
          IF ( mpiRC.NE.0 ) globalErrCount = globalErrCount + 1
        ENDIF
#endif
        IF ( globalErrCount.EQ.0 ) THEN
          CALL BOM_VALIDATE_P3_RESTART_GRAPH(
     I         scratchCount, scratchId, scratchStatus, scratchReal,
     I         scratchSpringEast, scratchSpringNorth,
     I         scratchNeighbor, scratchRaftId, scratchRaftSize,
     O         localErrCount,
     I         myThid )
          globalErrCount = localErrCount
#ifdef ALLOW_USE_MPI
          IF ( usingMPI ) THEN
            CALL MPI_Allreduce(localErrCount,globalErrCount,1,
     &           MPI_INTEGER,MPI_SUM,MPI_COMM_MODEL,mpiRC)
            IF ( mpiRC.NE.0 ) globalErrCount = globalErrCount + 1
          ENDIF
#endif
        ENDIF
        IF ( globalErrCount.GT.0 ) THEN
          IF ( myProcId.EQ.0 ) THEN
            WRITE(msgBuf,'(A,A,A,I4,A,I12)')
     &           'BOM_READ_PICKUP: schema-3 sidecar suffix=', suffix,
     &           ' code=', BOM_FAIL_PICKUP_SCHEMA3,
     &           ' errors=', globalErrCount
            CALL PRINT_ERROR( msgBuf, myThid )
          ENDIF
          CALL ALL_PROC_DIE( 0 )
          STOP 'ABNORMAL END: S/R BOM_READ_PICKUP'
        ENDIF
      ENDIF

C--   Gather and sort exact integer ID words before committing COMMON state.
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allgather(localIdCount,1,MPI_INTEGER,
     &       idCounts,1,MPI_INTEGER,MPI_COMM_MODEL,mpiRC)
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
        idDispls(jp) = globalIdCount
        IF ( idCounts(jp).LT.0 .OR.
     &       idCounts(jp).GT.bomMaxInitRecords-globalIdCount ) THEN
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
          CALL MPI_Allgatherv(idHiLocal,localIdCount,MPI_INTEGER,
     &         idHiGlobal,idCounts,idDispls,MPI_INTEGER,
     &         MPI_COMM_MODEL,mpiRC)
          IF ( mpiRC.NE.0 ) mpiErrCount = mpiErrCount + 1
          CALL MPI_Allgatherv(idLoLocal,localIdCount,MPI_INTEGER,
     &         idLoGlobal,idCounts,idDispls,MPI_INTEGER,
     &         MPI_COMM_MODEL,mpiRC)
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
      globalOwnerCount = localOwnerCount
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allreduce(localOwnerCount,globalOwnerCount,1,
     &       MPI_INTEGER,MPI_SUM,MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.0 ) mpiErrCount = mpiErrCount + 1
      ENDIF
#endif
      storedOwnerBudget=storedExpected
      IF ( useSchema4 ) storedOwnerBudget=storedLive
      IF ( globalOwnerCount.NE.storedOwnerBudget .OR.
     &     globalIdCount.NE.storedOwnerBudget )
     &     mpiErrCount = mpiErrCount + 1
      IF ( mpiErrCount.EQ.0 ) THEN
        CALL BOM_SORT_ID_WORDS(
     U       globalIdCount, idHiGlobal, idLoGlobal )
        DO ip=2,globalIdCount
          IF ( idHiGlobal(ip).EQ.idHiGlobal(ip-1) .AND.
     &         idLoGlobal(ip).EQ.idLoGlobal(ip-1) ) THEN
            WRITE(msgBuf,'(A,2I14,A,2I12)')
     &           'BOM_READ_PICKUP: duplicate ID words=',
     &           idHiGlobal(ip), idLoGlobal(ip),
     &           ' sorted slots=', ip-1, ip
            CALL PRINT_ERROR( msgBuf, myThid )
            mpiErrCount = mpiErrCount + 1
          ENDIF
        ENDDO
      ENDIF
      globalMaxId=0_8
      IF ( globalIdCount.GT.0 ) THEN
        idHi8=INT(idHiGlobal(globalIdCount),8)
        idLo8=INT(idLoGlobal(globalIdCount),8)
        IF ( idLo8.LT.0_8 ) idLo8=idLo8+idRadix
        globalMaxId=idHi8*idRadix+idLo8
      ENDIF
      IF ( useSchema4 ) THEN
        IF ( storedNextId.LE.globalMaxId .OR.
     &       storedNextId.LE.0_8 .OR.
     &       storedEventIndex.LT.0_8 .OR.
     &       INT(storedExpected,8)+storedBirth-storedDeath-
     &       storedBeach-storedOutside.NE.INT(storedLive,8) )
     &       mpiErrCount=mpiErrCount+1
      ENDIF
      globalErrCount = mpiErrCount
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allreduce(mpiErrCount,globalErrCount,1,MPI_INTEGER,
     &       MPI_SUM,MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.0 ) globalErrCount = globalErrCount + 1
      ENDIF
#endif
      IF ( globalErrCount.GT.0 ) THEN
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,A,A,3I12)')
     &         'BOM_READ_PICKUP: global ID budget failed suffix=',
     &         suffix, ' owner/id/expected=',
     &         globalOwnerCount, globalIdCount, storedOwnerBudget
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_READ_PICKUP'
      ENDIF

C--   One commit publishes the fully validated scratch transaction.
      IF ( activeSchema.EQ.bomPickupSchema2 )
     &     bomEnvReady = .FALSE.
      IF ( activeSchema.EQ.bomPickupSchema2 ) THEN
        DO bj=1,nSy
         DO bi=1,nSx
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            DO iSource=1,BOM_ENV_NSOURCE
             DO iEnd=1,BOM_ENV_NEND
              bomEnvEast(i,j,iEnd,iSource,bi,bj) =
     &             bomEnvEastScratch(i,j,iEnd,iSource,bi,bj)
              bomEnvNorth(i,j,iEnd,iSource,bi,bj) =
     &             bomEnvNorthScratch(i,j,iEnd,iSource,bi,bj)
              bomEnvValid(i,j,iEnd,iSource,bi,bj) =
     &             bomEnvValidScratch(i,j,iEnd,iSource,bi,bj)
             ENDDO
            ENDDO
           ENDDO
          ENDDO
         ENDDO
        ENDDO
      ENDIF
      IF ( useSchema4 .AND. bomUseBiology ) THEN
        bomBioReady=.FALSE.
        DO bj=1,nSy
         DO bi=1,nSx
          DO iEnd=1,BOM_ENV_NEND
           DO j=1-OLy,sNy+OLy
            DO i=1-OLx,sNx+OLx
              bomBioTemp(i,j,iEnd,bi,bj)=
     &             bomBioTempScratch(i,j,iEnd,bi,bj)
              bomBioN(i,j,iEnd,bi,bj)=
     &             bomBioNScratch(i,j,iEnd,bi,bj)
              bomBioValid(i,j,iEnd,bi,bj)=
     &             bomBioValidScratch(i,j,iEnd,bi,bj)
            ENDDO
           ENDDO
          ENDDO
         ENDDO
        ENDDO
      ENDIF
      DO bj=1,nSy
       DO bi=1,nSx
        bomNPartTile(bi,bj) = scratchCount(bi,bj)
        DO ip=1,bomMaxPartTile
          IF ( ip.LE.scratchCount(bi,bj) ) THEN
            bomId(ip,bi,bj) = scratchId(ip,bi,bj)
            bomStatus(ip,bi,bj) = scratchStatus(ip,bi,bj)
            IF ( useSchema4 ) THEN
              bomParentId(ip,bi,bj)=scratchParent(ip,bi,bj)
              bomS(ip,bi,bj)=scratchP4S(ip,bi,bj)
              bomBirthCount(ip,bi,bj)=
     &             scratchBirthCount(ip,bi,bj)
            ELSE
              bomParentId(ip,bi,bj)=0_8
              bomS(ip,bi,bj)=0. _d 0
              bomBirthCount(ip,bi,bj)=0
            ENDIF
            bomX(ip,bi,bj) = scratchReal(1,ip,bi,bj)
            bomY(ip,bi,bj) = scratchReal(2,ip,bi,bj)
            bomReleaseTime(ip,bi,bj) = scratchReal(3,ip,bi,bj)
            bomAge(ip,bi,bj) = scratchReal(4,ip,bi,bj)
            bomI(ip,bi,bj) = scratchReal(5,ip,bi,bj)
            bomJ(ip,bi,bj) = scratchReal(6,ip,bi,bj)
            bomVEast(ip,bi,bj) = scratchReal(7,ip,bi,bj)
            bomVNorth(ip,bi,bj) = scratchReal(8,ip,bi,bj)
            bomWindEast(ip,bi,bj) = scratchReal(9,ip,bi,bj)
            bomWindNorth(ip,bi,bj) = scratchReal(10,ip,bi,bj)
            bomDriftEast(ip,bi,bj) = scratchReal(11,ip,bi,bj)
            bomDriftNorth(ip,bi,bj) = scratchReal(12,ip,bi,bj)
            DO iDiag=1,BOM_RHS_NDIAG
              bomRhsDiag(iDiag,ip,bi,bj) =
     &             scratchDiag(iDiag,ip,bi,bj)
            ENDDO
            IF ( useSchema3 ) THEN
              bomSpringEast(ip,bi,bj) =
     &             scratchSpringEast(ip,bi,bj)
              bomSpringNorth(ip,bi,bj) =
     &             scratchSpringNorth(ip,bi,bj)
              bomNeighborCount(ip,bi,bj) =
     &             scratchNeighbor(ip,bi,bj)
              bomRaftId(ip,bi,bj) = scratchRaftId(ip,bi,bj)
              bomRaftSize(ip,bi,bj) = scratchRaftSize(ip,bi,bj)
            ELSE
              bomSpringEast(ip,bi,bj) = 0. _d 0
              bomSpringNorth(ip,bi,bj) = 0. _d 0
              bomNeighborCount(ip,bi,bj) = 0
              bomRaftId(ip,bi,bj) = 0_8
              bomRaftSize(ip,bi,bj) = 0
            ENDIF
          ELSE
            bomId(ip,bi,bj) = 0_8
            bomParentId(ip,bi,bj) = 0_8
            bomStatus(ip,bi,bj) = BOM_UNUSED
            bomBirthCount(ip,bi,bj) = 0
            bomX(ip,bi,bj) = 0. _d 0
            bomY(ip,bi,bj) = 0. _d 0
            bomReleaseTime(ip,bi,bj) = 0. _d 0
            bomAge(ip,bi,bj) = 0. _d 0
            bomI(ip,bi,bj) = 0. _d 0
            bomJ(ip,bi,bj) = 0. _d 0
            bomVEast(ip,bi,bj) = 0. _d 0
            bomVNorth(ip,bi,bj) = 0. _d 0
            bomWindEast(ip,bi,bj) = 0. _d 0
            bomWindNorth(ip,bi,bj) = 0. _d 0
            bomDriftEast(ip,bi,bj) = 0. _d 0
            bomDriftNorth(ip,bi,bj) = 0. _d 0
            bomS(ip,bi,bj) = 0. _d 0
            bomSpringEast(ip,bi,bj) = 0. _d 0
            bomSpringNorth(ip,bi,bj) = 0. _d 0
            bomNeighborCount(ip,bi,bj) = 0
            bomRaftId(ip,bi,bj) = 0_8
            bomRaftSize(ip,bi,bj) = 0
            DO iDiag=1,BOM_RHS_NDIAG
              bomRhsDiag(iDiag,ip,bi,bj) = 0. _d 0
            ENDDO
          ENDIF
        ENDDO
       ENDDO
      ENDDO
      bomNPartExpected = storedExpected
      bomNPartLiveExpected = storedOwnerBudget
      bomNextOutputTime = storedNext
      bomOutputScheduleReady = .TRUE.
      IF ( activeSchema.EQ.bomPickupSchema2 ) THEN
        bomEnvTime(BOM_ENV_OLD) = envTime0
        bomEnvTime(BOM_ENV_NEW) = envTime1
        bomEnvIter(BOM_ENV_OLD) = envIter0
        bomEnvIter(BOM_ENV_NEW) = envIter1
        bomEnvReady = .TRUE.
      ENDIF
      IF ( useSchema4 ) THEN
        bomNextId=storedNextId
        bomEventTimeIndex=storedEventIndex
        bomBirthEvents=storedBirth
        bomDeathEvents=storedDeath
        bomBeachEvents=storedBeach
        bomOutsideEvents=storedOutside
        bomCancelEvents=storedCancel
        bomMissingGrowthEvents=storedMissing
        bomEventShardRecords=storedShardRecords
        bomEventShardBirth=storedShardBirth
        bomEventShardDeath=storedShardDeath
        bomEventShardBeach=storedShardBeach
        bomEventShardOutside=storedShardOutside
        bomEventShardCancel=storedShardCancel
        bomEventShardTimeMin=storedShardTimeMin
        bomEventShardTimeMax=storedShardTimeMax
        bomEventShardReady=.TRUE.
        CALL BOM_EVENT_BUFFER_CLEAR
        IF ( bomUseBiology ) THEN
          DO iEnd=1,BOM_ENV_NEND
            bomBioTime(iEnd)=storedBioTime(iEnd)
            bomBioIter(iEnd)=storedBioIter(iEnd)
            bomBioTempSource(iEnd)=storedTempSource(iEnd)
            bomBioNSource(iEnd)=storedNSource(iEnd)
          ENDDO
          bomBioReady=storedBioReady
        ENDIF
        bomFreeRebuildOps=0_8
        bomFreeRemoveOps=0_8
        bomFreeAllocOps=0_8
        DO bj=1,nSy
         DO bi=1,nSx
          nFree=bomMaxPartTile-bomNPartTile(bi,bj)
          bomFreeCount(bi,bj)=nFree
          DO ip=1,nFree
            bomFreeStack(ip,bi,bj)=bomMaxPartTile-ip+1
          ENDDO
          DO ip=nFree+1,bomMaxPartTile
            bomFreeStack(ip,bi,bj)=0
          ENDDO
          bomFreeRebuildOps=bomFreeRebuildOps+1_8
         ENDDO
        ENDDO
      ENDIF
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A,A,A,I12,A,3(1X,1PE24.16))')
     &       'BOM_READ_PICKUP: complete suffix=', suffix,
     &       ' count=', storedOwnerBudget,
     &       ' time/freq/next=', storedTime, storedFreq, storedNext
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF

      _END_MASTER(myThid)
      _BARRIER
C--   Schema 2 stores primary endpoints; derived gradients are rebuilt.
      IF ( bomMode.EQ.'BOM' ) THEN
        CALL BOM_BUILD_DERIVATIVES( myThid )
      ENDIF
      _BARRIER
#endif

      RETURN
      END
