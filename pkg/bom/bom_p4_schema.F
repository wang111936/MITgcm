#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P4_GLOBAL_SUM_COUNTS(
     I                 localCounts,nCounts,
     O                 globalCounts,localErrCount,
     I                 myThid)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
      INTEGER nCounts,localErrCount,myThid
      INTEGER*8 localCounts(nCounts),globalCounts(nCounts)
      INTEGER hiLocal(nCounts),loLocal(nCounts)
      INTEGER hiAll(nCounts*nPx*nPy),loAll(nCounts*nPx*nPy)
      INTEGER i,j,index,mpiRC
      INTEGER*8 highWord,lowWord,value,radix
      LOGICAL wordValid

      localErrCount=0
      radix=4294967296_8
      DO i=1,nCounts
        globalCounts(i)=0_8
        CALL BOM_P4_I8_WORDS(
     I       localCounts(i),highWord,lowWord,
     O       wordValid)
        IF ( .NOT.wordValid ) localErrCount=localErrCount+1
        hiLocal(i)=INT(highWord)
        IF ( lowWord.GT.2147483647_8 ) THEN
          loLocal(i)=INT(lowWord-radix)
        ELSE
          loLocal(i)=INT(lowWord)
        ENDIF
      ENDDO
#ifdef ALLOW_USE_MPI
      IF ( usingMPI ) THEN
        CALL MPI_Allgather(hiLocal,nCounts,MPI_INTEGER,
     &       hiAll,nCounts,MPI_INTEGER,MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.0 ) localErrCount=localErrCount+1
        CALL MPI_Allgather(loLocal,nCounts,MPI_INTEGER,
     &       loAll,nCounts,MPI_INTEGER,MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.0 ) localErrCount=localErrCount+1
      ELSE
#endif
        DO i=1,nCounts
          hiAll(i)=hiLocal(i)
          loAll(i)=loLocal(i)
        ENDDO
#ifdef ALLOW_USE_MPI
      ENDIF
