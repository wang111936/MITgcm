#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_SCHEMA3_IO( myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid

      IF ( startTime.EQ.0. _d 0 ) THEN
        CALL BOM_BUILD_ENDPOINTS(0. _d 0,0,.TRUE.,myThid)
        CALL BOM_BUILD_ENDPOINTS(100. _d 0,1,.FALSE.,myThid)
        CALL BOM_BUILD_FIELDS(100. _d 0,1,myThid)
        CALL BOM_P34_LOAD_SCHEMA_RING(myThid)
        CALL BOM_OUTPUT(100. _d 0,1,myThid)
        CALL BOM_WRITE_PICKUP('p34schema3',100. _d 0,1,myThid)
        CALL BOM_MAIN(200. _d 0,2,myThid)
        CALL BOM_OUTPUT(200. _d 0,2,myThid)
        CALL BOM_WRITE_PICKUP('p34cont',200. _d 0,2,myThid)
        IF ( myProcId.EQ.0 )
     &    WRITE(standardMessageUnit,'(A)')
     &    'P3-P01 PASS: schema-3 trajectory and pickup written'
      ELSEIF ( startTime.EQ.100. _d 0 ) THEN
        _BEGIN_MASTER(myThid)
        nIter0=1
        pickupSuff='p34schema3'
        _END_MASTER(myThid)
        _BARRIER
        CALL BOM_READ_PICKUP(myThid)
        CALL BOM_MAIN(200. _d 0,2,myThid)
        CALL BOM_OUTPUT(200. _d 0,2,myThid)
        CALL BOM_WRITE_PICKUP('p34split',200. _d 0,2,myThid)
        IF ( myProcId.EQ.0 )
     &    WRITE(standardMessageUnit,'(A)')
     &    'P3-P02 PASS: schema-3 pickup restored and advanced'
      ELSE
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P3.4 SCHEMA DRIVER ITER'
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P34_LOAD_SCHEMA_RING( myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM_GRAPH_SIZE.h"
#include "BOM.h"
      INTEGER myThid
      INTEGER nPoint,point,rank,bi,bj,hop,ip,iDiag
      INTEGER nOwner,owner,failCode,failPhase
      INTEGER componentIterations,maximumComponentSize
      INTEGER pointStatus(4),ownerStatus(bomMaxOwnerRecord)
      INTEGER ownerIp(bomMaxOwnerRecord)
      INTEGER ownerBi(bomMaxOwnerRecord)
      INTEGER ownerBj(bomMaxOwnerRecord)
      INTEGER ownerNeighbor(bomMaxOwnerRecord)
      INTEGER ownerRaftSize(bomMaxOwnerRecord)
      INTEGER*8 pointId(4),ownerId(bomMaxOwnerRecord)
      INTEGER*8 ownerRaftId(bomMaxOwnerRecord)
      _RL pointX(4),pointY(4),xOwner,yOwner,mappedI,mappedJ
      _RL ownerX(bomMaxOwnerRecord),ownerY(bomMaxOwnerRecord)
      _RL springEast(bomMaxOwnerRecord)
      _RL springNorth(bomMaxOwnerRecord)
      INTEGER*8 ownerRecords,ghostRecords,nonEmptyCells
      INTEGER*8 comparisons,directed,edges,maxNeighbors
      LOGICAL valid,isOwner,hasStencil

      nPoint=4
C--   Ascending exact IDs keep every compact tile record canonical.
      pointId(1)=11_8
      pointX(1)=2200. _d 0
      pointY(1)=500. _d 0
      pointId(2)=22_8
      pointX(2)=2000. _d 0
      pointY(2)=700. _d 0
      pointId(3)=33_8
      pointX(3)=2200. _d 0
      pointY(3)=700. _d 0
      pointId(4)=44_8
      pointX(4)=2000. _d 0
      pointY(4)=500. _d 0
      DO point=1,nPoint
        pointStatus(point)=BOM_ALIVE
      ENDDO
      _BEGIN_MASTER(myThid)
      bomNPartExpected=nPoint
      bomNextOutputTime=100. _d 0
      bomOutputScheduleReady=.TRUE.
      _END_MASTER(myThid)
      _BARRIER

      DO point=1,nPoint
        CALL BOM_LOCATE_OWNER(
     I       pointX(point),pointY(point),1,1,
     O       xOwner,yOwner,rank,bi,bj,hop,valid,myThid)
        IF ( .NOT.valid ) THEN
          CALL ALL_PROC_DIE(0)
          STOP 'ABNORMAL END: P3.4 SCHEMA OWNER'
        ENDIF
        IF ( rank.EQ.myProcId ) THEN
          ip=bomNPartTile(bi,bj)+1
          IF ( ip.GT.bomMaxPartTile ) THEN
            CALL ALL_PROC_DIE(0)
            STOP 'ABNORMAL END: P3.4 SCHEMA CAPACITY'
          ENDIF
          CALL BOM_MAP_XY2IJLOCAL(
     I         xOwner,yOwner,bi,bj,
     O         pointX(point),mappedI,mappedJ,isOwner,hasStencil,
     I         myThid)
          IF ( .NOT.isOwner .OR. .NOT.hasStencil ) THEN
            CALL ALL_PROC_DIE(0)
            STOP 'ABNORMAL END: P3.4 SCHEMA MAPPING'
          ENDIF
          bomNPartTile(bi,bj)=ip
          bomId(ip,bi,bj)=pointId(point)
          bomStatus(ip,bi,bj)=pointStatus(point)
          bomX(ip,bi,bj)=xOwner
          bomY(ip,bi,bj)=yOwner
          bomReleaseTime(ip,bi,bj)=0. _d 0
          bomAge(ip,bi,bj)=100. _d 0
          bomI(ip,bi,bj)=mappedI
          bomJ(ip,bi,bj)=mappedJ
          bomVEast(ip,bi,bj)=0. _d 0
          bomVNorth(ip,bi,bj)=0. _d 0
          bomWindEast(ip,bi,bj)=0. _d 0
          bomWindNorth(ip,bi,bj)=0. _d 0
          bomDriftEast(ip,bi,bj)=0. _d 0
          bomDriftNorth(ip,bi,bj)=0. _d 0
          DO iDiag=1,BOM_RHS_NDIAG
            bomRhsDiag(iDiag,ip,bi,bj)=0. _d 0
          ENDDO
        ENDIF
      ENDDO

      nOwner=0
      DO bj=1,nSy
       DO bi=1,nSx
        DO ip=1,bomNPartTile(bi,bj)
          nOwner=nOwner+1
          ownerIp(nOwner)=ip
          ownerBi(nOwner)=bi
          ownerBj(nOwner)=bj
          ownerId(nOwner)=bomId(ip,bi,bj)
          ownerStatus(nOwner)=bomStatus(ip,bi,bj)
          ownerX(nOwner)=bomX(ip,bi,bj)
          ownerY(nOwner)=bomY(ip,bi,bj)
        ENDDO
       ENDDO
      ENDDO
      CALL BOM_GHOST_EXCHANGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,ownerBi,ownerBj,
     I     BOM_STAGE_FINAL,301,1,
     O     failCode,failPhase,valid,myThid)
      IF ( .NOT.valid ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P3.4 SCHEMA GHOST'
      ENDIF
      CALL BOM_SPRING_STAGE(
     I     nOwner,ownerId,ownerStatus,ownerX,ownerY,
     I     BOM_STAGE_FINAL,301,1,0. _d 0,
     O     springEast,springNorth,ownerNeighbor,
     O     ownerRecords,ghostRecords,nonEmptyCells,
     O     comparisons,directed,edges,maxNeighbors,
     O     failCode,failPhase,valid,myThid)
      IF ( .NOT.valid ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P3.4 SCHEMA SPRING'
      ENDIF
      CALL BOM_COMPONENT_FETCH(
     I     nOwner,ownerId,BOM_STAGE_FINAL,301,1,
     O     ownerRaftId,ownerRaftSize,
     O     componentIterations,maximumComponentSize,
     O     failCode,valid,myThid)
      IF ( .NOT.valid ) THEN
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: P3.4 SCHEMA COMPONENT'
      ENDIF
      DO owner=1,nOwner
        ip=ownerIp(owner)
        bi=ownerBi(owner)
        bj=ownerBj(owner)
        bomSpringEast(ip,bi,bj)=springEast(owner)
        bomSpringNorth(ip,bi,bj)=springNorth(owner)
        bomNeighborCount(ip,bi,bj)=ownerNeighbor(owner)
        bomRaftId(ip,bi,bj)=ownerRaftId(owner)
        bomRaftSize(ip,bi,bj)=ownerRaftSize(owner)
      ENDDO
      CALL BOM_GHOST_INVALIDATE
      CALL BOM_COMPONENT_INVALIDATE
      RETURN
      END
