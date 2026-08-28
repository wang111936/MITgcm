#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_REFERENCE_LAWS( myThid )

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_VALUE, IEEE_QUIET_NAN, IEEE_POSITIVE_INF
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid

#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      _RL dEast, dNorth, distance, dEastSwap, dNorthSwap, dSwap
      _RL velocityEast, velocityNorth, stiffness
      _RL velocityEast2, velocityNorth2, stiffness2
      _RL expected, tolerance, piValue, nanValue, infValue
      _RL hugeValue, resultEast, resultNorth
      _RL geomEastRecord, geomNorthRecord, geomDistanceRecord
      _RL ebombStiffRecord, ebombExpectedRecord, ebombTolRecord
      _RL rk2Coarse, rk2Fine, rk4Coarse, rk4Fine, exactDistance
      _RL error2Coarse, error2Fine, error4Coarse, error4Fine
      INTEGER failCode, globalFail, nFail, negativeCount
      LOGICAL valid, valid2, valid3, valid4

      nFail = 0
      negativeCount = 0
      nanValue = IEEE_VALUE(oneRL,IEEE_QUIET_NAN)
      infValue = IEEE_VALUE(oneRL,IEEE_POSITIVE_INF)
      hugeValue = HUGE(oneRL)
      piValue = 4. _d 0*ATAN(oneRL)

C--   C01: defaults and all stable numeric values.
      CALL BOM_P31_ASSERT(
     &     bomSpringLaw.EQ.'NONE' .AND.
     &     bomNeighborPolicy.EQ.'NONE' .AND.
     &     bomSpringL.EQ.0. _d 0 .AND.
     &     bomHookeK.EQ.0. _d 0 .AND.
     &     bomSpringA.EQ.0. _d 0 .AND.
     &     bomSpringDelta.EQ.0. _d 0 .AND.
     &     bomNeighborCutoff.EQ.0. _d 0 .AND.
     &     bomPairDistanceMin.EQ.0. _d 0 .AND.
     &     bomSpringCFL.EQ.0.5 _d 0 .AND.
     &     .NOT.bomRaftDiagnostics,
     &     'C01 inactive defaults',nFail,myThid)
      CALL BOM_P31_ASSERT(
     &     BOM_FAIL_NONE.EQ.0 .AND. BOM_FAIL_MAP.EQ.1 .AND.
     &     BOM_FAIL_OWNER.EQ.2 .AND. BOM_FAIL_STENCIL.EQ.3 .AND.
     &     BOM_FAIL_INTERP.EQ.4 .AND. BOM_FAIL_NONFINITE.EQ.5 .AND.
     &     BOM_FAIL_CFL.EQ.6 .AND. BOM_FAIL_STATE.EQ.7 .AND.
     &     BOM_FAIL_RELEASE.EQ.8 .AND. BOM_FAIL_FIELD_TIME.EQ.9
     &     .AND. BOM_FAIL_FIELD_SOURCE.EQ.10
     &     .AND. BOM_FAIL_METRIC.EQ.11
     &     .AND. BOM_FAIL_GRADIENT.EQ.12
     &     .AND. BOM_FAIL_EQUATION.EQ.13
     &     .AND. BOM_FAIL_STOKES_DUPLICATE.EQ.14
     &     .AND. BOM_FAIL_PICKUP_SCHEMA.EQ.15,
     &     'C01 old failure codes unchanged',nFail,myThid)
      CALL BOM_P31_ASSERT(
     &     bomInitialSchema.EQ.1 .AND. bomInitialFields.EQ.8
     &     .AND. bomOutputSchema.EQ.1 .AND. bomOutputFields.EQ.24
     &     .AND. bomOutputSchema2.EQ.2 .AND. bomOutputFields2.EQ.48
     &     .AND. bomPickupSchema.EQ.1 .AND. bomPickupFields.EQ.24
     &     .AND. bomPickupFields2.EQ.45
     &     .AND. bomPickupSigFields.EQ.16
     &     .AND. bomPickupSchema2.EQ.2
     &     .AND. bomPickup2SigBase.EQ.53
     &     .AND. bomPickupEnvHeader.EQ.12
     &     .AND. bomPickupChunkFields.EQ.24,
     &     'C01 schema-1/schema-2 codes unchanged',nFail,myThid)
      CALL BOM_P31_ASSERT(
     &     BOM_FAIL_NEIGHBOR_CONFIG.EQ.16
     &     .AND. BOM_FAIL_PAIR_GEOMETRY.EQ.17
     &     .AND. BOM_FAIL_CELL_CAPACITY.EQ.18
     &     .AND. BOM_FAIL_GHOST_CAPACITY.EQ.19
     &     .AND. BOM_FAIL_NEIGHBOR_CAPACITY.EQ.20
     &     .AND. BOM_FAIL_GHOST_PACKET.EQ.21
     &     .AND. BOM_FAIL_SPRING_LAW.EQ.22
     &     .AND. BOM_FAIL_SPRING_CFL.EQ.23
     &     .AND. BOM_FAIL_COMPONENT.EQ.24
     &     .AND. BOM_FAIL_PICKUP_SCHEMA3.EQ.25,
     &     'C01 Phase-3 failure codes',nFail,myThid)
      CALL BOM_P31_ASSERT(
     &     BOM_STAGE_NONE.EQ.0 .AND. BOM_STAGE_K1.EQ.1
     &     .AND. BOM_STAGE_K2.EQ.2 .AND. BOM_STAGE_K3.EQ.3
     &     .AND. BOM_STAGE_K4.EQ.4 .AND. BOM_STAGE_FINAL.EQ.5
     &     .AND. BOM_STAGE_FIELD_OLD.EQ.6
     &     .AND. BOM_STAGE_FIELD_NEW.EQ.7
     &     .AND. BOM_STAGE_DERIVATIVE.EQ.8
     &     .AND. BOM_P3_PHASE_NONE.EQ.0
     &     .AND. BOM_P3_PHASE_POSITION.EQ.1
     &     .AND. BOM_P3_PHASE_GHOST.EQ.2
     &     .AND. BOM_P3_PHASE_CELL.EQ.3
     &     .AND. BOM_P3_PHASE_NEIGHBOR.EQ.4
     &     .AND. BOM_P3_PHASE_SPRING.EQ.5
     &     .AND. BOM_P3_PHASE_BASE_RHS.EQ.6
     &     .AND. BOM_P3_PHASE_NATIVE_RATE.EQ.7
     &     .AND. BOM_P3_PHASE_COMPONENT.EQ.8
     &     .AND. BOM_P3_PHASE_SCHEMA3.EQ.9,
     &     'C01 stage and Phase-3 phase codes',nFail,myThid)

      CALL BOM_VALIDATE_SPRING_CONFIG(
     I     'BOM','HOOKE','CUTOFF',1000. _d 0,2. _d -4,
     I     0. _d 0,0. _d 0,9000. _d 0,1. _d -6,0.5 _d 0,
     I     .FALSE.,.FALSE.,0. _d 0,
     O     failCode,valid)
      CALL BOM_P31_ASSERT(valid .AND. failCode.EQ.BOM_FAIL_NONE,
     &     'C01 legal Hooke SI row',nFail,myThid)
      CALL BOM_VALIDATE_SPRING_CONFIG(
     I     'BOM','EBOMB','CUTOFF',1000. _d 0,0. _d 0,
     I     3. _d -4,200. _d 0,3600. _d 0,1. _d -6,0.4 _d 0,
     I     .TRUE.,.TRUE.,20000000. _d 0,
     O     failCode,valid)
      CALL BOM_P31_ASSERT(valid .AND. failCode.EQ.BOM_FAIL_NONE,
     &     'C01 legal eBOMB SI row',nFail,myThid)

      CALL BOM_P31_CONFIG_NEGATIVES(
     I     nanValue,
     U     nFail,negativeCount,myThid)

