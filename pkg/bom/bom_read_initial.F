#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_READ_INITIAL

C !INTERFACE:
      SUBROUTINE BOM_READ_INITIAL( myThid )

C !DESCRIPTION:
C     Read and validate the bounded Phase-1.1 global initial file.
C     Every rank reads the small verification file and retains only the
C     records owned by its local regular tiles.  This is deliberately
C     limited by bomInitGlobalLimit and is not the production reader.

C !USES:
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
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
      INTEGER bomRecordSize
      PARAMETER ( bomRecordSize = 8 )
      _RL record(bomRecordSize)
      _RS dummyRS(1)
      INTEGER*8 inputIds(bomMaxInitRecords)
      INTEGER*8 particleId
      INTEGER ioUnit, bi, bj, ip, jp, slot
      INTEGER ownerBi, ownerBj
      INTEGER nInput, nAssignedLocal, nAssignedGlobal
      INTEGER nAliveLocal, nAliveGlobal
      INTEGER nWaitingLocal, nWaitingGlobal
      INTEGER nFoundLocal, statusValue
      INTEGER errCount, globalErrCount, idError, k
      INTEGER metaFilePrec, metaNDims, metaNFlds, metaNTimRec
      INTEGER metaDimList(3,3), metaNRecords, metaFileIter, prefixLen
      INTEGER*8 dataFileBytes, expectedFileBytes
      _RL ix, jy, ownerIx, ownerJy
      _RL metaTimList(1), metaMissingValue
      LOGICAL isLocal, isWet, recordValid, headerFinite, ownerWet
      LOGICAL useCurrentDir, dataFileExists
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*(MAX_LEN_MBUF) metaSimulation, metaTitle
      CHARACTER*8 metaFieldList(1)
      CHARACTER*(MAX_LEN_FNAM) dataFileName

      nInput = 0
      nAssignedLocal = 0
      nAliveLocal = 0
      nWaitingLocal = 0
      errCount = 0

      _BEGIN_MASTER(myThid)

