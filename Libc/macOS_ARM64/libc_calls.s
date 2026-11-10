// macOS Apple silicon (arm64): C standard library calls from assembly.  Apple "as" syntax.
// Build: make   Run: ./libc_calls
// Convention: args X0..X7, result X0, SP 16-byte aligned, X19-X28 callee-saved.
//   !! Apple differs from Linux for VARIADIC functions (printf): the fixed arguments
//   !! (the format string) go in registers, but every variadic argument is stored on
//   !! the STACK, in 8-byte slots.  The "printf2" macro below does that.
// macOS differences: C symbols get a leading underscore (_puts); data is addressed
//   with sym@PAGE / sym@PAGEOFF; MAP_ANON is 0x1000.
// Shows: 1. fopen/fwrite/fread/fclose   2. malloc/free
//        3. fork + execv + waitpid (create a process)
//        4. executable memory.  Apple silicon enforces W^X: map with MAP_JIT, switch
//           the thread to "write" mode, copy the code, switch back to "execute"
//           mode, flush the instruction cache, then call it.
        .macro ldaddr reg, sym
        adrp    \reg, \sym@PAGE
        add     \reg, \reg, \sym@PAGEOFF
        .endm

        // printf2 fmt, a, b : variadic args a and b go on the stack
        .macro printf2 fmt, a, b
        ldaddr  x0, \fmt
        sub     sp, sp, #16
        str     \a, [sp]
        str     \b, [sp, #8]
        bl      _printf
        add     sp, sp, #16
        .endm

        .section __DATA,__data
path:    .asciz "/tmp/libc_demo_mac_arm.txt"
wmode:   .asciz "w"
rmode:   .asciz "r"
text:    .ascii "written with fwrite\n"
        .set text_len, . - text
h1:      .asciz "1. stdio: fopen/fwrite/fclose then fopen/fread/fclose"
f1:      .asciz "   read back %zu bytes: %s"
f2:      .asciz "2. malloc(64) returned %p, stored value %ld, now free()\n"
h3:      .asciz "3. fork + execv(/bin/echo) + waitpid"
f3:      .asciz "   child %d finished with exit status %d\n"
f4:      .asciz "4. executable page at %p: called generated code, it returned %d\n"
echo:    .asciz "/bin/echo"
arg1:    .asciz "   hello from the child process"
        .p2align 3
argv:    .quad echo, arg1, 0
// machine code:  mov w0, #42 ; ret
code:    .long 0x52800540, 0xd65f03c0
        .set code_len, . - code
buf:     .space 64
status:  .space 8

        .text
        .globl _main
        .p2align 2
_main:
        stp     x29, x30, [sp, #-48]!
        mov     x29, sp
        stp     x19, x20, [sp, #16]
        str     x21, [sp, #32]

        // 1. stdio
        ldaddr  x0, h1
        bl      _puts
        ldaddr  x0, path
        ldaddr  x1, wmode
        bl      _fopen
        cbz     x0, fail
        mov     x19, x0                 // FILE*
        mov     x3, x0                  // fwrite(ptr, size, count, stream)
        ldaddr  x0, text
        mov     x1, #1
        mov     x2, #text_len
        bl      _fwrite
        mov     x0, x19
        bl      _fclose
        ldaddr  x0, path
        ldaddr  x1, rmode
        bl      _fopen
        cbz     x0, fail
        mov     x19, x0
        mov     x3, x0                  // fread(ptr, size, count, stream)
        ldaddr  x0, buf
        mov     x1, #1
        mov     x2, #63
        bl      _fread
        mov     x20, x0                 // bytes read
        ldaddr  x1, buf
        strb    wzr, [x1, x20]          // zero terminator
        mov     x0, x19
        bl      _fclose
        ldaddr  x2, buf
        printf2 f1, x20, x2

        // 2. malloc / free
        mov     x0, #64
        bl      _malloc
        cbz     x0, fail
        mov     x19, x0
        mov     x1, #12345
        str     x1, [x19]
        ldr     x2, [x19]
        printf2 f2, x19, x2
        mov     x0, x19
        bl      _free

        // 3. fork / execv / waitpid
        ldaddr  x0, h3
        bl      _puts
        mov     x0, #0
        bl      _fflush                 // fflush(NULL): child must not repeat our output
        bl      _fork
        cmp     w0, #0
        b.lt    fail
        b.eq    child
        mov     w19, w0                 // child pid
        ldaddr  x1, status
        mov     w2, #0
        bl      _waitpid
        ldaddr  x1, status
        ldr     w2, [x1]
        ubfx    w2, w2, #8, #8          // WEXITSTATUS
        sxtw    x1, w19
        uxtw    x2, w2
        printf2 f3, x1, x2
        b       exec_page
child:
        ldaddr  x0, echo
        ldaddr  x1, argv
        bl      _execv
        mov     w0, #127                // only reached if execv failed
        bl      __exit

        // 4. executable memory (MAP_JIT)
exec_page:
        mov     x0, #0
        mov     x1, #16384              // Apple silicon page size
        mov     x2, #7                  // PROT_READ | PROT_WRITE | PROT_EXEC
        mov     x3, #0x1802             // MAP_PRIVATE | MAP_ANON | MAP_JIT (0x800)
        mov     x4, #-1
        mov     x5, #0
        bl      _mmap
        cmn     x0, #1
        b.eq    fail
        mov     x19, x0
        mov     w0, #0
        bl      _pthread_jit_write_protect_np   // 0 = this thread may write JIT memory
        ldaddr  x1, code
        mov     x2, #code_len
        mov     x3, x19
1:      ldrb    w4, [x1], #1
        strb    w4, [x3], #1
        subs    x2, x2, #1
        b.ne    1b
        mov     w0, #1
        bl      _pthread_jit_write_protect_np   // 1 = back to execute mode
        mov     x0, x19
        mov     x1, #code_len
        bl      _sys_icache_invalidate
        blr     x19                     // run the generated code
        mov     w2, w0
        sxtw    x2, w2
        printf2 f4, x19, x2
        mov     x0, x19
        mov     x1, #16384
        bl      _munmap

        mov     w0, #0
        b       done
fail:
        mov     w0, #1
done:
        ldr     x21, [sp, #32]
        ldp     x19, x20, [sp, #16]
        ldp     x29, x30, [sp], #48
        ret
