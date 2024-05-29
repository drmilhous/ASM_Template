.global _foo	            // Provide program starting address
.global _floater
.global _asm_main
.align 4
.text

_asm_main:
    stp	x29, x30, [sp, #-16]!
    mov	x29, sp
    adrp 	X0, hello@PAGE // printf format str
	add		X0, X0, hello@PAGEOFF
    bl	_printf
    mov	x0, #0
    ldp	x29, x30, [sp], #16
    RET

.data
LC2:
        //.word   1036831949
		.float 1.1
hello: .asciz "Hello World\n"

.align 4
.text