C--   D01 Cartesian axis/diagonal and canonical call-order invariance.
      CALL BOM_PAIR_GEOMETRY(
     I     100_8,0. _d 0,0. _d 0,900_8,3. _d 0,4. _d 0,
     I     .TRUE.,.FALSE.,.FALSE.,-10. _d 0,10. _d 0,
     I     -10. _d 0,10. _d 0,0. _d 0,0. _d 0,1. _d -12,
     O     dEast,dNorth,distance,failCode,valid)
      CALL BOM_PAIR_GEOMETRY(
     I     900_8,3. _d 0,4. _d 0,100_8,0. _d 0,0. _d 0,
     I     .TRUE.,.FALSE.,.FALSE.,-10. _d 0,10. _d 0,
     I     -10. _d 0,10. _d 0,0. _d 0,0. _d 0,1. _d -12,
     O     dEastSwap,dNorthSwap,dSwap,failCode,valid2)
      CALL BOM_P31_ASSERT(valid .AND. valid2
     &     .AND. dEast.EQ.3. _d 0 .AND. dNorth.EQ.4. _d 0
     &     .AND. distance.EQ.5. _d 0
     &     .AND. TRANSFER(dEast,0_8).EQ.TRANSFER(dEastSwap,0_8)
     &     .AND. TRANSFER(dNorth,0_8).EQ.TRANSFER(dNorthSwap,0_8)
     &     .AND. TRANSFER(distance,0_8).EQ.TRANSFER(dSwap,0_8),
     &     'D01 Cartesian canonical geometry',nFail,myThid)
      geomEastRecord = dEast
      geomNorthRecord = dNorth
      geomDistanceRecord = distance

C--   Periodic shortest image and exact half-period ambiguity.
      CALL BOM_PAIR_GEOMETRY(
     I     42_8,359. _d 0,0. _d 0,9001_8,1. _d 0,0. _d 0,
     I     .TRUE.,.FALSE.,.TRUE.,0. _d 0,360. _d 0,
     I     -10. _d 0,10. _d 0,360. _d 0,0. _d 0,1. _d -12,
     O     dEast,dNorth,distance,failCode,valid)
      CALL BOM_P31_ASSERT(valid .AND. dEast.EQ.2. _d 0
     &     .AND. dNorth.EQ.0. _d 0 .AND. distance.EQ.2. _d 0,
     &     'D01 periodic shortest image',nFail,myThid)
      CALL BOM_PAIR_GEOMETRY(
     I     42_8,1. _d 0,0. _d 0,9001_8,359. _d 0,0. _d 0,
     I     .TRUE.,.FALSE.,.TRUE.,0. _d 0,360. _d 0,
     I     -10. _d 0,10. _d 0,360. _d 0,0. _d 0,1. _d -12,
     O     dEast,dNorth,distance,failCode,valid)
      CALL BOM_P31_ASSERT(valid .AND. dEast.EQ.-2. _d 0
     &     .AND. dNorth.EQ.0. _d 0 .AND. distance.EQ.2. _d 0,
     &     'D01 periodic shortest image opposite side',nFail,myThid)
      CALL BOM_PAIR_GEOMETRY(
     I     42_8,-359. _d 0,0. _d 0,
     I     9001_8,721. _d 0,1. _d 0,
     I     .TRUE.,.FALSE.,.TRUE.,0. _d 0,360. _d 0,
     I     -10. _d 0,10. _d 0,360. _d 0,0. _d 0,1. _d -12,
     O     dEast,dNorth,distance,failCode,valid)
      CALL BOM_P31_ASSERT(valid .AND. dEast.EQ.0. _d 0
     &     .AND. dNorth.EQ.1. _d 0 .AND. distance.EQ.1. _d 0,
     &     'D01 periodic multi-period normalization',nFail,myThid)
      CALL BOM_P31_SET_GEOM_SENTINEL(dEast,dNorth,distance)
      CALL BOM_PAIR_GEOMETRY(
     I     1_8,0. _d 0,0. _d 0,2_8,180. _d 0,0. _d 0,
     I     .TRUE.,.FALSE.,.TRUE.,0. _d 0,360. _d 0,
     I     -10. _d 0,10. _d 0,360. _d 0,0. _d 0,1. _d -12,
     O     dEast,dNorth,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dEast,dNorth,
     &     distance,nFail,negativeCount,myThid)

