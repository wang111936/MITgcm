#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P43_PACKET(myThid,nFail)
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_VALUE,IEEE_QUIET_NAN
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid,nFail
#ifdef ALLOW_BOM
      INTEGER packetInt(bomPacketInts3),packetBi,packetBj
      INTEGER destRank,destBi,destBj,hop,savedInt
      INTEGER savedCount
      INTEGER*8 packetId,packetParentId,packetRaftId,savedNext
      _RL packetReal(bomPacketReals3),ownerX,ownerY,savedReal
      LOGICAL isValid,locateValid

      IF ( myProcId.EQ.0 ) THEN
        CALL BOM_LOCATE_OWNER(
     I       -3500. _d 0,-1500. _d 0,1,1,
     O       ownerX,ownerY,destRank,destBi,destBj,
     O       hop,locateValid,myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       locateValid .AND. destRank.EQ.0 .AND. hop.EQ.0,
     &       'P4-M01 packet destination fixture',nFail,myThid)

        packetInt(1)=bomPacketSchema3
        packetInt(2)=1
        packetInt(3)=17
        packetInt(4)=BOM_ALIVE
        packetInt(5)=destBi
        packetInt(6)=destBj
        packetInt(7)=0
        packetInt(8)=1
        packetInt(9)=3
        packetInt(10)=1
        packetInt(11)=1
        packetInt(12)=9
        packetInt(13)=9
        packetReal(1)=ownerX
        packetReal(2)=ownerY
        packetReal(3)=10. _d 0
        packetReal(4)=2. _d 0
        packetReal(5)=0.25 _d 0
        packetReal(6)=-0.5 _d 0
        packetReal(7)=2.25 _d 0
        CALL BOM_OWNER_PACKET_VALIDATE(
     I       packetInt,bomPacketInts3,packetReal,bomPacketReals3,
     I       bomPacketSchema3,
     O       packetId,packetParentId,packetRaftId,
     O       packetBi,packetBj,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       isValid .AND. packetId.EQ.4294967313_8 .AND.
     &       packetParentId.EQ.4294967305_8 .AND.
     &       packetRaftId.EQ.4294967299_8 .AND.
     &       packetBi.EQ.destBi .AND. packetBj.EQ.destBj,
     &       'P4-M01 exact schema3 packet decode',nFail,myThid)

C--     Released schema 2 keeps the exact ten/six layout and no biology tail.
        packetInt(1)=bomPacketSchema
        CALL BOM_OWNER_PACKET_VALIDATE(
     I       packetInt,bomPacketInts,packetReal,bomPacketReals,
     I       bomPacketSchema,
     O       packetId,packetParentId,packetRaftId,
     O       packetBi,packetBj,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       isValid .AND. packetParentId.EQ.0_8,
     &       'P4-M01 released schema2 exact width',nFail,myThid)
        packetInt(1)=bomPacketSchema3

C--     Every malformed packet is rejected without mutating owner authority.
        savedNext=bomNextId
        savedCount=bomEventBufferCount
        packetInt(1)=bomPacketSchema
        CALL BOM_OWNER_PACKET_VALIDATE(
     I       packetInt,bomPacketInts3,packetReal,bomPacketReals3,
     I       bomPacketSchema3,
     O       packetId,packetParentId,packetRaftId,
     O       packetBi,packetBj,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       .NOT.isValid,'P4-M01 schema mutation',nFail,myThid)
        packetInt(1)=bomPacketSchema3

        savedInt=packetInt(2)
        packetInt(2)=-1
        CALL BOM_OWNER_PACKET_VALIDATE(
     I       packetInt,bomPacketInts3,packetReal,bomPacketReals3,
     I       bomPacketSchema3,
     O       packetId,packetParentId,packetRaftId,
     O       packetBi,packetBj,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       .NOT.isValid,'P4-M01 owner-word mutation',nFail,myThid)
        packetInt(2)=savedInt

        savedInt=packetInt(11)
        packetInt(11)=-1
        CALL BOM_OWNER_PACKET_VALIDATE(
     I       packetInt,bomPacketInts3,packetReal,bomPacketReals3,
     I       bomPacketSchema3,
     O       packetId,packetParentId,packetRaftId,
     O       packetBi,packetBj,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       .NOT.isValid,'P4-M01 parent-word mutation',nFail,myThid)
        packetInt(11)=savedInt

        savedInt=packetInt(13)
        packetInt(13)=-1
        CALL BOM_OWNER_PACKET_VALIDATE(
     I       packetInt,bomPacketInts3,packetReal,bomPacketReals3,
     I       bomPacketSchema3,
     O       packetId,packetParentId,packetRaftId,
     O       packetBi,packetBj,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       .NOT.isValid,'P4-M01 count mutation',nFail,myThid)
        packetInt(13)=savedInt

        savedInt=packetInt(5)
        packetInt(5)=0
        CALL BOM_OWNER_PACKET_VALIDATE(
     I       packetInt,bomPacketInts3,packetReal,bomPacketReals3,
     I       bomPacketSchema3,
     O       packetId,packetParentId,packetRaftId,
     O       packetBi,packetBj,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       .NOT.isValid,'P4-M01 destination mutation',nFail,myThid)
        packetInt(5)=savedInt

        savedReal=packetReal(7)
        packetReal(7)=IEEE_VALUE(packetReal(7),IEEE_QUIET_NAN)
        CALL BOM_OWNER_PACKET_VALIDATE(
     I       packetInt,bomPacketInts3,packetReal,bomPacketReals3,
     I       bomPacketSchema3,
     O       packetId,packetParentId,packetRaftId,
     O       packetBi,packetBj,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       .NOT.isValid,'P4-M01 real mutation',nFail,myThid)
        packetReal(7)=savedReal

        CALL BOM_OWNER_PACKET_VALIDATE(
     I       packetInt,bomPacketInts3-1,packetReal,bomPacketReals3,
     I       bomPacketSchema3,
     O       packetId,packetParentId,packetRaftId,
     O       packetBi,packetBj,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       .NOT.isValid,'P4-M01 integer length mutation',nFail,myThid)
        CALL BOM_OWNER_PACKET_VALIDATE(
     I       packetInt,bomPacketInts3,packetReal,bomPacketReals3-1,
     I       bomPacketSchema3,
     O       packetId,packetParentId,packetRaftId,
     O       packetBi,packetBj,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       .NOT.isValid,'P4-M01 real length mutation',nFail,myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       bomNextId.EQ.savedNext .AND.
     &       bomEventBufferCount.EQ.savedCount,
     &       'P4-M01 malformed packet leaves authority unchanged',
     &       nFail,myThid)
      ENDIF
#endif
      RETURN
      END
