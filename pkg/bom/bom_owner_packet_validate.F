#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_OWNER_PACKET_VALIDATE
C !INTERFACE:
      SUBROUTINE BOM_OWNER_PACKET_VALIDATE(
     I     packetInt,nPacketInt,packetReal,nPacketReal,
     I     expectedSchema,
     O     packetId,packetParentId,packetRaftId,packetBi,packetBj,
     O     isValid,
     I     myThid )

C !DESCRIPTION:
C     Validate and decode one complete owner-migration packet before any
C     authoritative owner array is replaced.  Schema 2 remains the released
C     ten-integer/six-real record; biology selects schema 3 and its appended
C     parent-ID, birth-count and S fields.

C !USES:
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"

C !INPUT PARAMETERS:
      INTEGER packetInt(*),nPacketInt,nPacketReal,expectedSchema
      _RL packetReal(*)
      INTEGER myThid

C !OUTPUT PARAMETERS:
      INTEGER*8 packetId,packetParentId,packetRaftId
      INTEGER packetBi,packetBj
      LOGICAL isValid
CEOP

#ifdef ALLOW_BOM
C !LOCAL VARIABLES:
      INTEGER*8 idRadix,maxWordHi,maxWordLo
      INTEGER*8 wordHi,wordLo
      INTEGER ownerRank,ownerBi,ownerBj,ownerHop
      _RL ownerX,ownerY
      LOGICAL locateValid

      idRadix=4294967296_8
      maxWordHi=HUGE(packetId)/idRadix
      maxWordLo=MOD(HUGE(packetId),idRadix)
      packetId=0_8
      packetParentId=0_8
      packetRaftId=0_8
      packetBi=0
      packetBj=0
      isValid=.FALSE.

C--   Exact sizes are part of the packet schema and guard every access.
      IF ( expectedSchema.EQ.bomPacketSchema ) THEN
        IF ( nPacketInt.NE.bomPacketInts .OR.
     &       nPacketReal.NE.bomPacketReals ) RETURN
      ELSEIF ( expectedSchema.EQ.bomPacketSchema3 ) THEN
        IF ( nPacketInt.NE.bomPacketInts3 .OR.
     &       nPacketReal.NE.bomPacketReals3 ) RETURN
      ELSE
        RETURN
      ENDIF
      IF ( packetInt(1).NE.expectedSchema ) RETURN
      isValid=.TRUE.

C--   Decode the positive exact owner ID without signed overflow.
      wordHi=INT(packetInt(2),8)
      wordLo=INT(packetInt(3),8)
      IF ( wordLo.LT.0_8 ) wordLo=wordLo+idRadix
      IF ( wordHi.LT.0_8 .OR. wordHi.GT.maxWordHi .OR.
     &     (wordHi.EQ.maxWordHi .AND. wordLo.GT.maxWordLo) ) THEN
        isValid=.FALSE.
      ELSE
        packetId=wordHi*idRadix+wordLo
        IF ( packetId.LE.0_8 ) isValid=.FALSE.
      ENDIF

      IF ( packetInt(4).NE.BOM_ALIVE .AND.
     &     packetInt(4).NE.BOM_WAITING ) isValid=.FALSE.
      packetBi=packetInt(5)
      packetBj=packetInt(6)
      IF ( packetBi.LT.1 .OR. packetBi.GT.nSx .OR.
     &     packetBj.LT.1 .OR. packetBj.GT.nSy ) isValid=.FALSE.
      IF ( packetInt(7).LT.0 .OR.
     &     packetInt(7).GT.bomMaxNeighbor ) isValid=.FALSE.

C--   Raft ID zero pairs only with size zero; positive IDs need size >= 1.
      wordHi=INT(packetInt(8),8)
      wordLo=INT(packetInt(9),8)
      IF ( wordLo.LT.0_8 ) wordLo=wordLo+idRadix
      IF ( wordHi.LT.0_8 .OR. wordHi.GT.maxWordHi .OR.
     &     (wordHi.EQ.maxWordHi .AND. wordLo.GT.maxWordLo) ) THEN
        isValid=.FALSE.
      ELSE
        packetRaftId=wordHi*idRadix+wordLo
      ENDIF
      IF ( (packetRaftId.EQ.0_8 .AND. packetInt(10).NE.0)
     &     .OR. (packetRaftId.GT.0_8 .AND.
     &     packetInt(10).LT.1) ) isValid=.FALSE.

      IF ( .NOT.IEEE_IS_FINITE(packetReal(1)) .OR.
     &     .NOT.IEEE_IS_FINITE(packetReal(2)) .OR.
     &     .NOT.IEEE_IS_FINITE(packetReal(3)) .OR.
     &     .NOT.IEEE_IS_FINITE(packetReal(4)) .OR.
     &     .NOT.IEEE_IS_FINITE(packetReal(5)) .OR.
     &     .NOT.IEEE_IS_FINITE(packetReal(6)) .OR.
     &     packetReal(3).LT.0. _d 0 .OR.
     &     packetReal(4).LT.0. _d 0 ) isValid=.FALSE.

      IF ( expectedSchema.EQ.bomPacketSchema3 ) THEN
        wordHi=INT(packetInt(11),8)
        wordLo=INT(packetInt(12),8)
        IF ( wordLo.LT.0_8 ) wordLo=wordLo+idRadix
        IF ( wordHi.LT.0_8 .OR. wordHi.GT.maxWordHi .OR.
     &       (wordHi.EQ.maxWordHi .AND. wordLo.GT.maxWordLo) ) THEN
          isValid=.FALSE.
        ELSE
          packetParentId=wordHi*idRadix+wordLo
        ENDIF
        IF ( packetParentId.EQ.packetId .OR.
     &       packetInt(13).LT.0 .OR.
     &       .NOT.IEEE_IS_FINITE(packetReal(7)) ) isValid=.FALSE.
      ENDIF

C--   Destination words must agree exactly with coordinate ownership.
      IF ( isValid ) THEN
        CALL BOM_LOCATE_OWNER(
     I       packetReal(1),packetReal(2),packetBi,packetBj,
     O       ownerX,ownerY,ownerRank,ownerBi,ownerBj,
     O       ownerHop,locateValid,
     I       myThid )
        IF ( .NOT.locateValid .OR. ownerRank.NE.myProcId .OR.
     &       ownerBi.NE.packetBi .OR. ownerBj.NE.packetBj .OR.
     &       ownerHop.NE.0 .OR. ownerX.NE.packetReal(1) .OR.
     &       ownerY.NE.packetReal(2) ) isValid=.FALSE.
      ENDIF
#endif
      RETURN
      END
