; Windows ARM64 template (armasm64 syntax).  Build with: .\quickBuild.ps1
    AREA    |.text|, CODE, READONLY, ALIGN=4
    EXPORT  asm_main
    IMPORT  print_int
    IMPORT  print_nl
    IMPORT  print_string

asm_main PROC
    stp     fp, lr, [sp, #-16]!     ; prolog
    mov     fp, sp
    ;***************CODE STARTS HERE***************************

    adrp    x0, hello
    add     x0, x0, hello
    bl      print_string            ; prints the string whose address is in x0
    mov     w0, #42
    bl      print_int               ; prints the int in w0
    bl      print_nl

    mov     w0, #0                  ; return value (0 = success)
    ;***************CODE ENDS HERE*****************************
    ldp     fp, lr, [sp], #16       ; epilog
    ret
    ENDP

    AREA    |.rdata|, DATA, READONLY
hello   DCB     "Hello World", 0

    END
