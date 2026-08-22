#ifndef BOM_OPTIONS_H
#define BOM_OPTIONS_H
#include "PACKAGES_CONFIG.h"
#include "CPP_OPTIONS.h"

CBOP
C !ROUTINE: BOM_OPTIONS.h
C !INTERFACE:
C #include "BOM_OPTIONS.h"

C !DESCRIPTION:
C *==================================================================*
C | CPP options for the MITGCM-BOM package.
C | Phase 0 contains a compile-only, zero-particle package skeleton.
C *==================================================================*
CEOP

#ifdef ALLOW_BOM
C     EXCH2 support remains disabled until dedicated topology tests exist.
#undef ALLOW_BOM_EXCH2
#endif /* ALLOW_BOM */

#endif /* BOM_OPTIONS_H */
