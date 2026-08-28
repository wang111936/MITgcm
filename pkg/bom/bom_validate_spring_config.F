#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VALIDATE_SPRING_CONFIG
C !INTERFACE:
      SUBROUTINE BOM_VALIDATE_SPRING_CONFIG(
     I                 mode, springLaw, neighborPolicy,
     I                 springL, hookeK, springA, springDelta,
     I                 neighborCutoff, pairDistanceMin, springCFL,
     I                 raftDiagnostics, periodicX, halfPeriodPhysical,
     O                 failCode, configValid )

C !DESCRIPTION:
C     Stateless P3.1 configuration validator.  Numeric spring controls are
C     deliberately ignored only for the exact NONE/NONE inactive path.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

      CHARACTER*(*) mode, springLaw, neighborPolicy
      _RL springL, hookeK, springA, springDelta
      _RL neighborCutoff, pairDistanceMin, springCFL
      _RL halfPeriodPhysical
      LOGICAL raftDiagnostics, periodicX
      INTEGER failCode
      LOGICAL configValid
CEOP

      failCode = BOM_FAIL_NEIGHBOR_CONFIG
      configValid = .FALSE.

      IF ( springLaw.NE.'NONE' .AND.
     &     springLaw.NE.'HOOKE' .AND.
     &     springLaw.NE.'EBOMB' ) RETURN
      IF ( neighborPolicy.NE.'NONE' .AND.
     &     neighborPolicy.NE.'CUTOFF' ) RETURN

      IF ( springLaw.EQ.'NONE' ) THEN
        IF ( neighborPolicy.NE.'NONE' ) RETURN
        IF ( raftDiagnostics ) RETURN
        failCode = BOM_FAIL_NONE
        configValid = .TRUE.
        RETURN
      ENDIF

      IF ( mode.NE.'BOM' ) RETURN
      IF ( neighborPolicy.NE.'CUTOFF' ) RETURN
      IF ( .NOT.IEEE_IS_FINITE(springL) .OR.
     &     .NOT.IEEE_IS_FINITE(neighborCutoff) .OR.
     &     .NOT.IEEE_IS_FINITE(pairDistanceMin) .OR.
     &     .NOT.IEEE_IS_FINITE(springCFL) ) RETURN
      IF ( springL.LE.0. _d 0 .OR.
     &     neighborCutoff.LE.0. _d 0 .OR.
     &     pairDistanceMin.LE.0. _d 0 .OR.
     &     springCFL.LE.0. _d 0 ) RETURN
      IF ( neighborCutoff.LE.pairDistanceMin ) RETURN

      IF ( springLaw.EQ.'HOOKE' ) THEN
        IF ( .NOT.IEEE_IS_FINITE(hookeK) ) RETURN
        IF ( hookeK.LE.0. _d 0 ) RETURN
      ELSE
        IF ( .NOT.IEEE_IS_FINITE(springA) .OR.
     &       .NOT.IEEE_IS_FINITE(springDelta) ) RETURN
        IF ( springA.LE.0. _d 0 .OR.
     &       springDelta.LE.0. _d 0 ) RETURN
      ENDIF

      IF ( periodicX ) THEN
        IF ( .NOT.IEEE_IS_FINITE(halfPeriodPhysical) ) RETURN
        IF ( halfPeriodPhysical.LE.0. _d 0 ) RETURN
        IF ( neighborCutoff.GE.halfPeriodPhysical ) RETURN
      ENDIF

      failCode = BOM_FAIL_NONE
      configValid = .TRUE.

      RETURN
      END
