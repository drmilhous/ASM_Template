/* platform.h: small portability layer so the same GNU as source assembles for
 *   Linux (System V ABI), macOS Intel (System V ABI, C symbols get a leading
 *   underscore) and Windows x64 (Microsoft x64 ABI, MinGW or clang).
 * The files are named .S (capital S): gcc and clang run the C preprocessor over
 * them first, then hand the result to GNU as. Comments therefore use C style.
 * Only the ABI details these examples touch are covered:
 *   - which registers carry the first printf arguments
 *   - the 32-byte shadow space the Windows ABI wants below every call
 *   - how a double is passed to a variadic function such as printf
 *   - symbol names and the ELF-only .note.GNU-stack section
 */
#if defined(_WIN32)
#define WINDOWS 1
#define MAIN main
#define PRINTF printf
#define ARG1  %rcx
#define ARG2  %rdx
#define ARG2D %edx
#elif defined(__APPLE__)
#define MACOS 1
#define MAIN _main
#define PRINTF _printf
#define ARG1  %rdi
#define ARG2  %rsi
#define ARG2D %esi
#else
#define MAIN main
#define PRINTF printf@PLT      /* through the PLT: works with PIE executables */
#define ARG1  %rdi
#define ARG2  %rsi
#define ARG2D %esi
#endif

#ifdef __ELF__
#define GNU_STACK_NOTE .section .note.GNU-stack,"",@progbits
#else
#define GNU_STACK_NOTE
#endif

/* CCALL fn: call a C function with the stack set up for the platform.
 * Windows needs 32 bytes of shadow space; adding 32 keeps the 16-byte alignment. */
#ifdef WINDOWS
.macro CCALL fn
    sub $32, %rsp
    call \fn
    add $32, %rsp
.endm
/* DOUBLE_ARG2 / DOUBLE_ARG3: the double in xmm0 becomes the 2nd / 3rd argument of printf.
 * System V: it simply stays in xmm0 (and eax = number of vector registers used).
 * Windows: a variadic double travels in BOTH the xmm register and the matching integer register. */
.macro DOUBLE_ARG2
    movapd %xmm0, %xmm1
    movq %xmm0, %rdx
.endm
.macro DOUBLE_ARG3
    movapd %xmm0, %xmm2
    movq %xmm0, %r8
.endm
#else
.macro CCALL fn
    call \fn
.endm
.macro DOUBLE_ARG2
.endm
.macro DOUBLE_ARG3
.endm
#endif
