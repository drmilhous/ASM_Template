; platform.inc: glue between these examples and the ASM_Template I/O library (io.asm / io.inc).
; Each example is the usual template program: it defines asm_main, and driver.c's main() calls it.
; The library supplies print_int, print_string and print_nl, so there is no printf in the examples.
;
; The library for each platform is built from the template folder:
;   Linux    64_Bit_Intel/io.asm      (elf64)    value or pointer to print is passed in RAX
;   macOS    M1_Mac/io.asm            (macho64)  value or pointer to print is passed in RDI
;   Windows  64_Bit_Windows/io.asm    (win64)    value or pointer to print is passed in RAX
; The macros below hide that difference (and the underscore macOS puts in front of C names).
;
; Floats are printed with print_float, which takes a double in xmm0 (like printf "%f"); the
; examples widen a single-precision float with cvtss2sd first.
;
; Library calls clobber the caller-saved registers (printf runs inside them), so loop counters
; that live across a print are kept in callee-saved registers (rbx, r12, r13 ...).

%include "io.inc"

%ifidn __OUTPUT_FORMAT__, macho64
  %define ASM_MAIN _asm_main
  %define LIBARG   rdi
  %define LIBARG32 edi
%else
  %define ASM_MAIN asm_main
  %define LIBARG   rax
  %define LIBARG32 eax
%endif

; PRINT_INT x   : print the 32-bit value x (register or number) in decimal
; PRINT_STR lbl : print the zero-terminated string at label lbl
; PRINT_PTR reg : print the zero-terminated string whose address is in reg
; PRINT_FLOAT   : print the double in xmm0 (the library keeps xmm0 intact)
; PRINT_NL      : print a newline
%macro PRINT_INT 1
    mov LIBARG32, %1
    call print_int
%endmacro
%macro PRINT_STR 1
    lea LIBARG, [%1]
    call print_string
%endmacro
%macro PRINT_PTR 1
    mov LIBARG, %1
    call print_string
%endmacro
%macro PRINT_FLOAT 0
    call print_float
%endmacro
%macro PRINT_NL 0
    call print_nl
%endmacro

; Only ELF wants this marker (it says the stack does not need to be executable).
%macro GNU_STACK_NOTE 0
  %ifidn __OUTPUT_FORMAT__, elf64
    section .note.GNU-stack noalloc noexec nowrite progbits
  %endif
%endmacro
