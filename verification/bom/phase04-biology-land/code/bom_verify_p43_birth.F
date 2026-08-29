#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P43_BIRTH( myThid )
      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_VALUE,IEEE_QUIET_NAN
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER bi,bj,ip,jp,i,j,iCell,jCell,nFail,globalFail
      INTEGER eventType,destRank,destBi,destBj,attemptUsed
      INTEGER failCode,p4Phase,failRank,failBi,failBj,failSlot
      INTEGER nLocal,nGlobal,nRank,parentIndex,ownerRank,ownerBi
      INTEGER ownerBj,hop
      INTEGER localBi(bomMaxEventBuffer)
      INTEGER localBj(bomMaxEventBuffer)
      INTEGER localSlot(bomMaxEventBuffer)
      INTEGER localOrdinal(bomMaxEventBuffer)
      INTEGER localBirthCount(bomMaxEventBuffer)
      INTEGER localAttempt(bomMaxEventBuffer)
      INTEGER localDestRank(bomMaxEventBuffer)
      INTEGER localDestBi(bomMaxEventBuffer)
      INTEGER localDestBj(bomMaxEventBuffer)
      INTEGER globalBirthCount(bomMaxEventBuffer)
      INTEGER globalAttempt(bomMaxEventBuffer)
      INTEGER globalSourceRank(bomMaxEventBuffer)
      INTEGER globalSourceBi(bomMaxEventBuffer)
      INTEGER globalSourceBj(bomMaxEventBuffer)
      INTEGER globalSourceSlot(bomMaxEventBuffer)
      INTEGER globalDestRank(bomMaxEventBuffer)
      INTEGER globalDestBi(bomMaxEventBuffer)
      INTEGER globalDestBj(bomMaxEventBuffer)
      INTEGER*8 parentId,eventIndex,placementWord,failId
      INTEGER*8 localParentId(bomMaxEventBuffer)
      INTEGER*8 localEventIndex(bomMaxEventBuffer)
      INTEGER*8 localChildId(bomMaxEventBuffer)
      INTEGER*8 globalParentId(bomMaxEventBuffer)
      INTEGER*8 globalChildId(bomMaxEventBuffer)
      INTEGER*8 globalEventIndex(bomMaxEventBuffer)
      INTEGER*8 nextIdAfter
      _RL parentX,parentY,childX,childY,childI,childJ
      _RL firstX,firstY,angle,savedSpring,savedPeriod,xOwner,yOwner
      _RL localX(bomMaxEventBuffer),localY(bomMaxEventBuffer)
      _RL globalX(bomMaxEventBuffer),globalY(bomMaxEventBuffer)
      _RS savedMask(1-OLx:sNx+OLx,1-OLy:sNy+OLy)
      LOGICAL isValid,locateValid,savedPeriodic
      LOGICAL savedCartesian,savedSpherical
      INTEGER*8 orderedParent(4)
      DATA orderedParent / 40_8,10_8,30_8,20_8 /

      nFail=0
      nRank=nPx*nPy
      bomMetricReady=.TRUE.
      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          bomMetricValid(i,j,bi,bj)=
     &         maskC(i,j,1,bi,bj).GT.0.
         ENDDO
        ENDDO
       ENDDO
      ENDDO

C--   Placement fixtures run on rank zero; the ordering fixtures below are
C     collective and use all ranks.
      IF ( myProcId.EQ.0 ) THEN
        bi=myBxLo(myThid)
        bj=myByLo(myThid)
        parentX=DBLE(xC(2,2,bi,bj))
        parentY=DBLE(yC(2,2,bi,bj))
        parentId=1_8
        eventIndex=0_8
        savedSpring=bomSpringL
        bomSpringL=100. _d 0
        CALL BOM_BIRTH_PLACE(
     I       parentX,parentY,bi,bj,parentId,0,eventIndex,
     O       childX,childY,childI,childJ,firstX,firstY,
     O       placementWord,angle,attemptUsed,eventType,
     O       destRank,destBi,destBj,failCode,p4Phase,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       isValid .AND. eventType.EQ.BOM_EVENT_BIRTH .AND.
     &       attemptUsed.EQ.0 .AND. failCode.EQ.BOM_FAIL_NONE,
     &       'P4-BR01 attempt-zero wet success',nFail,myThid)

