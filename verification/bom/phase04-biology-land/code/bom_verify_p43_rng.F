#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P43_RNG( myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
#ifdef ALLOW_BOM
      INTEGER nBirth
      PARAMETER ( nBirth=13 )
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      INTEGER caseIndex,nFail,globalFail,failCode
      INTEGER seedCase(nBirth),birthCase(nBirth),attemptCase(nBirth)
      INTEGER*8 parentCase(nBirth),eventCase(nBirth)
      INTEGER*8 expectedWord(nBirth),expectedTheta(nBirth)
      INTEGER*8 counter(4),key(2),output(4),placementWord
      INTEGER*8 thetaBits,highWord,lowWord
      _RL theta
      LOGICAL isValid

      DATA seedCase /
     &  0,0,0,0,0,-1,0,0,0,0,0,0,324508639 /
      DATA parentCase /
     &  1_8,4294967295_8,4294967296_8,4294967297_8,
     &  9223372036854775807_8,1_8,1_8,1_8,1_8,1_8,
     &  1_8,1_8,4294967313_8 /
      DATA birthCase /
     &  0,0,0,0,0,0,2147483647,0,0,0,0,0,19 /
      DATA eventCase /
     &  0_8,0_8,0_8,0_8,0_8,0_8,0_8,4294967295_8,
     &  4294967296_8,9223372036854775807_8,0_8,0_8,
     &  4294967319_8 /
      DATA attemptCase /
     &  0,0,0,0,0,0,0,0,0,0,1,2147483647,7 /
      DATA expectedWord /
     &  4190644000_8,2787156614_8,308051156_8,
     &  3694036235_8,1095445230_8,1423354184_8,
     &  885408917_8,3022491160_8,189653080_8,
     &  2345006819_8,3087676103_8,3251901499_8,
     &  3296537124_8 /
      DATA expectedTheta /
     &  4618588425349381982_8,4616276742217409442_8,
     &  4601789873569421766_8,4617770463032792210_8,
     &  4609896047589822358_8,4611871230244926512_8,
     &  4608512244908851758_8,4616664361590255459_8,
     &  4598669659304556798_8,4614907337118590347_8,
     &  4616771727666142436_8,4617042223205725940_8,
     &  4617115742513720313_8 /

      nFail=0
      counter(1)=0_8
      counter(2)=0_8
      counter(3)=0_8
      counter(4)=0_8
      key(1)=0_8
      key(2)=0_8
      CALL BOM_PHILOX4X32(
     I     counter,key,
     O     output,failCode,isValid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     isValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &     output(1).EQ.1713891541_8 .AND.
     &     output(2).EQ.3781805453_8 .AND.
     &     output(3).EQ.3159862348_8 .AND.
     &     output(4).EQ.2600524760_8,
     &     'P4-RNG01 zero counter/key',nFail,myThid)

      counter(1)=4294967295_8
      counter(2)=4294967295_8
      counter(3)=4294967295_8
      counter(4)=4294967295_8
      key(1)=4294967295_8
      key(2)=4294967295_8
      CALL BOM_PHILOX4X32(
     I     counter,key,
     O     output,failCode,isValid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     isValid .AND. output(1).EQ.1083123565_8 .AND.
     &     output(2).EQ.1103641358_8 .AND.
     &     output(3).EQ.2718681030_8 .AND.
     &     output(4).EQ.1834242557_8,
     &     'P4-RNG01 maximum counter/key',nFail,myThid)

      CALL BOM_U32_MUL(
     I     4294967295_8,4294967295_8,
     O     highWord,lowWord,isValid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     isValid .AND. highWord.EQ.4294967294_8 .AND.
     &     lowWord.EQ.1_8,
     &     'P4-RNG01 16-bit limb multiply',nFail,myThid)

      DO caseIndex=1,nBirth
        CALL BOM_BIRTH_RANDOM(
     I       seedCase(caseIndex),parentCase(caseIndex),
     I       birthCase(caseIndex),eventCase(caseIndex),
     I       attemptCase(caseIndex),
     O       placementWord,theta,failCode,isValid)
        thetaBits=TRANSFER(theta,thetaBits)
        CALL BOM_VERIFY_P43_ASSERT(
     &       isValid .AND. failCode.EQ.BOM_FAIL_NONE .AND.
     &       placementWord.EQ.expectedWord(caseIndex) .AND.
     &       thetaBits.EQ.expectedTheta(caseIndex),
     &       'P4-RNG01 birth key fixture',nFail,myThid)
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I3,2I22)')
     &         'P43-RNG ',caseIndex,placementWord,thetaBits
          CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                       SQUEEZE_RIGHT,myThid)
        ENDIF
        _END_MASTER(myThid)
      ENDDO

