.global asm_main
.align 4
.text
.extern print_int

asm_main:
    stp	x29, x30, [sp, #-16]!
    mov	x29, sp
    adrp x0, hello
    add x0, x0, :lo12:hello
    bl	printf
    ldr x0, =hello
    bl printf
   ldr w0, =42
    bl print_int
    mov	x0, #0
    ldp	x29, x30, [sp], #16
    RET

.data
LC2:
a:        .word   1036831949
b:       .float 1.1
hello: .asciz "Hello World\n"

.align 4
.text
