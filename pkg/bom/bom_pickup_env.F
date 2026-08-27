#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_WRITE_PICKUP_ENV
C !INTERFACE:
      SUBROUTINE BOM_WRITE_PICKUP_ENV(
     I                 particlePrefix, myTime, myIter,
     I                 envFields, myThid )

C !DESCRIPTION:
C     Write one fixed schema-2 environmental endpoint record per tile.
C     The complete halos are retained for exact same-decomposition restart.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      CHARACTER*(*) particlePrefix
      _RL myTime
      INTEGER myIter, envFields, myThid

#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_FNAM) envName
      _RL record(bomPickupEnvHeader
     & +3*(sNx+2*OLx)*(sNy+2*OLy)
     &    *BOM_ENV_NEND*BOM_ENV_NSOURCE)
      _RL chunk(bomPickupChunkFields)
      _RS dummyRS(1)
      INTEGER bi, bj, i, j, iEnd, iSource
      INTEGER k, ioUnit, iGlobal, jGlobal
      INTEGER iRecord, nRecords, iValue, writeRecord

      WRITE(envName,'(A,A)')
     &     particlePrefix(1:LEN_TRIM(particlePrefix)), '.env'
      DO bj=1,nSy
       DO bi=1,nSx
        DO k=1,envFields
          record(k) = 0. _d 0
        ENDDO
        iGlobal = myXGlobalLo + (bi-1)*sNx
        jGlobal = myYGlobalLo + (bj-1)*sNy
        record(1) = DFLOAT(bomPickupSchema2)
        record(2) = DFLOAT(envFields)
        record(3) = DFLOAT(myIter)
        record(4) = myTime
        record(5) = DFLOAT(bomEnvIter(BOM_ENV_OLD))
        record(6) = DFLOAT(bomEnvIter(BOM_ENV_NEW))
        record(7) = bomEnvTime(BOM_ENV_OLD)
        record(8) = bomEnvTime(BOM_ENV_NEW)
        record(9) = DFLOAT(nPx)
        record(10) = DFLOAT(nPy)
        record(11) = DFLOAT(iGlobal)
        record(12) = DFLOAT(jGlobal)
        k = bomPickupEnvHeader
        DO iSource=1,BOM_ENV_NSOURCE
         DO iEnd=1,BOM_ENV_NEND
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            k = k + 1
            record(k) = bomEnvEast(i,j,iEnd,iSource,bi,bj)
            k = k + 1
            record(k) = bomEnvNorth(i,j,iEnd,iSource,bi,bj)
            k = k + 1
            IF ( bomEnvValid(i,j,iEnd,iSource,bi,bj) )
     &           record(k) = 1. _d 0
           ENDDO
          ENDDO
         ENDDO
        ENDDO
        IF ( k.NE.envFields ) THEN
          CALL ALL_PROC_DIE( 0 )
          STOP 'ABNORMAL END: S/R BOM_WRITE_PICKUP_ENV'
        ENDIF
        nRecords = (envFields+bomPickupChunkFields-1)
     &             /bomPickupChunkFields
        ioUnit = -1
        DO iRecord=1,nRecords
          DO k=1,bomPickupChunkFields
            chunk(k) = 0. _d 0
            iValue = (iRecord-1)*bomPickupChunkFields+k
            IF ( iValue.LE.envFields ) chunk(k) = record(iValue)
          ENDDO
          writeRecord = iRecord
          IF ( iRecord.LT.nRecords ) writeRecord = -iRecord
          CALL MDS_WRITEVEC_LOC(
     I         envName, precFloat64, ioUnit,
     I         'RL', bomPickupChunkFields, chunk, dummyRS,
     I         bi, bj, writeRecord, myIter, myThid )
        ENDDO
        CLOSE(ioUnit)
       ENDDO
      ENDDO
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_READ_PICKUP_ENV
C !INTERFACE:
      SUBROUTINE BOM_READ_PICKUP_ENV(
     I                 particlePrefix, storedTime, storedIter,
     I                 envTime0, envTime1, envIter0, envIter1,
     I                 envFields,
     O                 localErrCount,
     I                 myThid )

C !DESCRIPTION:
C     Preflight and decode schema-2 environmental endpoint records into
C     non-authoritative scratch storage.  The caller owns the final commit.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      CHARACTER*(*) particlePrefix
      _RL storedTime, envTime0, envTime1
      INTEGER storedIter, envIter0, envIter1, envFields
      INTEGER localErrCount, myThid