C--   Invalid words and signed counter inputs fail closed.
      counter(1)=-1_8
      CALL BOM_PHILOX4X32(
     I     counter,key,
     O     output,failCode,isValid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     .NOT.isValid .AND. failCode.EQ.BOM_FAIL_BIRTH_RNG,
     &     'P4-RNG01 negative word rejection',nFail,myThid)
      CALL BOM_BIRTH_RANDOM(
     I     0,0_8,0,0_8,0,
     O     placementWord,theta,failCode,isValid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     .NOT.isValid .AND. failCode.EQ.BOM_FAIL_BIRTH_RNG,
     &     'P4-RNG01 zero parent rejection',nFail,myThid)
      CALL BOM_BIRTH_RANDOM(
     I     0,1_8,0,-1_8,0,
     O     placementWord,theta,failCode,isValid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     .NOT.isValid .AND. failCode.EQ.BOM_FAIL_BIRTH_RNG,
     &     'P4-RNG01 negative event rejection',nFail,myThid)
      CALL BOM_BIRTH_RANDOM(
     I     0,1_8,-1,0_8,0,
     O     placementWord,theta,failCode,isValid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     .NOT.isValid .AND. failCode.EQ.BOM_FAIL_BIRTH_RNG,
     &     'P4-RNG01 negative count rejection',nFail,myThid)
      CALL BOM_BIRTH_RANDOM(
     I     0,1_8,0,0_8,-1,
     O     placementWord,theta,failCode,isValid)
      CALL BOM_VERIFY_P43_ASSERT(
     &     .NOT.isValid .AND. failCode.EQ.BOM_FAIL_BIRTH_RNG,
     &     'P4-RNG01 negative attempt rejection',nFail,myThid)

      globalFail=nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.GT.0 ) THEN
        CALL BOM_VERIFY_P43_ABORT(
     &       'BOM_VERIFY_P43_RNG',globalFail,myThid)
      ENDIF
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P4-RNG01 PASS: exact Philox words and angles'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
      ENDIF
      _END_MASTER(myThid)
#endif
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P43_ASSERT(
     I     condition,label,
     U     nFail,
     I     myThid)
      IMPLICIT NONE
#include "EEPARAMS.h"
      LOGICAL condition
      CHARACTER*(*) label
      INTEGER nFail,myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      IF ( .NOT.condition ) THEN
        IF ( nFail.LT.16 ) THEN
          WRITE(msgBuf,'(A,A)') 'P4.3 assertion failed: ',label
          CALL PRINT_ERROR(msgBuf,myThid)
        ENDIF
        nFail=nFail+1
      ENDIF
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_P43_ABORT(routine,nFail,myThid)
      IMPLICIT NONE
#include "EEPARAMS.h"
      CHARACTER*(*) routine
      INTEGER nFail,myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A,A,A,I8)') 'P4.3 ',routine,
     &       ': failures=',nFail
        CALL PRINT_ERROR(msgBuf,myThid)
      ENDIF
      _END_MASTER(myThid)
      CALL ALL_PROC_DIE(0)
      STOP 'ABNORMAL END: P4.3 DIRECT GATE'
      END
