/* platform.h: glue between these ARM64 examples and the ASM_Template I/O library.
 * Each example is the usual template program: it defines asm_main, and the template's driver.c
 * main() calls it. Output goes through the template's library for the platform:
 *   Linux ARM64     64_Bit_ARM/io.s              (GNU as syntax, ELF)
 *   macOS (M1...)   M1_Mac/io_arm.s              (Mach-O: C names get a leading underscore,
 *                                                  addresses use @PAGE / @PAGEOFF)
 *   Windows ARM64   64_Bit_Windows_ARM/io_c_fallback.c   (C version of the same routines,
 *                                                  compiled with clang; the armasm64 io.asm
 *                                                  is for armasm64 projects)
 * Library routines: print_int (w0), print_string (x0 = address), print_float (d0), print_nl.
 *
 * The files are named .S (capital S): clang and gcc run the C preprocessor over them first,
 * then the GNU-syntax assembler, so comments use C style.
 *
 * Library calls clobber the caller-saved registers (x0-x17, v0-v7), because printf runs inside
 * them. Anything that has to survive a print lives in x19-x28 (callee-saved: save them with
 * stp/ldp) or in a stack slot.
 */
#if defined(__APPLE__)
#define ASM_MAIN      _asm_main
#define L_PRINT_INT   _print_int
#define L_PRINT_STR   _print_string
#define L_PRINT_FLOAT _print_float
#define L_PRINT_NL    _print_nl
#else
#define ASM_MAIN      asm_main
#define L_PRINT_INT   print_int
#define L_PRINT_STR   print_string
#define L_PRINT_FLOAT print_float
#define L_PRINT_NL    print_nl
#endif

#if defined(__ELF__)
#define GNU_STACK_NOTE .section .note.GNU-stack,"",%progbits
#else
#define GNU_STACK_NOTE
#endif

/* ADDR reg, sym : reg = address of a global or local symbol (always PC-relative, two instructions) */
.macro ADDR reg, sym
#if defined(__APPLE__)
    adrp \reg, \sym@PAGE
    add  \reg, \reg, \sym@PAGEOFF
#else
    adrp \reg, \sym
    add  \reg, \reg, :lo12:\sym
#endif
.endm

/* PRINT_INT wN   : print the 32-bit value in register wN in decimal
 * PRINT_STR sym  : print the zero-terminated string at label sym
 * PRINT_FLOAT    : print the double in d0 (the library keeps d0 intact, but only if it is the asm one)
 * PRINT_NL       : print a newline */
.macro PRINT_INT reg
    mov  w0, \reg
    bl   L_PRINT_INT
.endm
.macro PRINT_STR sym
    ADDR x0, \sym
    bl   L_PRINT_STR
.endm
.macro PRINT_FLOAT
    bl   L_PRINT_FLOAT
.endm
.macro PRINT_NL
    bl   L_PRINT_NL
.endm