#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_FNAM) envName, physicalPrefix
      CHARACTER*(MAX_LEN_FNAM) tilePrefix, dataName, metaName
      CHARACTER*(MAX_LEN_MBUF) metaSimulation, metaTitle
      CHARACTER*8 metaFieldList(1)
      _RL record(bomPickupEnvHeader
     & +3*(sNx+2*OLx)*(sNy+2*OLy)
     &    *BOM_ENV_NEND*BOM_ENV_NSOURCE)
      _RL chunk(bomPickupChunkFields)
      _RL metaTimList(1), metaMissingValue
      _RL eastValue, northValue
      _RS dummyRS(1)
      INTEGER metaDimList(3,3)
      INTEGER bi, bj, i, j, iEnd, iSource, k, ioUnit
      INTEGER iGlobal, jGlobal, iTile, jTile
      INTEGER prefixLen, localDirLen
      INTEGER iRecord, nRecords, iValue
      INTEGER metaFilePrec, metaNDims, metaNFlds, metaNTimRec
      INTEGER metaNRecords, metaFileIter
      INTEGER*8 tileBytes(nSx,nSy), expectedBytes
      LOGICAL dataExists, metaExists, useCurrentDir
      LOGICAL recordFinite, wetPoint, validValue, freshBracket

      localErrCount = 0
      IF ( envFields.NE.bomPickupEnvHeader
     & +3*(sNx+2*OLx)*(sNy+2*OLy)
     &    *BOM_ENV_NEND*BOM_ENV_NSOURCE ) THEN
        localErrCount = localErrCount + 1
        RETURN
      ENDIF
      WRITE(envName,'(A,A)')
     &     particlePrefix(1:LEN_TRIM(particlePrefix)), '.env'
      prefixLen = LEN_TRIM(envName)
      localDirLen = LEN_TRIM(mdsioLocalDir)
      IF ( localDirLen.GT.0 ) THEN
        WRITE(physicalPrefix,'(2A)')
     &       mdsioLocalDir(1:localDirLen), envName(1:prefixLen)
      ELSE
        physicalPrefix = envName
      ENDIF
      nRecords = (envFields+bomPickupChunkFields-1)
     &           /bomPickupChunkFields
      expectedBytes = INT(nRecords,8)*INT(bomPickupChunkFields,8)*8_8