#endif
      IF ( localErrCount.NE.0 ) RETURN
      DO j=1,nPx*nPy
       DO i=1,nCounts
        index=(j-1)*nCounts+i
        highWord=INT(hiAll(index),8)
        lowWord=INT(loAll(index),8)
        IF ( lowWord.LT.0_8 ) lowWord=lowWord+radix
        IF ( highWord.LT.0_8 .OR. lowWord.LT.0_8 .OR.
     &       lowWord.GE.radix .OR.
     &       highWord.GT.(HUGE(value)-lowWord)/radix ) THEN
          localErrCount=localErrCount+1
        ELSE
          value=highWord*radix+lowWord
          IF ( value.GT.HUGE(value)-globalCounts(i) ) THEN
            localErrCount=localErrCount+1
          ELSE
            globalCounts(i)=globalCounts(i)+value
          ENDIF
        ENDIF
       ENDDO
      ENDDO
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BUILD_P4_SIGNATURE
C !INTERFACE:
      SUBROUTINE BOM_BUILD_P4_SIGNATURE(
     I                 fileClass, coreFields,
     I                 myTime, scheduledTime, nextOutput, myIter,
     O                 signature, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Build the schema-4 container signature.  The released schema-2 core
C     and optional P3 files remain separate, byte-for-byte members; this
C     signature records their presence and the complete P4 restart state.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER fileClass,coreFields,myIter,myThid
      _RL myTime,scheduledTime,nextOutput
      _RL signature(bomP4SigFields)
      LOGICAL isValid
      INTEGER k,offset,springCode
      INTEGER*8 wordHi,wordLo
      LOGICAL wordValid

      isValid=.FALSE.
      DO k=1,bomP4SigFields
        signature(k)=0. _d 0
      ENDDO
      IF ( bomMode.NE.'BOM' ) RETURN
      IF ( .NOT.bomUseLand .AND. .NOT.bomUseBiology ) RETURN
      IF ( fileClass.LT.1 .OR. fileClass.GT.2 ) RETURN
      IF ( coreFields.NE.bomOutputFields2 .AND.
     &     coreFields.NE.bomPickupFields2 ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(myTime) .OR.
     &     .NOT.IEEE_IS_FINITE(scheduledTime) .OR.
     &     .NOT.IEEE_IS_FINITE(nextOutput) .OR.
     &     .NOT.IEEE_IS_FINITE(bomMuMax) .OR.
     &     .NOT.IEEE_IS_FINITE(bomMort) .OR.
     &     .NOT.IEEE_IS_FINITE(bomKN) .OR.
     &     .NOT.IEEE_IS_FINITE(bomTMin) .OR.
     &     .NOT.IEEE_IS_FINITE(bomTMax) .OR.
     &     .NOT.IEEE_IS_FINITE(bomS0) .OR.
     &     .NOT.IEEE_IS_FINITE(bomSMin) .OR.
     &     .NOT.IEEE_IS_FINITE(bomSMax) .OR.
     &     .NOT.IEEE_IS_FINITE(bomNStartTime) .OR.
     &     .NOT.IEEE_IS_FINITE(bomNPeriod) .OR.
     &     .NOT.IEEE_IS_FINITE(bomNRepCycle) .OR.
     &     .NOT.IEEE_IS_FINITE(bomNInScale) ) RETURN
      IF ( bomNPartExpected.LT.0 .OR.
     &     bomNPartLiveExpected.LT.0 .OR.
     &     bomEventBufferCount.LT.0 .OR.
     &     bomEventBufferCount.GT.bomMaxEventBuffer ) RETURN

      springCode=0
      IF ( bomSpringLaw.EQ.'HOOKE' ) springCode=1
      IF ( bomSpringLaw.EQ.'EBOMB' ) springCode=2

      signature(1)=DFLOAT(bomP4ContainerSchema)
      signature(2)=DFLOAT(bomP4SigFields)
      signature(3)=DFLOAT(fileClass)
      signature(4)=DFLOAT(bomOutputSchema2)
      signature(5)=DFLOAT(coreFields)
      signature(6)=0. _d 0
      IF ( bomSpringLaw.NE.'NONE' ) signature(6)=1. _d 0
      signature(7)=DFLOAT(bomP4SidecarSchema)
      signature(8)=DFLOAT(bomP4SidecarFields)
      signature(9)=0. _d 0
      IF ( bomUseBiology ) signature(9)=1. _d 0
      signature(10)=DFLOAT(bomP4EventSchema)
      signature(11)=DFLOAT(bomP4ManifestSchema)
      signature(12)=DFLOAT(nPx)
      signature(13)=DFLOAT(nPy)
      signature(14)=DFLOAT(sNx)
      signature(15)=DFLOAT(sNy)
      signature(16)=DFLOAT(nSx)
      signature(17)=DFLOAT(nSy)
      signature(18)=DFLOAT(Nx)
      signature(19)=DFLOAT(Ny)
      signature(20)=DFLOAT(bomMaxPartTile)
      signature(21)=DFLOAT(bomMaxEventBuffer)
      signature(22)=DFLOAT(myIter)
      signature(23)=myTime
      signature(24)=scheduledTime
      signature(25)=nextOutput
      signature(26)=DFLOAT(bomNPartExpected)
      signature(27)=DFLOAT(bomNPartLiveExpected)
      signature(28)=DFLOAT(bomSeed)
      signature(29)=DFLOAT(bomBirthMaxTry)

      CALL BOM_P4_I8_WORDS(bomNextId,wordHi,wordLo,wordValid)
      IF ( .NOT.wordValid ) RETURN
      signature(30)=DFLOAT(wordHi)
      signature(31)=DFLOAT(wordLo)
      CALL BOM_P4_I8_WORDS(
     I     bomEventTimeIndex,wordHi,wordLo,wordValid)
      IF ( .NOT.wordValid ) RETURN
      signature(32)=DFLOAT(wordHi)
      signature(33)=DFLOAT(wordLo)
      CALL BOM_P4_I8_WORDS(
     I     bomBirthEvents,wordHi,wordLo,wordValid)
      IF ( .NOT.wordValid ) RETURN
      signature(34)=DFLOAT(wordHi)
      signature(35)=DFLOAT(wordLo)
      CALL BOM_P4_I8_WORDS(
     I     bomDeathEvents,wordHi,wordLo,wordValid)
      IF ( .NOT.wordValid ) RETURN
      signature(36)=DFLOAT(wordHi)
      signature(37)=DFLOAT(wordLo)
      CALL BOM_P4_I8_WORDS(
     I     bomBeachEvents,wordHi,wordLo,wordValid)
      IF ( .NOT.wordValid ) RETURN
      signature(38)=DFLOAT(wordHi)
      signature(39)=DFLOAT(wordLo)
      CALL BOM_P4_I8_WORDS(
     I     bomOutsideEvents,wordHi,wordLo,wordValid)
      IF ( .NOT.wordValid ) RETURN
      signature(40)=DFLOAT(wordHi)
      signature(41)=DFLOAT(wordLo)
      CALL BOM_P4_I8_WORDS(
     I     bomCancelEvents,wordHi,wordLo,wordValid)
      IF ( .NOT.wordValid ) RETURN
      signature(42)=DFLOAT(wordHi)
      signature(43)=DFLOAT(wordLo)
      CALL BOM_P4_I8_WORDS(
     I     bomMissingGrowthEvents,wordHi,wordLo,wordValid)
      IF ( .NOT.wordValid ) RETURN
      signature(44)=DFLOAT(wordHi)
      signature(45)=DFLOAT(wordLo)
C--   The compact-tail stack is a deterministic function of each tile owner
C     count.  Its global free-slot total and the empty buffer proof are
C     retained here; per-rank shard state remains in event manifests.
      signature(46)=DFLOAT(nPx*nPy*nSx*nSy*bomMaxPartTile-
     &                     bomNPartLiveExpected)
      signature(47)=DFLOAT(bomEventBufferCount)
      DO k=48,52
        signature(k)=0. _d 0
      ENDDO
      IF ( bomOutputScheduleReady ) signature(53)=1. _d 0
      IF ( bomBioReady ) signature(54)=1. _d 0
      IF ( bomUseLand ) signature(55)=1. _d 0
      IF ( bomUseBiology ) signature(56)=1. _d 0
      signature(57)=DFLOAT(springCode)
      signature(58)=DFLOAT(bomBioIter(BOM_ENV_OLD))
      signature(59)=DFLOAT(bomBioIter(BOM_ENV_NEW))
      signature(60)=bomBioTime(BOM_ENV_OLD)
      signature(61)=bomBioTime(BOM_ENV_NEW)
      signature(62)=DFLOAT(bomBioTempSource(BOM_ENV_OLD))
      signature(63)=DFLOAT(bomBioTempSource(BOM_ENV_NEW))
      signature(64)=DFLOAT(bomBioNSource(BOM_ENV_OLD))
      signature(65)=DFLOAT(bomBioNSource(BOM_ENV_NEW))
      signature(66)=bomMuMax
      signature(67)=bomMort
      signature(68)=bomKN
      signature(69)=bomTMin
      signature(70)=bomTMax
      signature(71)=bomS0
      signature(72)=bomSMin
      signature(73)=bomSMax
      signature(74)=bomNStartTime
      signature(75)=bomNPeriod
      signature(76)=bomNRepCycle
      signature(77)=bomNInScale
      signature(78)=DFLOAT(bomNFilePrec)
      signature(79)=DFLOAT(nPx*nPy)
      IF ( bomEventBufferCount.EQ.0 ) signature(80)=1. _d 0
      offset=bomP4SigBase
      CALL BOM_PACK_PICKUP_CHARS(
     I     bomEventFile,
     U     signature,offset)
      CALL BOM_PACK_PICKUP_CHARS(
     I     bomP4SourceHead,
     U     signature,offset)
      IF ( offset.NE.bomP4SigFields ) RETURN
      isValid=.TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_WRITE_P4_SIGNATURE(
     I                 fileName, fileClass, coreFields,
     I                 myTime, scheduledTime, nextOutput, myIter,
     O                 localErrCount,
     I                 myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
      CHARACTER*(*) fileName
      CHARACTER*(MAX_LEN_FNAM) sigName
      INTEGER fileClass,coreFields,myIter,localErrCount,myThid
      _RL myTime,scheduledTime,nextOutput
      _RL signature(bomP4SigFields)
      _RL record(bomPickupChunkFields)
      _RS dummyRS(1)
      INTEGER nRecords,iRecord,k,index,writeRecord,ioUnit
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK
      LOGICAL isValid

      localErrCount=0
      CALL BOM_BUILD_P4_SIGNATURE(
     I     fileClass,coreFields,myTime,scheduledTime,nextOutput,myIter,
     O     signature,isValid,
     I     myThid)
      IF ( .NOT.isValid ) THEN
        localErrCount=1
        RETURN
      ENDIF
      WRITE(sigName,'(A,A)')
     &     fileName(1:ILNBLNK(fileName)),'.p4sig'
      nRecords=(bomP4SigFields+bomPickupChunkFields-1)
     &     /bomPickupChunkFields
      ioUnit=-1
      DO iRecord=1,nRecords
        DO k=1,bomPickupChunkFields
          index=(iRecord-1)*bomPickupChunkFields+k
          record(k)=0. _d 0
          IF ( index.LE.bomP4SigFields )
     &         record(k)=signature(index)
        ENDDO
        writeRecord=iRecord
        IF ( iRecord.LT.nRecords ) writeRecord=-iRecord
        CALL MDS_WRITEVEC_LOC(
     I       sigName,precFloat64,ioUnit,
     I       'RL',bomPickupChunkFields,record,dummyRS,
     I       0,0,writeRecord,myIter,myThid)
      ENDDO
      IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P4_I8_WORDS(value,wordHi,wordLo,isValid)
      IMPLICIT NONE
      INTEGER*8 value,wordHi,wordLo,radix
      LOGICAL isValid
      radix=4294967296_8
      isValid=value.GE.0_8
      wordHi=0_8
      wordLo=0_8
      IF ( .NOT.isValid ) RETURN
      wordHi=value/radix
      wordLo=MOD(value,radix)
      IF ( wordHi.LT.0_8 .OR. wordHi.GT.2147483647_8 .OR.
     &     wordLo.LT.0_8 .OR. wordLo.GE.radix ) isValid=.FALSE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P4_I8_FROM_WORDS(wordHiRL,wordLoRL,value,isValid)
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
      _RL wordHiRL,wordLoRL
      INTEGER*8 value,wordHi,wordLo,radix
      LOGICAL isValid
      radix=4294967296_8
      value=0_8
      isValid=IEEE_IS_FINITE(wordHiRL) .AND.
     &        IEEE_IS_FINITE(wordLoRL)
      IF ( .NOT.isValid ) RETURN
      IF ( wordHiRL.NE.DNINT(wordHiRL) .OR.
     &     wordLoRL.NE.DNINT(wordLoRL) .OR.
     &     wordHiRL.LT.0. _d 0 .OR.
     &     wordHiRL.GT.2147483647. _d 0 .OR.
     &     wordLoRL.LT.0. _d 0 .OR.
     &     wordLoRL.GE.4294967296. _d 0 ) THEN
        isValid=.FALSE.
        RETURN
      ENDIF
      wordHi=INT(wordHiRL,8)
      wordLo=INT(wordLoRL,8)
      IF ( wordHi.GT.(HUGE(value)-wordLo)/radix ) THEN
        isValid=.FALSE.
        RETURN
      ENDIF
      value=wordHi*radix+wordLo
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_READ_P4_SIGNATURE
C !INTERFACE:
      SUBROUTINE BOM_READ_P4_SIGNATURE(
     I                 fileName,fileClass,coreFields,
     I                 myTime,scheduledTime,nextOutput,myIter,
     O                 storedInitial,storedLive,storedNextId,
     O                 storedEventIndex,storedBirth,storedDeath,
     O                 storedBeach,storedOutside,storedCancel,
     O                 storedMissing,storedBioTime,storedBioIter,
     O                 storedTempSource,storedNSource,storedBioReady,
     O                 localErrCount,
     I                 myThid)

C !DESCRIPTION:
C     Read schema-4 metadata into non-authoritative scalars and validate all
C     static, decomposition, parameter and forced-flush fields exactly.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) fileName
      INTEGER fileClass,coreFields,myIter
      _RL myTime,scheduledTime,nextOutput
      INTEGER storedInitial,storedLive
      INTEGER*8 storedNextId,storedEventIndex
      INTEGER*8 storedBirth,storedDeath,storedBeach
      INTEGER*8 storedOutside,storedCancel,storedMissing
      _RL storedBioTime(BOM_ENV_NEND)
      INTEGER storedBioIter(BOM_ENV_NEND)
      INTEGER storedTempSource(BOM_ENV_NEND)
      INTEGER storedNSource(BOM_ENV_NEND)
      LOGICAL storedBioReady
      INTEGER localErrCount,myThid
      CHARACTER*(MAX_LEN_FNAM) sigName,dataName,metaName
      CHARACTER*(MAX_LEN_MBUF) metaSimulation,metaTitle
      CHARACTER*8 metaFieldList(1)
      _RL signature(bomP4SigFields)
      _RL record(bomPickupChunkFields)
      _RL metaTimList(1),metaMissingValue
      _RS dummyRS(1)
      INTEGER metaDimList(3,3)
      INTEGER ioUnit,ios,k,iRecord,nRecords,index,offset
      INTEGER metaFilePrec,metaNDims,metaNFlds,metaNTimRec
      INTEGER metaNRecords,metaFileIter,springCode
      INTEGER expectedTempSource,expectedNSource
      INTEGER*8 expectedBytes,actualBytes
      LOGICAL dataExists,metaExists,useCurrentDir,wordValid
      LOGICAL recordFinite
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK

      localErrCount=0
      storedInitial=-1
      storedLive=-1
      storedNextId=0_8
      storedEventIndex=0_8
      storedBirth=0_8
      storedDeath=0_8
      storedBeach=0_8
      storedOutside=0_8
      storedCancel=0_8
      storedMissing=0_8
      storedBioReady=.FALSE.
      DO k=1,BOM_ENV_NEND
        storedBioTime(k)=0. _d 0
        storedBioIter(k)=0
        storedTempSource(k)=BOM_BIO_TEMP_NONE
        storedNSource(k)=BOM_BIO_N_NONE
      ENDDO
      WRITE(sigName,'(A,A)')
     &     fileName(1:ILNBLNK(fileName)),'.p4sig'
      WRITE(dataName,'(A,A)') sigName(1:ILNBLNK(sigName)),'.data'
      WRITE(metaName,'(A,A)') sigName(1:ILNBLNK(sigName)),'.meta'
      nRecords=(bomP4SigFields+bomPickupChunkFields-1)
     &     /bomPickupChunkFields
      expectedBytes=INT(nRecords,8)*INT(bomPickupChunkFields,8)*8_8
      actualBytes=-1_8
      INQUIRE(FILE=dataName,EXIST=dataExists,SIZE=actualBytes)
      INQUIRE(FILE=metaName,EXIST=metaExists)
      IF ( .NOT.dataExists .OR. .NOT.metaExists .OR.
     &     actualBytes.NE.expectedBytes ) THEN
        localErrCount=1
        RETURN
      ENDIF
      metaNDims=3
      metaNFlds=1
      metaNTimRec=1
      useCurrentDir=.TRUE.
      CALL MDS_READ_META(
     I     sigName,
     O     metaSimulation,metaTitle,metaFilePrec,
     U     metaNDims,metaNFlds,metaNTimRec,
     O     metaDimList,metaFieldList,metaTimList,
     O     metaMissingValue,metaNRecords,metaFileIter,
     I     useCurrentDir,myThid)
      ioUnit=-1
      DO iRecord=1,nRecords
        CALL MDS_READVEC_LOC(
     I       sigName,precFloat64,ioUnit,
     I       'RL',bomPickupChunkFields,record,dummyRS,
     I       0,0,iRecord,myThid)
        DO k=1,bomPickupChunkFields
          index=(iRecord-1)*bomPickupChunkFields+k
          IF ( index.LE.bomP4SigFields ) signature(index)=record(k)
        ENDDO
      ENDDO
      IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
      recordFinite=.TRUE.
      DO k=1,bomP4SigFields
        IF ( .NOT.IEEE_IS_FINITE(signature(k)) ) recordFinite=.FALSE.
      ENDDO
      IF ( .NOT.recordFinite .OR.
     &     metaFilePrec.NE.precFloat64 .OR. metaNDims.NE.3 .OR.
     &     metaNRecords.NE.nRecords .OR. metaFileIter.NE.myIter .OR.
     &     metaDimList(1,1).NE.1 .OR.
     &     metaDimList(2,1).NE.1 .OR.
     &     metaDimList(3,1).NE.1 .OR.
     &     metaDimList(1,2).NE.1 .OR.
     &     metaDimList(2,2).NE.1 .OR.
     &     metaDimList(3,2).NE.1 .OR.
     &     metaDimList(1,3).NE.bomPickupChunkFields .OR.
     &     metaDimList(2,3).NE.1 .OR.
     &     metaDimList(3,3).NE.bomPickupChunkFields ) THEN
        localErrCount=1
        RETURN
      ENDIF
      IF ( signature(26).NE.DNINT(signature(26)) .OR.
     &     signature(27).NE.DNINT(signature(27)) ) THEN
        localErrCount=1
        RETURN
      ENDIF
      storedInitial=NINT(signature(26))
      storedLive=NINT(signature(27))
      CALL BOM_P4_I8_FROM_WORDS(
     I     signature(30),signature(31),
     O     storedNextId,wordValid)
      IF ( .NOT.wordValid ) localErrCount=localErrCount+1
      CALL BOM_P4_I8_FROM_WORDS(
     I     signature(32),signature(33),
     O     storedEventIndex,wordValid)
      IF ( .NOT.wordValid ) localErrCount=localErrCount+1
      CALL BOM_P4_I8_FROM_WORDS(
     I     signature(34),signature(35),
     O     storedBirth,wordValid)
      IF ( .NOT.wordValid ) localErrCount=localErrCount+1
      CALL BOM_P4_I8_FROM_WORDS(
     I     signature(36),signature(37),
     O     storedDeath,wordValid)
      IF ( .NOT.wordValid ) localErrCount=localErrCount+1
      CALL BOM_P4_I8_FROM_WORDS(
     I     signature(38),signature(39),
     O     storedBeach,wordValid)
      IF ( .NOT.wordValid ) localErrCount=localErrCount+1
      CALL BOM_P4_I8_FROM_WORDS(
     I     signature(40),signature(41),
     O     storedOutside,wordValid)
      IF ( .NOT.wordValid ) localErrCount=localErrCount+1
      CALL BOM_P4_I8_FROM_WORDS(
     I     signature(42),signature(43),
     O     storedCancel,wordValid)
      IF ( .NOT.wordValid ) localErrCount=localErrCount+1
      CALL BOM_P4_I8_FROM_WORDS(
     I     signature(44),signature(45),
     O     storedMissing,wordValid)
      IF ( .NOT.wordValid ) localErrCount=localErrCount+1
      DO k=1,BOM_ENV_NEND
        IF ( signature(57+k).NE.DNINT(signature(57+k)) .OR.
     &       signature(61+k).NE.DNINT(signature(61+k)) .OR.
     &       signature(63+k).NE.DNINT(signature(63+k)) )
     &       localErrCount=localErrCount+1
        storedBioIter(k)=NINT(signature(57+k))
        storedBioTime(k)=signature(59+k)
        storedTempSource(k)=NINT(signature(61+k))
        storedNSource(k)=NINT(signature(63+k))
      ENDDO
      storedBioReady=signature(54).EQ.1. _d 0
      springCode=0
      IF ( bomSpringLaw.EQ.'HOOKE' ) springCode=1
      IF ( bomSpringLaw.EQ.'EBOMB' ) springCode=2
      expectedTempSource=BOM_BIO_TEMP_NONE
      expectedNSource=BOM_BIO_N_NONE
      IF ( bomTempSource.EQ.'THETA' )
     &     expectedTempSource=BOM_BIO_TEMP_THETA
      IF ( bomNSource.EQ.'PTRACER' )
     &     expectedNSource=BOM_BIO_N_PTRACER
      IF ( bomNSource.EQ.'FILES' )
     &     expectedNSource=BOM_BIO_N_FILES
      IF ( signature(1).NE.DFLOAT(bomP4ContainerSchema) .OR.
     &     signature(2).NE.DFLOAT(bomP4SigFields) .OR.
     &     signature(3).NE.DFLOAT(fileClass) .OR.
     &     signature(4).NE.DFLOAT(bomOutputSchema2) .OR.
     &     signature(5).NE.DFLOAT(coreFields) .OR.
     &     signature(6).NE.MERGE(1. _d 0,0. _d 0,
     &       bomSpringLaw.NE.'NONE') .OR.
     &     signature(7).NE.DFLOAT(bomP4SidecarSchema) .OR.
     &     signature(8).NE.DFLOAT(bomP4SidecarFields) .OR.
     &     signature(9).NE.MERGE(1. _d 0,0. _d 0,bomUseBiology)
     &     .OR. signature(10).NE.DFLOAT(bomP4EventSchema) .OR.
     &     signature(11).NE.DFLOAT(bomP4ManifestSchema) .OR.
     &     signature(12).NE.DFLOAT(nPx) .OR.
     &     signature(13).NE.DFLOAT(nPy) .OR.
     &     signature(14).NE.DFLOAT(sNx) .OR.
     &     signature(15).NE.DFLOAT(sNy) .OR.
     &     signature(16).NE.DFLOAT(nSx) .OR.
     &     signature(17).NE.DFLOAT(nSy) .OR.
     &     signature(18).NE.DFLOAT(Nx) .OR.
     &     signature(19).NE.DFLOAT(Ny) .OR.
     &     signature(20).NE.DFLOAT(bomMaxPartTile) .OR.
     &     signature(21).NE.DFLOAT(bomMaxEventBuffer) .OR.
     &     signature(22).NE.DFLOAT(myIter) .OR.
     &     TRANSFER(signature(23),0_8).NE.TRANSFER(myTime,0_8)
     &     .OR. TRANSFER(signature(24),0_8).NE.
     &     TRANSFER(scheduledTime,0_8)
     &     .OR. TRANSFER(signature(25),0_8).NE.
     &     TRANSFER(nextOutput,0_8)
     &     .OR. storedInitial.LT.0
     &     .OR. storedInitial.GT.bomInitGlobalLimit
     &     .OR. storedInitial.GT.bomMaxInitRecords
     &     .OR. storedLive.LT.0
     &     .OR. storedLive.GT.bomMaxParticles
     &     .OR. storedLive.GT.bomMaxInitRecords
     &     .OR. signature(28).NE.DFLOAT(bomSeed)
     &     .OR. signature(29).NE.DFLOAT(bomBirthMaxTry)
     &     .OR. signature(46).NE.
     &     DFLOAT(nPx*nPy*nSx*nSy*bomMaxPartTile-storedLive)
     &     .OR. signature(47).NE.0. _d 0
     &     .OR. signature(53).NE.1. _d 0
     &     .OR. signature(54).NE.
     &     MERGE(1. _d 0,0. _d 0,bomUseBiology)
     &     .OR. signature(55).NE.MERGE(1. _d 0,0. _d 0,bomUseLand)
     &     .OR. signature(56).NE.
     &     MERGE(1. _d 0,0. _d 0,bomUseBiology)
     &     .OR. signature(57).NE.DFLOAT(springCode)
     &     .OR. TRANSFER(signature(66),0_8).NE.
     &     TRANSFER(bomMuMax,0_8)
     &     .OR. TRANSFER(signature(67),0_8).NE.
     &     TRANSFER(bomMort,0_8)
     &     .OR. TRANSFER(signature(68),0_8).NE.TRANSFER(bomKN,0_8)
     &     .OR. TRANSFER(signature(69),0_8).NE.TRANSFER(bomTMin,0_8)
     &     .OR. TRANSFER(signature(70),0_8).NE.TRANSFER(bomTMax,0_8)
     &     .OR. TRANSFER(signature(71),0_8).NE.TRANSFER(bomS0,0_8)
     &     .OR. TRANSFER(signature(72),0_8).NE.TRANSFER(bomSMin,0_8)
     &     .OR. TRANSFER(signature(73),0_8).NE.TRANSFER(bomSMax,0_8)
     &     .OR. TRANSFER(signature(74),0_8).NE.
     &     TRANSFER(bomNStartTime,0_8)
     &     .OR. TRANSFER(signature(75),0_8).NE.
     &     TRANSFER(bomNPeriod,0_8)
     &     .OR. TRANSFER(signature(76),0_8).NE.
     &     TRANSFER(bomNRepCycle,0_8)
     &     .OR. TRANSFER(signature(77),0_8).NE.
     &     TRANSFER(bomNInScale,0_8)
     &     .OR. signature(78).NE.DFLOAT(bomNFilePrec)
     &     .OR. signature(79).NE.DFLOAT(nPx*nPy)
     &     .OR. signature(80).NE.1. _d 0 )
     &     localErrCount=localErrCount+1
      DO k=48,52
        IF ( signature(k).NE.0. _d 0 )
     &       localErrCount=localErrCount+1
      ENDDO
      offset=bomP4SigBase
      DO k=1,LEN(bomEventFile)
        offset=offset+1
        IF ( signature(offset).NE.DFLOAT(IACHAR(bomEventFile(k:k))))
     &       localErrCount=localErrCount+1
      ENDDO
      DO k=1,LEN(bomP4SourceHead)
        offset=offset+1
        IF ( signature(offset).NE.
     &       DFLOAT(IACHAR(bomP4SourceHead(k:k))))
     &       localErrCount=localErrCount+1
      ENDDO
      IF ( offset.NE.bomP4SigFields )
     &     localErrCount=localErrCount+1
      IF ( bomUseBiology ) THEN
        IF ( .NOT.storedBioReady .OR.
     &       storedTempSource(BOM_ENV_OLD).NE.
     &       expectedTempSource .OR.
     &       storedTempSource(BOM_ENV_NEW).NE.
     &       expectedTempSource .OR.
     &       storedNSource(BOM_ENV_OLD).NE.
     &       expectedNSource .OR.
     &       storedNSource(BOM_ENV_NEW).NE.
     &       expectedNSource )
     &       localErrCount=localErrCount+1
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
