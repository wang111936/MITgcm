#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_GET_STOKES
C !INTERFACE:
      SUBROUTINE BOM_GET_STOKES(
     I                 targetTime, targetIter,
     O                 failCode, stokesValid,
     I                 myThid )

C !DESCRIPTION:
C     Evaluate paired FILES Stokes records at one exact endpoint.  All
C     metadata and requested records are validated before reader calls;
C     only BOM-owned work arrays are changed on a provider failure.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL targetTime
      INTEGER targetIter, myThid

C !OUTPUT PARAMETERS:
      INTEGER failCode
      LOGICAL stokesValid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER bi, bj, i, j
      INTEGER previousRec, rec0, rec1
      INTEGER localErrCount, globalErrCount
      _RL weight0, weight1, locTime, cycleRecords
      _RL uValue, vValue, maxAbs, mixedValue, scaleAbs
      _RL eastValue, northValue
      LOGICAL uFileValid, vFileValid
      LOGICAL wetPoint, invalidValue

      failCode = BOM_FAIL_FIELD_SOURCE
      stokesValid = .FALSE.
      localErrCount = 0
      previousRec = 0
      rec0 = 0
      rec1 = 0
      weight0 = 0. _d 0
      weight1 = 0. _d 0

C--   Reject unsafe metadata before the interval helper or any file read.
      IF ( bomStokesSource.NE.'FILES' )
     &     localErrCount = localErrCount + 1
      IF ( .NOT.IEEE_IS_FINITE(targetTime) .OR.
     &     .NOT.IEEE_IS_FINITE(bomStokesStartTime) .OR.
     &     .NOT.IEEE_IS_FINITE(bomStokesPeriod) .OR.
     &     bomStokesPeriod.LE.0. _d 0 .OR.
     &     .NOT.IEEE_IS_FINITE(bomStokesRepCycle) .OR.
     &     bomStokesRepCycle.LT.0. _d 0 .OR.
     &     .NOT.IEEE_IS_FINITE(bomStokesInScale) )
     &     localErrCount = localErrCount + 1
      IF ( bomUStokesFile.EQ.' ' .OR.
     &     bomVStokesFile.EQ.' ' )
     &     localErrCount = localErrCount + 1
      IF ( bomStokesFilePrec.NE.32 .AND.
     &     bomStokesFilePrec.NE.64 )
     &     localErrCount = localErrCount + 1
      IF ( bomStokesRepCycle.GT.0. _d 0 .AND.
     &     bomStokesPeriod.GT.0. _d 0 ) THEN
        cycleRecords = ANINT(bomStokesRepCycle/bomStokesPeriod)
        IF ( .NOT.IEEE_IS_FINITE(cycleRecords) .OR.
     &       cycleRecords.LT.1. _d 0 .OR.
     &       bomStokesRepCycle.NE.cycleRecords*bomStokesPeriod )
     &       localErrCount = localErrCount + 1
      ENDIF
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

C--   Resolve the exact bracket and prove both complete records exist.
      locTime = targetTime-bomStokesStartTime
     &        + bomStokesPeriod*halfRL
      CALL GET_PERIODIC_INTERVAL(
     O     previousRec, rec0, rec1, weight0, weight1,
     I     bomStokesRepCycle, bomStokesPeriod,
     I     deltaTClock, locTime, myThid )
      localErrCount = 0
      IF ( rec0.LE.0 .OR. rec1.LE.0 .OR.
     &     .NOT.IEEE_IS_FINITE(weight0) .OR.
     &     .NOT.IEEE_IS_FINITE(weight1) .OR.
     &     weight0.LT.0. _d 0 .OR. weight0.GT.1. _d 0 .OR.
     &     weight1.LT.0. _d 0 .OR. weight1.GT.1. _d 0 ) THEN
        localErrCount = localErrCount + 1
      ELSE
        CALL BOM_STOKES_FILE_PREFLIGHT(
     I       bomUStokesFile, rec0, rec1, Nx, Ny,
     I       bomStokesFilePrec,
     O       uFileValid,
     I       myThid )
        CALL BOM_STOKES_FILE_PREFLIGHT(
     I       bomVStokesFile, rec0, rec1, Nx, Ny,
     I       bomStokesFilePrec,
     O       vFileValid,
     I       myThid )
        IF ( .NOT.uFileValid .OR. .NOT.vFileValid )
     &       localErrCount = localErrCount + 1
      ENDIF
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

