C--   Shared direct-gate workspace.  Verification code may hold an all-pairs
C     oracle; none of these arrays is compiled into pkg/bom.
      INTEGER*8 p32RecordId(bomMaxCellRecord)
      INTEGER*8 p32NeighborId(bomMaxNeighbor,bomMaxOwnerRecord)
      COMMON /P32_TEST_I8/ p32RecordId, p32NeighborId

      INTEGER p32RecordStatus(bomMaxCellRecord)
      INTEGER p32RecordOwner(bomMaxCellRecord)
      INTEGER p32CellHead(bomMaxCell)
      INTEGER p32CellNext(bomMaxCellRecord)
      INTEGER p32RecordCell(bomMaxCellRecord)
      INTEGER p32NeighborCount(bomMaxOwnerRecord)
      INTEGER p32NeighborRecord(bomMaxNeighbor,bomMaxOwnerRecord)
      INTEGER p32RowReachX(bomMaxCell)
      COMMON /P32_TEST_I/
     &       p32RecordStatus, p32RecordOwner,
     &       p32CellHead, p32CellNext, p32RecordCell,
     &       p32NeighborCount, p32NeighborRecord, p32RowReachX

      _RL p32RecordX(bomMaxCellRecord)
      _RL p32RecordY(bomMaxCellRecord)
      COMMON /P32_TEST_R/ p32RecordX, p32RecordY
