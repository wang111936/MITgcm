#include "BOM_OPTIONS.h"

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
CBOP
C !ROUTINE: BOM_VERIFY_RHS_COMPONENTS
C !INTERFACE:
      SUBROUTINE BOM_VERIFY_RHS_COMPONENTS( myThid )

C !DESCRIPTION:
C     Direct P2-H01--H06/P2-N06 gate for the stateless production kernels.
C     Expected values are formed by independent ordinary-arithmetic oracles.

      USE, INTRINSIC :: IEEE_ARITHMETIC,
     &     ONLY: IEEE_VALUE, IEEE_QUIET_NAN
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      INTEGER myThid
CEOP

#ifdef ALLOW_BOM
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      _RL sourceEast(BOM_ENV_NSOURCE)
      _RL sourceNorth(BOM_ENV_NSOURCE)
      _RL sourceDtEast(BOM_ENV_NSOURCE)
      _RL sourceDtNorth(BOM_ENV_NSOURCE)
      _RL gradEE(BOM_ENV_NSOURCE), gradNE(BOM_ENV_NSOURCE)
      _RL gradEN(BOM_ENV_NSOURCE), gradNN(BOM_ENV_NSOURCE)
      _RL diagPaper(BOM_RHS_NDIAG), diagJulia(BOM_RHS_NDIAG)
      _RL diagOracle(BOM_RHS_NDIAG), diagA(BOM_RHS_NDIAG)
      _RL diagB(BOM_RHS_NDIAG), diagNorth(BOM_RHS_NDIAG)
      _RL diagSouth(BOM_RHS_NDIAG), diagCycl(BOM_RHS_NDIAG)
      _RL diagAnti(BOM_RHS_NDIAG)
      _RL alpha, tauValue, rValue, sigma, fCori, tauSphere
      _RL stageCFL, maxDiff, diffTol, tolerance, piValue
      _RL baseE, baseN, stokesE, stokesN, windE, windN
      _RL nanValue, hugeValue
      INTEGER failCode, failStage, nFail, globalFail, iDiag
      INTEGER bi, bj, negativeCount
      LOGICAL rhsValid, stokesApplied

      nFail = 0
      negativeCount = 0
      CALL BOM_VERIFY_SET_FIXTURE(
     O     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     O     gradEE,gradNE,gradEN,gradNN,
     O     alpha,tauValue,rValue,sigma,fCori,tauSphere )

C--   H01: paper total-field algebra and complete component table.
      CALL BOM_RHS_COMPONENTS(
     I     'PAPER2024','EULERIAN',.TRUE.,BOM_STAGE_K1,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     alpha,tauValue,rValue,sigma,fCori,tauSphere,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     O     diagPaper,stageCFL,stokesApplied,
     O     failCode,failStage,rhsValid )
      CALL BOM_VERIFY_ORACLE(
     I     'PAPER2024',alpha,tauValue,rValue,sigma,
     I     fCori,tauSphere,sourceEast,sourceNorth,
     I     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN,
     O     diagOracle )
      CALL BOM_VERIFY_ASSERT(
     &     rhsValid .AND. stokesApplied .AND.
     &     failCode.EQ.BOM_FAIL_NONE .AND.
     &     failStage.EQ.BOM_STAGE_NONE .AND. stageCFL.EQ.0. _d 0,
     &     'H01 PAPER valid candidate',nFail,myThid)
      CALL BOM_VERIFY_DIAG_CLOSE(
     I     diagPaper,diagOracle,'H01 PAPER component table',
     U     nFail,myThid )

C--   H02: locked Julia per-source derivative and base-vorticity path.
      CALL BOM_RHS_COMPONENTS(
     I     'JULIA','EULERIAN',.TRUE.,BOM_STAGE_K1,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     alpha,tauValue,rValue,sigma,fCori,tauSphere,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     O     diagJulia,stageCFL,stokesApplied,
     O     failCode,failStage,rhsValid )
      CALL BOM_VERIFY_ORACLE(
     I     'JULIA',alpha,tauValue,rValue,sigma,
     I     fCori,tauSphere,sourceEast,sourceNorth,
     I     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN,
     O     diagOracle )
      CALL BOM_VERIFY_ASSERT(
     &     rhsValid .AND. stokesApplied .AND.
     &     failCode.EQ.BOM_FAIL_NONE,
     &     'H02 JULIA valid candidate',nFail,myThid)
      CALL BOM_VERIFY_DIAG_CLOSE(
     I     diagJulia,diagOracle,'H02 JULIA component table',
     U     nFail,myThid )

C--   H03: the nonparallel-gradient fixture must distinguish the modes.
      maxDiff = 0. _d 0
      diffTol = 0. _d 0
      DO iDiag=BOM_RHS_DV_E,BOM_RHS_DRIFT_N
        maxDiff = MAX(maxDiff,ABS(diagPaper(iDiag)-diagJulia(iDiag)))
        diffTol = MAX(diffTol,2048. _d 0*EPSILON(oneRL)
     &       *MAX(1. _d 0,ABS(diagPaper(iDiag)),
     &                         ABS(diagJulia(iDiag))))
      ENDDO
      CALL BOM_VERIFY_ASSERT(
     &     maxDiff.GT.1000. _d 0*diffTol,
     &     'H03 mode difference exceeds 1000 tolerances',nFail,myThid)

