#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_ID_FROM_WORDS

C !INTERFACE:
      SUBROUTINE BOM_ID_FROM_WORDS(
     I                 idHiRL, idLoRL,
     O                 particleId, idError )

C !DESCRIPTION:
C     Reconstruct a positive signed 64-bit particle identifier from two
C     exactly represented integer words stored in an IEEE-64 input file.

C !USES:
      IMPLICIT NONE

C !INPUT PARAMETERS:
      _RL idHiRL
      _RL idLoRL

C !OUTPUT PARAMETERS:
      INTEGER*8 particleId
      INTEGER idError
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER*8 idHi
      INTEGER*8 idLo
      INTEGER*8 idRadix

      idError = 0
      particleId = 0
      idRadix = 4294967296_8

      IF ( idHiRL.NE.idHiRL .OR. idLoRL.NE.idLoRL ) THEN
        idError = 1
      ELSEIF ( idHiRL.NE.DNINT(idHiRL) .OR.
     &         idLoRL.NE.DNINT(idLoRL) ) THEN
        idError = 2
      ELSEIF ( idHiRL.LT.0. _d 0 .OR.
     &         idHiRL.GT.2147483647. _d 0 ) THEN
        idError = 3
      ELSEIF ( idLoRL.LT.0. _d 0 .OR.
     &         idLoRL.GT.4294967295. _d 0 ) THEN
        idError = 4
      ELSE
        idHi = INT(idHiRL,8)
        idLo = INT(idLoRL,8)
        particleId = idHi*idRadix + idLo
        IF ( particleId.LE.0 ) idError = 5
      ENDIF
#endif

      RETURN
      END
