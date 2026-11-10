@ Linux ARM (32-bit, hard-float EABI): C standard library calls from assembly.
@ Build: make   Run: ./libc_calls
@ Convention: args R0-R3 then the stack, result R0, return address in LR (non-leaf
@             code must save it), SP 8-byte aligned at calls, R4-R11 callee-saved.
@ Shows: 1. fopen/fwrite/fread/fclose   2. malloc/free
@        3. fork + execv + waitpid (create a process)
@        4. mmap an executable page, copy machine code into it and call it
@           (needs __clear_cache: instruction and data caches are separate on ARM)
        .arch armv7-a
        .data
path:    .asciz "/tmp/libc_demo_a32.txt"
wmode:   .asciz "w"
rmode:   .asciz "r"
text:    .ascii "written with fwrite\n"
        .equ text_len, . - text
h1:      .asciz "1. stdio: fopen/fwrite/fclose then fopen/fread/fclose"
f1:      .asciz "   read back %u bytes: %s"
f2:      .asciz "2. malloc(64) returned %p, stored value %d, now free()\n"
h3:      .asciz "3. fork + execv(/bin/echo) + waitpid"
f3:      .asciz "   child %d finished with exit status %d\n"
f4:      .asciz "4. executable page at %p: called generated code, it returned %d\n"
echo:    .asciz "/bin/echo"
arg1:    .asciz "   hello from the child process"
        .align 2
argv:    .word echo, arg1, 0
@ machine code (ARM state):  mov r0, #42 ; bx lr
code:    .word 0xE3A0002A, 0xE12FFF1E
        .equ code_len, . - code

        .bss
        .align 2
buf:     .skip 64
status:  .skip 4

        .text
        .global main
main:
        push    {r4-r8, lr}             @ 24 bytes: SP stays 8-byte aligned
        sub     sp, sp, #8              @ two outgoing stack-argument slots

        @ 1. stdio
        ldr     r0, =h1
        bl      puts
        ldr     r0, =path
        ldr     r1, =wmode
        bl      fopen
        cmp     r0, #0
        beq     fail
        mov     r4, r0                  @ FILE*
        mov     r3, r0                  @ fwrite(ptr, size, count, stream)
        ldr     r0, =text
        mov     r1, #1
        mov     r2, #text_len
        bl      fwrite
        mov     r0, r4
        bl      fclose
        ldr     r0, =path
        ldr     r1, =rmode
        bl      fopen
        cmp     r0, #0
        beq     fail
        mov     r4, r0
        mov     r3, r0                  @ fread(ptr, size, count, stream)
        ldr     r0, =buf
        mov     r1, #1
        mov     r2, #63
        bl      fread
        mov     r5, r0                  @ bytes read
        ldr     r1, =buf
        mov     r2, #0
        strb    r2, [r1, r5]            @ zero terminator
        mov     r0, r4
        bl      fclose
        ldr     r0, =f1
        mov     r1, r5
        ldr     r2, =buf
        bl      printf

        @ 2. malloc / free
        mov     r0, #64
        bl      malloc
        cmp     r0, #0
        beq     fail
        mov     r4, r0
        ldr     r1, =12345
        str     r1, [r4]
        ldr     r0, =f2
        mov     r1, r4
        ldr     r2, [r4]
        bl      printf
        mov     r0, r4
        bl      free

        @ 3. fork / execv / waitpid
        ldr     r0, =h3
        bl      puts
        mov     r0, #0
        bl      fflush                  @ fflush(NULL): child must not repeat our output
        bl      fork
        cmp     r0, #0
        blt     fail
        beq     child
        mov     r4, r0                  @ child pid
        ldr     r1, =status
        mov     r2, #0
        bl      waitpid
        ldr     r1, =status
        ldr     r2, [r1]
        ubfx    r2, r2, #8, #8          @ WEXITSTATUS
        ldr     r0, =f3
        mov     r1, r4
        bl      printf
        b       exec_page
child:
        ldr     r0, =echo
        ldr     r1, =argv
        bl      execv
        mov     r0, #127                @ only reached if execv failed
        bl      _exit

        @ 4. executable memory
exec_page:
        mov     r0, #0                  @ mmap(0, 4096, RWX, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
        ldr     r1, =4096
        mov     r2, #7
        mov     r3, #0x22
        mvn     r4, #0
        str     r4, [sp]                @ 5th argument: fd = -1
        mov     r4, #0
        str     r4, [sp, #4]            @ 6th argument: offset = 0
        bl      mmap
        cmn     r0, #1
        beq     fail
        mov     r4, r0
        ldr     r1, =code
        mov     r2, #code_len
        mov     r3, r4
1:      ldrb    r5, [r1], #1
        strb    r5, [r3], #1
        subs    r2, r2, #1
        bne     1b
        mov     r0, r4                  @ __clear_cache(begin, end)
        add     r1, r4, #code_len
        bl      __clear_cache
        blx     r4                      @ run the generated code (even address = ARM state)
        mov     r2, r0
        ldr     r0, =f4
        mov     r1, r4
        bl      printf
        mov     r0, r4
        ldr     r1, =4096
        bl      munmap

        mov     r0, #0
        b       done
fail:
        mov     r0, #1
done:
        add     sp, sp, #8
        pop     {r4-r8, pc}
        .ltorg