C--   Spherical midpoint metric at multiple orientations.
      CALL BOM_PAIR_GEOMETRY(
     I     1_8,150. _d 0,20. _d 0,
     I     2_8,150.5 _d 0,20. _d 0,
     I     .FALSE.,.TRUE.,.TRUE.,0. _d 0,360. _d 0,
     I     -80. _d 0,80. _d 0,360. _d 0,6370000. _d 0,
     I     1. _d -9,dEast,dNorth,distance,failCode,valid)
      expected = 6370000. _d 0*COS(20. _d 0*piValue/180. _d 0)
     &     *0.5 _d 0*piValue/180. _d 0
      tolerance = 512. _d 0*EPSILON(oneRL)*MAX(oneRL,ABS(expected))
      CALL BOM_P31_ASSERT(valid .AND. ABS(dEast-expected).LE.tolerance
     &     .AND. dNorth.EQ.0. _d 0,
     &     'D01 spherical zonal midpoint metric',nFail,myThid)
      CALL BOM_PAIR_GEOMETRY(
     I     1_8,150. _d 0,20. _d 0,
     I     2_8,150. _d 0,20.5 _d 0,
     I     .FALSE.,.TRUE.,.TRUE.,0. _d 0,360. _d 0,
     I     -80. _d 0,80. _d 0,360. _d 0,6370000. _d 0,
     I     1. _d -9,dEast,dNorth,distance,failCode,valid)
      expected = 6370000. _d 0*0.5 _d 0*piValue/180. _d 0
      tolerance = 512. _d 0*EPSILON(oneRL)*MAX(oneRL,ABS(expected))
      CALL BOM_P31_ASSERT(valid .AND. dEast.EQ.0. _d 0
     &     .AND. ABS(dNorth-expected).LE.tolerance,
     &     'D01 spherical meridional metric',nFail,myThid)
      CALL BOM_PAIR_GEOMETRY(
     I     1_8,150. _d 0,20. _d 0,
     I     2_8,150.5 _d 0,20.5 _d 0,
     I     .FALSE.,.TRUE.,.TRUE.,0. _d 0,360. _d 0,
     I     -80. _d 0,80. _d 0,360. _d 0,6370000. _d 0,
     I     1. _d -9,dEast,dNorth,distance,failCode,valid)
      velocityEast = 6370000. _d 0
     &     *COS(20.25 _d 0*piValue/180. _d 0)
     &     *0.5 _d 0*piValue/180. _d 0
      velocityNorth = 6370000. _d 0
     &     *0.5 _d 0*piValue/180. _d 0
      CALL BOM_SAFE_NORM2_RL(velocityEast,velocityNorth,
     &                       expected,valid2)
      tolerance = 512. _d 0*EPSILON(oneRL)*MAX(oneRL,expected)
      CALL BOM_P31_ASSERT(valid .AND. valid2
     &     .AND. ABS(dEast-velocityEast).LE.tolerance
     &     .AND. ABS(dNorth-velocityNorth).LE.tolerance
     &     .AND. ABS(distance-expected).LE.tolerance,
     &     'D01 spherical diagonal midpoint metric',nFail,myThid)
      CALL BOM_PAIR_GEOMETRY(
     I     71_8,-20. _d 0,-45. _d 0,
     I     9000000000007_8,-19.5 _d 0,-44.5 _d 0,
     I     .FALSE.,.TRUE.,.TRUE.,0. _d 0,360. _d 0,
     I     -80. _d 0,80. _d 0,360. _d 0,6370000. _d 0,
     I     1. _d -9,dEast,dNorth,distance,failCode,valid)
      velocityEast = 6370000. _d 0
     &     *COS(-44.75 _d 0*piValue/180. _d 0)
     &     *0.5 _d 0*piValue/180. _d 0
      velocityNorth = 6370000. _d 0
     &     *0.5 _d 0*piValue/180. _d 0
      CALL BOM_SAFE_NORM2_RL(velocityEast,velocityNorth,
     &                       expected,valid2)
      tolerance = 512. _d 0*EPSILON(oneRL)*MAX(oneRL,expected)
      CALL BOM_P31_ASSERT(valid .AND. valid2
     &     .AND. ABS(dEast-velocityEast).LE.tolerance
     &     .AND. ABS(dNorth-velocityNorth).LE.tolerance
     &     .AND. ABS(distance-expected).LE.tolerance,
     &     'D01 spherical second-latitude diagonal',nFail,myThid)

