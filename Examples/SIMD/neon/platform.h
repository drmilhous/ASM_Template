/* Clang/GNU assembly preprocessing; Microsoft armasm64 syntax is different. */
#ifdef __APPLE__
#define ASM_MAIN _asm_main
#else
#define ASM_MAIN asm_main
#endif

#ifdef __APPLE__
#define OP _simd_operation
#define DATA_A _demo_a
#define DATA_B _demo_b
#define DATA_OUT _demo_out
#define DATA_N _demo_count
#else
#define OP simd_operation
#define DATA_A demo_a
#define DATA_B demo_b
#define DATA_OUT demo_out
#define DATA_N demo_count
#endif

// Load a symbol's address, not its contents. Relocations vary by object format.
.macro ADDRESS reg, symbol
#ifdef __APPLE__
    adrp \reg, \symbol@PAGE
    add \reg, \reg, \symbol@PAGEOFF
#else
    adrp \reg, \symbol
    add \reg, \reg, :lo12:\symbol
#endif
.endm
