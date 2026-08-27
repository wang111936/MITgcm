#include "BOM_OPTIONS.h"

#ifdef ALLOW_EXF
# include "EXF_OPTIONS.h"
#endif

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_GET_EXF_WIND
C !INTERFACE:
      SUBROUTINE BOM_GET_EXF_WIND(
     I                 targetTime, targetIter,
     O                 failCode, windValid,
     I                 myThid )

C !DESCRIPTION:
C     Evaluate paired EXF wind at one exact endpoint in BOM-owned arrays.
C     EXF global current and record arrays are read neither as values nor
C     aliases and are never modified.  Metadata and file coverage are
C     checked before calling EXF readers that otherwise stop on bad input.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#ifdef ALLOW_EXF
# include "EXF_PARAM.h"
# include "EXF_INTERP_SIZE.h"
# include "EXF_INTERP_PARAM.h"
#endif
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      _RL targetTime
      INTEGER targetIter, myThid

C !OUTPUT PARAMETERS:
      INTEGER failCode
      LOGICAL windValid
CEOP

#if defined(ALLOW_BOM) && defined(ALLOW_EXF)
C !LOCAL VARIABLES:
      INTEGER bi, bj, i, j
      INTEGER previousRec, rec0, rec1
      INTEGER localErrCount, globalErrCount
      INTEGER uNx, uNy, vNx, vNy
      _RL locTime, cycleRecords
      _RL eastValue, northValue
      LOGICAL uHasFile, vHasFile
      LOGICAL uFileValid, vFileValid
      LOGICAL wetPoint, invalidValue

      failCode = BOM_FAIL_FIELD_SOURCE
      windValid = .FALSE.
      localErrCount = 0
      previousRec = 0
      rec0 = 0
      rec1 = 0
      uNx = Nx
      uNy = Ny
      vNx = Nx
      vNy = Ny
      uHasFile = uwindfile.NE.' '
      vHasFile = vwindfile.NE.' '

C--   This increment supports regular non-calendar EXF sequences.  Reject
C     unsupported ownership/timing before any reader or work-array write.
      IF ( .NOT.IEEE_IS_FINITE(targetTime) )
     &     localErrCount = localErrCount + 1
      IF ( .NOT.useEXF .OR. .NOT.useAtmWind )
     &     localErrCount = localErrCount + 1
      IF ( useCAL .OR. useExfYearlyFields )
     &     localErrCount = localErrCount + 1
      IF ( exf_iprec.NE.32 .AND. exf_iprec.NE.64 )
     &     localErrCount = localErrCount + 1
      IF ( uHasFile.NEQV.vHasFile )
     &     localErrCount = localErrCount + 1
      IF ( .NOT.IEEE_IS_FINITE(uwindperiod) .OR.
     &     .NOT.IEEE_IS_FINITE(vwindperiod) .OR.
     &     uwindperiod.LT.0. _d 0 .OR.
     &     vwindperiod.LT.0. _d 0 .OR.
     &     uwindperiod.NE.vwindperiod )
     &     localErrCount = localErrCount + 1
      IF ( .NOT.IEEE_IS_FINITE(uwindRepCycle) .OR.
     &     .NOT.IEEE_IS_FINITE(vwindRepCycle) .OR.
     &     uwindRepCycle.LT.0. _d 0 .OR.
     &     vwindRepCycle.LT.0. _d 0 .OR.
     &     uwindRepCycle.NE.vwindRepCycle )
     &     localErrCount = localErrCount + 1
      IF ( .NOT.IEEE_IS_FINITE(exf_inscal_uwind) .OR.
     &     .NOT.IEEE_IS_FINITE(exf_inscal_vwind) .OR.
     &     .NOT.IEEE_IS_FINITE(uwind_exfremo_intercept) .OR.
     &     .NOT.IEEE_IS_FINITE(vwind_exfremo_intercept) .OR.
     &     .NOT.IEEE_IS_FINITE(uwind_exfremo_slope) .OR.
     &     .NOT.IEEE_IS_FINITE(vwind_exfremo_slope) .OR.
     &     .NOT.IEEE_IS_FINITE(uwindconst) .OR.
     &     .NOT.IEEE_IS_FINITE(vwindconst) )
     &     localErrCount = localErrCount + 1
      IF ( uwindperiod.GT.0. _d 0 ) THEN
        IF ( .NOT.uHasFile .OR. .NOT.vHasFile )
     &       localErrCount = localErrCount + 1
        IF ( .NOT.IEEE_IS_FINITE(uwindStartTime) .OR.
     &       .NOT.IEEE_IS_FINITE(vwindStartTime) .OR.
     &       uwindStartTime.NE.vwindStartTime )
     &       localErrCount = localErrCount + 1
        IF ( uwindRepCycle.GT.0. _d 0 ) THEN
          cycleRecords = ANINT(uwindRepCycle/uwindperiod)
          IF ( .NOT.IEEE_IS_FINITE(cycleRecords) .OR.
     &         cycleRecords.LT.1. _d 0 .OR.
     &         uwindRepCycle.NE.cycleRecords*uwindperiod )
     &         localErrCount = localErrCount + 1
        ENDIF
      ENDIF

