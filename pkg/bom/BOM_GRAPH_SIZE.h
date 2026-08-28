CBOP
C     !ROUTINE: BOM_GRAPH_SIZE.h
C     !INTERFACE:
C     #include "BOM_GRAPH_SIZE.h"

C     !DESCRIPTION:
C     Compile-time local storage limits for the Phase-3 cell and cutoff graph.
C     Include SIZE.h and BOM_SIZE.h before this header.  Candidate storage is
C     reused owner by owner; no dimension depends on the global particle count.
CEOP

      INTEGER bomMaxOwnerRecord
      INTEGER bomMaxCellRecord
      INTEGER bomMaxCell
      INTEGER bomMaxCandidate
      INTEGER bomMaxGhostExchange
      PARAMETER (
     &  bomMaxOwnerRecord = bomMaxPartTile*nSx*nSy,
     &  bomMaxCellRecord  =
     &       (bomMaxPartTile+bomMaxGhostTile)*nSx*nSy,
     &  bomMaxCell        = Nx*Ny,
     &  bomMaxCandidate   = bomMaxCellRecord,
     &  bomMaxGhostExchange =
     &       bomMaxOwnerRecord*MAX(1,nPx*nPy-1) )

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
