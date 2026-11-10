; Windows ARM64 (armasm64): C runtime (UCRT) calls from assembly, plus the Win32 process API.
; Build + run: .\quickBuild.ps1
; Convention (ARM64 Windows): args X0..X7 then the stack, result X0, SP 16-byte aligned,
;   X19-X28 preserved, X18 reserved (never use it).  Variadic calls (printf) pass their
;   extra arguments in X1..X7 exactly like normal arguments.
; Shows: 1. fopen/fwrite/fread/fclose   2. malloc/free
;        3. create a process: CreateProcessA + WaitForSingleObject + GetExitCodeProcess
;           (Windows has no fork/exec; one call both creates and starts the child)
;        4. VirtualAlloc executable memory, copy machine code into it and call it
;           (FlushInstructionCache is required on ARM after writing code)
    AREA    |.text|, CODE, READONLY, ALIGN=4
    EXPORT  main
    IMPORT  puts
    IMPORT  printf
    IMPORT  fopen
    IMPORT  fwrite
    IMPORT  fread
    IMPORT  fclose
    IMPORT  fflush
    IMPORT  malloc
    IMPORT  free
    IMPORT  CreateProcessA
    IMPORT  WaitForSingleObject
    IMPORT  GetExitCodeProcess
    IMPORT  CloseHandle
    IMPORT  VirtualAlloc
    IMPORT  VirtualFree
    IMPORT  GetCurrentProcess
    IMPORT  FlushInstructionCache

main PROC
    stp     fp, lr, [sp, #-48]!
    mov     fp, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]

    ; 1. stdio
    adrp    x0, h1
    add     x0, x0, h1
    bl      puts
    adrp    x0, path
    add     x0, x0, path
    adrp    x1, wmode
    add     x1, x1, wmode
    bl      fopen
    cbz     x0, fail
    mov     x19, x0                     ; FILE*
    mov     x3, x0                      ; fwrite(ptr, size, count, stream)
    adrp    x0, text
    add     x0, x0, text
    mov     x1, #1
    mov     x2, #20                     ; length of text
    bl      fwrite
    mov     x0, x19
    bl      fclose
    adrp    x0, path
    add     x0, x0, path
    adrp    x1, rmode
    add     x1, x1, rmode
    bl      fopen
    cbz     x0, fail
    mov     x19, x0
    mov     x3, x0                      ; fread(ptr, size, count, stream)
    adrp    x0, buf
    add     x0, x0, buf
    mov     x1, #1
    mov     x2, #63
    bl      fread
    mov     x20, x0                     ; bytes read
    adrp    x1, buf
    add     x1, x1, buf
    strb    wzr, [x1, x20]              ; zero terminator
    mov     x0, x19
    bl      fclose
    adrp    x0, f1
    add     x0, x0, f1
    mov     x1, x20
    adrp    x2, buf
    add     x2, x2, buf
    bl      printf

    ; 2. malloc / free
    mov     x0, #64
    bl      malloc
    cbz     x0, fail
    mov     x19, x0
    mov     x1, #12345
    str     x1, [x19]
    adrp    x0, f2
    add     x0, x0, f2
    mov     x1, x19
    ldr     x2, [x19]
    bl      printf
    mov     x0, x19
    bl      free

    ; 3. CreateProcessA
    adrp    x0, h3
    add     x0, x0, h3
    bl      puts
    mov     x0, #0
    bl      fflush                      ; fflush(NULL): keep our output before the child's
    adrp    x19, sinfo
    add     x19, x19, sinfo
    mov     w1, #104
    str     w1, [x19]                   ; STARTUPINFOA.cb
    adrp    x20, pinfo
    add     x20, x20, pinfo
    sub     sp, sp, #16
    str     x19, [sp]                   ; 9th argument: lpStartupInfo
    str     x20, [sp, #8]               ; 10th argument: lpProcessInformation
    mov     x0, #0                      ; lpApplicationName
    adrp    x1, cmdline
    add     x1, x1, cmdline                  ; lpCommandLine (writable)
    mov     x2, #0                      ; process security attributes
    mov     x3, #0                      ; thread security attributes
    mov     w4, #0                      ; bInheritHandles = FALSE
    mov     w5, #0                      ; dwCreationFlags
    mov     x6, #0                      ; lpEnvironment
    mov     x7, #0                      ; lpCurrentDirectory
    bl      CreateProcessA
    add     sp, sp, #16
    cbz     w0, fail
    ldr     x0, [x20]                   ; hProcess
    movn    w1, #0                      ; INFINITE (0xFFFFFFFF)
    bl      WaitForSingleObject
    ldr     x0, [x20]
    adrp    x1, exitcode
    add     x1, x1, exitcode
    bl      GetExitCodeProcess
    adrp    x0, f3
    add     x0, x0, f3
    ldr     w1, [x20, #16]              ; dwProcessId
    adrp    x2, exitcode
    add     x2, x2, exitcode
    ldr     w2, [x2]
    bl      printf
    ldr     x0, [x20]
    bl      CloseHandle
    ldr     x0, [x20, #8]
    bl      CloseHandle

    ; 4. executable memory
    mov     x0, #0
    mov     w1, #4096
    mov     w2, #0x3000                 ; MEM_COMMIT | MEM_RESERVE
    mov     w3, #0x40                   ; PAGE_EXECUTE_READWRITE
    bl      VirtualAlloc
    cbz     x0, fail
    mov     x19, x0
    adrp    x1, code
    add     x1, x1, code
    mov     x2, #8                      ; code length
    mov     x3, x19
cp_loop
    ldrb    w4, [x1], #1
    strb    w4, [x3], #1
    subs    x2, x2, #1
    bne     cp_loop
    bl      GetCurrentProcess
    mov     x1, x19
    mov     x2, #8
    bl      FlushInstructionCache       ; (process handle, address, size)
    blr     x19                         ; run the generated code
    mov     w2, w0
    adrp    x0, f4
    add     x0, x0, f4
    mov     x1, x19
    bl      printf
    mov     x0, x19
    mov     x1, #0
    movz    w2, #0x8000                 ; MEM_RELEASE
    bl      VirtualFree

    mov     w0, #0
    b       done
fail
    mov     w0, #1
done
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     fp, lr, [sp], #48
    ret
    ENDP

    AREA    |.rdata|, DATA, READONLY
path    DCB     "libc_demo_win_arm.txt", 0
wmode   DCB     "wb", 0                 ; "b" = binary: no CR LF translation
rmode   DCB     "rb", 0
h1      DCB     "1. stdio: fopen/fwrite/fclose then fopen/fread/fclose", 0
f1      DCB     "   read back %zu bytes: %s", 0
f2      DCB     "2. malloc(64) returned %p, stored value %lld, now free()", 10, 0
h3      DCB     "3. CreateProcessA(cmd.exe /c echo ...) + WaitForSingleObject", 0
f3      DCB     "   child process %lu finished with exit code %lu", 10, 0
f4      DCB     "4. executable page at %p: called generated code, it returned %d", 10, 0
text    DCB     "written with fwrite", 10       ; 20 bytes
        ALIGN   4
; machine code (ARM64):  mov w0, #42 ; ret
code    DCD     0x52800540, 0xD65F03C0

    AREA    |.data|, DATA, READWRITE, ALIGN=3
cmdline DCB     "cmd.exe /c echo    hello from the child process", 0
        ALIGN   8
sinfo   SPACE   104                     ; STARTUPINFOA
pinfo   SPACE   24                      ; PROCESS_INFORMATION
exitcode DCD    0
buf     SPACE   64

    END
