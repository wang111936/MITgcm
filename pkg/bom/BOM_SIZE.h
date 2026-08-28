CBOP
C     !ROUTINE: BOM_SIZE.h
C     !INTERFACE:
C     #include "BOM_SIZE.h"

C     !DESCRIPTION:
C     Compile-time storage limits for pkg/bom.  P1.4 adds bounded exact-ID
C     owner exchange packets without changing the compact tile capacity.
CEOP

      INTEGER bomMaxPartTile
      INTEGER bomMaxGhostTile
      INTEGER bomMaxExchange
      INTEGER bomMaxNeighbor
      INTEGER bomMaxEventBuffer
      INTEGER bomMaxInitRecords
      INTEGER bomPacketSchema
      INTEGER bomPacketInts
      INTEGER bomPacketReals
      INTEGER bomGhostSchema
      INTEGER bomGhostPacketInts
      INTEGER bomGhostPacketReals
      INTEGER bomGhostPacketBytes
      INTEGER bomInitialSchema
      INTEGER bomInitialFields
      INTEGER bomOutputSchema
      INTEGER bomOutputFields
      INTEGER bomOutputSchema2
      INTEGER bomOutputFields2
      INTEGER bomPickupSchema
      INTEGER bomPickupFields
      INTEGER bomPickupFields2
      INTEGER bomPickupSigFields
      INTEGER bomPickupSchema2
      INTEGER bomPickup2SigBase
      INTEGER bomPickupEnvHeader
      INTEGER bomPickupChunkFields
      PARAMETER ( bomMaxInitRecords = 10000 )
      PARAMETER ( bomMaxPartTile    = 64 )
      PARAMETER ( bomMaxGhostTile   = bomMaxInitRecords )
      PARAMETER ( bomMaxExchange    = bomMaxInitRecords )
      PARAMETER ( bomMaxNeighbor    = bomMaxInitRecords )
      PARAMETER ( bomMaxEventBuffer = 1 )
      PARAMETER ( bomPacketSchema   = 2 )
      PARAMETER ( bomPacketInts     = 10 )
      PARAMETER ( bomPacketReals    = 6 )
      PARAMETER ( bomGhostSchema    = 1 )
      PARAMETER ( bomGhostPacketInts = 9 )
      PARAMETER ( bomGhostPacketReals = 2 )
      PARAMETER ( bomGhostPacketBytes =
     &            4*bomGhostPacketInts+8*bomGhostPacketReals )
      PARAMETER ( bomInitialSchema  = 1 )
      PARAMETER ( bomInitialFields  = 8 )
      PARAMETER ( bomOutputSchema   = 1 )
      PARAMETER ( bomOutputFields   = 24 )
      PARAMETER ( bomOutputSchema2  = 2 )
      PARAMETER ( bomOutputFields2  = 48 )
      PARAMETER ( bomPickupSchema   = 1 )
      PARAMETER ( bomPickupFields   = 24 )
      PARAMETER ( bomPickupFields2  = 45 )
      PARAMETER ( bomPickupSigFields = 16 )
      PARAMETER ( bomPickupSchema2  = 2 )
      PARAMETER ( bomPickup2SigBase = 53 )
      PARAMETER ( bomPickupEnvHeader = 12 )
      PARAMETER ( bomPickupChunkFields = 24 )

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
