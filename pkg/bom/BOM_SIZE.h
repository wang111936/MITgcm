CBOP
C     !ROUTINE: BOM_SIZE.h
C     !INTERFACE:
C     #include "BOM_SIZE.h"

C     !DESCRIPTION:
C     Compile-time storage limits for pkg/bom.  Phase 0 deliberately
C     keeps each limit at one while the package has no particle state.
CEOP

      INTEGER bomMaxPartTile
      INTEGER bomMaxGhostTile
      INTEGER bomMaxExchange
      INTEGER bomMaxNeighbor
      INTEGER bomMaxEventBuffer
      PARAMETER ( bomMaxPartTile    = 1 )
      PARAMETER ( bomMaxGhostTile   = 1 )
      PARAMETER ( bomMaxExchange    = 1 )
      PARAMETER ( bomMaxNeighbor    = 1 )
      PARAMETER ( bomMaxEventBuffer = 1 )

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
