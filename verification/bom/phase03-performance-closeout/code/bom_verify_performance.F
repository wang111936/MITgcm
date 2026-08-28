#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_PERFORMANCE_CLOSEOUT( myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      INTEGER myThid, nFail, globalFail, nSide

      nFail = 0
      CALL BOM_P35_TEST_COUNTER_REDUCTION(nFail,myThid)
      DO nSide=16,64,16
        IF ( nSide.NE.48 ) THEN
          CALL BOM_P35_RUN_FIXED_DENSITY(
     I         nSide,.FALSE.,nFail,myThid)
          CALL BOM_P35_RUN_FIXED_DENSITY(
     I         nSide,.TRUE.,nFail,myThid)
        ENDIF
      ENDDO
      CALL BOM_P35_TEST_DENSE_FAILURE(nFail,myThid)
      globalFail = nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.NE.0 ) THEN
        IF ( myProcId.EQ.0 )
     &    WRITE(errorMessageUnit,'(A,I12)')
     &      'P3.5 PERFORMANCE FAIL: assertions=',globalFail
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P3.5 PERFORMANCE'
      ENDIF
      IF ( myProcId.EQ.0 ) THEN
        WRITE(standardMessageUnit,'(A)')
     &    'P3-X01 PASS: exact portable counter reductions'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-X02 PASS: fixed-density Cartesian/spherical bounds'
        WRITE(standardMessageUnit,'(A)')
     &    'P3-X02-DENSE PASS: bounded failure preserves outputs'
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P35_TEST_DENSE_FAILURE( nFail, myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nFail,myThid,nOwner,point,rank,bi,bj,hop,owner
      INTEGER failCode,failPhase
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord)
      INTEGER ownerBj(bomMaxOwnerRecord)
      INTEGER ownerNeighbor(bomMaxOwnerRecord)
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord),ownerY(bomMaxOwnerRecord)
      _RL springEast(bomMaxOwnerRecord)
      _RL springNorth(bomMaxOwnerRecord)
      _RL pointX,pointY,xOwner,yOwner
      INTEGER*8 ownerRecords,ghostRecords,nonEmptyCells
      INTEGER*8 comparisons,directed,undirected,maximumNeighbors
      LOGICAL valid,stageValid

      CALL BOM_P35_SET_MAPPING(16,.FALSE.,myThid)
      nOwner = 0
      DO point=1,6
        pointX = bomMapXFace(myXGlobalLo-1)
     &       +2000. _d 0+DFLOAT(point)
        pointY = bomMapYFace(myYGlobalLo-1)+2000. _d 0
        CALL BOM_LOCATE_OWNER(
     I       pointX,pointY,1,1,
     O       xOwner,yOwner,rank,bi,bj,hop,valid,myThid)
        CALL BOM_P35_ASSERT(valid,nFail)
        IF ( valid .AND. rank.EQ.myProcId ) THEN
          nOwner = nOwner+1
          ownerId(nOwner) = 900000_8
     &         +100_8*INT(myProcId,8)+INT(point,8)
          ownerStatus(nOwner) = BOM_ALIVE
          ownerX(nOwner) = xOwner
          ownerY(nOwner) = yOwner
          ownerBi(nOwner) = bi
          ownerBj(nOwner) = bj
        ENDIF
      ENDDO
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_K2,999,1,
     O     failCode,failPhase,valid,myThid)
      CALL BOM_P35_ASSERT(valid,nFail)
      DO owner=1,bomMaxOwnerRecord
        springEast(owner) = -777. _d 0
        springNorth(owner) = -777. _d 0
        ownerNeighbor(owner) = -777
      ENDDO
      ownerRecords = -777_8
      ghostRecords = -777_8
      nonEmptyCells = -777_8
      comparisons = -777_8
      directed = -777_8
      undirected = -777_8
      maximumNeighbors = -777_8
      CALL BOM_SPRING_STAGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     BOM_STAGE_K2,999,1,0. _d 0,
     O     springEast,springNorth,ownerNeighbor,
     O     ownerRecords,ghostRecords,nonEmptyCells,
     O     comparisons,directed,undirected,maximumNeighbors,
     O     failCode,failPhase,stageValid,myThid)
      CALL BOM_P35_ASSERT(.NOT.stageValid .AND.
     &     failCode.EQ.BOM_FAIL_NEIGHBOR_CAPACITY .AND.
     &     failPhase.EQ.BOM_P3_PHASE_NEIGHBOR,nFail)
      CALL BOM_P35_ASSERT(ownerRecords.EQ.-777_8 .AND.
     &     ghostRecords.EQ.-777_8 .AND.
     &     nonEmptyCells.EQ.-777_8 .AND.
     &     comparisons.EQ.-777_8 .AND.
     &     directed.EQ.-777_8 .AND.
     &     undirected.EQ.-777_8 .AND.
     &     maximumNeighbors.EQ.-777_8,nFail)
      DO owner=1,nOwner
        CALL BOM_P35_ASSERT(springEast(owner).EQ.-777. _d 0
     &       .AND. springNorth(owner).EQ.-777. _d 0
     &       .AND. ownerNeighbor(owner).EQ.-777,nFail)
      ENDDO
      CALL BOM_GHOST_INVALIDATE
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P35_TEST_COUNTER_REDUCTION( nFail, myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nFail,myThid,field,failCode,nProc
      INTEGER*8 baseValue,localExpected,sumExpected,maxExpected
      INTEGER*8 localValue(bomP3CounterFields)
      INTEGER*8 globalSum(bomP3CounterFields)
      INTEGER*8 globalMaximum(bomP3CounterFields)
      LOGICAL valid

      nProc = nPx*nPy
      baseValue = 5000000000_8+INT(myProcId,8)*100_8
      CALL BOM_P35_ASSIGN_COUNTERS(baseValue)
      DO field=1,bomP3CounterFields
        localValue(field) = -777_8
        globalSum(field) = -777_8
        globalMaximum(field) = -777_8
      ENDDO
      CALL BOM_P3_COUNTER_SNAPSHOT(
     O     localValue,globalSum,globalMaximum,
     O     failCode,valid,myThid)
      DO field=1,bomP3CounterFields
        localExpected = baseValue+INT(field,8)
        sumExpected = INT(nProc,8)*
     &       (5000000000_8+INT(field,8))
     &       +50_8*INT(nProc*(nProc-1),8)
        maxExpected = 5000000000_8+INT(field,8)
     &       +100_8*INT(nProc-1,8)
        CALL BOM_P35_ASSERT(valid .AND.
     &       failCode.EQ.BOM_FAIL_NONE .AND.
     &       localValue(field).EQ.localExpected .AND.
     &       globalSum(field).EQ.sumExpected .AND.
     &       globalMaximum(field).EQ.maxExpected,nFail)
      ENDDO

C--   A global overflow or one negative rank must fail on every rank and
C     preserve every caller-owned output slot.
      CALL BOM_P35_ASSIGN_COUNTERS(1_8)
      IF ( nProc.GT.1 ) THEN
        IF ( myProcId.EQ.0 )
     &       bomP3OwnerRecords=HUGE(bomP3OwnerRecords)-100_8
        IF ( myProcId.NE.0 ) bomP3OwnerRecords=200_8
      ELSE
        bomP3OwnerRecords=-1_8
      ENDIF
      DO field=1,bomP3CounterFields
        localValue(field) = -888_8
        globalSum(field) = -888_8
        globalMaximum(field) = -888_8
      ENDDO
      CALL BOM_P3_COUNTER_SNAPSHOT(
     O     localValue,globalSum,globalMaximum,
     O     failCode,valid,myThid)
      CALL BOM_P35_ASSERT(.NOT.valid .AND.
     &     failCode.EQ.BOM_FAIL_CELL_CAPACITY,nFail)
      DO field=1,bomP3CounterFields
        CALL BOM_P35_ASSERT(localValue(field).EQ.-888_8 .AND.
     &       globalSum(field).EQ.-888_8 .AND.
     &       globalMaximum(field).EQ.-888_8,nFail)
      ENDDO
      CALL BOM_P35_CLEAR_COUNTERS
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P35_RUN_FIXED_DENSITY(
     I                 nSide, sphericalFixture,
     U                 nFail,
     I                 myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER nSide,nFail,myThid
      LOGICAL sphericalFixture
      INTEGER pointI,pointJ,nOwner,rank,bi,bj,hop,owner
      INTEGER failCode,failPhase,epoch
      INTEGER clockStart,clockFinish,clockRate,clockMaximum
      INTEGER clockTicks
      INTEGER ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord)
      INTEGER ownerBj(bomMaxOwnerRecord)
      INTEGER ownerNeighbor(bomMaxOwnerRecord)
      INTEGER*8 ownerId(bomMaxOwnerRecord)
      _RL ownerX(bomMaxOwnerRecord),ownerY(bomMaxOwnerRecord)
      _RL springEast(bomMaxOwnerRecord)
      _RL springNorth(bomMaxOwnerRecord)
      _RL xPoint,yPoint,xOwner,yOwner,spacingAngle,elapsed
      INTEGER*8 ownerRecords,ghostRecords,nonEmptyCells
      INTEGER*8 comparisons,directed,undirected,maximumNeighbors
      INTEGER*8 localCounter(bomP3CounterFields)
      INTEGER*8 globalSum(bomP3CounterFields)
      INTEGER*8 globalMaximum(bomP3CounterFields)
      INTEGER*8 expectedOwner,expectedEdge,boundaryIncidents
      CHARACTER*4 geometryName
      LOGICAL valid,stageValid,counterValid

      CALL BOM_P35_SET_MAPPING(nSide,sphericalFixture,myThid)
      IF ( sphericalFixture ) THEN
        spacingAngle =
     &       1000. _d 0/(rSphere*deg2rad)
        geometryName = 'SPHR'
      ELSE
        spacingAngle = 1000. _d 0
        geometryName = 'CART'
      ENDIF
      nOwner = 0
      DO pointJ=1,nSide
        DO pointI=1,nSide
          xPoint = (DFLOAT(pointI)-halfRL)*spacingAngle
          IF ( sphericalFixture ) THEN
            yPoint = (DFLOAT(pointJ)-halfRL
     &           -halfRL*DFLOAT(nSide))*spacingAngle
          ELSE
            yPoint = (DFLOAT(pointJ)-halfRL)*spacingAngle
          ENDIF
          CALL BOM_LOCATE_OWNER(
     I         xPoint,yPoint,1,1,
     O         xOwner,yOwner,rank,bi,bj,hop,valid,myThid)
          CALL BOM_P35_ASSERT(valid,nFail)
          IF ( valid .AND. rank.EQ.myProcId ) THEN
            IF ( nOwner.GE.bomMaxOwnerRecord ) THEN
              CALL BOM_P35_ASSERT(.FALSE.,nFail)
            ELSE
              nOwner = nOwner+1
              ownerId(nOwner) = INT((pointJ-1)*nSide+pointI,8)
              ownerStatus(nOwner) = BOM_ALIVE
              ownerX(nOwner) = xOwner
              ownerY(nOwner) = yOwner
              ownerBi(nOwner) = bi
              ownerBj(nOwner) = bj
            ENDIF
          ENDIF
        ENDDO
      ENDDO

      epoch = nSide
      IF ( sphericalFixture ) epoch=100+nSide
      CALL SYSTEM_CLOCK(clockStart,clockRate,clockMaximum)
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     ownerBi,ownerBj,BOM_STAGE_K1,epoch,1,
     O     failCode,failPhase,valid,myThid)
      IF ( valid ) THEN
        CALL BOM_SPRING_STAGE(
     I       nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I       BOM_STAGE_K1,epoch,1,0. _d 0,
     O       springEast,springNorth,ownerNeighbor,
     O       ownerRecords,ghostRecords,nonEmptyCells,
     O       comparisons,directed,undirected,maximumNeighbors,
     O       failCode,failPhase,stageValid,myThid)
      ELSE
        stageValid = .FALSE.
      ENDIF
      CALL SYSTEM_CLOCK(clockFinish,clockRate,clockMaximum)
      IF ( clockFinish.GE.clockStart ) THEN
        clockTicks = clockFinish-clockStart
      ELSE
        clockTicks = clockMaximum-clockStart+clockFinish+1
      ENDIF
      elapsed = DFLOAT(clockTicks)/DFLOAT(MAX(1,clockRate))
      CALL BOM_P35_ASSERT(valid .AND. stageValid .AND.
     &     failCode.EQ.BOM_FAIL_NONE .AND.
     &     failPhase.EQ.BOM_P3_PHASE_NONE,nFail)
      IF ( .NOT.valid .OR. .NOT.stageValid ) RETURN

      localCounter(BOM_P3_COUNT_OWNER) = ownerRecords
      localCounter(BOM_P3_COUNT_GHOST) = ghostRecords
      localCounter(BOM_P3_COUNT_NONEMPTY) = nonEmptyCells
      localCounter(BOM_P3_COUNT_COMPARISON) = comparisons
      localCounter(BOM_P3_COUNT_DIRECTED) = directed
      localCounter(BOM_P3_COUNT_UNDIRECTED) = undirected
      localCounter(BOM_P3_COUNT_MAX_NEIGHBOR) = maximumNeighbors
      localCounter(BOM_P3_COUNT_REBUILD) = 1_8
      localCounter(BOM_P3_COUNT_PACKET_SENT) =
     &     bomGhostRecordsSent
      localCounter(BOM_P3_COUNT_PACKET_RECEIVED) =
     &     bomGhostRecordsReceived
      localCounter(BOM_P3_COUNT_BYTE_SENT) = bomGhostBytesSent
      localCounter(BOM_P3_COUNT_BYTE_RECEIVED) =
     &     bomGhostBytesReceived
      localCounter(BOM_P3_COUNT_MAX_COMPONENT) = 0_8
      localCounter(BOM_P3_COUNT_COMPONENT_ITER) = 0_8
      CALL BOM_P3_REDUCE_COUNTERS(
     I     localCounter,
     O     globalSum,globalMaximum,failCode,counterValid,myThid)
      CALL BOM_P35_ASSERT(counterValid .AND.
     &     failCode.EQ.BOM_FAIL_NONE,nFail)
      IF ( .NOT.counterValid ) RETURN

      expectedOwner = INT(nSide,8)*INT(nSide,8)
      expectedEdge = 2_8*INT(nSide,8)*INT(nSide-1,8)
      boundaryIncidents = 2_8*INT(nSide,8)*
     &     INT(nPx*nSx+nPy*nSy-2,8)
      CALL BOM_P35_ASSERT(ownerRecords.EQ.INT(nOwner,8) .AND.
     &     globalSum(BOM_P3_COUNT_OWNER).EQ.expectedOwner,nFail)
      CALL BOM_P35_ASSERT(
     &     globalSum(BOM_P3_COUNT_DIRECTED).EQ.2_8*expectedEdge
     &     .AND.
     &     globalSum(BOM_P3_COUNT_UNDIRECTED).EQ.expectedEdge,
     &     nFail)
      CALL BOM_P35_ASSERT(
     &     globalMaximum(BOM_P3_COUNT_MAX_NEIGHBOR).EQ.4_8
     &     .AND. maximumNeighbors.LE.4_8,nFail)
      CALL BOM_P35_ASSERT(
     &     globalSum(BOM_P3_COUNT_COMPARISON)
     &       .LE.16_8*expectedOwner,nFail)
      CALL BOM_P35_ASSERT(
     &     globalSum(BOM_P3_COUNT_GHOST)
     &       .LE.8_8*boundaryIncidents,nFail)
      CALL BOM_P35_ASSERT(
     &     globalSum(BOM_P3_COUNT_PACKET_SENT).EQ.
     &       globalSum(BOM_P3_COUNT_PACKET_RECEIVED) .AND.
     &     globalSum(BOM_P3_COUNT_BYTE_SENT).EQ.
     &       globalSum(BOM_P3_COUNT_BYTE_RECEIVED),nFail)
      CALL BOM_P35_ASSERT(
     &     bomGhostBytesSent.EQ.bomGhostRecordsSent
     &       *INT(bomGhostPacketBytes,8) .AND.
     &     bomGhostBytesReceived.EQ.bomGhostRecordsReceived
     &       *INT(bomGhostPacketBytes,8),nFail)
      DO owner=1,nOwner
        CALL BOM_P35_ASSERT(ownerNeighbor(owner).LE.4,nFail)
      ENDDO

      WRITE(standardMessageUnit,
     & '(A,1X,I4,1X,A4,1X,I4,1X,12(I21,1X),1PE23.15)')
     & 'P35METRIC',myProcId,geometryName,nSide,nOwner,
     & ownerRecords,ghostRecords,nonEmptyCells,comparisons,
     & directed,undirected,maximumNeighbors,
     & bomGhostRecordsSent,bomGhostRecordsReceived,
     & bomGhostBytesSent,bomGhostBytesReceived,elapsed
      CALL BOM_GHOST_INVALIDATE
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P35_SET_MAPPING(
     I                 nSide, sphericalFixture, myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER nSide,myThid,i,j
      LOGICAL sphericalFixture
      _RL spacing,spanX,spanY,scale

      _BEGIN_MASTER(myThid)
      IF ( sphericalFixture ) THEN
        usingCartesianGrid = .FALSE.
        usingSphericalPolarGrid = .TRUE.
        spacing = 1000. _d 0/(rSphere*deg2rad)
        bomMapXLo = 0. _d 0
        bomMapYLo = -halfRL*DFLOAT(nSide)*spacing
      ELSE
        usingCartesianGrid = .TRUE.
        usingSphericalPolarGrid = .FALSE.
        spacing = 1000. _d 0
        bomMapXLo = 0. _d 0
        bomMapYLo = 0. _d 0
      ENDIF
      spanX = DFLOAT(nSide)*spacing
      spanY = DFLOAT(nSide)*spacing
      bomMapXHi = bomMapXLo+spanX
      bomMapYHi = bomMapYLo+spanY
      bomMapXPeriod = 0. _d 0
      bomMapPeriodicX = .FALSE.
      DO i=0,Nx
        bomMapXFace(i) = bomMapXLo+spanX*DFLOAT(i)/DFLOAT(Nx)
      ENDDO
      DO j=0,Ny
        bomMapYFace(j) = bomMapYLo+spanY*DFLOAT(j)/DFLOAT(Ny)
      ENDDO
      scale = MAX(oneRL,ABS(bomMapXLo),ABS(bomMapXHi))
      scale = MAX(scale,ABS(bomMapYLo),ABS(bomMapYHi))
      bomMapTol = 64. _d 0*EPSILON(oneRL)*scale
      bomNeighborCutoff = 1010. _d 0
      bomPairDistanceMin = 1. _d -6
      bomSpringL = 1000. _d 0
      bomHookeK = 0.001 _d 0
      bomSpringCFL = oneRL
      bomRaftDiagnostics = .FALSE.
      _END_MASTER(myThid)
      _BARRIER
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P35_ASSIGN_COUNTERS( baseValue )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER*8 baseValue
      bomP3OwnerRecords = baseValue+1_8
      bomP3GhostRecords = baseValue+2_8
      bomP3NonEmptyCells = baseValue+3_8
      bomP3CandidateComparisons = baseValue+4_8
      bomP3DirectedNeighbors = baseValue+5_8
      bomP3UndirectedEdges = baseValue+6_8
      bomP3MaximumNeighbors = baseValue+7_8
      bomP3RebuildCount = baseValue+8_8
      bomP3GhostPacketsSent = baseValue+9_8
      bomP3GhostPacketsReceived = baseValue+10_8
      bomP3GhostBytesSent = baseValue+11_8
      bomP3GhostBytesReceived = baseValue+12_8
      bomP3MaximumComponentSize = baseValue+13_8
      bomP3ComponentIterations = baseValue+14_8
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P35_CLEAR_COUNTERS
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      bomP3OwnerRecords = 0_8
      bomP3GhostRecords = 0_8
      bomP3NonEmptyCells = 0_8
      bomP3CandidateComparisons = 0_8
      bomP3DirectedNeighbors = 0_8
      bomP3UndirectedEdges = 0_8
      bomP3MaximumNeighbors = 0_8
      bomP3RebuildCount = 0_8
      bomP3GhostPacketsSent = 0_8
      bomP3GhostPacketsReceived = 0_8
      bomP3GhostBytesSent = 0_8
      bomP3GhostBytesReceived = 0_8
      bomP3MaximumComponentSize = 0_8
      bomP3ComponentIterations = 0_8
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P35_ASSERT( condition, nFail )
      IMPLICIT NONE
      LOGICAL condition
      INTEGER nFail
      IF ( .NOT.condition ) nFail=nFail+1
      RETURN
      END