C--   Initialise all halos, then read the two global 2-D record pairs.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomStokesUWork(i,j,1,bi,bj) = 0. _d 0
          bomStokesVWork(i,j,1,bi,bj) = 0. _d 0
          bomStokesEastWork(i,j,1,bi,bj) = 0. _d 0
          bomStokesNorthWork(i,j,1,bi,bj) = 0. _d 0
          bomStokesU0(i,j,1,bi,bj) = 0. _d 0
          bomStokesU1(i,j,1,bi,bj) = 0. _d 0
          bomStokesV0(i,j,1,bi,bj) = 0. _d 0
          bomStokesV1(i,j,1,bi,bj) = 0. _d 0
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      CALL READ_REC_3D_RL(
     I     bomUStokesFile, bomStokesFilePrec, 1,
     O     bomStokesU0,
     I     rec0, targetIter, myThid )
      CALL READ_REC_3D_RL(
     I     bomUStokesFile, bomStokesFilePrec, 1,
     O     bomStokesU1,
     I     rec1, targetIter, myThid )
      CALL READ_REC_3D_RL(
     I     bomVStokesFile, bomStokesFilePrec, 1,
     O     bomStokesV0,
     I     rec0, targetIter, myThid )
      CALL READ_REC_3D_RL(
     I     bomVStokesFile, bomStokesFilePrec, 1,
     O     bomStokesV1,
     I     rec1, targetIter, myThid )

C--   Reject raw non-finite data before interpolation arithmetic.
      localErrCount = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          IF ( .NOT.IEEE_IS_FINITE(
     &           bomStokesU0(i,j,1,bi,bj)) .OR.
     &         .NOT.IEEE_IS_FINITE(
     &           bomStokesU1(i,j,1,bi,bj)) .OR.
     &         .NOT.IEEE_IS_FINITE(
     &           bomStokesV0(i,j,1,bi,bj)) .OR.
     &         .NOT.IEEE_IS_FINITE(
     &           bomStokesV1(i,j,1,bi,bj)) )
     &         localErrCount = 1
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

C--   Interpolate in BOM storage.  Normalisation prevents overflow while
C     mixing opposite-signed finite record values; scale overflow is fatal.
      localErrCount = 0
      scaleAbs = ABS(bomStokesInScale)
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1,sNy
         DO i=1,sNx
          uValue = bomStokesU0(i,j,1,bi,bj)
          vValue = bomStokesU1(i,j,1,bi,bj)
          maxAbs = MAX(ABS(uValue),ABS(vValue))
          mixedValue = 0. _d 0
          IF ( maxAbs.GT.0. _d 0 )
     &       mixedValue = maxAbs*(weight0*(uValue/maxAbs)
     &                    +weight1*(vValue/maxAbs))
          IF ( scaleAbs.GT.1. _d 0 .AND.
     &         ABS(mixedValue).GT.HUGE(oneRL)/scaleAbs ) THEN
            localErrCount = 1
          ELSE
            bomStokesUWork(i,j,1,bi,bj) =
     &           bomStokesInScale*mixedValue
          ENDIF

          uValue = bomStokesV0(i,j,1,bi,bj)
          vValue = bomStokesV1(i,j,1,bi,bj)
          maxAbs = MAX(ABS(uValue),ABS(vValue))
          mixedValue = 0. _d 0
          IF ( maxAbs.GT.0. _d 0 )
     &       mixedValue = maxAbs*(weight0*(uValue/maxAbs)
     &                    +weight1*(vValue/maxAbs))
          IF ( scaleAbs.GT.1. _d 0 .AND.
     &         ABS(mixedValue).GT.HUGE(oneRL)/scaleAbs ) THEN
            localErrCount = 1
          ELSE
            bomStokesVWork(i,j,1,bi,bj) =
     &           bomStokesInScale*mixedValue
          ENDIF
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

