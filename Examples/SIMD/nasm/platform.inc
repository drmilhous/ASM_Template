; C ABI arguments for leaf kernels. Use only volatile registers on both ABIs.
%ifidn __OUTPUT_FORMAT__, macho64
 %define ASM_MAIN _asm_main
 %define FEATURES _simd_features
%else
 %define ASM_MAIN asm_main
 %define FEATURES simd_features
%endif
%ifidn __OUTPUT_FORMAT__, win64
 %define A rcx
 %define B rdx
 %define OUT r8
 %define COUNT r9
%else
 %define A rdi
 %define B rsi
 %define OUT rdx
 %define COUNT rcx
%endif
%macro NOTE 0
 %ifidn __OUTPUT_FORMAT__, elf64
 section .note.GNU-stack noalloc noexec nowrite progbits
 %endif
%endmacro

; C-visible symbol names differ only by the Mach-O leading underscore.
%ifidn __OUTPUT_FORMAT__, macho64
 %define OP _simd_operation
 %define DATA_A _demo_a
 %define DATA_B _demo_b
 %define DATA_OUT _demo_out
 %define DATA_N _demo_count
%else
 %define OP simd_operation
 %define DATA_A demo_a
 %define DATA_B demo_b
 %define DATA_OUT demo_out
 %define DATA_N demo_count
%endif
