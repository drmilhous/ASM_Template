; I/O helpers for Windows ARM64 (armasm64), written in assembly.
;   print_int    : w0 = integer to print
;   print_nl     : prints a newline
;   print_string : x0 = address of a zero-terminated string
; Each one calls the C runtime's printf (linked via legacy_stdio_definitions.lib).
    AREA    |.text|, CODE, READONLY, ALIGN=4
    EXPORT  print_int
    EXPORT  print_nl
    EXPORT  print_string
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

    AREA    |.rdata|, DATA, READONLY
fmtInt  DCB     "%d", 0
fmtNl   DCB     10, 0
fmtStr  DCB     "%s", 0

    END