C--   Overflow-safe large Cartesian norm remains finite when representable.
      CALL BOM_PAIR_GEOMETRY(
     I     1_8,0. _d 0,0. _d 0,
     I     2_8,0.4 _d 0*hugeValue,0.3 _d 0*hugeValue,
     I     .TRUE.,.FALSE.,.FALSE.,-hugeValue,0.9 _d 0*hugeValue,
     I     -hugeValue,0.9 _d 0*hugeValue,0. _d 0,0. _d 0,
     I     1. _d -12,dEast,dNorth,distance,failCode,valid)
      CALL BOM_P31_ASSERT(valid .AND.
     &     ABS(distance-0.5 _d 0*hugeValue)
     &       .LE.512. _d 0*EPSILON(oneRL)*distance,
     &     'D01 overflow-safe representable norm',nFail,myThid)

      CALL BOM_P31_GEOMETRY_NEGATIVES(
     I     nanValue,infValue,hugeValue,
     U     nFail,negativeCount,myThid)

C--   B07 Hooke equilibrium, compression, extension and reversal.
      CALL BOM_SPRING_PAIR(
     I     'HOOKE',2. _d 0,10. _d 0,0.25 _d 0,
     I     0. _d 0,0. _d 0,10. _d 0,0. _d 0,10. _d 0,
     O     velocityEast,velocityNorth,stiffness,failCode,valid)
      CALL BOM_P31_ASSERT(valid .AND. velocityEast.EQ.0. _d 0
     &     .AND. velocityNorth.EQ.0. _d 0
     &     .AND. stiffness.EQ.0.25 _d 0,
     &     'B07 Hooke equilibrium',nFail,myThid)
      CALL BOM_SPRING_PAIR(
     I     'HOOKE',2. _d 0,10. _d 0,0.25 _d 0,
     I     0. _d 0,0. _d 0,8. _d 0,0. _d 0,8. _d 0,
     O     velocityEast,velocityNorth,stiffness,failCode,valid)
      CALL BOM_SPRING_PAIR(
     I     'HOOKE',2. _d 0,10. _d 0,0.25 _d 0,
     I     0. _d 0,0. _d 0,8. _d 0,0. _d 0,8. _d 0,
     O     velocityEast2,velocityNorth2,stiffness2,
     O     failCode,valid2)
      CALL BOM_P31_ASSERT(valid .AND. valid2
     &     .AND. velocityEast.EQ.-1. _d 0
     &     .AND. velocityEast2.EQ.velocityEast
     &     .AND. velocityNorth2.EQ.velocityNorth
     &     .AND. velocityEast+(-velocityEast).EQ.0. _d 0
     &     .AND. velocityNorth+(-velocityNorth).EQ.0. _d 0,
     &     'B07 compression and equal/opposite centre',nFail,myThid)
      CALL BOM_SPRING_PAIR(
     I     'HOOKE',2. _d 0,10. _d 0,0.25 _d 0,
     I     0. _d 0,0. _d 0,12. _d 0,0. _d 0,12. _d 0,
     O     velocityEast,velocityNorth,stiffness,failCode,valid)
      tolerance = 128. _d 0*EPSILON(oneRL)
      CALL BOM_P31_ASSERT(valid
     &     .AND. ABS(velocityEast-oneRL).LE.tolerance,
     &     'B07 extension sign and magnitude',nFail,myThid)

      CALL BOM_P31_INTEGRATE_HOOKE(
     I     2,4,1. _d 0,3. _d 0,2. _d 0,1. _d 0,1. _d 0,
     O     rk2Coarse,valid)
      CALL BOM_P31_INTEGRATE_HOOKE(
     I     2,8,1. _d 0,3. _d 0,2. _d 0,1. _d 0,1. _d 0,
     O     rk2Fine,valid2)
      exactDistance = 2. _d 0+EXP(-2. _d 0)
      error2Coarse = ABS(rk2Coarse-exactDistance)
      error2Fine = ABS(rk2Fine-exactDistance)
      CALL BOM_P31_ASSERT(valid .AND. valid2 .AND. error2Fine.GT.0. _d 0
     &     .AND. error2Coarse/error2Fine.GT.3.5 _d 0,
     &     'B07 RK2 relative separation convergence',nFail,myThid)
      CALL BOM_P31_INTEGRATE_HOOKE(
     I     4,4,1. _d 0,3. _d 0,2. _d 0,1. _d 0,1. _d 0,
     O     rk4Coarse,valid)
      CALL BOM_P31_INTEGRATE_HOOKE(
     I     4,8,1. _d 0,3. _d 0,2. _d 0,1. _d 0,1. _d 0,
     O     rk4Fine,valid2)
      error4Coarse = ABS(rk4Coarse-exactDistance)
      error4Fine = ABS(rk4Fine-exactDistance)
      CALL BOM_P31_ASSERT(valid .AND. valid2 .AND. error4Fine.GT.0. _d 0
     &     .AND. error4Coarse/error4Fine.GT.12. _d 0,
     &     'B07 RK4 relative separation convergence',nFail,myThid)