C--   H04: explicit and declared-precombined inputs agree when equivalent.
      CALL BOM_VERIFY_ZERO_SOURCES(
     O     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     O     gradEE,gradNE,gradEN,gradNN )
      baseE = 1.1 _d 0
      baseN = -0.6 _d 0
      stokesE = 0.25 _d 0
      stokesN = 0.15 _d 0
      windE = 3.0 _d 0
      windN = -1.0 _d 0
      sigma = 1.3 _d 0
      alpha = 0.2 _d 0
      tauValue = 20. _d 0
      rValue = 0.8 _d 0
      fCori = 2.5 _d -5
      tauSphere = 0. _d 0
      sourceEast(BOM_ENV_EULERIAN) = baseE
      sourceNorth(BOM_ENV_EULERIAN) = baseN
      sourceEast(BOM_ENV_STOKES) = stokesE
      sourceNorth(BOM_ENV_STOKES) = stokesN
      sourceEast(BOM_ENV_WIND) = windE
      sourceNorth(BOM_ENV_WIND) = windN
      CALL BOM_RHS_COMPONENTS(
     I     'PAPER2024','EULERIAN',.TRUE.,BOM_STAGE_K2,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     alpha,tauValue,rValue,sigma,fCori,tauSphere,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     O     diagA,stageCFL,stokesApplied,
     O     failCode,failStage,rhsValid )
      CALL BOM_VERIFY_ASSERT(rhsValid,
     &     'H04 PAPER explicit valid',nFail,myThid)
      sourceEast(BOM_ENV_EULERIAN) = baseE+sigma*stokesE
      sourceNorth(BOM_ENV_EULERIAN) = baseN+sigma*stokesN
      sourceEast(BOM_ENV_STOKES) = 0. _d 0
      sourceNorth(BOM_ENV_STOKES) = 0. _d 0
      sigma = 0. _d 0
      CALL BOM_RHS_COMPONENTS(
     I     'PAPER2024','PRECOMBINED',.FALSE.,BOM_STAGE_K2,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     alpha,tauValue,rValue,sigma,fCori,tauSphere,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     O     diagB,stageCFL,stokesApplied,
     O     failCode,failStage,rhsValid )
      CALL BOM_VERIFY_ASSERT(rhsValid .AND. .NOT.stokesApplied,
     &     'H04 PAPER precombined valid',nFail,myThid)
      CALL BOM_VERIFY_DERIVED_CLOSE(
     I     diagA,diagB,'H04 PAPER explicit/precombined',
     U     nFail,myThid )

C--   Uniform inputs make the two legal policies equivalent in JULIA too.
      sourceEast(BOM_ENV_EULERIAN) = baseE
      sourceNorth(BOM_ENV_EULERIAN) = baseN
      sourceEast(BOM_ENV_STOKES) = stokesE
      sourceNorth(BOM_ENV_STOKES) = stokesN
      sigma = 1.3 _d 0
      CALL BOM_RHS_COMPONENTS(
     I     'JULIA','EULERIAN',.TRUE.,BOM_STAGE_K2,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     alpha,tauValue,rValue,sigma,fCori,tauSphere,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     O     diagA,stageCFL,stokesApplied,
     O     failCode,failStage,rhsValid )
      sourceEast(BOM_ENV_EULERIAN) = baseE+sigma*stokesE
      sourceNorth(BOM_ENV_EULERIAN) = baseN+sigma*stokesN
      sourceEast(BOM_ENV_STOKES) = 0. _d 0
      sourceNorth(BOM_ENV_STOKES) = 0. _d 0
      sigma = 0. _d 0
      CALL BOM_RHS_COMPONENTS(
     I     'JULIA','PRECOMBINED',.FALSE.,BOM_STAGE_K2,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     alpha,tauValue,rValue,sigma,fCori,tauSphere,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     O     diagB,stageCFL,stokesApplied,
     O     failCode,failStage,rhsValid )
      CALL BOM_VERIFY_DERIVED_CLOSE(
     I     diagA,diagB,'H04 JULIA explicit/precombined',
     U     nFail,myThid )