C--     Make only the exact first candidate cell dry; a later deterministic
C       retry must win without changing the recorded first attempt.
        bomSpringL=900. _d 0
        CALL BOM_BIRTH_PLACE(
     I       parentX,parentY,bi,bj,parentId,0,eventIndex,
     O       childX,childY,childI,childJ,firstX,firstY,
     O       placementWord,angle,attemptUsed,eventType,
     O       destRank,destBi,destBj,failCode,p4Phase,isValid,
     I       myThid)
        iCell=INT(childI+halfRL)
        IF ( DFLOAT(iCell).GT.childI+halfRL ) iCell=iCell-1
        jCell=INT(childJ+halfRL)
        IF ( DFLOAT(jCell).GT.childJ+halfRL ) jCell=jCell-1
        IF ( iCell.GE.1-OLx .AND. iCell.LE.sNx+OLx .AND.
     &       jCell.GE.1-OLy .AND. jCell.LE.sNy+OLy ) THEN
          savedMask(iCell,jCell)=maskC(iCell,jCell,1,bi,bj)
          maskC(iCell,jCell,1,bi,bj)=0.
          CALL BOM_BIRTH_PLACE(
     I         parentX,parentY,bi,bj,parentId,0,eventIndex,
     O         childX,childY,childI,childJ,firstX,firstY,
     O         placementWord,angle,attemptUsed,eventType,
     O         destRank,destBi,destBj,failCode,p4Phase,isValid,
     I         myThid)
          CALL BOM_VERIFY_P43_ASSERT(
     &         isValid .AND. eventType.EQ.BOM_EVENT_BIRTH .AND.
     &         attemptUsed.GT.0 .AND. failCode.EQ.BOM_FAIL_NONE,
     &         'P4-BR01 land then success',nFail,myThid)
          maskC(iCell,jCell,1,bi,bj)=savedMask(iCell,jCell)
        ELSE
          CALL BOM_VERIFY_P43_ASSERT(
     &         .FALSE.,'P4-BR01 first-cell fixture',nFail,myThid)
        ENDIF

C--     A fully dry local support consumes every retry and cancels without
C       allocating an ID.
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          savedMask(i,j)=maskC(i,j,1,bi,bj)
          maskC(i,j,1,bi,bj)=0.
         ENDDO
        ENDDO
        CALL BOM_BIRTH_PLACE(
     I       parentX,parentY,bi,bj,parentId,0,eventIndex,
     O       childX,childY,childI,childJ,firstX,firstY,
     O       placementWord,angle,attemptUsed,eventType,
     O       destRank,destBi,destBj,failCode,p4Phase,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       isValid .AND. eventType.EQ.BOM_EVENT_BIRTH_CANCEL
     &       .AND. attemptUsed.EQ.bomBirthMaxTry .AND.
     &       failCode.EQ.BOM_FAIL_NONE,
     &       'P4-BR01 all-invalid cancellation',nFail,myThid)
        DO j=1-OLy,sNy+OLy
         DO i=1-OLx,sNx+OLx
          maskC(i,j,1,bi,bj)=savedMask(i,j)
         ENDDO
        ENDDO

        CALL BOM_BIRTH_PLACE(
     I       IEEE_VALUE(parentX,IEEE_QUIET_NAN),parentY,
     I       bi,bj,parentId,0,eventIndex,
     O       childX,childY,childI,childJ,firstX,firstY,
     O       placementWord,angle,attemptUsed,eventType,
     O       destRank,destBi,destBj,failCode,p4Phase,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       .NOT.isValid .AND. failCode.EQ.BOM_FAIL_NONFINITE .AND.
     &       p4Phase.EQ.BOM_P4_PHASE_BIRTH_PLACE,
     &       'P4-BR01 nonfinite fatal',nFail,myThid)

C--     The spherical midpoint metric fails closed near its polar limit.
        savedCartesian=usingCartesianGrid
        savedSpherical=usingSphericalPolarGrid
        usingCartesianGrid=.FALSE.
        usingSphericalPolarGrid=.TRUE.
        bomSpringL=1. _d -3
        CALL BOM_BIRTH_PLACE(
     I       0. _d 0,90. _d 0,bi,bj,parentId,0,eventIndex,
     O       childX,childY,childI,childJ,firstX,firstY,
     O       placementWord,angle,attemptUsed,eventType,
     O       destRank,destBi,destBj,failCode,p4Phase,isValid,
     I       myThid)
        CALL BOM_VERIFY_P43_ASSERT(
     &       .NOT.isValid .AND. failCode.EQ.BOM_FAIL_METRIC,
     &       'P4-BR01 spherical metric limit',nFail,myThid)
        usingCartesianGrid=savedCartesian
        usingSphericalPolarGrid=savedSpherical
        bomSpringL=900. _d 0

