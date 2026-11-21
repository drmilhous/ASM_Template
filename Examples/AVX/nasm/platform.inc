; platform.inc: small portability layer so the same source assembles for
;   nasm -f elf64    Linux   (System V ABI)
;   nasm -f macho64  macOS   (System V ABI, C symbols get a leading underscore)
;   nasm -f win64    Windows (Microsoft x64 ABI)
; Only the ABI details that these examples touch are covered:
;   - which registers carry the first printf arguments
;   - the 32-byte "shadow space" the Windows ABI wants below every call
;   - how a double is passed to a variadic function such as printf
;   - symbol names, and the ELF-only .note.GNU-stack section

%ifidn __OUTPUT_FORMAT__, win64
  %define WINDOWS
  %define MAIN main
  %define PRINTF printf
  %define ARG1  rcx
  %define ARG2  rdx
  %define ARG2D edx
%elifidn __OUTPUT_FORMAT__, macho64
  %define MACOS
  %define MAIN _main
  %define PRINTF _printf
  %define ARG1  rdi
  %define ARG2  rsi
  %define ARG2D esi
%else
  %define MAIN main
  %define PRINTF printf
  %define ARG1  rdi
  %define ARG2  rsi
  %define ARG2D esi
%endif

; CCALL fn: call a C function with the stack set up for the platform.
; Windows needs 32 bytes of shadow space; adding 32 keeps the 16-byte alignment.
%macro CCALL 1
  extern %1
  %ifdef WINDOWS
    sub rsp, 32
    call %1
    add rsp, 32
  %elifdef MACOS
    call %1
  %else
    call %1 wrt ..plt               ; Linux: through the PLT, works with PIE executables
  %endif
%endmacro

; DOUBLE_ARG2 / DOUBLE_ARG3: the double in xmm0 becomes the 2nd / 3rd argument of printf.
; System V: it simply stays in xmm0 (and eax = number of vector registers used).
; Windows: a variadic double travels in BOTH the xmm register and the matching integer register.
%macro DOUBLE_ARG2 0
  %ifdef WINDOWS
    movapd xmm1, xmm0
    movq rdx, xmm0
  %endif
%endmacro
%macro DOUBLE_ARG3 0
  %ifdef WINDOWS
    movapd xmm2, xmm0
    movq r8, xmm0
  %endif
%endmacro

; Only ELF wants this marker (it says the stack does not need to be executable).
%macro GNU_STACK_NOTE 0
  %ifidn __OUTPUT_FORMAT__, elf64
    section .note.GNU-stack noalloc noexec nowrite progbits
  %endif
%endmacro