C--   B08 overflow-safe logistic and locked Julia 200 m convention.
      CALL BOM_P31_EBOMB_STIFFNESS(
     I     2000. _d 0,1000. _d 0,2. _d 0,200. _d 0,
     O     stiffness,valid)
      CALL BOM_P31_ASSERT(valid .AND. stiffness.EQ.1. _d 0,
     &     'B08 stiffness A/2 at 2L',nFail,myThid)
      CALL BOM_P31_EBOMB_STIFFNESS(
     I     100. _d 0,1000. _d 0,2. _d 0,200. _d 0,
     O     velocityEast,valid)
      CALL BOM_P31_EBOMB_STIFFNESS(
     I     1500. _d 0,1000. _d 0,2. _d 0,200. _d 0,
     O     velocityNorth,valid2)
      CALL BOM_P31_EBOMB_STIFFNESS(
     I     2500. _d 0,1000. _d 0,2. _d 0,200. _d 0,
     O     stiffness2,valid3)
      CALL BOM_P31_EBOMB_STIFFNESS(
     I     10000. _d 0,1000. _d 0,2. _d 0,200. _d 0,
     O     dSwap,valid4)
      CALL BOM_P31_ASSERT(valid .AND. valid2 .AND. valid3 .AND. valid4
     &     .AND. velocityEast.GT.velocityNorth
     &     .AND. velocityNorth.GT.stiffness2
     &     .AND. stiffness2.GT.dSwap .AND. dSwap.GE.0. _d 0,
     &     'B08 monotone eBOMB stiffness',nFail,myThid)
      CALL BOM_P31_EBOMB_STIFFNESS(
     I     1. _d 0,1000000. _d 0,1. _d 0,1. _d 0,
     O     velocityEast,valid)
      CALL BOM_P31_EBOMB_STIFFNESS(
     I     3000000. _d 0,1000000. _d 0,1. _d 0,1. _d 0,
     O     velocityNorth,valid2)
      CALL BOM_P31_ASSERT(valid .AND. valid2
     &     .AND. velocityEast.EQ.1. _d 0
     &     .AND. velocityNorth.EQ.0. _d 0,
     &     'B08 extreme logistic arguments finite',nFail,myThid)
      CALL BOM_P31_EBOMB_STIFFNESS(
     I     2300. _d 0,1000. _d 0,2. _d 0,200. _d 0,
     O     stiffness,valid)
      expected = 2. _d 0/(EXP(1.5 _d 0)+oneRL)
      tolerance = 128. _d 0*EPSILON(oneRL)*MAX(oneRL,ABS(expected))
      CALL BOM_P31_ASSERT(valid .AND.
     &     ABS(stiffness-expected).LE.tolerance,
     &     'B08 locked Julia 200 m SI conversion',nFail,myThid)
      ebombStiffRecord = stiffness
      ebombExpectedRecord = expected
      ebombTolRecord = tolerance