#ifdef USE_EXF_INTERPOLATION
      IF ( uwind_interpMethod.GE.1 ) THEN
        uNx = uwind_nlon
        uNy = uwind_nlat
      ENDIF
      IF ( vwind_interpMethod.GE.1 ) THEN
        vNx = vwind_nlon
        vNy = vwind_nlat
      ENDIF
#endif
      IF ( uNx.LE.0 .OR. uNy.LE.0 .OR.
     &     vNx.LE.0 .OR. vNy.LE.0 )
     &     localErrCount = localErrCount + 1

      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

C--   Resolve EXF record IDs with the same regular-time helper, then prove
C     both files contain every record before invoking an EXF reader.
      IF ( uwindperiod.GT.0. _d 0 ) THEN
        locTime = targetTime-uwindStartTime+uwindperiod*halfRL
        CALL GET_PERIODIC_INTERVAL(
     O       previousRec, rec0, rec1, cycleRecords, locTime,
     I       uwindRepCycle, uwindperiod,
     I       deltaTClock,
     I       targetTime-uwindStartTime+uwindperiod*halfRL,
     I       myThid )
        IF ( rec0.LE.0 .OR. rec1.LE.0 ) THEN
          localErrCount = 1
        ELSE
          CALL BOM_EXF_FILE_PREFLIGHT(
     I         uwindfile, rec0, rec1, uNx, uNy, exf_iprec,
     O         uFileValid,
     I         myThid )
          CALL BOM_EXF_FILE_PREFLIGHT(
     I         vwindfile, rec0, rec1, vNx, vNy, exf_iprec,
     O         vFileValid,
     I         myThid )
          IF ( .NOT.uFileValid .OR. .NOT.vFileValid )
     &         localErrCount = 1
        ENDIF
      ELSEIF ( uHasFile ) THEN
        CALL BOM_EXF_FILE_PREFLIGHT(
     I       uwindfile, 1, 1, uNx, uNy, exf_iprec,
     O       uFileValid,
     I       myThid )
        CALL BOM_EXF_FILE_PREFLIGHT(
     I       vwindfile, 1, 1, vNx, vNy, exf_iprec,
     O       vFileValid,
     I       myThid )
        IF ( .NOT.uFileValid .OR. .NOT.vFileValid )
     &       localErrCount = 1
      ENDIF
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

