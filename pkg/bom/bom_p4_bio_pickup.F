#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_WRITE_P4_BIO_PICKUP
C !INTERFACE:
      SUBROUTINE BOM_WRITE_P4_BIO_PICKUP(
     I                 particlePrefix,myTime,myIter,myThid)

C !DESCRIPTION:
C     Persist the complete accepted temperature/nutrient OLD/NEW bracket,
C     including halos, source codes and exact validity bits.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) particlePrefix
      _RL myTime
      INTEGER myIter,myThid
#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_FNAM) bioName
      _RL record(bomP4BioHeader+
     &     3*(sNx+2*OLx)*(sNy+2*OLy)*BOM_ENV_NEND)
      _RL chunk(bomPickupChunkFields)
      _RS dummyRS(1)
      INTEGER bioFields,nRecords,bi,bj,i,j,iEnd,k
      INTEGER ioUnit,iRecord,iValue,writeRecord,iGlobal,jGlobal

      bioFields=bomP4BioHeader+
     &     3*(sNx+2*OLx)*(sNy+2*OLy)*BOM_ENV_NEND
      WRITE(bioName,'(A,A)')
     &     particlePrefix(1:LEN_TRIM(particlePrefix)),'.p4bio'
      DO bj=1,nSy
       DO bi=1,nSx
        DO k=1,bioFields
          record(k)=0. _d 0
        ENDDO
        iGlobal=myXGlobalLo+(bi-1)*sNx
        jGlobal=myYGlobalLo+(bj-1)*sNy
        record(1)=DFLOAT(bomP4SidecarSchema)
        record(2)=DFLOAT(bioFields)
        record(3)=DFLOAT(bomP4ContainerSchema)
        record(4)=DFLOAT(myIter)
        record(5)=myTime
        record(6)=DFLOAT(bomBioIter(BOM_ENV_OLD))
        record(7)=DFLOAT(bomBioIter(BOM_ENV_NEW))
        record(8)=bomBioTime(BOM_ENV_OLD)
        record(9)=bomBioTime(BOM_ENV_NEW)
        record(10)=DFLOAT(nPx)
        record(11)=DFLOAT(nPy)
        record(12)=DFLOAT(iGlobal)
        record(13)=DFLOAT(jGlobal)
        record(14)=DFLOAT(bomBioTempSource(BOM_ENV_OLD))
        record(15)=DFLOAT(bomBioTempSource(BOM_ENV_NEW))
        record(16)=DFLOAT(bomBioNSource(BOM_ENV_OLD))
        record(17)=DFLOAT(bomBioNSource(BOM_ENV_NEW))
        record(18)=MERGE(1. _d 0,0. _d 0,bomBioReady)
        k=bomP4BioHeader
        DO iEnd=1,BOM_ENV_NEND
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
            k=k+1
            record(k)=bomBioTemp(i,j,iEnd,bi,bj)
            k=k+1
            record(k)=bomBioN(i,j,iEnd,bi,bj)
            k=k+1
            record(k)=MERGE(1. _d 0,0. _d 0,
     &           bomBioValid(i,j,iEnd,bi,bj))
          ENDDO
         ENDDO
        ENDDO
        IF ( k.NE.bioFields ) THEN
          CALL ALL_PROC_DIE(0)
          STOP 'ABNORMAL END: BOM_WRITE_P4_BIO_PICKUP'
        ENDIF
        nRecords=(bioFields+bomPickupChunkFields-1)
     &       /bomPickupChunkFields
        ioUnit=-1
        DO iRecord=1,nRecords
          DO k=1,bomPickupChunkFields
            iValue=(iRecord-1)*bomPickupChunkFields+k
            chunk(k)=0. _d 0
            IF ( iValue.LE.bioFields ) chunk(k)=record(iValue)
          ENDDO
          writeRecord=iRecord
          IF ( iRecord.LT.nRecords ) writeRecord=-iRecord
          CALL MDS_WRITEVEC_LOC(
     I         bioName,precFloat64,ioUnit,
     I         'RL',bomPickupChunkFields,chunk,dummyRS,
     I         bi,bj,writeRecord,myIter,myThid)
        ENDDO
        IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
       ENDDO
      ENDDO
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_READ_P4_BIO_PICKUP
C !INTERFACE:
      SUBROUTINE BOM_READ_P4_BIO_PICKUP(
     I                 particlePrefix,storedTime,storedIter,
     I                 storedBioTime,storedBioIter,
     I                 storedTempSource,storedNSource,storedReady,
     O                 localErrCount,
     I                 myThid)

C !DESCRIPTION:
C     Validate and decode the biology endpoint member into scratch COMMON.
C     The caller publishes it only after the complete pickup transaction.

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
      _RL storedTime,storedBioTime(BOM_ENV_NEND)
      INTEGER storedIter,storedBioIter(BOM_ENV_NEND)
      INTEGER storedTempSource(BOM_ENV_NEND)
      INTEGER storedNSource(BOM_ENV_NEND)
      LOGICAL storedReady
      INTEGER localErrCount,myThid
