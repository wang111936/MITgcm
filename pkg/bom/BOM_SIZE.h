CBOP
C     !ROUTINE: BOM_SIZE.h
C     !INTERFACE:
C     #include "BOM_SIZE.h"

C     !DESCRIPTION:
C     Compile-time storage limits for pkg/bom.  Phase 1.1 enables a
C     compact owner array and bounded global initial-file validation.
CEOP

      INTEGER bomMaxPartTile
      INTEGER bomMaxGhostTile
      INTEGER bomMaxExchange
      INTEGER bomMaxNeighbor
      INTEGER bomMaxEventBuffer
      INTEGER bomMaxInitRecords
      INTEGER bomInitialSchema
      INTEGER bomInitialFields
      PARAMETER ( bomMaxPartTile    = 64 )
      PARAMETER ( bomMaxGhostTile   = 1 )
      PARAMETER ( bomMaxExchange    = 1 )
      PARAMETER ( bomMaxNeighbor    = 1 )
      PARAMETER ( bomMaxEventBuffer = 1 )
      PARAMETER ( bomMaxInitRecords = 10000 )
      PARAMETER ( bomInitialSchema  = 1 )
      PARAMETER ( bomInitialFields  = 8 )

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