C--   H05: direct north/south, cyclonic/anticyclonic and SI assertions.
      CALL BOM_VERIFY_ZERO_SOURCES(
     O     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     O     gradEE,gradNE,gradEN,gradNN )
      sourceEast(BOM_ENV_EULERIAN) = 1.0 _d 0
      sourceNorth(BOM_ENV_EULERIAN) = 0.2 _d 0
      alpha = 0. _d 0
      tauValue = 0.0103 _d 0*86400. _d 0
      rValue = 0.823 _d 0
      sigma = 0. _d 0
      piValue = 4. _d 0*ATAN(1. _d 0)
      tauSphere = TAN(30. _d 0*piValue/180. _d 0)/6370000. _d 0
      fCori = 3. _d -5
      CALL BOM_RHS_COMPONENTS(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K3,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     alpha,tauValue,rValue,sigma,fCori,tauSphere,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     O     diagNorth,stageCFL,stokesApplied,
     O     failCode,failStage,rhsValid )
      CALL BOM_VERIFY_ASSERT(rhsValid .AND.
     &     diagNorth(BOM_RHS_FCORI).GT.0. _d 0 .AND.
     &     diagNorth(BOM_RHS_TAUSPHERE).GT.0. _d 0 .AND.
     &     diagNorth(BOM_RHS_CV).GT.0. _d 0 .AND.
     &     diagNorth(BOM_RHS_CU).GT.0. _d 0,
     &     'H05 north signs',nFail,myThid)
      tolerance = 1024. _d 0*EPSILON(oneRL)
     &     *MAX(1. _d 0,ABS(diagNorth(BOM_RHS_DRIFT_E)))
      CALL BOM_VERIFY_ASSERT(
     &     ABS(diagNorth(BOM_RHS_DRIFT_E)
     &       -diagNorth(BOM_RHS_U_E)
     &       -tauValue*diagNorth(BOM_RHS_INERT_E)).LE.tolerance
     &     .AND. ABS(diagNorth(BOM_RHS_DRIFT_E)
     &       -diagNorth(BOM_RHS_U_E)
     &       -0.0103 _d 0*diagNorth(BOM_RHS_INERT_E))
     &       .GT.1000. _d 0*tolerance,
     &     'H05 tau converted from days exactly once',nFail,myThid)
      tauSphere = -tauSphere
      fCori = -fCori
      CALL BOM_RHS_COMPONENTS(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K3,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     alpha,tauValue,rValue,sigma,fCori,tauSphere,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     O     diagSouth,stageCFL,stokesApplied,
     O     failCode,failStage,rhsValid )
      CALL BOM_VERIFY_ASSERT(rhsValid .AND.
     &     diagSouth(BOM_RHS_FCORI).LT.0. _d 0 .AND.
     &     diagSouth(BOM_RHS_TAUSPHERE).LT.0. _d 0 .AND.
     &     diagSouth(BOM_RHS_CV).LT.0. _d 0 .AND.
     &     diagSouth(BOM_RHS_CU).LT.0. _d 0,
     &     'H05 south signs',nFail,myThid)
      tauSphere = 0. _d 0
      fCori = 0. _d 0
      gradEN(BOM_ENV_EULERIAN) = 4. _d -5
      CALL BOM_RHS_COMPONENTS(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K3,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     alpha,tauValue,rValue,sigma,fCori,tauSphere,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     O     diagCycl,stageCFL,stokesApplied,
     O     failCode,failStage,rhsValid )
      gradEN(BOM_ENV_EULERIAN) = -4. _d -5
      CALL BOM_RHS_COMPONENTS(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K3,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     alpha,tauValue,rValue,sigma,fCori,tauSphere,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     O     diagAnti,stageCFL,stokesApplied,
     O     failCode,failStage,rhsValid )
      CALL BOM_VERIFY_ASSERT(
     &     diagCycl(BOM_RHS_OMEGA).GT.0. _d 0 .AND.
     &     diagAnti(BOM_RHS_OMEGA).LT.0. _d 0,
     &     'H05 cyclonic and anticyclonic signs',nFail,myThid)

C--   Seed authoritative state; all H06/N06 failures must leave it unchanged.
      bi = myBxLo(myThid)
      bj = myByLo(myThid)
      bomNPartTile(bi,bj) = 1
      bomStatus(1,bi,bj) = BOM_ALIVE
      bomId(1,bi,bj) = 2300000000001_8
      bomX(1,bi,bj) = 12.5 _d 0
      bomY(1,bi,bj) = -7.25 _d 0
      bomAge(1,bi,bj) = 44. _d 0
      bomI(1,bi,bj) = 2.25 _d 0
      bomJ(1,bi,bj) = 1.75 _d 0
      bomVEast(1,bi,bj) = 8.5 _d 0
      bomVNorth(1,bi,bj) = -4.5 _d 0
      bomDriftEast(1,bi,bj) = 6.5 _d 0
      bomDriftNorth(1,bi,bj) = -3.5 _d 0
      nanValue = IEEE_VALUE(oneRL,IEEE_QUIET_NAN)
      hugeValue = HUGE(oneRL)

C--   H04 negative priority: duplicate is retained before injected NaN.
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceEast(BOM_ENV_EULERIAN) = nanValue
      sigma = 0. _d 0
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','PRECOMBINED',.TRUE.,BOM_STAGE_K2,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,1. _d 0,1. _d 0,sigma,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_STOKES_DUPLICATE,bi,bj,
     U     nFail,negativeCount,myThid )

C--   N06 source nonfinite, combined, covariant and vorticity overflow.
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceEast(BOM_ENV_EULERIAN) = nanValue
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K1,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,1. _d 0,1. _d 0,0. _d 0,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceEast(BOM_ENV_EULERIAN) = 0.75 _d 0*hugeValue
      sourceEast(BOM_ENV_STOKES) = 0.75 _d 0*hugeValue
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.TRUE.,BOM_STAGE_K2,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,1. _d 0,1. _d 0,2. _d 0,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceEast(BOM_ENV_EULERIAN) = 0.75 _d 0*hugeValue
      gradEE(BOM_ENV_EULERIAN) = 2. _d 0
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K3,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,1. _d 0,1. _d 0,0. _d 0,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      gradEN(BOM_ENV_EULERIAN) = 0.75 _d 0*hugeValue
      gradNE(BOM_ENV_EULERIAN) = -0.75 _d 0*hugeValue
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K4,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,1. _d 0,1. _d 0,0. _d 0,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )

C--   N06 final coefficients, rotation, inertia and drift overflow.
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceEast(BOM_ENV_EULERIAN) = 1. _d 0
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_FINAL,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,1. _d 0,1. _d 0,0. _d 0,
     I     0.3 _d 0*hugeValue,0.6 _d 0*hugeValue,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceNorth(BOM_ENV_EULERIAN) = 2. _d 0
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K1,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,1. _d 0,1. _d 0,0. _d 0,
     I     0.75 _d 0*hugeValue,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceDtEast(BOM_ENV_EULERIAN) = 0.75 _d 0*hugeValue
      sourceDtEast(BOM_ENV_WIND) = -0.75 _d 0*hugeValue
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K2,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     1. _d 0,1. _d 0,1. _d 0,0. _d 0,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceDtEast(BOM_ENV_EULERIAN) = 0.75 _d 0*hugeValue
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K3,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     1. _d 0,2. _d 0,1. _d 0,0. _d 0,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )

