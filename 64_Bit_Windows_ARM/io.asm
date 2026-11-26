; I/O helpers for Windows ARM64 (armasm64), written in assembly.
;   print_int    : w0 = integer to print
;   print_nl     : prints a newline
;   print_string : x0 = address of a zero-terminated string
;   print_float  : d0 = double to print (printf "%f")
;   read_int     : reads one line, returns it as a signed decimal number in w0 (sign-extended into x0)
;   read_float   : reads one line, returns it as a double in d0
;   read_string  : x0 = buffer address, x1 = buffer size in bytes (including the terminating 0).
;                  Reads one line; the newline is removed and the string is always zero-terminated.
;                  Returns x0 = number of characters stored, or -1 at end of input (buffer = "").
;                  Characters that do not fit are thrown away, so the next read starts on a new line.
; All three readers take a whole line, so you can mix them freely. Input that is not a number
; gives 0 / 0.0. These follow the normal ARM64 rules: x0-x18 and v0-v7 (d0..) may change,
; x19-x28 are kept.
; Each one calls the C runtime (printf via legacy_stdio_definitions.lib, fgets, strtol, strtod).
    AREA    |.text|, CODE, READONLY, ALIGN=4
    EXPORT  print_int
    EXPORT  print_nl
    EXPORT  print_string
    EXPORT  print_float
    EXPORT  read_int
    EXPORT  read_float
    EXPORT  read_string
    IMPORT  printf
    IMPORT  fgets
    IMPORT  getchar
    IMPORT  strlen
    IMPORT  strtol
    IMPORT  strtod
    IMPORT  __acrt_iob_func         ; __acrt_iob_func(0) is stdin in the Universal C Runtime

READ_LINE_SIZE EQU 256

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
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    fmov    x1, d0                  ; Windows ARM64 passes variadic doubles in integer registers
    adrp    x0, fmtFloat
    add     x0, x0, fmtFloat
    bl      printf
    ldp     fp, lr, [sp], #16
    ret
    ENDP

read_int PROC
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    adrp    x0, readLine
    add     x0, x0, readLine
    mov     x1, #READ_LINE_SIZE
    bl      read_string
    adrp    x0, readLine
    add     x0, x0, readLine
    mov     x1, #0                  ; no end pointer
    mov     w2, #10                 ; base 10
    bl      strtol                  ; long is 32 bits on Windows
    sxtw    x0, w0
    ldp     fp, lr, [sp], #16
    ret
    ENDP

read_float PROC
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    adrp    x0, readLine
    add     x0, x0, readLine
    mov     x1, #READ_LINE_SIZE
    bl      read_string
    adrp    x0, readLine
    add     x0, x0, readLine
    mov     x1, #0
    bl      strtod                  ; result in d0
    ldp     fp, lr, [sp], #16
    ret
    ENDP

read_string PROC
    stp     fp, lr, [sp, #-32]!
    mov     fp, sp
    stp     x19, x20, [sp, #16]
    mov     x19, x0                 ; buffer
    mov     x20, x1                 ; size
    mov     x0, #0
    cmp     x20, #1
    b.lt    rs_return               ; no room at all: read nothing
    movz    x2, #0xFFFF
    movk    x2, #0x7FFF, lsl #16
    cmp     x20, x2
    csel    x20, x20, x2, ls        ; fgets takes an int size
    mov     w0, #0
    bl      __acrt_iob_func         ; x0 = stdin
    mov     x2, x0
    mov     x0, x19
    mov     w1, w20
    bl      fgets
    cbz     x0, rs_eof
    mov     x0, x19
    bl      strlen
    mov     x20, x0                 ; x20 = length from here on
    cbz     x20, rs_discard         ; buffer of size 1: nothing fit
    sub     x1, x20, #1
    ldrb    w2, [x19, x1]
    cmp     w2, #10
    b.ne    rs_discard              ; no newline: the line was longer than the buffer
    mov     x20, x1
    strb    wzr, [x19, x20]
    b       rs_strip_cr
rs_discard                          ; throw away the rest of the line
    bl      getchar
    cmp     w0, #10
    b.eq    rs_strip_cr
    cmn     w0, #1
    b.ne    rs_discard
rs_strip_cr                         ; a CRLF file read in binary mode leaves a \r
    cbz     x20, rs_length
    sub     x1, x20, #1
    ldrb    w2, [x19, x1]
    cmp     w2, #13
    b.ne    rs_length
    mov     x20, x1
    strb    wzr, [x19, x20]
rs_length
    mov     x0, x20
rs_return
    ldp     x19, x20, [sp, #16]
    ldp     fp, lr, [sp], #32
    ret
rs_eof
    strb    wzr, [x19]
    mov     x0, #-1
    b       rs_return
    ENDP

    AREA    |.rdata|, DATA, READONLY
fmtInt   DCB     "%d", 0
fmtNl    DCB     10, 0
fmtStr   DCB     "%s", 0
fmtFloat DCB     "%f", 0

    AREA    |.bss|, NOINIT, READWRITE, ALIGN=3
readLine SPACE   READ_LINE_SIZE     ; line buffer for read_int / read_float

    END
