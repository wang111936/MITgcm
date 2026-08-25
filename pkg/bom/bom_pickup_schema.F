#include "BOM_OPTIONS.h"
#ifdef ALLOW_EXF
# include "EXF_OPTIONS.h"
#endif

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_GET_PICKUP2_SIZES
C !INTERFACE:
      SUBROUTINE BOM_GET_PICKUP2_SIZES(
     O                 sigFields, envFields )

C !DESCRIPTION:
C     Return the fixed schema-2 signature and per-tile environment sizes.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER sigFields, envFields, nPoint

      nPoint = (sNx+2*OLx)*(sNy+2*OLy)
      sigFields = bomPickup2SigBase + 2*MAX_LEN_FNAM + 256
      envFields = bomPickupEnvHeader
     &          + 3*nPoint*BOM_ENV_NEND*BOM_ENV_NSOURCE

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BUILD_PICKUP2_SIGNATURE
C !INTERFACE:
      SUBROUTINE BOM_BUILD_PICKUP2_SIGNATURE(
     I                 myTime, myIter, nExpected, nextOutput,
     I                 envTime0, envTime1, envIter0, envIter1,
     I                 envReady,
     O                 signature, sigFields, envFields, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Build the exact schema-2 configuration fingerprint.  Real-valued
C     parameters are compared later by transferred bits; provider names
C     are stored as exact character codes including trailing blanks.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#ifdef ALLOW_EXF
# include "EXF_PARAM.h"
#endif
#include "BOM_SIZE.h"
#include "BOM.h"

      _RL myTime, nextOutput, envTime0, envTime1
      _RL signature(*)
      INTEGER myIter, nExpected, envIter0, envIter1
      INTEGER sigFields, envFields, myThid
      LOGICAL envReady, isValid

      CHARACTER*128 exfUFile, exfVFile
      INTEGER k, offset
      INTEGER modeCode, equationCode, currentCode
      INTEGER windCode, stokesCode, integratorCode
      INTEGER couplerCapability, exfCapability
      LOGICAL codesValid, metadataValid

      isValid = .FALSE.
      CALL BOM_GET_PICKUP2_SIZES( sigFields, envFields )
      DO k=1,sigFields
        signature(k) = 0. _d 0
      ENDDO
      CALL BOM_PICKUP2_CODES(
     O     modeCode, equationCode, currentCode,
     O     windCode, stokesCode, integratorCode, codesValid )
      CALL BOM_VALIDATE_PICKUP2_METADATA(
     I     myTime, myIter, envTime0, envTime1,
     I     envIter0, envIter1, envReady,
     O     metadataValid )
      IF ( .NOT.codesValid .OR. .NOT.metadataValid ) RETURN
      IF ( nExpected.LT.0 .OR. nExpected.GT.bomMaxParticles .OR.
     &     nExpected.GT.bomInitGlobalLimit .OR.
     &     nExpected.GT.bomMaxInitRecords ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(bomOutputFreq) .OR.
     &     .NOT.IEEE_IS_FINITE(nextOutput) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(bomAlpha) .OR.
     &     .NOT.IEEE_IS_FINITE(bomTau) .OR.
     &     .NOT.IEEE_IS_FINITE(bomR) .OR.
     &     .NOT.IEEE_IS_FINITE(bomSigma) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(bomDeltaTTarget) .OR.
     &     .NOT.IEEE_IS_FINITE(bomWetWeightMin) .OR.
     &     .NOT.IEEE_IS_FINITE(bomAdvCFL) .OR.
     &     .NOT.IEEE_IS_FINITE(bomLeewayWindCoeff) ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(bomStokesStartTime) .OR.
     &     .NOT.IEEE_IS_FINITE(bomStokesPeriod) .OR.
     &     .NOT.IEEE_IS_FINITE(bomStokesRepCycle) .OR.
     &     .NOT.IEEE_IS_FINITE(bomStokesInScale) .OR.
     &     .NOT.IEEE_IS_FINITE(deltaTClock) ) RETURN

#ifdef ALLOW_BOM_STOKES_COUPLER
      couplerCapability = 1
#else
      couplerCapability = 0
#endif
#ifdef ALLOW_EXF
      exfCapability = 1
      exfUFile = uwindfile
      exfVFile = vwindfile
      IF ( .NOT.IEEE_IS_FINITE(uwindStartTime) .OR.
     &     .NOT.IEEE_IS_FINITE(uwindperiod) .OR.
     &     .NOT.IEEE_IS_FINITE(uwindRepCycle) .OR.
     &     .NOT.IEEE_IS_FINITE(exf_inscal_uwind) .OR.
     &     .NOT.IEEE_IS_FINITE(vwindStartTime) .OR.
     &     .NOT.IEEE_IS_FINITE(vwindperiod) .OR.
     &     .NOT.IEEE_IS_FINITE(vwindRepCycle) .OR.
     &     .NOT.IEEE_IS_FINITE(exf_inscal_vwind) ) RETURN
#else
      exfCapability = 0
      exfUFile = ' '
      exfVFile = ' '
#endif

      signature(1) = DFLOAT(bomPickupSchema2)
      signature(2) = DFLOAT(sigFields)
      signature(3) = DFLOAT(nPx)
      signature(4) = DFLOAT(nPy)
      signature(5) = DFLOAT(sNx)
      signature(6) = DFLOAT(sNy)
      signature(7) = DFLOAT(nSx)
      signature(8) = DFLOAT(nSy)
      signature(9) = DFLOAT(Nx)
      signature(10) = DFLOAT(Ny)
      signature(11) = DFLOAT(bomMaxPartTile)
      signature(12) = DFLOAT(nExpected)
      signature(13) = DFLOAT(myIter)
      signature(14) = myTime
      signature(15) = bomOutputFreq
      signature(16) = nextOutput
      signature(17) = DFLOAT(modeCode)
      signature(18) = DFLOAT(equationCode)
      signature(19) = DFLOAT(currentCode)
      signature(20) = DFLOAT(windCode)
      signature(21) = DFLOAT(stokesCode)
      signature(22) = DFLOAT(integratorCode)
      signature(23) = bomAlpha
      signature(24) = bomTau
      signature(25) = bomR
      signature(26) = bomSigma
      signature(27) = bomDeltaTTarget
      signature(28) = bomWetWeightMin
      signature(29) = bomAdvCFL
      signature(30) = bomLeewayWindCoeff
      signature(31) = bomStokesStartTime
      signature(32) = bomStokesPeriod
      signature(33) = bomStokesRepCycle
      signature(34) = bomStokesInScale
      signature(35) = DFLOAT(bomStokesFilePrec)
      signature(36) = deltaTClock
      signature(37) = 1. _d 0
      signature(38) = envTime0
      signature(39) = envTime1
      signature(40) = DFLOAT(envIter0)
      signature(41) = DFLOAT(envIter1)
      signature(42) = DFLOAT(envFields)
      signature(43) = DFLOAT(couplerCapability)
      signature(44) = DFLOAT(exfCapability)
#ifdef ALLOW_EXF
      signature(45) = uwindStartTime
      signature(46) = uwindperiod
      signature(47) = uwindRepCycle
      signature(48) = exf_inscal_uwind
      signature(49) = vwindStartTime
      signature(50) = vwindperiod
      signature(51) = vwindRepCycle
      signature(52) = exf_inscal_vwind
#endif

      offset = bomPickup2SigBase
      CALL BOM_PACK_PICKUP_CHARS(
     I     bomUStokesFile,
     U     signature, offset )
      CALL BOM_PACK_PICKUP_CHARS(
     I     bomVStokesFile,
     U     signature, offset )
      CALL BOM_PACK_PICKUP_CHARS(
     I     exfUFile,
     U     signature, offset )
      CALL BOM_PACK_PICKUP_CHARS(
     I     exfVFile,
     U     signature, offset )
      IF ( offset.NE.sigFields ) RETURN
      isValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VALIDATE_PICKUP2_SIGNATURE(
     I                 signature, sigFields,
     O                 nExpected, storedNext,
     O                 envTime0, envTime1, envIter0, envIter1,
     O                 envFields, isValid,
     I                 myTime, myIter, myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL signature(*), expected(
     &     bomPickup2SigBase+2*MAX_LEN_FNAM+256)
      _RL storedNext, envTime0, envTime1, myTime
      INTEGER sigFields, nExpected, envIter0, envIter1
      INTEGER envFields, myIter, myThid
      INTEGER expectedSigFields, expectedEnvFields, k
      LOGICAL isValid, buildValid

      isValid = .FALSE.
      nExpected = -1
      storedNext = 0. _d 0
      envTime0 = 0. _d 0
      envTime1 = 0. _d 0
      envIter0 = 0
      envIter1 = 0
      envFields = 0
      CALL BOM_GET_PICKUP2_SIZES(
     O     expectedSigFields, expectedEnvFields )
      IF ( sigFields.NE.expectedSigFields ) RETURN
      DO k=1,sigFields
        IF ( .NOT.IEEE_IS_FINITE(signature(k)) ) RETURN
      ENDDO
      IF ( signature(12).NE.DNINT(signature(12)) .OR.
     &     signature(40).NE.DNINT(signature(40)) .OR.
     &     signature(41).NE.DNINT(signature(41)) ) RETURN
      nExpected = NINT(signature(12))
      storedNext = signature(16)
      envTime0 = signature(38)
      envTime1 = signature(39)
      envIter0 = NINT(signature(40))
      envIter1 = NINT(signature(41))
      CALL BOM_BUILD_PICKUP2_SIGNATURE(
     I     myTime, myIter, nExpected, storedNext,
     I     envTime0, envTime1, envIter0, envIter1, .TRUE.,
     O     expected, expectedSigFields, envFields, buildValid,
     I     myThid )
      IF ( .NOT.buildValid ) RETURN
      IF ( envFields.NE.expectedEnvFields ) RETURN
      DO k=1,sigFields
        IF ( TRANSFER(signature(k),0_8).NE.
     &       TRANSFER(expected(k),0_8) ) RETURN
      ENDDO
      isValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_PICKUP2_CODES(
     O                 modeCode, equationCode, currentCode,
     O                 windCode, stokesCode, integratorCode,
     O                 isValid )

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER modeCode, equationCode, currentCode
      INTEGER windCode, stokesCode, integratorCode
      LOGICAL isValid

      modeCode = 0
      equationCode = 0
      currentCode = 0
      windCode = -1
      stokesCode = -1
      integratorCode = 0
      isValid = .FALSE.
      IF ( bomMode.NE.'BOM' ) RETURN
      modeCode = 2
      IF ( bomEquationMode.EQ.'PAPER2024' ) THEN
        equationCode = 1
      ELSEIF ( bomEquationMode.EQ.'JULIA' ) THEN
        equationCode = 2
      ELSE
        RETURN
      ENDIF
      IF ( bomCurrentPolicy.EQ.'EULERIAN' ) THEN
        currentCode = 1
      ELSEIF ( bomCurrentPolicy.EQ.'PRECOMBINED' ) THEN
        currentCode = 2
      ELSE
        RETURN
      ENDIF
      IF ( bomWindSource.EQ.'NONE' ) THEN
        windCode = 0
      ELSEIF ( bomWindSource.EQ.'EXF' ) THEN
        windCode = 1
      ELSE
        RETURN
      ENDIF
      IF ( bomStokesSource.EQ.'NONE' ) THEN
        stokesCode = 0
      ELSEIF ( bomStokesSource.EQ.'FILES' ) THEN
        stokesCode = 1
      ELSEIF ( bomStokesSource.EQ.'COUPLER' ) THEN
        stokesCode = 2
      ELSE
        RETURN
      ENDIF
      IF ( bomIntegrator.EQ.'RK2' ) THEN
        integratorCode = 2
      ELSEIF ( bomIntegrator.EQ.'RK4' ) THEN
        integratorCode = 4
      ELSE
        RETURN
      ENDIF
      isValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VALIDATE_PICKUP2_METADATA(
     I                 myTime, myIter, envTime0, envTime1,
     I                 envIter0, envIter1, envReady,
     O                 isValid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
      _RL myTime, envTime0, envTime1
      _RL interval, scale, tolerance
      INTEGER myIter, envIter0, envIter1
      LOGICAL envReady, isValid, diffValid, near, compareValid

      isValid = .FALSE.
      IF ( .NOT.envReady ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(myTime) .OR.
     &     .NOT.IEEE_IS_FINITE(envTime0) .OR.
     &     .NOT.IEEE_IS_FINITE(envTime1) ) RETURN
      IF ( envTime1.NE.myTime .OR. envIter1.NE.myIter ) RETURN
      IF ( envTime1.EQ.envTime0 ) THEN
        IF ( envIter1.NE.envIter0 ) RETURN
        isValid = .TRUE.
        RETURN
      ENDIF
      IF ( envTime1.LT.envTime0 ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(deltaTClock) .OR.
     &     deltaTClock.LE.0. _d 0 ) RETURN
      CALL BOM_NONNEG_TIME_DIFF(
     I     envTime1, envTime0,
     O     interval, diffValid )
      IF ( .NOT.diffValid .OR. interval.LE.0. _d 0 ) RETURN
      scale = MAX(oneRL,ABS(interval),ABS(deltaTClock))
      tolerance = 16. _d 0*EPSILON(oneRL)*scale
      CALL BOM_TIME_NEAR(
     I     interval, deltaTClock, tolerance,
     O     near, compareValid )
      IF ( .NOT.compareValid .OR. .NOT.near ) RETURN
      IF ( envIter0.GE.HUGE(envIter0) ) RETURN
      IF ( envIter1.NE.envIter0+1 ) RETURN
      isValid = .TRUE.

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_PACK_PICKUP_CHARS(
     I                 value,
     U                 signature, offset )

      IMPLICIT NONE
      CHARACTER*(*) value
      _RL signature(*)
      INTEGER offset, k

      DO k=1,LEN(value)
        offset = offset + 1
        signature(offset) = DFLOAT(IACHAR(value(k:k)))
      ENDDO

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VALIDATE_ENV_PICKUP_STATE(
     I                 myTime, myIter,
     O                 localErrCount,
     I                 myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL myTime, east0, east1, north0, north1
      INTEGER myIter, localErrCount, myThid
      INTEGER bi, bj, i, j, iSource
      LOGICAL metadataValid, valid0, valid1, referenceValid
      LOGICAL freshBracket

      localErrCount = 0
      CALL BOM_VALIDATE_PICKUP2_METADATA(
     I     myTime, myIter,
     I     bomEnvTime(BOM_ENV_OLD), bomEnvTime(BOM_ENV_NEW),
     I     bomEnvIter(BOM_ENV_OLD), bomEnvIter(BOM_ENV_NEW),
     I     bomEnvReady,
     O     metadataValid )
      IF ( .NOT.metadataValid ) localErrCount = localErrCount + 1
      freshBracket = bomEnvTime(BOM_ENV_OLD).EQ.
     &               bomEnvTime(BOM_ENV_NEW)
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          referenceValid = bomEnvValid(
     &         i,j,BOM_ENV_OLD,BOM_ENV_EULERIAN,bi,bj)
          DO iSource=1,BOM_ENV_NSOURCE
            east0 = bomEnvEast(
     &           i,j,BOM_ENV_OLD,iSource,bi,bj)
            east1 = bomEnvEast(
     &           i,j,BOM_ENV_NEW,iSource,bi,bj)
            north0 = bomEnvNorth(
     &           i,j,BOM_ENV_OLD,iSource,bi,bj)
            north1 = bomEnvNorth(
     &           i,j,BOM_ENV_NEW,iSource,bi,bj)
            valid0 = bomEnvValid(
     &           i,j,BOM_ENV_OLD,iSource,bi,bj)
            valid1 = bomEnvValid(
     &           i,j,BOM_ENV_NEW,iSource,bi,bj)
            IF ( .NOT.IEEE_IS_FINITE(east0) .OR.
     &           .NOT.IEEE_IS_FINITE(east1) .OR.
     &           .NOT.IEEE_IS_FINITE(north0) .OR.
     &           .NOT.IEEE_IS_FINITE(north1) ) THEN
              localErrCount = localErrCount + 1
            ENDIF
            IF ( valid0.NEQV.valid1 )
     &           localErrCount = localErrCount + 1
            IF ( valid0.NEQV.referenceValid )
     &           localErrCount = localErrCount + 1
            IF ( .NOT.valid0 ) THEN
              IF ( east0.NE.0. _d 0 .OR. east1.NE.0. _d 0
     &             .OR. north0.NE.0. _d 0
     &             .OR. north1.NE.0. _d 0 )
     &             localErrCount = localErrCount + 1
            ENDIF
            IF ( freshBracket ) THEN
              IF ( TRANSFER(east0,0_8).NE.TRANSFER(east1,0_8)
     &             .OR. TRANSFER(north0,0_8).NE.
     &                  TRANSFER(north1,0_8) )
     &             localErrCount = localErrCount + 1
            ENDIF
          ENDDO
         ENDDO
        ENDDO
       ENDDO
      ENDDO

      RETURN
      END
