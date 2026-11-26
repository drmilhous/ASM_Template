; Platform names and ABI arguments for void operation(uint32_t *in, uint32_t *out).
%ifidn __OUTPUT_FORMAT__, macho64
 %define MAIN _asm_main
 %define OP _re_operation
 %define INPUT _demo_input
 %define OUTPUT _demo_output
%else
 %define MAIN asm_main
 %define OP re_operation
 %define INPUT demo_input
 %define OUTPUT demo_output
%endif
%ifidn __OUTPUT_FORMAT__, win64
 %define ARG_IN rcx
 %define ARG_OUT rdx
%else
 %define ARG_IN rdi
 %define ARG_OUT rsi
%endif