C--   No MDS read is attempted until every local sidecar is present.
      DO bj=1,nSy
       DO bi=1,nSx
        iTile = bi + (myXGlobalLo-1)/sNx
        jTile = bj + (myYGlobalLo-1)/sNy
        WRITE(tilePrefix,'(A,A,I3.3,A,I3.3)')
     &       physicalPrefix(1:LEN_TRIM(physicalPrefix)), '.',
     &       iTile, '.', jTile
        WRITE(dataName,'(A,A)')
     &       tilePrefix(1:LEN_TRIM(tilePrefix)), '.data'
        WRITE(metaName,'(A,A)')
     &       tilePrefix(1:LEN_TRIM(tilePrefix)), '.meta'
        tileBytes(bi,bj) = -1_8
        INQUIRE(FILE=dataName,EXIST=dataExists,SIZE=tileBytes(bi,bj))
        INQUIRE(FILE=metaName,EXIST=metaExists)
        IF ( .NOT.dataExists .OR. .NOT.metaExists .OR.
     &       tileBytes(bi,bj).NE.expectedBytes )
     &       localErrCount = localErrCount + 1
       ENDDO
      ENDDO
      IF ( localErrCount.GT.0 ) RETURN

      freshBracket = envTime0.EQ.envTime1
      DO bj=1,nSy
       DO bi=1,nSx
        iTile = bi + (myXGlobalLo-1)/sNx
        jTile = bj + (myYGlobalLo-1)/sNy
        WRITE(tilePrefix,'(A,A,I3.3,A,I3.3)')
     &       physicalPrefix(1:LEN_TRIM(physicalPrefix)), '.',
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
        DO iRecord=1,nRecords
          CALL MDS_READVEC_LOC(
     I         envName, precFloat64, ioUnit,
     I         'RL', bomPickupChunkFields, chunk, dummyRS,
     I         bi, bj, iRecord, myThid )
          DO k=1,bomPickupChunkFields
            iValue = (iRecord-1)*bomPickupChunkFields+k
            IF ( iValue.LE.envFields ) record(iValue) = chunk(k)
          ENDDO
        ENDDO
        CLOSE(ioUnit)

        recordFinite = .TRUE.
        DO k=1,envFields
          IF ( .NOT.IEEE_IS_FINITE(record(k)) )
     &         recordFinite = .FALSE.
        ENDDO
        iGlobal = myXGlobalLo + (bi-1)*sNx
        jGlobal = myYGlobalLo + (bj-1)*sNy
        IF ( .NOT.recordFinite .OR.
     &       record(1).NE.DFLOAT(bomPickupSchema2) .OR.
     &       record(2).NE.DFLOAT(envFields) .OR.
     &       record(3).NE.DFLOAT(storedIter) .OR.
     &       TRANSFER(record(4),0_8).NE.
     &       TRANSFER(storedTime,0_8) .OR.
     &       record(5).NE.DFLOAT(envIter0) .OR.
     &       record(6).NE.DFLOAT(envIter1) .OR.
     &       TRANSFER(record(7),0_8).NE.
     &       TRANSFER(envTime0,0_8) .OR.
     &       TRANSFER(record(8),0_8).NE.
     &       TRANSFER(envTime1,0_8) .OR.
     &       record(9).NE.DFLOAT(nPx) .OR.
     &       record(10).NE.DFLOAT(nPy) .OR.
     &       record(11).NE.DFLOAT(iGlobal) .OR.
     &       record(12).NE.DFLOAT(jGlobal) )
     &       localErrCount = localErrCount + 1
        IF ( metaFilePrec.NE.precFloat64 .OR. metaNDims.NE.3 .OR.
     &       metaNRecords.NE.nRecords .OR.
     &       metaFileIter.NE.storedIter .OR.
     &       metaDimList(1,1).NE.nSx*nPx .OR.
     &       metaDimList(2,1).NE.iTile .OR.
     &       metaDimList(3,1).NE.iTile .OR.
     &       metaDimList(1,2).NE.nSy*nPy .OR.
     &       metaDimList(2,2).NE.jTile .OR.
     &       metaDimList(3,2).NE.jTile .OR.
     &       metaDimList(1,3).NE.bomPickupChunkFields .OR.
     &       metaDimList(2,3).NE.1 .OR.
     &       metaDimList(3,3).NE.bomPickupChunkFields )
     &       localErrCount = localErrCount + 1

        k = bomPickupEnvHeader
        DO iSource=1,BOM_ENV_NSOURCE
         DO iEnd=1,BOM_ENV_NEND
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            k = k + 1
            eastValue = record(k)
            k = k + 1
            northValue = record(k)
            k = k + 1
            validValue = record(k).EQ.1. _d 0
            IF ( record(k).NE.0. _d 0 .AND.
     &           record(k).NE.1. _d 0 )
     &           localErrCount = localErrCount + 1
            bomEnvEastScratch(i,j,iEnd,iSource,bi,bj) = eastValue
            bomEnvNorthScratch(i,j,iEnd,iSource,bi,bj) = northValue
            bomEnvValidScratch(i,j,iEnd,iSource,bi,bj) = validValue
            wetPoint = maskC(i,j,1,bi,bj).GT.0.
            IF ( wetPoint ) THEN
              IF ( .NOT.validValue )
     &             localErrCount = localErrCount + 1
            ELSEIF ( validValue .OR. eastValue.NE.0. _d 0 .OR.
     &               northValue.NE.0. _d 0 ) THEN
              localErrCount = localErrCount + 1
            ENDIF
           ENDDO
          ENDDO
         ENDDO
        ENDDO
        IF ( k.NE.envFields ) localErrCount = localErrCount + 1

        IF ( freshBracket ) THEN
          DO iSource=1,BOM_ENV_NSOURCE
           DO j=1-OLy,sNy+OLy
            DO i=1-OLx,sNx+OLx
             IF ( TRANSFER(bomEnvEastScratch(i,j,BOM_ENV_OLD,
     &            iSource,bi,bj),0_8).NE.
     &            TRANSFER(bomEnvEastScratch(i,j,BOM_ENV_NEW,
     &            iSource,bi,bj),0_8) .OR.
     &            TRANSFER(bomEnvNorthScratch(i,j,BOM_ENV_OLD,
     &            iSource,bi,bj),0_8).NE.
     &            TRANSFER(bomEnvNorthScratch(i,j,BOM_ENV_NEW,
     &            iSource,bi,bj),0_8) .OR.
     &            bomEnvValidScratch(i,j,BOM_ENV_OLD,
     &            iSource,bi,bj).NEQV.
     &            bomEnvValidScratch(i,j,BOM_ENV_NEW,
     &            iSource,bi,bj) )
     &            localErrCount = localErrCount + 1
            ENDDO
           ENDDO
          ENDDO
        ENDIF
       ENDDO
      ENDDO
      IF ( localErrCount.EQ.0 ) THEN
        bomEnvTimeScratch(BOM_ENV_OLD) = envTime0
        bomEnvTimeScratch(BOM_ENV_NEW) = envTime1
        bomEnvIterScratch(BOM_ENV_OLD) = envIter0
        bomEnvIterScratch(BOM_ENV_NEW) = envIter1
      ENDIF
#else
      localErrCount = 1
#endif

      RETURN
      END
