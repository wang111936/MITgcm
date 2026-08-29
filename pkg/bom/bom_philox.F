#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_U32_MUL
C !INTERFACE:
      SUBROUTINE BOM_U32_MUL(
     I                 valueA, valueB,
     O                 highWord, lowWord, isValid )

C !DESCRIPTION:
C     Multiply two unsigned 32-bit words using 16-bit limbs.  Every
C     intermediate fits a positive signed INTEGER*8 value.

      IMPLICIT NONE
      INTEGER*8 valueA,valueB,highWord,lowWord
      INTEGER*8 a0,a1,b0,b1,p0,p1,p2,p3,carry
      INTEGER*8 limbRadix,wordRadix,wordMaximum
      LOGICAL isValid

      limbRadix=65536_8
      wordRadix=4294967296_8
      wordMaximum=wordRadix-1_8
      highWord=0_8
      lowWord=0_8
      isValid=.FALSE.
      IF ( valueA.LT.0_8 .OR. valueA.GT.wordMaximum .OR.
     &     valueB.LT.0_8 .OR. valueB.GT.wordMaximum ) RETURN

      a0=MOD(valueA,limbRadix)
      a1=valueA/limbRadix
      b0=MOD(valueB,limbRadix)
      b1=valueB/limbRadix
      p0=a0*b0
      p1=a0*b1
      p2=a1*b0
      p3=a1*b1
      carry=p0/limbRadix+MOD(p1,limbRadix)
     &      +MOD(p2,limbRadix)
      lowWord=MOD(p0,limbRadix)
     &       +limbRadix*MOD(carry,limbRadix)
      highWord=MOD(p3+p1/limbRadix+p2/limbRadix
     &         +carry/limbRadix,wordRadix)
      IF ( lowWord.LT.0_8 .OR. lowWord.GT.wordMaximum .OR.
     &     highWord.LT.0_8 .OR. highWord.GT.wordMaximum ) THEN
        highWord=0_8
        lowWord=0_8
        RETURN
      ENDIF
      isValid=.TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_PHILOX4X32
C !INTERFACE:
      SUBROUTINE BOM_PHILOX4X32(
     I                 counterWord, keyWord,
     O                 outputWord, failCode, isValid )

C !DESCRIPTION:
C     Frozen ten-round Philox4x32 transform.  Input/output values are exact
C     unsigned words represented in positive INTEGER*8 values.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER*8 counterWord(4),keyWord(2),outputWord(4)
      INTEGER failCode,roundIndex,wordIndex
      LOGICAL isValid,mul0Valid,mul1Valid
      INTEGER*8 c0,c1,c2,c3,k0,k1,n0,n1,n2,n3
      INTEGER*8 hi0,lo0,hi1,lo1
      INTEGER*8 wordRadix,wordMaximum,m0,m1,w0,w1

      wordRadix=4294967296_8
      wordMaximum=wordRadix-1_8
      m0=3528531795_8
      m1=3449720151_8
      w0=2654435769_8
      w1=3144134277_8
      failCode=BOM_FAIL_BIRTH_RNG
      isValid=.FALSE.
      DO wordIndex=1,4
        outputWord(wordIndex)=0_8
        IF ( counterWord(wordIndex).LT.0_8 .OR.
     &       counterWord(wordIndex).GT.wordMaximum ) RETURN
      ENDDO
      DO wordIndex=1,2
        IF ( keyWord(wordIndex).LT.0_8 .OR.
     &       keyWord(wordIndex).GT.wordMaximum ) RETURN
      ENDDO

      c0=counterWord(1)
      c1=counterWord(2)
      c2=counterWord(3)
      c3=counterWord(4)
      k0=keyWord(1)
      k1=keyWord(2)
      DO roundIndex=1,10
        CALL BOM_U32_MUL(m0,c0,hi0,lo0,mul0Valid)
        CALL BOM_U32_MUL(m1,c2,hi1,lo1,mul1Valid)
        IF ( .NOT.mul0Valid .OR. .NOT.mul1Valid ) RETURN
        n0=IEOR(IEOR(hi1,c1),k0)
        n1=lo1
        n2=IEOR(IEOR(hi0,c3),k1)
        n3=lo0
        IF ( n0.LT.0_8 .OR. n0.GT.wordMaximum .OR.
     &       n1.LT.0_8 .OR. n1.GT.wordMaximum .OR.
     &       n2.LT.0_8 .OR. n2.GT.wordMaximum .OR.
     &       n3.LT.0_8 .OR. n3.GT.wordMaximum ) RETURN
        c0=n0
        c1=n1
        c2=n2
        c3=n3
        IF ( roundIndex.LT.10 ) THEN
          k0=MOD(k0+w0,wordRadix)
          k1=MOD(k1+w1,wordRadix)
        ENDIF
      ENDDO
      outputWord(1)=c0
      outputWord(2)=c1
      outputWord(3)=c2
      outputWord(4)=c3
      failCode=BOM_FAIL_NONE
      isValid=.TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_BIRTH_RANDOM