C--   Initialise and independently evaluate in BOM-owned storage.  Passing
C     nIter0 forces EXF to load both records for every endpoint request.
      CALL EXF_INIT_FLD(
     I     'uwind', uwindfile, uwindmask,
     I     uwindperiod, exf_inscal_uwind, uwindconst,
     U     bomExfWindUWork, bomExfWindU0, bomExfWindU1,
#ifdef USE_EXF_INTERPOLATION
     I     uwind_lon0, uwind_lon_inc, uwind_lat0, uwind_lat_inc,
     I     uwind_nlon, uwind_nlat, xC, yC, uwind_interpMethod,
#endif
     I     myThid )
      CALL EXF_INIT_FLD(
     I     'vwind', vwindfile, vwindmask,
     I     vwindperiod, exf_inscal_vwind, vwindconst,
     U     bomExfWindVWork, bomExfWindV0, bomExfWindV1,
#ifdef USE_EXF_INTERPOLATION
     I     vwind_lon0, vwind_lon_inc, vwind_lat0, vwind_lat_inc,
     I     vwind_nlon, vwind_nlat, xC, yC, vwind_interpMethod,
#endif
     I     myThid )
      CALL EXF_SET_UV(
     I     'uwind', uwindfile, uwindmask,
     I     uwindStartTime, uwindperiod, uwindRepCycle,
     I     exf_inscal_uwind,
     I     uwind_exfremo_intercept, uwind_exfremo_slope,
     U     bomExfWindUWork, bomExfWindU0, bomExfWindU1,
     I     'vwind', vwindfile, vwindmask,
     I     vwindStartTime, vwindperiod, vwindRepCycle,
     I     exf_inscal_vwind,
     I     vwind_exfremo_intercept, vwind_exfremo_slope,
     U     bomExfWindVWork, bomExfWindV0, bomExfWindV1,
#ifdef USE_EXF_INTERPOLATION
     I     uwind_lon0, uwind_lon_inc, uwind_lat0, uwind_lat_inc,
     I     uwind_nlon, uwind_nlat, uwind_interpMethod,
     I     vwind_lon0, vwind_lon_inc, vwind_lat0, vwind_lat_inc,
     I     vwind_nlon, vwind_nlat, vwind_interpMethod,
     I     uvInterp_wind,
#endif
     I     targetTime, nIter0, myThid )

C--   EXF A-point components are in model-grid directions after its vector
C     handling.  Rotate once back to geographic east/north and mask wet C.
      CALL ROTATE_UV2EN_RL(
     U     bomExfWindUWork, bomExfWindVWork,
     U     bomExfWindEastWork, bomExfWindNorthWork,
     I     .TRUE., .FALSE., .TRUE., 1, myThid )
      CALL EXCH_3D_RL( bomExfWindEastWork, 1, myThid )
      CALL EXCH_3D_RL( bomExfWindNorthWork, 1, myThid )

      localErrCount = 0
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          eastValue = bomExfWindEastWork(i,j,1,bi,bj)
          northValue = bomExfWindNorthWork(i,j,1,bi,bj)
          wetPoint = maskC(i,j,1,bi,bj).GT.0.
          invalidValue = .NOT.IEEE_IS_FINITE(eastValue) .OR.
     &                   .NOT.IEEE_IS_FINITE(northValue)
          IF ( .NOT.wetPoint ) invalidValue = invalidValue .OR.
     &         eastValue.NE.0. _d 0 .OR. northValue.NE.0. _d 0
          IF ( invalidValue ) localErrCount = 1
         ENDDO
        ENDDO
       ENDDO
      ENDDO
      globalErrCount = localErrCount
      CALL GLOBAL_SUM_INT( globalErrCount, myThid )
      IF ( globalErrCount.GT.0 ) RETURN

      failCode = BOM_FAIL_NONE
      windValid = .TRUE.
#else
      failCode = BOM_FAIL_FIELD_SOURCE
      windValid = .FALSE.
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_EXF_FILE_PREFLIGHT
C !INTERFACE:
      SUBROUTINE BOM_EXF_FILE_PREFLIGHT(
     I                 fileName, rec0, rec1,
     I                 nX, nY, filePrec,
     O                 fileValid,
     I                 myThid )

C !DESCRIPTION:
C     Prove a global raw EXF file contains both requested complete records.

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