C--   The BOM initial-file contract requires a standard MDS meta file.
C     fldList(1) carries the BOM schema independently of the data header.
      metaNDims = 3
      metaNFlds = 1
      metaNTimRec = 0
      useCurrentDir = .TRUE.
      CALL MDS_READ_META(
     I     bomInitialFile,
     O     metaSimulation, metaTitle, metaFilePrec,
     U     metaNDims, metaNFlds, metaNTimRec,
     O     metaDimList, metaFieldList, metaTimList,
     O     metaMissingValue, metaNRecords, metaFileIter,
     I     useCurrentDir, myThid )

      IF ( metaNFlds.LT.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_READ_INITIAL: required MDS meta file is missing'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSE
        IF ( metaNDims.NE.3 ) THEN
          WRITE(msgBuf,'(A,I4,A)')
     &         'BOM_READ_INITIAL: meta nDims=', metaNDims,
     &         ' expected=3'
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ELSEIF (
     &       metaDimList(1,1).NE.1 .OR.
     &       metaDimList(2,1).NE.1 .OR.
     &       metaDimList(3,1).NE.1 .OR.
     &       metaDimList(1,2).NE.1 .OR.
     &       metaDimList(2,2).NE.1 .OR.
     &       metaDimList(3,2).NE.1 .OR.
     &       metaDimList(1,3).NE.bomRecordSize .OR.
     &       metaDimList(2,3).NE.1 .OR.
     &       metaDimList(3,3).NE.bomRecordSize ) THEN
          WRITE(msgBuf,'(A)')
     &         'BOM_READ_INITIAL: invalid MDS meta dimList'
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
        IF ( metaFilePrec.NE.precFloat64 ) THEN
          WRITE(msgBuf,'(A,I4,A,I4)')
     &         'BOM_READ_INITIAL: meta precision=', metaFilePrec,
     &         ' expected=', precFloat64
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
        IF ( metaNFlds.NE.1 .OR.
     &       metaFieldList(1).NE.'BOMV0001' ) THEN
          WRITE(msgBuf,'(A,I4,A,A)')
     &         'BOM_READ_INITIAL: meta schema fields=', metaNFlds,
     &         ' schema=', metaFieldList(1)
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
        IF ( metaNRecords.LT.2 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_READ_INITIAL: invalid meta record count=',
     &         metaNRecords
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
      ENDIF

      ioUnit = -1
      bi = 0
      bj = 0
      CALL MDS_READVEC_LOC(
     I     bomInitialFile, precFloat64, ioUnit,
     I     'RL', bomRecordSize, record, dummyRS,
     I     bi, bj, 1, myThid )

C--   Header: schema, fields, count, coordinate, ID encoding,
C     precision, reserved, reserved.
      headerFinite = .TRUE.
      DO k=1,bomRecordSize
        IF ( record(k).NE.record(k) .OR.
     &       ABS(record(k)).GT.HUGE(record(k)) )
     &       headerFinite = .FALSE.
      ENDDO
      IF ( .NOT.headerFinite ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_READ_INITIAL: non-finite header field'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSE
       IF ( record(1).NE.DFLOAT(bomInitialSchema) ) THEN
        WRITE(msgBuf,'(A,F12.3,A,I4)')
     &       'BOM_READ_INITIAL: schema=', record(1),
     &       ' expected=', bomInitialSchema
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
      IF ( record(2).NE.DFLOAT(bomInitialFields) ) THEN
        WRITE(msgBuf,'(A,F12.3,A,I4)')
     &       'BOM_READ_INITIAL: fields=', record(2),
     &       ' expected=', bomInitialFields
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
      IF ( record(3).NE.DNINT(record(3)) .OR.
     &     record(3).LT.1. _d 0 .OR.
     &     record(3).GT.DFLOAT(bomInitGlobalLimit) ) THEN
        WRITE(msgBuf,'(A,F16.3,A,I8)')
     &       'BOM_READ_INITIAL: invalid particle count=', record(3),
     &       ' limit=', bomInitGlobalLimit
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ELSE
        nInput = NINT(record(3))
      ENDIF
      IF ( nInput.GT.bomMaxParticles ) THEN
        WRITE(msgBuf,'(A,I8,A,I8)')
     &       'BOM_READ_INITIAL: input count=', nInput,
     &       ' exceeds bomMaxParticles=', bomMaxParticles
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
      IF ( record(4).NE.1. _d 0 ) THEN
        WRITE(msgBuf,'(A,F12.3)')
     &       'BOM_READ_INITIAL: coordinateCode must be 1, got ',
     &       record(4)
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
      IF ( record(5).NE.1. _d 0 ) THEN
        WRITE(msgBuf,'(A,F12.3)')
     &       'BOM_READ_INITIAL: idEncoding must be 1, got ',
     &       record(5)
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
      IF ( record(6).NE.64. _d 0 ) THEN
        WRITE(msgBuf,'(A,F12.3)')
     &       'BOM_READ_INITIAL: precisionBits must be 64, got ',
     &       record(6)
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF
       IF ( record(7).NE.0. _d 0 .OR.
     &     record(8).NE.0. _d 0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'BOM_READ_INITIAL: header reserved fields must be zero'
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
       ENDIF
      ENDIF

      IF ( nInput.GT.0 .AND.
     &     metaNRecords.NE.nInput+1 ) THEN
        WRITE(msgBuf,'(A,I8,A,I8)')
     &       'BOM_READ_INITIAL: meta records=', metaNRecords,
     &       ' expected from header=', nInput+1
        CALL PRINT_ERROR( msgBuf, myThid )
        errCount = errCount + 1
      ENDIF

C--   Cross-check the physical data-file length.  MDS_READVEC_LOC first
C     tries the bare prefix, then the .data suffix for a global vector;
C     use the same precedence here.  SIZE and the expected byte count are
C     INTEGER*8 so the check remains safe beyond the P1.1 verification cap.
      IF ( nInput.GT.0 .AND. errCount.EQ.0 ) THEN
        prefixLen = ILNBLNK( bomInitialFile )
        dataFileName = bomInitialFile
        dataFileBytes = -1
        INQUIRE( FILE=dataFileName, EXIST=dataFileExists,
     &           SIZE=dataFileBytes )
        IF ( .NOT.dataFileExists ) THEN
          WRITE(dataFileName,'(2A)')
     &         bomInitialFile(1:prefixLen), '.data'
          dataFileBytes = -1
          INQUIRE( FILE=dataFileName, EXIST=dataFileExists,
     &             SIZE=dataFileBytes )
        ENDIF
        expectedFileBytes = INT(nInput+1,8)
     &                    * INT(bomRecordSize,8) * 8_8
        IF ( .NOT.dataFileExists .OR.
     &       dataFileBytes.NE.expectedFileBytes ) THEN
          WRITE(msgBuf,'(A,I20,A,I20)')
     &         'BOM_READ_INITIAL: physical data bytes=', dataFileBytes,
     &         ' expected=', expectedFileBytes
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF
      ENDIF

      IF ( errCount.EQ.0 ) THEN
       DO ip=1,nInput
        CALL MDS_READVEC_LOC(
     I       bomInitialFile, precFloat64, ioUnit,
     I       'RL', bomRecordSize, record, dummyRS,
     I       bi, bj, ip+1, myThid )

        recordValid = .TRUE.
        DO k=1,bomRecordSize
          IF ( record(k).NE.record(k) .OR.
     &         ABS(record(k)).GT.HUGE(record(k)) )
     &         recordValid = .FALSE.
        ENDDO
        IF ( .NOT.recordValid ) THEN
          WRITE(msgBuf,'(A,I8)')
     &         'BOM_READ_INITIAL: non-finite record=', ip
          CALL PRINT_ERROR( msgBuf, myThid )
          errCount = errCount + 1
        ENDIF

        particleId = 0
        inputIds(ip) = 0
        statusValue = BOM_INVALID
        IF ( recordValid ) THEN
          CALL BOM_ID_FROM_WORDS(
     I         record(1), record(2),
     O         particleId, idError )
          IF ( idError.NE.0 ) THEN
            WRITE(msgBuf,'(A,I8,A,I4)')
     &           'BOM_READ_INITIAL: invalid ID record=', ip,
     &           ' code=', idError
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
            recordValid = .FALSE.
          ELSE
            inputIds(ip) = particleId
            DO jp=1,ip-1
              IF ( particleId.EQ.inputIds(jp) ) THEN
                WRITE(msgBuf,'(A,I20,A,2I8)')
     &               'BOM_READ_INITIAL: duplicate ID=', particleId,
     &               ' records=', jp, ip
                CALL PRINT_ERROR( msgBuf, myThid )
                errCount = errCount + 1
                recordValid = .FALSE.
              ENDIF
            ENDDO
          ENDIF

          IF ( record(6).NE.DNINT(record(6)) ) THEN
            statusValue = BOM_INVALID
          ELSE
            statusValue = NINT(record(6))
          ENDIF
          IF ( statusValue.NE.BOM_ALIVE .AND.
     &         statusValue.NE.BOM_WAITING ) THEN
            WRITE(msgBuf,'(A,I8,A,F12.3)')
     &           'BOM_READ_INITIAL: invalid status record=', ip,
     &           ' value=', record(6)
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
            recordValid = .FALSE.
          ENDIF

          IF ( record(5).LT.0. _d 0 ) THEN
            WRITE(msgBuf,'(A,I8)')
     &           'BOM_READ_INITIAL: invalid release time record=', ip
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
            recordValid = .FALSE.
          ENDIF
          IF ( record(7).LT.0. _d 0 ) THEN
            WRITE(msgBuf,'(A,I8)')
     &           'BOM_READ_INITIAL: invalid age record=', ip
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
            recordValid = .FALSE.
          ENDIF
          IF ( record(8).NE.0. _d 0 ) THEN
            WRITE(msgBuf,'(A,I8)')
     &           'BOM_READ_INITIAL: reserved field nonzero record=', ip
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
            recordValid = .FALSE.
          ENDIF
          IF ( statusValue.EQ.BOM_WAITING .AND.
     &         record(5).LE.startTime ) THEN
            WRITE(msgBuf,'(A,I8)')
     &           'BOM_READ_INITIAL: WAITING release record=', ip
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
            recordValid = .FALSE.
          ELSEIF ( statusValue.EQ.BOM_ALIVE .AND.
     &             record(5).GT.startTime ) THEN
            WRITE(msgBuf,'(A,I8)')
     &           'BOM_READ_INITIAL: future ALIVE release record=', ip
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
            recordValid = .FALSE.
          ENDIF
          IF ( statusValue.EQ.BOM_WAITING .AND.
     &         record(7).NE.0. _d 0 ) THEN
            WRITE(msgBuf,'(A,I8)')
     &           'BOM_READ_INITIAL: WAITING age must be zero: ', ip
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
            recordValid = .FALSE.
          ENDIF
        ENDIF

        IF ( recordValid ) THEN
          nFoundLocal = 0
          ownerBi = 0
          ownerBj = 0
          ownerIx = -1. _d 0
          ownerJy = -1. _d 0
          ownerWet = .FALSE.
          DO bj=1,nSy
           DO bi=1,nSx
            CALL BOM_LOCATE_INITIAL(
     I           record(3), record(4), bi, bj,
     O           ix, jy, isLocal, isWet,
     I           myThid )
            IF ( isLocal ) THEN
              nFoundLocal = nFoundLocal + 1
              IF ( nFoundLocal.EQ.1 ) THEN
                ownerBi = bi
                ownerBj = bj
                ownerIx = ix
                ownerJy = jy
                ownerWet = isWet
              ENDIF
            ENDIF
           ENDDO
          ENDDO

          IF ( nFoundLocal.GT.1 ) THEN
            WRITE(msgBuf,'(A,I20,A,I8)')
     &           'BOM_READ_INITIAL: multiple local owners id=',
     &           particleId, ' count=', nFoundLocal
            CALL PRINT_ERROR( msgBuf, myThid )
            errCount = errCount + 1
          ELSEIF ( nFoundLocal.EQ.1 ) THEN
            IF ( .NOT.ownerWet ) THEN
              WRITE(msgBuf,'(A,I20,A,2I4)')
     &             'BOM_READ_INITIAL: particle on dry cell id=',
     &             particleId, ' tile=', ownerBi, ownerBj
              CALL PRINT_ERROR( msgBuf, myThid )
              errCount = errCount + 1
            ELSEIF ( bomNPartTile(ownerBi,ownerBj)
     &               .GE.bomMaxPartTile ) THEN
              WRITE(msgBuf,'(A,2I4,A,I8,A,I8)')
     &             'BOM_READ_INITIAL: tile=', ownerBi, ownerBj,
     &             ' needs=', bomNPartTile(ownerBi,ownerBj)+1,
     &             ' capacity=', bomMaxPartTile
              CALL PRINT_ERROR( msgBuf, myThid )
              errCount = errCount + 1
            ELSE
              slot = bomNPartTile(ownerBi,ownerBj) + 1
              bomNPartTile(ownerBi,ownerBj) = slot
              bomId(slot,ownerBi,ownerBj)          = particleId
              bomStatus(slot,ownerBi,ownerBj)      = statusValue
              bomX(slot,ownerBi,ownerBj)           = record(3)
              bomY(slot,ownerBi,ownerBj)           = record(4)
              bomReleaseTime(slot,ownerBi,ownerBj) = record(5)
              bomAge(slot,ownerBi,ownerBj)         = record(7)
              bomI(slot,ownerBi,ownerBj)           = ownerIx
              bomJ(slot,ownerBi,ownerBj)           = ownerJy
              nAssignedLocal = nAssignedLocal + 1
              IF ( statusValue.EQ.BOM_ALIVE )
     &             nAliveLocal = nAliveLocal + 1
              IF ( statusValue.EQ.BOM_WAITING )
     &             nWaitingLocal = nWaitingLocal + 1
              IF ( nInput.LE.16 ) THEN
                WRITE(msgBuf,1000)
     &               'BOM_READ_INITIAL: id=', particleId,
     &               ' rank=', myProcId,
     &               ' tile=', ownerBi, ownerBj,
     &               ' status=', statusValue,
     &               ' xy=', record(3), record(4),
     &               ' release-age=', record(5), record(7),
     &               ' ij=', ownerIx, ownerJy
                CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                              SQUEEZE_RIGHT, myThid )
              ENDIF
            ENDIF
          ENDIF
        ENDIF
       ENDDO
      ENDIF

      IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
      _END_MASTER(myThid)
      _BARRIER

      globalErrCount = errCount
      nAssignedGlobal = nAssignedLocal
      nAliveGlobal = nAliveLocal
      nWaitingGlobal = nWaitingLocal
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      CALL GLOBAL_SUM_INT( nAssignedGlobal, myThid )
      CALL GLOBAL_SUM_INT( nAliveGlobal, myThid )
      CALL GLOBAL_SUM_INT( nWaitingGlobal, myThid )

      IF ( nAssignedGlobal.NE.nInput ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8,A,I8)')
     &         'BOM_READ_INITIAL: owner count=', nAssignedGlobal,
     &         ' expected=', nInput
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        globalErrCount = globalErrCount + 1
      ENDIF

      IF ( globalErrCount.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8,A)')
     &         'BOM_READ_INITIAL: detected ', globalErrCount,
     &         ' fatal validation error(s)'
          CALL PRINT_ERROR( msgBuf, myThid )
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE( 0 )
        STOP 'ABNORMAL END: S/R BOM_READ_INITIAL'
      ENDIF

      _BEGIN_MASTER(myThid)
      bomNPartExpected = nInput
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A,4(A,I8))')
     &       'BOM_READ_INITIAL: complete',
     &       ' owners=', nAssignedGlobal,
     &       ' alive=', nAliveGlobal,
     &       ' waiting=', nWaitingGlobal,
     &       ' expected=', bomNPartExpected
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      ENDIF
      _END_MASTER(myThid)
      _BARRIER
 1000 FORMAT(A,I20,A,I6,A,2I4,A,I3,A,2F24.16,
     &       A,2F24.16,A,2F24.16)
#endif

      RETURN
      END