C--   Raw files are C-point model-grid U/V; rotate to accepted east/north.
      CALL ROTATE_UV2EN_RL(
     U     bomStokesUWork, bomStokesVWork,
     U     bomStokesEastWork, bomStokesNorthWork,
     I     .TRUE., .FALSE., .TRUE., 1, myThid )
      CALL EXCH_3D_RL( bomStokesEastWork, 1, myThid )
      CALL EXCH_3D_RL( bomStokesNorthWork, 1, myThid )

      localErrCount = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          eastValue = bomStokesEastWork(i,j,1,bi,bj)
          northValue = bomStokesNorthWork(i,j,1,bi,bj)
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          invalidValue = .NOT.IEEE_IS_FINITE(eastValue) .OR.
     &                   .NOT.IEEE_IS_FINITE(northValue)
          IF ( .NOT.wetPoint ) invalidValue = invalidValue .OR.
     &         eastValue.NE.0. _d 0 .OR.
     &         northValue.NE.0. _d 0
          IF ( invalidValue ) localErrCount = 1
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      failCode = BOM_FAIL_NONE
      stokesValid = .TRUE.
#else
      failCode = BOM_FAIL_FIELD_SOURCE
      stokesValid = .FALSE.
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_STOKES_FILE_PREFLIGHT
C !INTERFACE:
      SUBROUTINE BOM_STOKES_FILE_PREFLIGHT(
     I                 fileName, rec0, rec1,
     I                 nX, nY, filePrec,
     O                 fileValid,
     I                 myThid )

C !DESCRIPTION:
C     Prove a global raw file contains both requested complete records.

      IMPLICIT NONE
#include "EEPARAMS.h"
      CHARACTER*(*) fileName
      INTEGER rec0, rec1, nX, nY, filePrec, myThid
      LOGICAL fileValid
      CHARACTER*(MAX_LEN_FNAM) dataName
      INTEGER nameLen, bytesPerValue, maxRec
      INTEGER*8 fileBytes, recordBytes, requiredBytes
      LOGICAL fileExists
      INTEGER ILNBLNK
      EXTERNAL ILNBLNK
CEOP

      fileValid = .FALSE.
      fileBytes = -1_8
      fileExists = .FALSE.
      nameLen = ILNBLNK(fileName)
      IF ( nameLen.LE.0 .OR. nX.LE.0 .OR. nY.LE.0 ) RETURN
      IF ( filePrec.EQ.32 ) THEN
        bytesPerValue = 4
      ELSEIF ( filePrec.EQ.64 ) THEN
        bytesPerValue = 8
      ELSE
        RETURN
      ENDIF
      INQUIRE(FILE=fileName(1:nameLen),EXIST=fileExists,SIZE=fileBytes)
      IF ( .NOT.fileExists ) THEN
        WRITE(dataName,'(A,A)') fileName(1:nameLen), '.data'
        INQUIRE(FILE=dataName,EXIST=fileExists,SIZE=fileBytes)
      ENDIF
      IF ( .NOT.fileExists ) RETURN
      recordBytes = INT(nX,8)*INT(nY,8)*INT(bytesPerValue,8)
      maxRec = MAX(rec0,rec1)
      requiredBytes = recordBytes*INT(maxRec,8)
      IF ( recordBytes.LE.0_8 .OR. requiredBytes.LE.0_8 ) RETURN
      IF ( fileBytes.LT.requiredBytes ) RETURN
      IF ( MOD(fileBytes,recordBytes).NE.0_8 ) RETURN
      fileValid = .TRUE.

      RETURN
      END