C--   N05 bad law/parameters and accumulation overflow.
      CALL BOM_P31_SET_SPRING_SENTINEL(
     O     velocityEast,velocityNorth,stiffness)
      CALL BOM_SPRING_PAIR(
     I     'BAD',1. _d 0,1. _d 0,1. _d 0,1. _d 0,1. _d 0,
     I     1. _d 0,0. _d 0,1. _d 0,
     O     velocityEast,velocityNorth,stiffness,failCode,valid)
      CALL BOM_P31_EXPECT_SPRING_FAIL(valid,failCode,velocityEast,
     &     velocityNorth,stiffness,nFail,negativeCount,myThid)
      CALL BOM_P31_SET_SPRING_SENTINEL(
     O     velocityEast,velocityNorth,stiffness)
      CALL BOM_SPRING_PAIR(
     I     'HOOKE',1. _d 0,1. _d 0,-1. _d 0,0. _d 0,0. _d 0,
     I     1. _d 0,0. _d 0,1. _d 0,
     O     velocityEast,velocityNorth,stiffness,failCode,valid)
      CALL BOM_P31_EXPECT_SPRING_FAIL(valid,failCode,velocityEast,
     &     velocityNorth,stiffness,nFail,negativeCount,myThid)
      CALL BOM_P31_SET_SPRING_SENTINEL(
     O     velocityEast,velocityNorth,stiffness)
      CALL BOM_SPRING_PAIR(
     I     'EBOMB',1. _d 0,1. _d 0,0. _d 0,1. _d 0,0. _d 0,
     I     1. _d 0,0. _d 0,1. _d 0,
     O     velocityEast,velocityNorth,stiffness,failCode,valid)
      CALL BOM_P31_EXPECT_SPRING_FAIL(valid,failCode,velocityEast,
     &     velocityNorth,stiffness,nFail,negativeCount,myThid)
      CALL BOM_P31_SET_SPRING_SENTINEL(
     O     velocityEast,velocityNorth,stiffness)
      CALL BOM_SPRING_PAIR(
     I     'HOOKE',1. _d 0,1. _d 0,1. _d 0,0. _d 0,0. _d 0,
     I     1. _d 0,0. _d 0,2. _d 0,
     O     velocityEast,velocityNorth,stiffness,failCode,valid)
      CALL BOM_P31_EXPECT_SPRING_FAIL(valid,failCode,velocityEast,
     &     velocityNorth,stiffness,nFail,negativeCount,myThid)
      CALL BOM_P31_SET_SPRING_SENTINEL(
     O     velocityEast,velocityNorth,stiffness)
      CALL BOM_SPRING_PAIR(
     I     'HOOKE',1. _d 0,1. _d 0,1. _d 0,0. _d 0,0. _d 0,
     I     nanValue,0. _d 0,1. _d 0,
     O     velocityEast,velocityNorth,stiffness,failCode,valid)
      CALL BOM_P31_EXPECT_SPRING_FAIL(valid,failCode,velocityEast,
     &     velocityNorth,stiffness,nFail,negativeCount,myThid)
      CALL BOM_P31_SET_SPRING_SENTINEL(
     O     velocityEast,velocityNorth,stiffness)
      CALL BOM_SPRING_PAIR(
     I     'HOOKE',hugeValue,2. _d 0,hugeValue,
     I     0. _d 0,0. _d 0,3. _d 0,0. _d 0,3. _d 0,
     O     velocityEast,velocityNorth,stiffness,failCode,valid)
      CALL BOM_P31_EXPECT_SPRING_FAIL(valid,failCode,velocityEast,
     &     velocityNorth,stiffness,nFail,negativeCount,myThid)
      CALL BOM_SPRING_ACCUMULATE(
     I     0.75 _d 0*hugeValue,17. _d 0,
     I     0.75 _d 0*hugeValue,2. _d 0,
     O     resultEast,resultNorth,failCode,valid)
      CALL BOM_P31_ASSERT(.NOT.valid
     &     .AND. failCode.EQ.BOM_FAIL_SPRING_LAW
     &     .AND. resultEast.EQ.0.75 _d 0*hugeValue
     &     .AND. resultNorth.EQ.17. _d 0,
     &     'N05 accumulation rollback',nFail,myThid)
      negativeCount = negativeCount+1

      globalFail = nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &       'BOM_VERIFY_REFERENCE_LAWS: failures=',globalFail
          CALL PRINT_ERROR(msgBuf,myThid)
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: S/R BOM_VERIFY_REFERENCE_LAWS'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P3-C01 PASS: parameters and stable codes'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(msgBuf,'(A)')
     &       'P3-D01 PASS: canonical Cartesian/spherical geometry'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(msgBuf,'(A)')
     &       'B07 PASS: Hooke law and RK2/RK4 convergence'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(msgBuf,'(A)')
     &       'B08 PASS: overflow-safe eBOMB and Julia SI case'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(msgBuf,'(A,I4,A)')
     &       'P3-N03/P3-N05 PASS: ',negativeCount,
     &       ' failure/rollback candidates'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P31-LAW-RECORD ','GEOM  ',
     &       TRANSFER(geomEastRecord,0_8),
     &       TRANSFER(geomNorthRecord,0_8),
     &       TRANSFER(geomDistanceRecord,0_8),negativeCount
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P31-LAW-RECORD ','RK2   ',
     &       TRANSFER(rk2Coarse,0_8),TRANSFER(rk2Fine,0_8),
     &       TRANSFER(error2Coarse/error2Fine,0_8),0_8
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P31-LAW-RECORD ','RK4   ',
     &       TRANSFER(rk4Coarse,0_8),TRANSFER(rk4Fine,0_8),
     &       TRANSFER(error4Coarse/error4Fine,0_8),0_8
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P31-LAW-RECORD ','EBOMB ',
     &       TRANSFER(ebombStiffRecord,0_8),
     &       TRANSFER(ebombExpectedRecord,0_8),
     &       TRANSFER(ebombTolRecord,0_8),0_8
      ENDIF
      _END_MASTER(myThid)
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P31_CONFIG_NEGATIVES(
     I                 nanValue,
     U                 nFail,negativeCount,myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL nanValue
      INTEGER nFail,negativeCount,myThid,failCode
      LOGICAL valid

      CALL BOM_VALIDATE_SPRING_CONFIG(
     I     'LEEW','NONE','NONE',nanValue,nanValue,nanValue,nanValue,
     I     nanValue,nanValue,nanValue,.FALSE.,.TRUE.,nanValue,
     O     failCode,valid)
      CALL BOM_P31_ASSERT(valid .AND. failCode.EQ.BOM_FAIL_NONE,
     &     'C01 inactive numeric controls ignored',nFail,myThid)

      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','BAD','NONE',
     &     1. _d 0,1. _d 0,1. _d 0,1. _d 0,2. _d 0,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('LEEW','HOOKE','CUTOFF',
     &     1. _d 0,1. _d 0,0. _d 0,0. _d 0,2. _d 0,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','HOOKE','NONE',
     &     1. _d 0,1. _d 0,0. _d 0,0. _d 0,2. _d 0,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','NONE','CUTOFF',
     &     0. _d 0,0. _d 0,0. _d 0,0. _d 0,0. _d 0,
     &     0. _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','NONE','NONE',
     &     0. _d 0,0. _d 0,0. _d 0,0. _d 0,0. _d 0,
     &     0. _d 0,0.5 _d 0,.TRUE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','HOOKE','CUTOFF',
     &     nanValue,1. _d 0,0. _d 0,0. _d 0,2. _d 0,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','HOOKE','CUTOFF',
     &     1. _d 0,nanValue,0. _d 0,0. _d 0,2. _d 0,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','HOOKE','CUTOFF',
     &     1. _d 0,0. _d 0,0. _d 0,0. _d 0,2. _d 0,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','EBOMB','CUTOFF',
     &     1. _d 0,0. _d 0,1. _d 0,0. _d 0,2. _d 0,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','EBOMB','CUTOFF',
     &     1. _d 0,0. _d 0,nanValue,1. _d 0,2. _d 0,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','EBOMB','CUTOFF',
     &     1. _d 0,0. _d 0,1. _d 0,nanValue,2. _d 0,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','HOOKE','CUTOFF',
     &     1. _d 0,1. _d 0,0. _d 0,0. _d 0,0.1 _d 0,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','HOOKE','CUTOFF',
     &     1. _d 0,1. _d 0,0. _d 0,0. _d 0,2. _d 0,
     &     0.1 _d 0,0. _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','HOOKE','CUTOFF',
     &     1. _d 0,1. _d 0,0. _d 0,0. _d 0,nanValue,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','HOOKE','CUTOFF',
     &     1. _d 0,1. _d 0,0. _d 0,0. _d 0,2. _d 0,
     &     nanValue,0.5 _d 0,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','HOOKE','CUTOFF',
     &     1. _d 0,1. _d 0,0. _d 0,0. _d 0,2. _d 0,
     &     0.1 _d 0,nanValue,.FALSE.,.FALSE.,0. _d 0,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_EXPECT_CONFIG_FAIL('BOM','HOOKE','CUTOFF',
     &     1. _d 0,1. _d 0,0. _d 0,0. _d 0,5. _d 0,
     &     0.1 _d 0,0.5 _d 0,.FALSE.,.TRUE.,5. _d 0,
     &     nFail,negativeCount,myThid)

      RETURN
      END

      SUBROUTINE BOM_P31_EXPECT_CONFIG_FAIL(
     I                 mode,law,policy,springL,hookeK,springA,delta,
     I                 cutoff,pairMin,springCFL,raft,periodicX,
     I                 halfPeriod,
     U                 nFail,negativeCount,myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) mode,law,policy
      _RL springL,hookeK,springA,delta,cutoff,pairMin,springCFL
      _RL halfPeriod
      LOGICAL raft,periodicX,valid
      INTEGER nFail,negativeCount,myThid,failCode
      CALL BOM_VALIDATE_SPRING_CONFIG(mode,law,policy,
     &     springL,hookeK,springA,delta,cutoff,pairMin,springCFL,
     &     raft,periodicX,halfPeriod,failCode,valid)
      CALL BOM_P31_ASSERT(.NOT.valid
     &     .AND. failCode.EQ.BOM_FAIL_NEIGHBOR_CONFIG,
     &     'C01 expected configuration failure',nFail,myThid)
      negativeCount=negativeCount+1
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P31_GEOMETRY_NEGATIVES(
     I                 nanValue,infValue,hugeValue,
     U                 nFail,negativeCount,myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL nanValue,infValue,hugeValue,dE,dN,distance
      INTEGER nFail,negativeCount,myThid,failCode
      LOGICAL valid

      CALL BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      CALL BOM_PAIR_GEOMETRY(1_8,0. _d 0,0. _d 0,
     &     1_8,1. _d 0,0. _d 0,.TRUE.,.FALSE.,.FALSE.,
     &     -10. _d 0,10. _d 0,-10. _d 0,10. _d 0,
     &     0. _d 0,0. _d 0,1. _d -6,dE,dN,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      CALL BOM_PAIR_GEOMETRY(1_8,0. _d 0,0. _d 0,
     &     2_8,0. _d 0,0. _d 0,.TRUE.,.FALSE.,.FALSE.,
     &     -10. _d 0,10. _d 0,-10. _d 0,10. _d 0,
     &     0. _d 0,0. _d 0,1. _d -6,dE,dN,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      CALL BOM_PAIR_GEOMETRY(1_8,nanValue,0. _d 0,
     &     2_8,1. _d 0,0. _d 0,.TRUE.,.FALSE.,.FALSE.,
     &     -10. _d 0,10. _d 0,-10. _d 0,10. _d 0,
     &     0. _d 0,0. _d 0,1. _d -6,dE,dN,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      CALL BOM_PAIR_GEOMETRY(1_8,0. _d 0,0. _d 0,
     &     2_8,infValue,0. _d 0,.TRUE.,.FALSE.,.FALSE.,
     &     -10. _d 0,10. _d 0,-10. _d 0,10. _d 0,
     &     0. _d 0,0. _d 0,1. _d -6,dE,dN,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      CALL BOM_PAIR_GEOMETRY(1_8,-1. _d 0,0. _d 0,
     &     2_8,1. _d 0,0. _d 0,.TRUE.,.FALSE.,.FALSE.,
     &     0. _d 0,10. _d 0,-10. _d 0,10. _d 0,
     &     0. _d 0,0. _d 0,1. _d -6,dE,dN,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      CALL BOM_PAIR_GEOMETRY(1_8,0. _d 0,89.9999999 _d 0,
     &     2_8,0.1 _d 0,89.9999999 _d 0,.FALSE.,.TRUE.,.TRUE.,
     &     0. _d 0,360. _d 0,-90. _d 0,90. _d 0,
     &     360. _d 0,6370000. _d 0,1. _d -6,
     &     dE,dN,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      CALL BOM_PAIR_GEOMETRY(1_8,0. _d 0,20. _d 0,
     &     2_8,1. _d 0,20. _d 0,.FALSE.,.TRUE.,.TRUE.,
     &     0. _d 0,360. _d 0,-80. _d 0,80. _d 0,
     &     360. _d 0,-1. _d 0,1. _d -6,
     &     dE,dN,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      CALL BOM_PAIR_GEOMETRY(1_8,0. _d 0,0. _d 0,
     &     2_8,0.8 _d 0*hugeValue,0.8 _d 0*hugeValue,
     &     .TRUE.,.FALSE.,.FALSE.,-hugeValue,hugeValue,
     &     -hugeValue,hugeValue,0. _d 0,0. _d 0,1. _d -6,
     &     dE,dN,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      CALL BOM_PAIR_GEOMETRY(1_8,0. _d 0,0. _d 0,
     &     2_8,1. _d -7,0. _d 0,.TRUE.,.FALSE.,.FALSE.,
     &     -1. _d 0,1. _d 0,-1. _d 0,1. _d 0,
     &     0. _d 0,0. _d 0,1. _d -6,dE,dN,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      CALL BOM_PAIR_GEOMETRY(1_8,0. _d 0,0. _d 0,
     &     2_8,1. _d 0,0. _d 0,.TRUE.,.TRUE.,.FALSE.,
     &     -10. _d 0,10. _d 0,-10. _d 0,10. _d 0,
     &     0. _d 0,0. _d 0,1. _d -6,dE,dN,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     &     nFail,negativeCount,myThid)
      CALL BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      CALL BOM_PAIR_GEOMETRY(1_8,0. _d 0,0. _d 0,
     &     2_8,1. _d 0,0. _d 0,.TRUE.,.FALSE.,.TRUE.,
     &     0. _d 0,360. _d 0,-10. _d 0,10. _d 0,
     &     infValue,0. _d 0,1. _d -6,
     &     dE,dN,distance,failCode,valid)
      CALL BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     &     nFail,negativeCount,myThid)
      RETURN
      END

      SUBROUTINE BOM_P31_EXPECT_GEOM_FAIL(valid,failCode,dE,dN,distance,
     U                 nFail,negativeCount,myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      LOGICAL valid
      INTEGER failCode,nFail,negativeCount,myThid
      _RL dE,dN,distance
      CALL BOM_P31_ASSERT(.NOT.valid
     &     .AND. failCode.EQ.BOM_FAIL_PAIR_GEOMETRY
     &     .AND. dE.EQ.11. _d 0 .AND. dN.EQ.-22. _d 0
     &     .AND. distance.EQ.33. _d 0,
     &     'N03 geometry failure preserves sentinels',nFail,myThid)
      negativeCount=negativeCount+1
      RETURN
      END

      SUBROUTINE BOM_P31_SET_GEOM_SENTINEL(dE,dN,distance)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      _RL dE,dN,distance
      dE=11. _d 0
      dN=-22. _d 0
      distance=33. _d 0
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P31_EBOMB_STIFFNESS(
     I                 distance,springL,springA,delta,
     O                 stiffness,valid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL distance,springL,springA,delta,stiffness,vE,vN
      INTEGER failCode
      LOGICAL valid
      CALL BOM_SPRING_PAIR('EBOMB',0. _d 0,springL,0. _d 0,
     &     springA,delta,distance,0. _d 0,distance,
     &     vE,vN,stiffness,failCode,valid)
      valid=valid .AND. failCode.EQ.BOM_FAIL_NONE
      RETURN
      END

      SUBROUTINE BOM_P31_EXPECT_SPRING_FAIL(
     I                 valid,failCode,vE,vN,stiffness,
     U                 nFail,negativeCount,myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      LOGICAL valid
      INTEGER failCode,nFail,negativeCount,myThid
      _RL vE,vN,stiffness
      CALL BOM_P31_ASSERT(.NOT.valid
     &     .AND. failCode.EQ.BOM_FAIL_SPRING_LAW
     &     .AND. vE.EQ.101. _d 0 .AND. vN.EQ.-202. _d 0
     &     .AND. stiffness.EQ.303. _d 0,
     &     'N05 spring failure preserves sentinels',nFail,myThid)
      negativeCount=negativeCount+1
      RETURN
      END

      SUBROUTINE BOM_P31_SET_SPRING_SENTINEL(vE,vN,stiffness)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      _RL vE,vN,stiffness
      vE=101. _d 0
      vN=-202. _d 0
      stiffness=303. _d 0
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P31_INTEGRATE_HOOKE(
     I                 method,nSteps,totalTime,dInitial,springL,
     I                 tauValue,hookeK,
     O                 dFinal,valid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
      INTEGER method,nSteps,iStep
      _RL totalTime,dInitial,springL,tauValue,hookeK,dFinal
      _RL dt,k1,k2,k3,k4,trial
      LOGICAL valid,rateValid
      valid=.FALSE.
      dFinal=dInitial
      IF ( nSteps.LT.1 ) RETURN
      dt=totalTime/DFLOAT(nSteps)
      DO iStep=1,nSteps
        CALL BOM_P31_HOOKE_RATE(dFinal,springL,tauValue,hookeK,
     &                         k1,rateValid)
        IF ( .NOT.rateValid ) RETURN
        IF ( method.EQ.2 ) THEN
          trial=dFinal+0.5 _d 0*dt*k1
          CALL BOM_P31_HOOKE_RATE(trial,springL,tauValue,hookeK,
     &                           k2,rateValid)
          IF ( .NOT.rateValid ) RETURN
          dFinal=dFinal+dt*k2
        ELSEIF ( method.EQ.4 ) THEN
          trial=dFinal+0.5 _d 0*dt*k1
          CALL BOM_P31_HOOKE_RATE(trial,springL,tauValue,hookeK,
     &                           k2,rateValid)
          IF ( .NOT.rateValid ) RETURN
          trial=dFinal+0.5 _d 0*dt*k2
          CALL BOM_P31_HOOKE_RATE(trial,springL,tauValue,hookeK,
     &                           k3,rateValid)
          IF ( .NOT.rateValid ) RETURN
          trial=dFinal+dt*k3
          CALL BOM_P31_HOOKE_RATE(trial,springL,tauValue,hookeK,
     &                           k4,rateValid)
          IF ( .NOT.rateValid ) RETURN
          dFinal=dFinal+dt*(k1+2. _d 0*k2+2. _d 0*k3+k4)/6. _d 0
        ELSE
          RETURN
        ENDIF
      ENDDO
      valid=.TRUE.
      RETURN
      END

      SUBROUTINE BOM_P31_HOOKE_RATE(
     I                 distance,springL,tauValue,hookeK,
     O                 rate,valid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL distance,springL,tauValue,hookeK,rate,vE,vN,stiffness
      INTEGER failCode
      LOGICAL valid
      rate=0. _d 0
      CALL BOM_SPRING_PAIR('HOOKE',tauValue,springL,hookeK,
     &     0. _d 0,0. _d 0,distance,0. _d 0,distance,
     &     vE,vN,stiffness,failCode,valid)
      IF ( .NOT.valid .OR. failCode.NE.BOM_FAIL_NONE ) THEN
        valid=.FALSE.
        RETURN
      ENDIF
      rate=-2. _d 0*vE
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_P31_ASSERT(condition,label,nFail,myThid)
      IMPLICIT NONE
#include "EEPARAMS.h"
      LOGICAL condition
      CHARACTER*(*) label
      INTEGER nFail,myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      IF ( .NOT.condition ) THEN
        IF ( nFail.LT.40 ) THEN
          WRITE(msgBuf,'(2A)')
     &       'BOM_VERIFY_REFERENCE_LAWS: FAIL: ',label
          CALL PRINT_ERROR(msgBuf,myThid)
        ENDIF
        nFail=nFail+1
      ENDIF
      RETURN
      END
