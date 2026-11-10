; Linux x86-64: C standard library calls from assembly (System V ABI).
; Build: make   Run: ./libc_calls
; Convention: args RDI RSI RDX RCX R8 R9, result RAX; for variadic calls (printf)
;             AL = number of vector registers used (0 here).
;             RSP must be 16-byte aligned at every "call".
;             Callee-saved: RBX RBP R12-R15.
; Shows: 1. fopen/fwrite/fread/fclose   2. malloc/free
;        3. fork + execv + waitpid (create a process)
;        4. mmap an executable page, copy machine code into it and call it
default rel
extern puts, printf, fopen, fwrite, fread, fclose, fflush
extern malloc, free, fork, execv, waitpid, _exit, mmap, munmap

section .data
path:    db "/tmp/libc_demo.txt", 0
wmode:   db "w", 0
rmode:   db "r", 0
text:    db "written with fwrite", 10
text_len equ $ - text
h1:      db "1. stdio: fopen/fwrite/fclose then fopen/fread/fclose", 0
f1:      db "   read back %zu bytes: %s", 0
f2:      db "2. malloc(64) returned %p, stored value %ld, now free()", 10, 0
h3:      db "3. fork + execv(/bin/echo) + waitpid", 0
f3:      db "   child %d finished with exit status %d", 10, 0
f4:      db "4. executable page at %p: called generated code, it returned %d", 10, 0
echo:    db "/bin/echo", 0
arg1:    db "   hello from the child process", 0
argv:    dq echo, arg1, 0
; machine code:  mov eax, 42 ; ret
code:    db 0xB8, 42, 0, 0, 0, 0xC3
code_len equ $ - code

section .bss
buf:     resb 64
status:  resd 1

section .text
global main
main:
        push    rbp
        mov     rbp, rsp
        push    rbx
        push    r12                     ; two pushes + rbp = aligned again

        ; 1. stdio
        lea     rdi, [h1]
        call    puts wrt ..plt
        lea     rdi, [path]
        lea     rsi, [wmode]
        call    fopen wrt ..plt
        test    rax, rax
        jz      .fail
        mov     rbx, rax                ; FILE*
        lea     rdi, [text]             ; fwrite(ptr, size, count, stream)
        mov     esi, 1
        mov     edx, text_len
        mov     rcx, rbx
        call    fwrite wrt ..plt
        mov     rdi, rbx
        call    fclose wrt ..plt
        lea     rdi, [path]
        lea     rsi, [rmode]
        call    fopen wrt ..plt
        test    rax, rax
        jz      .fail
        mov     rbx, rax
        lea     rdi, [buf]              ; fread(ptr, size, count, stream)
        mov     esi, 1
        mov     edx, 63
        mov     rcx, rbx
        call    fread wrt ..plt
        mov     r12, rax                ; bytes read
        lea     rdx, [buf]
        mov     byte [rdx + rax], 0     ; (rip-relative addressing cannot take an index)
        mov     rdi, rbx
        call    fclose wrt ..plt
        lea     rdi, [f1]
        mov     rsi, r12
        lea     rdx, [buf]
        xor     eax, eax
        call    printf wrt ..plt

        ; 2. malloc / free
        mov     edi, 64
        call    malloc wrt ..plt
        test    rax, rax
        jz      .fail
        mov     rbx, rax
        mov     qword [rbx], 12345
        lea     rdi, [f2]
        mov     rsi, rbx
        mov     rdx, [rbx]
        xor     eax, eax
        call    printf wrt ..plt
        mov     rdi, rbx
        call    free wrt ..plt

        ; 3. fork / execv / waitpid
        lea     rdi, [h3]
        call    puts wrt ..plt
        xor     edi, edi                ; fflush(NULL) flushes every stream, so the
                                        ; child's copy of our buffer is empty
        call    fflush wrt ..plt
        call    fork wrt ..plt
        test    eax, eax
        js      .fail
        jz      .child
        mov     r12d, eax               ; child pid
        mov     edi, eax
        lea     rsi, [status]
        xor     edx, edx
        call    waitpid wrt ..plt
        mov     eax, [status]
        shr     eax, 8
        and     eax, 0xFF               ; WEXITSTATUS
        lea     rdi, [f3]
        mov     esi, r12d
        mov     edx, eax
        xor     eax, eax
        call    printf wrt ..plt
        jmp     .exec_page
.child:
        lea     rdi, [echo]
        lea     rsi, [argv]
        call    execv wrt ..plt
        mov     edi, 127                ; only reached if execv failed
        call    _exit wrt ..plt

        ; 4. executable memory
.exec_page:
        xor     edi, edi
        mov     esi, 4096
        mov     edx, 7                  ; PROT_READ | PROT_WRITE | PROT_EXEC
        mov     ecx, 0x22               ; MAP_PRIVATE | MAP_ANONYMOUS
        mov     r8, -1
        xor     r9d, r9d
        call    mmap wrt ..plt
        cmp     rax, -1
        je      .fail
        mov     rbx, rax
        lea     rsi, [code]
        mov     rdi, rbx
        mov     ecx, code_len
        cld
        rep movsb
        call    rbx                     ; run the generated code
        mov     r12d, eax
        lea     rdi, [f4]
        mov     rsi, rbx
        mov     edx, r12d
        xor     eax, eax
        call    printf wrt ..plt
        mov     rdi, rbx
        mov     esi, 4096
        call    munmap wrt ..plt

        xor     eax, eax
        jmp     .done
.fail:
        mov     eax, 1
.done:
        pop     r12
        pop     rbx
        pop     rbp
        ret