#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_FNAM) bioName,physicalPrefix
      CHARACTER*(MAX_LEN_FNAM) tilePrefix,dataName,metaName
      CHARACTER*(MAX_LEN_MBUF) metaSimulation,metaTitle
      CHARACTER*8 metaFieldList(1)
      _RL record(bomP4BioHeader+
     &     3*(sNx+2*OLx)*(sNy+2*OLy)*BOM_ENV_NEND)
      _RL chunk(bomPickupChunkFields)
      _RL metaTimList(1),metaMissingValue
      _RS dummyRS(1)
      INTEGER metaDimList(3,3)
      INTEGER bioFields,nRecords,bi,bj,i,j,iEnd,k
      INTEGER ioUnit,iRecord,iValue,iGlobal,jGlobal,iTile,jTile
      INTEGER prefixLen,localDirLen,metaFilePrec,metaNDims
      INTEGER metaNFlds,metaNTimRec,metaNRecords,metaFileIter
      INTEGER*8 expectedBytes,tileBytes
      LOGICAL dataExists,metaExists,useCurrentDir,recordFinite
      LOGICAL validValue,wetPoint,freshBracket

      localErrCount=0
      bioFields=bomP4BioHeader+
     &     3*(sNx+2*OLx)*(sNy+2*OLy)*BOM_ENV_NEND
      nRecords=(bioFields+bomPickupChunkFields-1)
     &     /bomPickupChunkFields
      expectedBytes=INT(nRecords,8)*INT(bomPickupChunkFields,8)*8_8
      WRITE(bioName,'(A,A)')
     &     particlePrefix(1:LEN_TRIM(particlePrefix)),'.p4bio'
      prefixLen=LEN_TRIM(bioName)
      localDirLen=LEN_TRIM(mdsioLocalDir)
      IF ( localDirLen.GT.0 ) THEN
        WRITE(physicalPrefix,'(A,A)')
     &       mdsioLocalDir(1:localDirLen),bioName(1:prefixLen)
      ELSE
        physicalPrefix=bioName
      ENDIF
      DO bj=1,nSy
       DO bi=1,nSx
        iTile=bi+(myXGlobalLo-1)/sNx
        jTile=bj+(myYGlobalLo-1)/sNy
        WRITE(tilePrefix,'(A,A,I3.3,A,I3.3)')
     &       physicalPrefix(1:LEN_TRIM(physicalPrefix)),'.',
     &       iTile,'.',jTile
        WRITE(dataName,'(A,A)')
     &       tilePrefix(1:LEN_TRIM(tilePrefix)),'.data'
        WRITE(metaName,'(A,A)')
     &       tilePrefix(1:LEN_TRIM(tilePrefix)),'.meta'
        tileBytes=-1_8
        INQUIRE(FILE=dataName,EXIST=dataExists,SIZE=tileBytes)
        INQUIRE(FILE=metaName,EXIST=metaExists)
        IF ( .NOT.dataExists .OR. .NOT.metaExists .OR.
     &       tileBytes.NE.expectedBytes ) localErrCount=localErrCount+1
       ENDDO
      ENDDO
      IF ( localErrCount.GT.0 ) RETURN

      freshBracket=storedBioTime(BOM_ENV_OLD).EQ.
     &             storedBioTime(BOM_ENV_NEW)
      DO bj=1,nSy
       DO bi=1,nSx
        iTile=bi+(myXGlobalLo-1)/sNx
        jTile=bj+(myYGlobalLo-1)/sNy
        WRITE(tilePrefix,'(A,A,I3.3,A,I3.3)')
     &       physicalPrefix(1:LEN_TRIM(physicalPrefix)),'.',
     &       iTile,'.',jTile
        metaNDims=3
        metaNFlds=1
        metaNTimRec=1
        useCurrentDir=.TRUE.
        CALL MDS_READ_META(
     I       tilePrefix,
     O       metaSimulation,metaTitle,metaFilePrec,
     U       metaNDims,metaNFlds,metaNTimRec,
     O       metaDimList,metaFieldList,metaTimList,
     O       metaMissingValue,metaNRecords,metaFileIter,
     I       useCurrentDir,myThid)
        ioUnit=-1
        DO iRecord=1,nRecords
          CALL MDS_READVEC_LOC(
     I         bioName,precFloat64,ioUnit,
     I         'RL',bomPickupChunkFields,chunk,dummyRS,
     I         bi,bj,iRecord,myThid)
          DO k=1,bomPickupChunkFields
            iValue=(iRecord-1)*bomPickupChunkFields+k
            IF ( iValue.LE.bioFields ) record(iValue)=chunk(k)
          ENDDO
        ENDDO
        IF ( ioUnit.GT.0 ) CLOSE(ioUnit)
        recordFinite=.TRUE.
        DO k=1,bioFields
          IF ( .NOT.IEEE_IS_FINITE(record(k)) ) recordFinite=.FALSE.
        ENDDO
        iGlobal=myXGlobalLo+(bi-1)*sNx
        jGlobal=myYGlobalLo+(bj-1)*sNy
        IF ( .NOT.recordFinite .OR.
     &       record(1).NE.DFLOAT(bomP4SidecarSchema) .OR.
     &       record(2).NE.DFLOAT(bioFields) .OR.
     &       record(3).NE.DFLOAT(bomP4ContainerSchema) .OR.
     &       record(4).NE.DFLOAT(storedIter) .OR.
     &       TRANSFER(record(5),0_8).NE.TRANSFER(storedTime,0_8)
     &       .OR. record(6).NE.DFLOAT(storedBioIter(BOM_ENV_OLD))
     &       .OR. record(7).NE.DFLOAT(storedBioIter(BOM_ENV_NEW))
     &       .OR. TRANSFER(record(8),0_8).NE.
     &       TRANSFER(storedBioTime(BOM_ENV_OLD),0_8)
     &       .OR. TRANSFER(record(9),0_8).NE.
     &       TRANSFER(storedBioTime(BOM_ENV_NEW),0_8)
     &       .OR. record(10).NE.DFLOAT(nPx)
     &       .OR. record(11).NE.DFLOAT(nPy)
     &       .OR. record(12).NE.DFLOAT(iGlobal)
     &       .OR. record(13).NE.DFLOAT(jGlobal)
     &       .OR. record(14).NE.
     &       DFLOAT(storedTempSource(BOM_ENV_OLD))
     &       .OR. record(15).NE.
     &       DFLOAT(storedTempSource(BOM_ENV_NEW))
     &       .OR. record(16).NE.DFLOAT(storedNSource(BOM_ENV_OLD))
     &       .OR. record(17).NE.DFLOAT(storedNSource(BOM_ENV_NEW))
     &       .OR. record(18).NE.MERGE(1. _d 0,0. _d 0,
     &       storedReady) ) localErrCount=localErrCount+1
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
     &       localErrCount=localErrCount+1
        k=bomP4BioHeader
        DO iEnd=1,BOM_ENV_NEND
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
            k=k+1
            bomBioTempScratch(i,j,iEnd,bi,bj)=record(k)
            k=k+1
            bomBioNScratch(i,j,iEnd,bi,bj)=record(k)
            k=k+1
            validValue=record(k).EQ.1. _d 0
            IF ( record(k).NE.0. _d 0 .AND.
     &           record(k).NE.1. _d 0 ) localErrCount=localErrCount+1
            bomBioValidScratch(i,j,iEnd,bi,bj)=validValue
            wetPoint=maskC(i,j,1,bi,bj).GT.0.
            IF ( wetPoint ) THEN
              IF ( .NOT.validValue ) localErrCount=localErrCount+1
            ELSEIF ( validValue .OR.
     &               bomBioTempScratch(i,j,iEnd,bi,bj).NE.0. _d 0
     &               .OR. bomBioNScratch(i,j,iEnd,bi,bj).NE.0. _d 0 )
     &               THEN
              localErrCount=localErrCount+1
            ENDIF
          ENDDO
         ENDDO
        ENDDO
        IF ( k.NE.bioFields ) localErrCount=localErrCount+1
        IF ( freshBracket ) THEN
          DO j=1-OLy,sNy+OLy
           DO i=1-OLx,sNx+OLx
            IF ( TRANSFER(bomBioTempScratch(i,j,BOM_ENV_OLD,
     &           bi,bj),0_8).NE.
     &           TRANSFER(bomBioTempScratch(i,j,BOM_ENV_NEW,
     &           bi,bj),0_8) .OR.
     &           TRANSFER(bomBioNScratch(i,j,BOM_ENV_OLD,
     &           bi,bj),0_8).NE.
     &           TRANSFER(bomBioNScratch(i,j,BOM_ENV_NEW,
     &           bi,bj),0_8) .OR.
     &           bomBioValidScratch(i,j,BOM_ENV_OLD,bi,bj).NEQV.
     &           bomBioValidScratch(i,j,BOM_ENV_NEW,bi,bj) )
     &           localErrCount=localErrCount+1
           ENDDO
          ENDDO
        ENDIF
       ENDDO
      ENDDO
      IF ( localErrCount.EQ.0 ) THEN
        DO iEnd=1,BOM_ENV_NEND
          bomBioTimeScratch(iEnd)=storedBioTime(iEnd)
          bomBioIterScratch(iEnd)=storedBioIter(iEnd)
          bomBioTempSourceScratch(iEnd)=storedTempSource(iEnd)
          bomBioNSourceScratch(iEnd)=storedNSource(iEnd)
        ENDDO
      ENDIF
#else
      localErrCount=1
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