C--   N06 final total-drift CFL threshold and overflow use CFL code/stage.
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceEast(BOM_ENV_EULERIAN) = 2. _d 0
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K4,
     I     100. _d 0,0.01 _d 0,0.01 _d 0,0.5 _d 0,
     I     0. _d 0,0. _d 0,1. _d 0,0. _d 0,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_CFL,bi,bj,
     U     nFail,negativeCount,myThid )
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceEast(BOM_ENV_EULERIAN) = hugeValue
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'JULIA','EULERIAN',.FALSE.,BOM_STAGE_FINAL,
     I     1. _d 0,2. _d 0,1. _d 0,0.5 _d 0,
     I     0. _d 0,0. _d 0,1. _d 0,0. _d 0,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_CFL,bi,bj,
     U     nFail,negativeCount,myThid )

C--   H06 mode/source/parameter routing and safe missing-source preflight.
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'UNKNOWN','EULERIAN',.FALSE.,BOM_STAGE_K1,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,0. _d 0,1. _d 0,0. _d 0,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K2,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,0. _d 0,1. _d 0,1. _d 0,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_FIELD_SOURCE,bi,bj,
     U     nFail,negativeCount,myThid )
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceEast(BOM_ENV_STOKES) = nanValue
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'JULIA','EULERIAN',.FALSE.,BOM_STAGE_K3,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,0. _d 0,1. _d 0,0. _d 0,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_FIELD_SOURCE,bi,bj,
     U     nFail,negativeCount,myThid )
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceEast(BOM_ENV_EULERIAN) = 1. _d 0
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K4,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,0. _d 0,1. _d 0,0. _d 0,nanValue,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','PRECOMBINED',.FALSE.,BOM_STAGE_FINAL,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,0. _d 0,1. _d 0,nanValue,0. _d 0,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )

C--   N06 cV overflow is distinct from the following cU/rotation cases.
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      gradEN(BOM_ENV_EULERIAN) = 0.6 _d 0*hugeValue
      CALL BOM_VERIFY_EXPECT_FAIL(
     I     'PAPER2024','EULERIAN',.FALSE.,BOM_STAGE_K1,
     I     0. _d 0,1. _d -3,1. _d -3,0.5 _d 0,
     I     0. _d 0,0. _d 0,1. _d 0,0. _d 0,
     I     0.9 _d 0*hugeValue,0. _d 0,
     I     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     I     gradEE,gradNE,gradEN,gradNN,
     I     BOM_FAIL_EQUATION,bi,bj,
     U     nFail,negativeCount,myThid )

      globalFail = nFail
      CALL GLOBAL_SUM_INT(globalFail,myThid)
      IF ( globalFail.GT.0 ) THEN
        _BEGIN_MASTER(myThid)
        IF ( myProcId.EQ.0 ) THEN
          WRITE(msgBuf,'(A,I8)')
     &       'BOM_VERIFY_RHS_COMPONENTS: failures=',globalFail
          CALL PRINT_ERROR(msgBuf,myThid)
        ENDIF
        _END_MASTER(myThid)
        CALL ALL_PROC_DIE(0)
        STOP 'ABNORMAL END: S/R BOM_VERIFY_RHS_COMPONENTS'
      ENDIF

      _BEGIN_MASTER(myThid)
      IF ( myProcId.EQ.0 ) THEN
        WRITE(msgBuf,'(A)')
     &       'P2-H01 PASS: PAPER2024 analytic component table'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(msgBuf,'(A)')
     &       'P2-H02 PASS: JULIA per-source analytic component table'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(msgBuf,'(A,1PE12.4)')
     &       'P2-H03 PASS: discriminating mode difference=',maxDiff
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(msgBuf,'(A)')
     &       'P2-H04 PASS: Stokes policy equivalence and priority'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(msgBuf,'(A)')
     &       'P2-H05 PASS: SI, spherical, Coriolis/vorticity signs'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(msgBuf,'(A)')
     &       'P2-H06 PASS: stable failure stage and particle rollback'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(msgBuf,'(A,I4,A)')
     &       'P2-N06 PASS: ',negativeCount,' negative candidates'
        CALL PRINT_MESSAGE(msgBuf,standardMessageUnit,
     &                     SQUEEZE_RIGHT,myThid)
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P23-RHS-RECORD ','PAPER',
     &       TRANSFER(diagPaper(BOM_RHS_DV_E),0_8),
     &       TRANSFER(diagPaper(BOM_RHS_OMEGA),0_8),
     &       TRANSFER(diagPaper(BOM_RHS_INERT_E),0_8),
     &       TRANSFER(diagPaper(BOM_RHS_DRIFT_E),0_8)
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P23-RHS-RECORD ','JULIA',
     &       TRANSFER(diagJulia(BOM_RHS_DV_E),0_8),
     &       TRANSFER(diagJulia(BOM_RHS_OMEGA),0_8),
     &       TRANSFER(diagJulia(BOM_RHS_INERT_E),0_8),
     &       TRANSFER(diagJulia(BOM_RHS_DRIFT_E),0_8)
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P23-RHS-RECORD ','DIFF  ',
     &       TRANSFER(maxDiff,0_8),TRANSFER(diffTol,0_8),0_8,0_8
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P23-RHS-RECORD ','H04-A ',
     &       TRANSFER(diagA(BOM_RHS_V_E),0_8),
     &       TRANSFER(diagA(BOM_RHS_U_E),0_8),
     &       TRANSFER(diagA(BOM_RHS_INERT_E),0_8),
     &       TRANSFER(diagA(BOM_RHS_DRIFT_E),0_8)
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P23-RHS-RECORD ','H04-B ',
     &       TRANSFER(diagB(BOM_RHS_V_E),0_8),
     &       TRANSFER(diagB(BOM_RHS_U_E),0_8),
     &       TRANSFER(diagB(BOM_RHS_INERT_E),0_8),
     &       TRANSFER(diagB(BOM_RHS_DRIFT_E),0_8)
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P23-RHS-RECORD ','NORTH ',
     &       TRANSFER(diagNorth(BOM_RHS_OMEGA),0_8),
     &       TRANSFER(diagNorth(BOM_RHS_CV),0_8),
     &       TRANSFER(diagNorth(BOM_RHS_CU),0_8),
     &       TRANSFER(diagNorth(BOM_RHS_DRIFT_E),0_8)
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P23-RHS-RECORD ','SOUTH ',
     &       TRANSFER(diagSouth(BOM_RHS_OMEGA),0_8),
     &       TRANSFER(diagSouth(BOM_RHS_CV),0_8),
     &       TRANSFER(diagSouth(BOM_RHS_CU),0_8),
     &       TRANSFER(diagSouth(BOM_RHS_DRIFT_E),0_8)
        WRITE(standardMessageUnit,'(A,A,4(1X,Z16.16))')
     &       'P23-RHS-RECORD ','N06   ',negativeCount,0,0,0
      ENDIF
      _END_MASTER(myThid)
