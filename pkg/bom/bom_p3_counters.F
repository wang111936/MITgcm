#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_P3_COUNTER_SNAPSHOT
C !INTERFACE:
      SUBROUTINE BOM_P3_COUNTER_SNAPSHOT(
     O                 localCounters, globalSums, globalMaxima,
     O                 failCode, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Snapshot the last committed local Phase-3 counters and form exact
C     global sums and maxima.  Outputs remain unchanged if validation or
C     reduction fails.  The integer-only reduction avoids MPI_INTEGER8.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER*8 localCounters(bomP3CounterFields)
      INTEGER*8 globalSums(bomP3CounterFields)
      INTEGER*8 globalMaxima(bomP3CounterFields)
      INTEGER failCode, myThid
      LOGICAL isValid
      INTEGER*8 localWork(bomP3CounterFields)
      INTEGER*8 sumWork(bomP3CounterFields)
      INTEGER*8 maximumWork(bomP3CounterFields)
      INTEGER field, reduceFail
      LOGICAL reduceValid
CEOP

      failCode = BOM_FAIL_CELL_CAPACITY
      isValid = .FALSE.
      localWork(BOM_P3_COUNT_OWNER) = bomP3OwnerRecords
      localWork(BOM_P3_COUNT_GHOST) = bomP3GhostRecords
      localWork(BOM_P3_COUNT_NONEMPTY) = bomP3NonEmptyCells
      localWork(BOM_P3_COUNT_COMPARISON) =
     &     bomP3CandidateComparisons
      localWork(BOM_P3_COUNT_DIRECTED) = bomP3DirectedNeighbors
      localWork(BOM_P3_COUNT_UNDIRECTED) = bomP3UndirectedEdges
      localWork(BOM_P3_COUNT_MAX_NEIGHBOR) =
     &     bomP3MaximumNeighbors
      localWork(BOM_P3_COUNT_REBUILD) = bomP3RebuildCount
      localWork(BOM_P3_COUNT_PACKET_SENT) =
     &     bomP3GhostPacketsSent
      localWork(BOM_P3_COUNT_PACKET_RECEIVED) =
     &     bomP3GhostPacketsReceived
      localWork(BOM_P3_COUNT_BYTE_SENT) = bomP3GhostBytesSent
      localWork(BOM_P3_COUNT_BYTE_RECEIVED) =
     &     bomP3GhostBytesReceived
      localWork(BOM_P3_COUNT_MAX_COMPONENT) =
     &     bomP3MaximumComponentSize
      localWork(BOM_P3_COUNT_COMPONENT_ITER) =
     &     bomP3ComponentIterations

      CALL BOM_P3_REDUCE_COUNTERS(
     I     localWork,
     O     sumWork,maximumWork,reduceFail,reduceValid,myThid)
      IF ( .NOT.reduceValid ) THEN
        failCode = reduceFail
        RETURN
      ENDIF
      DO field=1,bomP3CounterFields
        localCounters(field) = localWork(field)
        globalSums(field) = sumWork(field)
        globalMaxima(field) = maximumWork(field)
      ENDDO
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_P3_REDUCE_COUNTERS
C !INTERFACE:
      SUBROUTINE BOM_P3_REDUCE_COUNTERS(
     I                 localCounters,
     O                 globalSums, globalMaxima,
     O                 failCode, isValid,
     I                 myThid )

C !DESCRIPTION:
C     Reduce non-negative signed 64-bit counters without a non-portable MPI
C     64-bit datatype.  Five base-32768 digits cover the signed 64-bit range.
C     Digit sums are carry-normalized with overflow checks; maxima use an
C     exact most-significant-digit eligibility reduction.  The global sum is
C     total rank work.  The global maximum is the per-rank high-water mark.

      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "EESUPPORT.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER*8 localCounters(bomP3CounterFields)
      INTEGER*8 globalSums(bomP3CounterFields)
      INTEGER*8 globalMaxima(bomP3CounterFields)
      INTEGER failCode, myThid
      LOGICAL isValid
      INTEGER digitLocal(bomP3CounterDigits,bomP3CounterFields)
      INTEGER digitSum(bomP3CounterDigits,bomP3CounterFields)
      INTEGER digitNorm(bomP3CounterDigits,bomP3CounterFields)
      INTEGER digitMaximum(bomP3CounterDigits,bomP3CounterFields)
      INTEGER maximumSend(bomP3CounterFields)
      INTEGER maximumReceive(bomP3CounterFields)
      INTEGER eligible(bomP3CounterFields)
      INTEGER field, digit, localErr, globalErr
      INTEGER*8 value8, base8, carry8, total8
      INTEGER*8 sumWork(bomP3CounterFields)
      INTEGER*8 maximumWork(bomP3CounterFields)
#ifdef ALLOW_USE_MPI
      INTEGER mpiRC
#endif
CEOP

      failCode = BOM_FAIL_CELL_CAPACITY
      isValid = .FALSE.
      base8 = 32768_8
      localErr = 0
      IF ( bomP3CounterDigits.NE.5 .OR.
     &     bomP3CounterFields.NE.14 .OR.
     &     nPx*nPy.LT.1 .OR.
     &     nPx*nPy.GT.HUGE(localErr)/32767 ) localErr=localErr+1
      DO field=1,bomP3CounterFields
        IF ( localCounters(field).LT.0_8 ) localErr=localErr+1
        value8 = MAX(0_8,localCounters(field))
        DO digit=1,bomP3CounterDigits
          digitLocal(digit,field) = INT(MOD(value8,base8))
          value8 = value8/base8
        ENDDO
        IF ( value8.NE.0_8 ) localErr=localErr+1
      ENDDO
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN

      IF ( nPx*nPy.EQ.1 ) THEN
        DO field=1,bomP3CounterFields
          globalSums(field) = localCounters(field)
          globalMaxima(field) = localCounters(field)
        ENDDO
        failCode = BOM_FAIL_NONE
        isValid = .TRUE.
        RETURN
      ENDIF

#ifndef ALLOW_USE_MPI
      RETURN
#else
      IF ( .NOT.usingMPI ) RETURN
      CALL MPI_Allreduce(
     I     digitLocal,digitSum,
     I     bomP3CounterDigits*bomP3CounterFields,
     I     MPI_INTEGER,MPI_SUM,
     I     MPI_COMM_MODEL,mpiRC)
      IF ( mpiRC.NE.MPI_SUCCESS ) localErr=localErr+1

      DO field=1,bomP3CounterFields
        eligible(field) = 1
      ENDDO
      DO digit=bomP3CounterDigits,1,-1
        DO field=1,bomP3CounterFields
          maximumSend(field) = -1
          IF ( eligible(field).EQ.1 )
     &         maximumSend(field)=digitLocal(digit,field)
        ENDDO
        CALL MPI_Allreduce(
     I       maximumSend,maximumReceive,bomP3CounterFields,
     I       MPI_INTEGER,MPI_MAX,
     I       MPI_COMM_MODEL,mpiRC)
        IF ( mpiRC.NE.MPI_SUCCESS ) localErr=localErr+1
        DO field=1,bomP3CounterFields
          digitMaximum(digit,field) = maximumReceive(field)
          IF ( digitLocal(digit,field).NE.maximumReceive(field) )
     &         eligible(field)=0
        ENDDO
      ENDDO

      DO field=1,bomP3CounterFields
        carry8 = 0_8
        DO digit=1,bomP3CounterDigits
          total8 = INT(digitSum(digit,field),8)+carry8
          digitNorm(digit,field) = INT(MOD(total8,base8))
          carry8 = total8/base8
        ENDDO
        IF ( carry8.NE.0_8 ) localErr=localErr+1
        value8 = 0_8
        DO digit=bomP3CounterDigits,1,-1
          IF ( value8.GT.
     &         (HUGE(value8)-digitNorm(digit,field))/base8 ) THEN
            localErr = localErr+1
          ELSE
            value8 = value8*base8+digitNorm(digit,field)
          ENDIF
        ENDDO
        sumWork(field) = value8
        value8 = 0_8
        DO digit=bomP3CounterDigits,1,-1
          IF ( digitMaximum(digit,field).LT.0 .OR.
     &         value8.GT.(HUGE(value8)-
     &         digitMaximum(digit,field))/base8 ) THEN
            localErr = localErr+1
          ELSE
            value8 = value8*base8+digitMaximum(digit,field)
          ENDIF
        ENDDO
        maximumWork(field) = value8
      ENDDO
      globalErr = localErr
      CALL GLOBAL_SUM_INT(globalErr,myThid)
      IF ( globalErr.GT.0 ) RETURN
      DO field=1,bomP3CounterFields
        globalSums(field) = sumWork(field)
        globalMaxima(field) = maximumWork(field)
      ENDDO
      failCode = BOM_FAIL_NONE
      isValid = .TRUE.
#endif /* ALLOW_USE_MPI */
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
