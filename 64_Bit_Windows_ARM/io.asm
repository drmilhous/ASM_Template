; I/O helpers for Windows ARM64 (armasm64), written in assembly.
;   print_int    : w0 = integer to print
;   print_nl     : prints a newline
;   print_string : x0 = address of a zero-terminated string
;   print_float  : d0 = double to print (printf "%f"); keeps x0, x1 and d0
; Each one calls the C runtime's printf (linked via legacy_stdio_definitions.lib).
    AREA    |.text|, CODE, READONLY, ALIGN=4
    EXPORT  print_int
    EXPORT  print_nl
    EXPORT  print_string
    EXPORT  print_float
    IMPORT  printf

print_int PROC
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    mov     w1, w0
    adrp    x0, fmtInt
    add     x0, x0, fmtInt
    bl      printf
    ldp     fp, lr, [sp], #16
    ret
    ENDP

print_nl PROC
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    adrp    x0, fmtNl
    add     x0, x0, fmtNl
    bl      printf
    ldp     fp, lr, [sp], #16
    ret
    ENDP

print_string PROC
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    mov     x1, x0
    adrp    x0, fmtStr
    add     x0, x0, fmtStr
    bl      printf
    ldp     fp, lr, [sp], #16
    ret
    ENDP

print_float PROC
    stp     fp, lr, [sp, #-48]!
    mov     fp, sp
    stp     x0, x1, [sp, #16]
    str     d0, [sp, #32]           ; keep d0 for the caller
    fmov    x1, d0                  ; Windows ARM64: variadic floating point arguments travel in integer registers
    adrp    x0, fmtFlt
    add     x0, x0, fmtFlt
    bl      printf
    ldr     d0, [sp, #32]
    ldp     x0, x1, [sp, #16]
    ldp     fp, lr, [sp], #48
    ret
    ENDP

    AREA    |.rdata|, DATA, READONLY
fmtInt  DCB     "%d", 0
fmtNl   DCB     10, 0
fmtStr  DCB     "%s", 0
fmtFlt  DCB     "%f", 0

    END
