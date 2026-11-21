/* platform.h: glue between these examples and the ASM_Template I/O library (io.asm).
 * Each example is the usual template program: it defines asm_main, and driver.c's main() calls it.
 * The library (written in NASM, built to io.o) supplies print_int, print_string and print_nl, so a
 * GNU as program can link against it like any other object file.
 *
 * The library for each platform is built from the template folder:
 *   Linux    64_Bit_Intel/io.asm      value or pointer to print is passed in RAX
 *   macOS    M1_Mac/io.asm            value or pointer to print is passed in RDI
 *   Windows  64_Bit_Windows/io.asm    value or pointer to print is passed in RAX
 * The macros below hide that difference (and the underscore macOS puts in front of C names).
 *
 * The files are named .S (capital S): gcc and clang run the C preprocessor over them first, then
 * hand the result to GNU as, so comments use C style.
 *
 * The library has no floating point output, so the examples convert a float to a whole number
 * with cvttss2si and print that. All the example data is chosen so the results are whole numbers.
 *
 * Library calls clobber the caller-saved registers (printf runs inside them), so loop counters
 * that live across a print are kept in callee-saved registers (rbx, r12, r13 ...).
 */
#if defined(__APPLE__)
#define ASM_MAIN _asm_main
#define LIBARG   %rdi
#define LIBARG32 %edi
#else
#define ASM_MAIN asm_main
#define LIBARG   %rax
#define LIBARG32 %eax
#endif

#ifdef __ELF__
#define GNU_STACK_NOTE .section .note.GNU-stack,"",@progbits
#else
#define GNU_STACK_NOTE
#endif

/* PRINT_INT x   : print the 32-bit value x (register or $number) in decimal
 * PRINT_STR sym : print the zero-terminated string at label sym
 * PRINT_PTR reg : print the zero-terminated string whose address is in reg
 * PRINT_NL      : print a newline */
.macro PRINT_INT src
    mov \src, LIBARG32
    call print_int
.endm
.macro PRINT_STR sym
    lea \sym(%rip), LIBARG
    call print_string
.endm
.macro PRINT_PTR reg
    mov \reg, LIBARG
    call print_string
.endm
.macro PRINT_NL
    call print_nl
.endm