C--     Serial exercises a nonperiodic outside retry and periodic seam.
        IF ( nRank.EQ.1 ) THEN
          parentX=bomMapXLo+100. _d 0
          parentY=0. _d 0
          CALL BOM_LOCATE_OWNER(
     I         parentX,parentY,bi,bj,
     O         xOwner,yOwner,ownerRank,ownerBi,ownerBj,
     O         hop,locateValid,myThid)
          CALL BOM_VERIFY_P43_ASSERT(
     &         locateValid .AND. ownerRank.EQ.0,
     &         'P4-BR01 boundary parent owner',nFail,myThid)
          IF ( locateValid ) THEN
            savedPeriodic=bomMapPeriodicX
            bomMapPeriodicX=.FALSE.
            CALL BOM_BIRTH_PLACE(
     I           parentX,parentY,ownerBi,ownerBj,
     I           parentId,0,eventIndex,
     O           childX,childY,childI,childJ,firstX,firstY,
     O           placementWord,angle,attemptUsed,eventType,
     O           destRank,destBi,destBj,failCode,p4Phase,isValid,
     I           myThid)
            WRITE(msgBuf,'(A,L2,3I5,3(1X,1PE18.10))')
     &           'P43-PLACE OUTSIDE ',isValid,eventType,attemptUsed,
     &           failCode,firstX,childX,childY
            CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                         SQUEEZE_RIGHT,myThid)
            CALL BOM_VERIFY_P43_ASSERT(
     &           isValid .AND. eventType.EQ.BOM_EVENT_BIRTH .AND.
     &           attemptUsed.GT.0 .AND. firstX.LT.bomMapXLo,
     &           'P4-BR01 outside then success',nFail,myThid)
            bomMapPeriodicX=.TRUE.
            savedPeriod=bomMapXPeriod
            bomMapXPeriod=bomMapXHi-bomMapXLo
            CALL BOM_BIRTH_PLACE(
     I           parentX,parentY,ownerBi,ownerBj,
     I           parentId,0,eventIndex,
     O           childX,childY,childI,childJ,firstX,firstY,
     O           placementWord,angle,attemptUsed,eventType,
     O           destRank,destBi,destBj,failCode,p4Phase,isValid,
     I           myThid)
            WRITE(msgBuf,'(A,L2,3I5,3(1X,1PE18.10))')
     &           'P43-PLACE PERIODIC ',isValid,eventType,
     &           attemptUsed,failCode,firstX,childX,childY
            CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                         SQUEEZE_RIGHT,myThid)
            CALL BOM_VERIFY_P43_ASSERT(
     &           isValid .AND. eventType.EQ.BOM_EVENT_BIRTH .AND.
     &           attemptUsed.EQ.0 .AND. childX.LT.bomMapXHi,
     &           'P4-BR01 periodic seam success',nFail,myThid)
            bomMapPeriodicX=savedPeriodic
            bomMapXPeriod=savedPeriod
          ENDIF
        ENDIF
        bomSpringL=savedSpring
      ENDIF

C--   The same four parent events are distributed differently in serial,
C     MPI2 and MPI4, while the canonical order and child IDs remain exact.
      nLocal=0
      DO parentIndex=1,4
        IF ( MOD(parentIndex-1,nRank).EQ.myProcId ) THEN
          nLocal=nLocal+1
          localParentId(nLocal)=orderedParent(parentIndex)
          localBi(nLocal)=myBxLo(myThid)
          localBj(nLocal)=myByLo(myThid)
          localSlot(nLocal)=nLocal
          localBirthCount(nLocal)=parentIndex
          localEventIndex(nLocal)=5_8
          localAttempt(nLocal)=MOD(parentIndex,MAX(1,bomBirthMaxTry))
          localDestRank(nLocal)=0
          localDestBi(nLocal)=1
          localDestBj(nLocal)=1
          localX(nLocal)=10. _d 0*DFLOAT(parentIndex)
          localY(nLocal)=-10. _d 0*DFLOAT(parentIndex)
        ENDIF
      ENDDO
      CALL BOM_BIRTH_PARENT_ORDER(
     I     nLocal,localParentId,localBi,localBj,localSlot,
     O     localOrdinal,nGlobal,failCode,p4Phase,failRank,
     O     failBi,failBj,failSlot,failId,isValid,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     isValid .AND. nGlobal.EQ.4,
     &     'P4-ID01 global prospective count',nFail,myThid)
      DO ip=1,nLocal
        CALL BOM_VERIFY_P43_ASSERT(
     &       localOrdinal(ip).EQ.INT(localParentId(ip)/10_8),
     &       'P4-ID01 exact parent order',nFail,myThid)
      ENDDO

      bomEventTimeIndex=5_8
      CALL BOM_BIRTH_ACCEPT_ORDER(
     I     nLocal,localParentId,localBirthCount,
     I     localEventIndex,localAttempt,localBi,localBj,localSlot,
     I     localDestRank,localDestBi,localDestBj,
     I     localX,localY,1000_8,
     O     localChildId,nGlobal,globalParentId,globalChildId,
     O     globalBirthCount,globalEventIndex,globalAttempt,
     O     globalSourceRank,globalSourceBi,globalSourceBj,
     O     globalSourceSlot,globalDestRank,globalDestBi,globalDestBj,
     O     globalX,globalY,nextIdAfter,
     O     failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O     failId,isValid,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     isValid .AND. nGlobal.EQ.4 .AND.
     &     nextIdAfter.EQ.1004_8,
     &     'P4-ID01 contiguous next ID',nFail,myThid)
      DO ip=1,4
        CALL BOM_VERIFY_P43_ASSERT(
     &       globalParentId(ip).EQ.INT(10*ip,8) .AND.
     &       globalChildId(ip).EQ.999_8+INT(ip,8),
     &       'P4-ID01 canonical child IDs',nFail,myThid)
      ENDDO
      DO ip=1,nLocal
        jp=INT(localParentId(ip)/10_8)
        CALL BOM_VERIFY_P43_ASSERT(
     &       localChildId(ip).EQ.999_8+INT(jp,8),
     &       'P4-ID01 local child binding',nFail,myThid)
      ENDDO