C !INTERFACE:
      SUBROUTINE BOM_BIRTH_RANDOM(
     I                 seed, parentId, parentBirthCount,
     I                 eventTimeIndex, attempt,
     O                 placementWord, theta, failCode, isValid )

C !DESCRIPTION:
C     Mix the frozen birth key in two Philox calls and return the first
C     placement word and its open-bin-centred angle in [0,2*pi).

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_IS_FINITE
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER seed,parentBirthCount,attempt,failCode
      INTEGER*8 parentId,eventTimeIndex,placementWord
      _RL theta
      LOGICAL isValid,callValid
      INTEGER*8 firstCounter(4),secondCounter(4)
      INTEGER*8 fixedKey(2),derivedWord(4),placementOutput(4)
      INTEGER*8 derivedKey(2),wordRadix,seedWord
      _RL unitValue,twoPi

      wordRadix=4294967296_8
      twoPi=6.28318530717958647692528676655900577 _d 0
      placementWord=0_8
      theta=0. _d 0
      failCode=BOM_FAIL_BIRTH_RNG
      isValid=.FALSE.
      IF ( parentId.LE.0_8 .OR. eventTimeIndex.LT.0_8 .OR.
     &     parentBirthCount.LT.0 .OR. attempt.LT.0 ) RETURN

      seedWord=MOD(INT(seed,8),wordRadix)
      IF ( seedWord.LT.0_8 ) seedWord=seedWord+wordRadix
      firstCounter(1)=MOD(parentId,wordRadix)
      firstCounter(2)=parentId/wordRadix
      firstCounter(3)=INT(parentBirthCount,8)
      firstCounter(4)=seedWord
      fixedKey(1)=0_8
      fixedKey(2)=0_8
      CALL BOM_PHILOX4X32(
     I     firstCounter,fixedKey,
     O     derivedWord,failCode,callValid)
      IF ( .NOT.callValid ) RETURN

      derivedKey(1)=derivedWord(1)
      derivedKey(2)=derivedWord(3)
      secondCounter(1)=MOD(eventTimeIndex,wordRadix)
      secondCounter(2)=eventTimeIndex/wordRadix
      secondCounter(3)=INT(attempt,8)
      secondCounter(4)=0_8
      CALL BOM_PHILOX4X32(
     I     secondCounter,derivedKey,
     O     placementOutput,failCode,callValid)
      IF ( .NOT.callValid ) RETURN

      placementWord=placementOutput(1)
      unitValue=(DBLE(placementWord)+halfRL)/DBLE(wordRadix)
      theta=twoPi*unitValue
      IF ( .NOT.IEEE_IS_FINITE(unitValue) .OR.
     &     .NOT.IEEE_IS_FINITE(theta) .OR.
     &     unitValue.LE.0. _d 0 .OR. unitValue.GE.oneRL .OR.
     &     theta.LT.0. _d 0 .OR. theta.GE.twoPi ) THEN
        placementWord=0_8
        theta=0. _d 0
        RETURN
      ENDIF
      failCode=BOM_FAIL_NONE
      isValid=.TRUE.
      RETURN
      END