#endif

      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_SET_FIXTURE(
     O                 sourceEast,sourceNorth,
     O                 sourceDtEast,sourceDtNorth,
     O                 gradEE,gradNE,gradEN,gradNN,
     O                 alpha,tauValue,rValue,sigma,fCori,tauSphere )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL sourceEast(BOM_ENV_NSOURCE)
      _RL sourceNorth(BOM_ENV_NSOURCE)
      _RL sourceDtEast(BOM_ENV_NSOURCE)
      _RL sourceDtNorth(BOM_ENV_NSOURCE)
      _RL gradEE(BOM_ENV_NSOURCE)
      _RL gradNE(BOM_ENV_NSOURCE)
      _RL gradEN(BOM_ENV_NSOURCE)
      _RL gradNN(BOM_ENV_NSOURCE)
      _RL alpha,tauValue,rValue,sigma,fCori,tauSphere,piValue
      CALL BOM_VERIFY_ZERO_SOURCES(sourceEast,sourceNorth,
     &     sourceDtEast,sourceDtNorth,gradEE,gradNE,gradEN,gradNN)
      sourceEast(BOM_ENV_EULERIAN)=1.2 _d 0
      sourceNorth(BOM_ENV_EULERIAN)=-0.7 _d 0
      sourceEast(BOM_ENV_STOKES)=0.35 _d 0
      sourceNorth(BOM_ENV_STOKES)=0.22 _d 0
      sourceEast(BOM_ENV_WIND)=5.1 _d 0
      sourceNorth(BOM_ENV_WIND)=-2.4 _d 0
      sourceDtEast(BOM_ENV_EULERIAN)=1.1 _d -4
      sourceDtNorth(BOM_ENV_EULERIAN)=-1.3 _d -4
      sourceDtEast(BOM_ENV_STOKES)=-2.0 _d -5
      sourceDtNorth(BOM_ENV_STOKES)=4.0 _d -5
      sourceDtEast(BOM_ENV_WIND)=5.0 _d -5
      sourceDtNorth(BOM_ENV_WIND)=-7.0 _d -5
      gradEE(BOM_ENV_EULERIAN)=2.0 _d -4
      gradNE(BOM_ENV_EULERIAN)=-3.0 _d -4
      gradEN(BOM_ENV_EULERIAN)=4.0 _d -4
      gradNN(BOM_ENV_EULERIAN)=1.0 _d -4
      gradEE(BOM_ENV_STOKES)=-1.0 _d -4
      gradNE(BOM_ENV_STOKES)=2.5 _d -4
      gradEN(BOM_ENV_STOKES)=-3.5 _d -4
      gradNN(BOM_ENV_STOKES)=1.5 _d -4
      gradEE(BOM_ENV_WIND)=5.0 _d -5
      gradNE(BOM_ENV_WIND)=-4.5 _d -4
      gradEN(BOM_ENV_WIND)=2.2 _d -4
      gradNN(BOM_ENV_WIND)=-2.8 _d -4
      alpha=0.00337 _d 0
      tauValue=0.0103 _d 0*86400. _d 0
      rValue=0.823 _d 0
      sigma=1.2 _d 0
      fCori=2.18213 _d 0/86400. _d 0
      piValue=4. _d 0*ATAN(1. _d 0)
      tauSphere=TAN(32. _d 0*piValue/180. _d 0)/6370000. _d 0
      RETURN
      END

      SUBROUTINE BOM_VERIFY_ZERO_SOURCES(
     O                 sourceEast,sourceNorth,
     O                 sourceDtEast,sourceDtNorth,
     O                 gradEE,gradNE,gradEN,gradNN )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL sourceEast(BOM_ENV_NSOURCE)
      _RL sourceNorth(BOM_ENV_NSOURCE)
      _RL sourceDtEast(BOM_ENV_NSOURCE)
      _RL sourceDtNorth(BOM_ENV_NSOURCE)
      _RL gradEE(BOM_ENV_NSOURCE)
      _RL gradNE(BOM_ENV_NSOURCE)
      _RL gradEN(BOM_ENV_NSOURCE)
      _RL gradNN(BOM_ENV_NSOURCE)
      INTEGER iSource
      DO iSource=1,BOM_ENV_NSOURCE
        sourceEast(iSource)=0. _d 0
        sourceNorth(iSource)=0. _d 0
        sourceDtEast(iSource)=0. _d 0
        sourceDtNorth(iSource)=0. _d 0
        gradEE(iSource)=0. _d 0
        gradNE(iSource)=0. _d 0
        gradEN(iSource)=0. _d 0
        gradNN(iSource)=0. _d 0
      ENDDO
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_ORACLE(
     I                 mode,alpha,tauValue,rValue,sigma,
     I                 fCori,tauSphere,sourceEast,sourceNorth,
     I                 sourceDtEast,sourceDtNorth,
     I                 gradEE,gradNE,gradEN,gradNN,
     O                 diag )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) mode
      _RL alpha,tauValue,rValue,sigma,fCori,tauSphere
      _RL sourceEast(BOM_ENV_NSOURCE)
      _RL sourceNorth(BOM_ENV_NSOURCE)
      _RL sourceDtEast(BOM_ENV_NSOURCE)
      _RL sourceDtNorth(BOM_ENV_NSOURCE)
      _RL gradEE(BOM_ENV_NSOURCE)
      _RL gradNE(BOM_ENV_NSOURCE)
      _RL gradEN(BOM_ENV_NSOURCE)
      _RL gradNN(BOM_ENV_NSOURCE)
      _RL diag(BOM_RHS_NDIAG),dse(BOM_ENV_NSOURCE)
      _RL dsn(BOM_ENV_NSOURCE),vort(BOM_ENV_NSOURCE)
      _RL vE,vN,uE,uN,dvE,dvN,duE,duN,omega
      _RL dtVE,dtVN,vEE,vNE,vEN,vNN
      _RL dtUE,dtUN,uEE,uNE,uEN,uNN
      INTEGER iSource
      vE=sourceEast(BOM_ENV_EULERIAN)
     &   +sigma*sourceEast(BOM_ENV_STOKES)
      vN=sourceNorth(BOM_ENV_EULERIAN)
     &   +sigma*sourceNorth(BOM_ENV_STOKES)
      uE=(1. _d 0-alpha)*vE+alpha*sourceEast(BOM_ENV_WIND)
      uN=(1. _d 0-alpha)*vN+alpha*sourceNorth(BOM_ENV_WIND)
      IF ( mode.EQ.'PAPER2024' ) THEN
        dtVE=sourceDtEast(BOM_ENV_EULERIAN)
     &      +sigma*sourceDtEast(BOM_ENV_STOKES)
        dtVN=sourceDtNorth(BOM_ENV_EULERIAN)
     &      +sigma*sourceDtNorth(BOM_ENV_STOKES)
        vEE=gradEE(BOM_ENV_EULERIAN)+sigma*gradEE(BOM_ENV_STOKES)
        vNE=gradNE(BOM_ENV_EULERIAN)+sigma*gradNE(BOM_ENV_STOKES)
        vEN=gradEN(BOM_ENV_EULERIAN)+sigma*gradEN(BOM_ENV_STOKES)
        vNN=gradNN(BOM_ENV_EULERIAN)+sigma*gradNN(BOM_ENV_STOKES)
        dtUE=(1. _d 0-alpha)*dtVE
     &       +alpha*sourceDtEast(BOM_ENV_WIND)
        dtUN=(1. _d 0-alpha)*dtVN
     &       +alpha*sourceDtNorth(BOM_ENV_WIND)
        uEE=(1. _d 0-alpha)*vEE+alpha*gradEE(BOM_ENV_WIND)
        uNE=(1. _d 0-alpha)*vNE+alpha*gradNE(BOM_ENV_WIND)
        uEN=(1. _d 0-alpha)*vEN+alpha*gradEN(BOM_ENV_WIND)
        uNN=(1. _d 0-alpha)*vNN+alpha*gradNN(BOM_ENV_WIND)
        CALL BOM_VERIFY_ORACLE_COV(vE,vN,dtVE,dtVN,
     &       vEE,vNE,vEN,vNN,tauSphere,dvE,dvN,omega)
        CALL BOM_VERIFY_ORACLE_COV(uE,uN,dtUE,dtUN,
     &       uEE,uNE,uEN,uNN,tauSphere,duE,duN,vort(1))
      ELSE
        DO iSource=1,BOM_ENV_NSOURCE
          CALL BOM_VERIFY_ORACLE_COV(
     &         sourceEast(iSource),sourceNorth(iSource),
     &         sourceDtEast(iSource),sourceDtNorth(iSource),
     &         gradEE(iSource),gradNE(iSource),
     &         gradEN(iSource),gradNN(iSource),tauSphere,
     &         dse(iSource),dsn(iSource),vort(iSource))
        ENDDO
        dvE=dse(BOM_ENV_EULERIAN)+sigma*dse(BOM_ENV_STOKES)
        dvN=dsn(BOM_ENV_EULERIAN)+sigma*dsn(BOM_ENV_STOKES)
        duE=(1. _d 0-alpha)*dvE+alpha*dse(BOM_ENV_WIND)
        duN=(1. _d 0-alpha)*dvN+alpha*dsn(BOM_ENV_WIND)
        omega=vort(BOM_ENV_EULERIAN)
      ENDIF
      CALL BOM_VERIFY_ORACLE_FINAL(sourceEast,sourceNorth,
     &     vE,vN,uE,uN,dvE,dvN,duE,duN,omega,
     &     fCori,tauSphere,tauValue,rValue,diag)
      RETURN
      END

      SUBROUTINE BOM_VERIFY_ORACLE_COV(wE,wN,dtE,dtN,
     &     dEE,dNE,dEN,dNN,tauSphere,dSelfE,dSelfN,vorticity)
      IMPLICIT NONE
      _RL wE,wN,dtE,dtN,dEE,dNE,dEN,dNN,tauSphere
      _RL dSelfE,dSelfN,vorticity
      dSelfE=dtE+wE*dEE+wN*dNE-tauSphere*wE*wN
      dSelfN=dtN+wE*dEN+wN*dNN+tauSphere*wE*wE
      vorticity=dEN-dNE+tauSphere*wE
      RETURN
      END

      SUBROUTINE BOM_VERIFY_ORACLE_FINAL(sourceEast,sourceNorth,
     &     vE,vN,uE,uN,dvE,dvN,duE,duN,omega,
     &     fCori,tauSphere,tauValue,rValue,diag)
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL sourceEast(BOM_ENV_NSOURCE),sourceNorth(BOM_ENV_NSOURCE)
      _RL vE,vN,uE,uN,dvE,dvN,duE,duN,omega
      _RL fCori,tauSphere,tauValue,rValue,diag(BOM_RHS_NDIAG)
      _RL cV,cU,rotVE,rotVN,rotUE,rotUN,inertE,inertN
      INTEGER iDiag
      DO iDiag=1,BOM_RHS_NDIAG
        diag(iDiag)=0. _d 0
      ENDDO
      cV=fCori+omega/3. _d 0
      cU=fCori+tauSphere*uE+rValue*omega/3. _d 0
      rotVE=-rValue*cV*vN
      rotVN=rValue*cV*vE
      rotUE=cU*uN
      rotUN=-cU*uE
      inertE=rValue*dvE+rotVE-duE+rotUE
      inertN=rValue*dvN+rotVN-duN+rotUN
      diag(BOM_RHS_VBASE_E)=sourceEast(BOM_ENV_EULERIAN)
      diag(BOM_RHS_VBASE_N)=sourceNorth(BOM_ENV_EULERIAN)
      diag(BOM_RHS_VS_E)=sourceEast(BOM_ENV_STOKES)
      diag(BOM_RHS_VS_N)=sourceNorth(BOM_ENV_STOKES)
      diag(BOM_RHS_VW_E)=sourceEast(BOM_ENV_WIND)
      diag(BOM_RHS_VW_N)=sourceNorth(BOM_ENV_WIND)
      diag(BOM_RHS_V_E)=vE
      diag(BOM_RHS_V_N)=vN
      diag(BOM_RHS_U_E)=uE
      diag(BOM_RHS_U_N)=uN
      diag(BOM_RHS_DV_E)=dvE
      diag(BOM_RHS_DV_N)=dvN
      diag(BOM_RHS_DU_E)=duE
      diag(BOM_RHS_DU_N)=duN
      diag(BOM_RHS_OMEGA)=omega
      diag(BOM_RHS_FCORI)=fCori
      diag(BOM_RHS_TAUSPHERE)=tauSphere
      diag(BOM_RHS_CV)=cV
      diag(BOM_RHS_CU)=cU
      diag(BOM_RHS_ROT_VE)=rotVE
      diag(BOM_RHS_ROT_VN)=rotVN
      diag(BOM_RHS_ROT_UE)=rotUE
      diag(BOM_RHS_ROT_UN)=rotUN
      diag(BOM_RHS_INERT_E)=inertE
      diag(BOM_RHS_INERT_N)=inertN
      diag(BOM_RHS_DRIFT_E)=uE+tauValue*inertE
      diag(BOM_RHS_DRIFT_N)=uN+tauValue*inertN
      RETURN
      END

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|
      SUBROUTINE BOM_VERIFY_EXPECT_FAIL(
     I                 equationMode,currentPolicy,hasStokes,rhsStage,
     I                 trialDt,recipDx,recipDy,advCFL,
     I                 alpha,tauValue,rValue,sigma,fCori,tauSphere,
     I                 sourceEast,sourceNorth,
     I                 sourceDtEast,sourceDtNorth,
     I                 gradEE,gradNE,
     I                 gradEN,gradNN,
     I                 expectedCode,bi,bj,
     U                 nFail,negativeCount,myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      CHARACTER*(*) equationMode,currentPolicy
      LOGICAL hasStokes
      INTEGER rhsStage,expectedCode,bi,bj,nFail,negativeCount,myThid
      _RL trialDt,recipDx,recipDy,advCFL
      _RL alpha,tauValue,rValue,sigma,fCori,tauSphere
      _RL sourceEast(BOM_ENV_NSOURCE)
      _RL sourceNorth(BOM_ENV_NSOURCE)
      _RL sourceDtEast(BOM_ENV_NSOURCE)
      _RL sourceDtNorth(BOM_ENV_NSOURCE)
      _RL gradEE(BOM_ENV_NSOURCE)
      _RL gradNE(BOM_ENV_NSOURCE)
      _RL gradEN(BOM_ENV_NSOURCE)
      _RL gradNN(BOM_ENV_NSOURCE)
      _RL diag(BOM_RHS_NDIAG),stageCFL
      INTEGER failCode,failStage,iDiag
      LOGICAL rhsValid,stokesApplied,diagZero,stateSame,condition
      CALL BOM_RHS_COMPONENTS(equationMode,currentPolicy,hasStokes,
     &     rhsStage,trialDt,recipDx,recipDy,advCFL,
     &     alpha,tauValue,rValue,sigma,fCori,tauSphere,
     &     sourceEast,sourceNorth,sourceDtEast,sourceDtNorth,
     &     gradEE,gradNE,gradEN,gradNN,
     &     diag,stageCFL,stokesApplied,failCode,failStage,rhsValid)
      diagZero=.TRUE.
      DO iDiag=1,BOM_RHS_NDIAG
        diagZero=diagZero .AND. diag(iDiag).EQ.0. _d 0
      ENDDO
      stateSame=bomNPartTile(bi,bj).EQ.1
     &     .AND. bomStatus(1,bi,bj).EQ.BOM_ALIVE
     &     .AND. bomId(1,bi,bj).EQ.2300000000001_8
     &     .AND. bomX(1,bi,bj).EQ.12.5 _d 0
     &     .AND. bomY(1,bi,bj).EQ.-7.25 _d 0
     &     .AND. bomAge(1,bi,bj).EQ.44. _d 0
     &     .AND. bomI(1,bi,bj).EQ.2.25 _d 0
     &     .AND. bomJ(1,bi,bj).EQ.1.75 _d 0
     &     .AND. bomVEast(1,bi,bj).EQ.8.5 _d 0
     &     .AND. bomVNorth(1,bi,bj).EQ.-4.5 _d 0
     &     .AND. bomDriftEast(1,bi,bj).EQ.6.5 _d 0
     &     .AND. bomDriftNorth(1,bi,bj).EQ.-3.5 _d 0
      condition=.NOT.rhsValid .AND. failCode.EQ.expectedCode
     &     .AND. failStage.EQ.rhsStage .AND. diagZero .AND. stateSame
      IF ( expectedCode.EQ.BOM_FAIL_CFL )
     &     condition=condition .AND. stageCFL.GT.0. _d 0
      IF ( .NOT.condition ) THEN
        WRITE(standardMessageUnit,'(A,5I6,4L3,1PE16.8)')
     &       'P23-NEGATIVE-DETAIL ',negativeCount+1,
     &       expectedCode,failCode,rhsStage,failStage,
     &       rhsValid,diagZero,stateSame,stokesApplied,stageCFL
      ENDIF
      CALL BOM_VERIFY_ASSERT(condition,
     &     'H06/N06 expected failure and rollback',nFail,myThid)
      negativeCount=negativeCount+1
      RETURN
      END

      SUBROUTINE BOM_VERIFY_DIAG_CLOSE(
     I                 actual,expected,label,
     U                 nFail,myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL actual(BOM_RHS_NDIAG),expected(BOM_RHS_NDIAG),tol
      CHARACTER*(*) label
      INTEGER nFail,myThid,iDiag
      LOGICAL close
      close=.TRUE.
      DO iDiag=1,BOM_RHS_NDIAG
        tol=1024. _d 0*EPSILON(oneRL)
     &       *MAX(1. _d 0,ABS(actual(iDiag)),ABS(expected(iDiag)))
        close=close .AND. ABS(actual(iDiag)-expected(iDiag)).LE.tol
      ENDDO
      CALL BOM_VERIFY_ASSERT(close,label,nFail,myThid)
      RETURN
      END

      SUBROUTINE BOM_VERIFY_DERIVED_CLOSE(
     I                 actual,expected,label,
     U                 nFail,myThid )
      IMPLICIT NONE
#include "SIZE.h"
#include "EEPARAMS.h"
#include "BOM_SIZE.h"
#include "BOM.h"
      _RL actual(BOM_RHS_NDIAG),expected(BOM_RHS_NDIAG),tol
      CHARACTER*(*) label
      INTEGER nFail,myThid,iDiag
      LOGICAL close
      close=.TRUE.
      DO iDiag=BOM_RHS_V_E,BOM_RHS_DRIFT_N
        tol=1024. _d 0*EPSILON(oneRL)
     &       *MAX(1. _d 0,ABS(actual(iDiag)),ABS(expected(iDiag)))
        close=close .AND. ABS(actual(iDiag)-expected(iDiag)).LE.tol
      ENDDO
      CALL BOM_VERIFY_ASSERT(close,label,nFail,myThid)
      RETURN
      END

      SUBROUTINE BOM_VERIFY_ASSERT(condition,label,nFail,myThid)
      IMPLICIT NONE
#include "EEPARAMS.h"
      LOGICAL condition
      CHARACTER*(*) label
      INTEGER nFail,myThid
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      IF ( .NOT.condition ) THEN
        IF ( nFail.LT.24 ) THEN
          WRITE(msgBuf,'(2A)')
     &       'BOM_VERIFY_RHS_COMPONENTS: FAIL: ',label
          CALL PRINT_ERROR(msgBuf,myThid)
        ENDIF
        nFail=nFail+1
      ENDIF
      RETURN
      END
