// Clang/GNU assembly. Q/V views share storage; these examples target ARM64.
#ifdef __APPLE__
#define MAIN _asm_main
#define OP _re_operation
#define INPUT _demo_input
#define OUTPUT _demo_output
#else
#define MAIN asm_main
#define OP re_operation
#define INPUT demo_input
#define OUTPUT demo_output
#endif
.macro ADDRESS reg, symbol
#ifdef __APPLE__
 adrp \reg, \symbol@PAGE
 add \reg, \reg, \symbol@PAGEOFF
#else
 adrp \reg, \symbol
 add \reg, \reg, :lo12:\symbol
#endif
.endm