C--   Duplicate parents and signed-64-bit allocation overflow fail without
C     changing the supplied next-ID value.
      nLocal=0
      IF ( myProcId.EQ.0 ) THEN
        nLocal=2
        DO ip=1,2
          localParentId(ip)=55_8
          localBi(ip)=1
          localBj(ip)=1
          localSlot(ip)=ip
        ENDDO
      ENDIF
      CALL BOM_BIRTH_PARENT_ORDER(
     I     nLocal,localParentId,localBi,localBj,localSlot,
     O     localOrdinal,nGlobal,failCode,p4Phase,failRank,
     O     failBi,failBj,failSlot,failId,isValid,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     .NOT.isValid .AND. failCode.EQ.BOM_FAIL_BIRTH_ID,
     &     'P4-ID01 duplicate parent rejection',nFail,myThid)

      nLocal=0
      DO parentIndex=1,4
        IF ( MOD(parentIndex-1,nRank).EQ.myProcId ) THEN
          nLocal=nLocal+1
          localParentId(nLocal)=orderedParent(parentIndex)
          localBi(nLocal)=myBxLo(myThid)
          localBj(nLocal)=myByLo(myThid)
          localSlot(nLocal)=nLocal
          localBirthCount(nLocal)=parentIndex
          localEventIndex(nLocal)=5_8
          localAttempt(nLocal)=0
          localDestRank(nLocal)=0
          localDestBi(nLocal)=1
          localDestBj(nLocal)=1
          localX(nLocal)=DFLOAT(parentIndex)
          localY(nLocal)=-DFLOAT(parentIndex)
        ENDIF
      ENDDO
      CALL BOM_BIRTH_ACCEPT_ORDER(
     I     nLocal,localParentId,localBirthCount,
     I     localEventIndex,localAttempt,localBi,localBj,localSlot,
     I     localDestRank,localDestBi,localDestBj,
     I     localX,localY,HUGE(nextIdAfter)-2_8,
     O     localChildId,nGlobal,globalParentId,globalChildId,
     O     globalBirthCount,globalEventIndex,globalAttempt,
     O     globalSourceRank,globalSourceBi,globalSourceBj,
     O     globalSourceSlot,globalDestRank,globalDestBi,globalDestBj,
     O     globalX,globalY,nextIdAfter,
     O     failCode,p4Phase,failRank,failBi,failBj,failSlot,
     O     failId,isValid,myThid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     .NOT.isValid .AND. failCode.EQ.BOM_FAIL_BIRTH_ID .AND.
     &     nextIdAfter.EQ.HUGE(nextIdAfter)-2_8,
     &     'P4-ID01 signed overflow rejection',nFail,myThid)

      globalFail=nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.GT.0 ) CALL BOM_VERIFY_P43_ABORT(
     &     'BOM_VERIFY_P43_BIRTH',globalFail,myThid)
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P4-BR01/P4-ID01 PASS: retry, order and IDs'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
      ENDIF
      _END_MASTER(myThid)
#endif
      RETURN
      END
