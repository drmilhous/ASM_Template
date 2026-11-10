; Windows x64: C runtime (UCRT) calls from assembly, plus the Win32 process API.
; Build + run: .\quickBuild.ps1
; Convention (Microsoft x64): args RCX RDX R8 R9 then the stack, result RAX; the caller
;   reserves 32 bytes of shadow space; RSP 16-byte aligned at every call.
;   Callee-saved: RBX RBP RDI RSI R12-R15.  printf-style calls use the same registers.
; Shows: 1. fopen/fwrite/fread/fclose   2. malloc/free
;        3. create a process: CreateProcessA + WaitForSingleObject + GetExitCodeProcess
;           (Windows has no fork/exec; one call both creates and starts the child)
;        4. VirtualAlloc executable memory, copy machine code into it and call it
default rel
extern puts, printf, fopen, fwrite, fread, fclose, fflush, malloc, free
extern CreateProcessA, WaitForSingleObject, GetExitCodeProcess, CloseHandle
extern VirtualAlloc, VirtualFree

section .data
path:    db "libc_demo_win.txt", 0
wmode:   db "wb", 0                     ; "b" = binary: no CR LF translation
rmode:   db "rb", 0
text:    db "written with fwrite", 10
text_len equ $ - text
h1:      db "1. stdio: fopen/fwrite/fclose then fopen/fread/fclose", 0
f1:      db "   read back %zu bytes: %s", 0
f2:      db "2. malloc(64) returned %p, stored value %lld, now free()", 10, 0
h3:      db "3. CreateProcessA(cmd.exe /c echo ...) + WaitForSingleObject", 0
f3:      db "   child process %lu finished with exit code %lu", 10, 0
f4:      db "4. executable page at %p: called generated code, it returned %d", 10, 0
cmdline: db "cmd.exe /c echo    hello from the child process", 0   ; must be writable
; machine code:  mov eax, 42 ; ret
code:    db 0xB8, 42, 0, 0, 0, 0xC3
code_len equ $ - code

section .bss
buf:     resb 64
sinfo:      resb 104                       ; STARTUPINFOA
pinfo:      resb 24                        ; PROCESS_INFORMATION
exitcode: resd 1

section .text
global main
main:
        push    rbx
        push    rbp
        push    rsi
        push    rdi
        sub     rsp, 0x58               ; 0x20 shadow + 0x28 stack args + padding, aligned

        ; 1. stdio
        lea     rcx, [h1]
        call    puts
        lea     rcx, [path]
        lea     rdx, [wmode]
        call    fopen
        test    rax, rax
        jz      .fail
        mov     rbx, rax                ; FILE*
        lea     rcx, [text]             ; fwrite(ptr, size, count, stream)
        mov     edx, 1
        mov     r8d, text_len
        mov     r9, rbx
        call    fwrite
        mov     rcx, rbx
        call    fclose
        lea     rcx, [path]
        lea     rdx, [rmode]
        call    fopen
        test    rax, rax
        jz      .fail
        mov     rbx, rax
        lea     rcx, [buf]              ; fread(ptr, size, count, stream)
        mov     edx, 1
        mov     r8d, 63
        mov     r9, rbx
        call    fread
        mov     rsi, rax                ; bytes read
        lea     rdx, [buf]
        mov     byte [rdx + rsi], 0
        mov     rcx, rbx
        call    fclose
        lea     rcx, [f1]
        mov     rdx, rsi
        lea     r8, [buf]
        call    printf

        ; 2. malloc / free
        mov     ecx, 64
        call    malloc
        test    rax, rax
        jz      .fail
        mov     rbx, rax
        mov     qword [rbx], 12345
        lea     rcx, [f2]
        mov     rdx, rbx
        mov     r8, [rbx]
        call    printf
        mov     rcx, rbx
        call    free

        ; 3. CreateProcessA
        lea     rcx, [h3]
        call    puts
        xor     ecx, ecx
        call    fflush                  ; fflush(NULL): keep our output before the child's
        lea     rdi, [sinfo]
        mov     dword [rdi], 104        ; STARTUPINFOA.cb
        xor     ecx, ecx                ; lpApplicationName = NULL
        lea     rdx, [cmdline]          ; lpCommandLine
        xor     r8d, r8d                ; process security attributes
        xor     r9d, r9d                ; thread security attributes
        mov     qword [rsp + 0x20], 0   ; bInheritHandles = FALSE
        mov     qword [rsp + 0x28], 0   ; dwCreationFlags
        mov     qword [rsp + 0x30], 0   ; lpEnvironment
        mov     qword [rsp + 0x38], 0   ; lpCurrentDirectory
        mov     [rsp + 0x40], rdi       ; lpStartupInfo
        lea     rax, [pinfo]
        mov     [rsp + 0x48], rax       ; lpProcessInformation
        call    CreateProcessA
        test    eax, eax
        jz      .fail
        mov     rcx, [pinfo]               ; hProcess
        mov     edx, -1                 ; INFINITE
        call    WaitForSingleObject
        mov     rcx, [pinfo]
        lea     rdx, [exitcode]
        call    GetExitCodeProcess
        lea     rcx, [f3]
        mov     edx, [pinfo + 16]          ; dwProcessId
        mov     r8d, [exitcode]
        call    printf
        mov     rcx, [pinfo]
        call    CloseHandle
        mov     rcx, [pinfo + 8]
        call    CloseHandle

        ; 4. executable memory
        xor     ecx, ecx
        mov     edx, 4096
        mov     r8d, 0x3000             ; MEM_COMMIT | MEM_RESERVE
        mov     r9d, 0x40               ; PAGE_EXECUTE_READWRITE
        call    VirtualAlloc
        test    rax, rax
        jz      .fail
        mov     rbx, rax
        mov     rdi, rbx
        lea     rsi, [code]
        mov     ecx, code_len
        cld
        rep movsb
        call    rbx                     ; run the generated code
        lea     rcx, [f4]
        mov     rdx, rbx
        mov     r8d, eax
        call    printf
        mov     rcx, rbx
        xor     edx, edx
        mov     r8d, 0x8000             ; MEM_RELEASE
        call    VirtualFree

        xor     eax, eax
        jmp     .done
.fail:
        mov     eax, 1
.done:
        add     rsp, 0x58
        pop     rdi
        pop     rsi
        pop     rbp
        pop     rbx
        ret
