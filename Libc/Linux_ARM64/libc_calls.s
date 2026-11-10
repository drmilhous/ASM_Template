// Linux AArch64: C standard library calls from assembly (AAPCS64), GNU as syntax.
// Build: make   Run: ./libc_calls
// Convention: args X0..X7, result X0, return address in X30 (so non-leaf code must
//             save it: stp x29, x30), SP 16-byte aligned, X19-X28 callee-saved.
//             Variadic calls (printf) just use X0..X7 the same way on Linux.
// Shows: 1. fopen/fwrite/fread/fclose   2. malloc/free
//        3. fork + execv + waitpid (create a process)
//        4. mmap an executable page, copy machine code into it and call it
//           (needs __clear_cache: instruction and data caches are separate on ARM)
        .macro ldaddr reg, sym
        adrp    \reg, \sym
        add     \reg, \reg, :lo12:\sym
        .endm

        .data
path:    .asciz "/tmp/libc_demo_a64.txt"
wmode:   .asciz "w"
rmode:   .asciz "r"
text:    .ascii "written with fwrite\n"
        .equ text_len, . - text
h1:      .asciz "1. stdio: fopen/fwrite/fclose then fopen/fread/fclose"
f1:      .asciz "   read back %zu bytes: %s"
f2:      .asciz "2. malloc(64) returned %p, stored value %ld, now free()\n"
h3:      .asciz "3. fork + execv(/bin/echo) + waitpid"
f3:      .asciz "   child %d finished with exit status %d\n"
f4:      .asciz "4. executable page at %p: called generated code, it returned %d\n"
echo:    .asciz "/bin/echo"
arg1:    .asciz "   hello from the child process"
        .align 3
argv:    .quad echo, arg1, 0
// machine code:  mov w0, #42 ; ret
code:    .word 0x52800540, 0xd65f03c0
        .equ code_len, . - code

        .bss
        .align 3
buf:     .skip 64
status:  .skip 8

        .text
        .global main
main:
        stp     x29, x30, [sp, #-48]!
        mov     x29, sp
        stp     x19, x20, [sp, #16]
        str     x21, [sp, #32]

        // 1. stdio
        ldaddr  x0, h1
        bl      puts
        ldaddr  x0, path
        ldaddr  x1, wmode
        bl      fopen
        cbz     x0, fail
        mov     x19, x0                 // FILE*
        mov     x3, x0                  // fwrite(ptr, size, count, stream)
        ldaddr  x0, text
        mov     x1, #1
        mov     x2, #text_len
        bl      fwrite
        mov     x0, x19
        bl      fclose
        ldaddr  x0, path
        ldaddr  x1, rmode
        bl      fopen
        cbz     x0, fail
        mov     x19, x0
        mov     x3, x0                  // fread(ptr, size, count, stream)
        ldaddr  x0, buf
        mov     x1, #1
        mov     x2, #63
        bl      fread
        mov     x20, x0                 // bytes read
        ldaddr  x1, buf
        strb    wzr, [x1, x20]          // zero terminator
        mov     x0, x19
        bl      fclose
        ldaddr  x0, f1
        mov     x1, x20
        ldaddr  x2, buf
        bl      printf

        // 2. malloc / free
        mov     x0, #64
        bl      malloc
        cbz     x0, fail
        mov     x19, x0
        mov     x1, #12345
        str     x1, [x19]
        ldaddr  x0, f2
        mov     x1, x19
        ldr     x2, [x19]
        bl      printf
        mov     x0, x19
        bl      free

        // 3. fork / execv / waitpid
        ldaddr  x0, h3
        bl      puts
        mov     x0, #0
        bl      fflush                  // fflush(NULL): child must not repeat our output
        bl      fork
        cmp     w0, #0
        blt     fail
        beq     child
        mov     w19, w0                 // child pid
        ldaddr  x1, status
        mov     w2, #0
        bl      waitpid
        ldaddr  x1, status
        ldr     w2, [x1]
        ubfx    w2, w2, #8, #8          // WEXITSTATUS
        ldaddr  x0, f3
        mov     w1, w19
        bl      printf
        b       exec_page
child:
        ldaddr  x0, echo
        ldaddr  x1, argv
        bl      execv
        mov     w0, #127                // only reached if execv failed
        bl      _exit

        // 4. executable memory
exec_page:
        mov     x0, #0
        mov     x1, #4096
        mov     x2, #7                  // PROT_READ | PROT_WRITE | PROT_EXEC
        mov     x3, #0x22               // MAP_PRIVATE | MAP_ANONYMOUS
        mov     x4, #-1
        mov     x5, #0
        bl      mmap
        cmn     x0, #1
        beq     fail
        mov     x19, x0
        ldaddr  x1, code
        mov     x2, #code_len
        mov     x3, x19
1:      ldrb    w4, [x1], #1
        strb    w4, [x3], #1
        subs    x2, x2, #1
        b.ne    1b
        mov     x0, x19                 // __clear_cache(begin, end)
        add     x1, x19, #code_len
        bl      __clear_cache
        blr     x19                     // run the generated code
        mov     w2, w0
        ldaddr  x0, f4
        mov     x1, x19
        bl      printf
        mov     x0, x19
        mov     x1, #4096
        bl      munmap

        mov     w0, #0
        b       done
fail:
        mov     w0, #1
done:
        ldr     x21, [sp, #32]
        ldp     x19, x20, [sp, #16]
        ldp     x29, x30, [sp], #48
        ret
