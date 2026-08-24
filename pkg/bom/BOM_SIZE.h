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
      INTEGER bomPacketInts
      INTEGER bomPacketReals
      INTEGER bomInitialSchema
      INTEGER bomInitialFields
      PARAMETER ( bomMaxInitRecords = 10000 )
      PARAMETER ( bomMaxPartTile    = 64 )
      PARAMETER ( bomMaxGhostTile   = 1 )
      PARAMETER ( bomMaxExchange    = bomMaxInitRecords )
      PARAMETER ( bomMaxNeighbor    = bomMaxInitRecords )
      PARAMETER ( bomMaxEventBuffer = 1 )
      PARAMETER ( bomPacketInts     = 5 )
      PARAMETER ( bomPacketReals    = 4 )
      PARAMETER ( bomInitialSchema  = 1 )
      PARAMETER ( bomInitialFields  = 8 )

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
