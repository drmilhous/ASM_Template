// ARM64 Assembly I/O Functions
// Converted from x86-64 io.asm
// ARM64 calling convention: x0-x7 for parameters, x0-x1 for return values

.data
    printInt:       .asciz "%d"
    printNewline:   .asciz "\n"
    printString:    .asciz "%s"
    dump_regs_string: .asciz "X0:  0x%016lX X1:  0x%016lX X2:  0x%016lX X3:  0x%016lX X4:  0x%016lX X5:  0x%016lX X6:  0x%016lX X7:  0x%016lX\n"
    dump_regs_string2: .asciz "X8:  0x%016lX X9:  0x%016lX X10: 0x%016lX X11: 0x%016lX X12: 0x%016lX X13: 0x%016lX X14: 0x%016lX X15: 0x%016lX\n"
    dump_regs_string3: .asciz "X16: 0x%016lX X17: 0x%016lX X18: 0x%016lX X19: 0x%016lX X20: 0x%016lX X21: 0x%016lX X22: 0x%016lX X23: 0x%016lX\n"
    dump_regs_string4: .asciz "X24: 0x%016lX X25: 0x%016lX X26: 0x%016lX X27: 0x%016lX X28: 0x%016lX X29: 0x%016lX X30: 0x%016lX SP:  0x%016lX\n"

.text
.global _print_int
.global _print_nl  
.global _print_string
.global _dump_regs

// External function (printf from libc)
.extern _printf

// print_int: prints an integer value
// Input: x0 = integer to print
_print_int:
    // Function prologue
    stp     x29, x30, [sp, #-32]!   // Save frame pointer and link register
    mov     x29, sp                  // Set up frame pointer
    stp     x0, x1, [sp, #16]       // Save registers
    
    // Prepare arguments for printf
    mov     x1, x0                  // Move integer to second argument (x1)
    adrp    x0, printInt@PAGE       // Load address of format string
    add     x0, x0, printInt@PAGEOFF
    
    // Call printf
    bl      _printf
    
    // Function epilogue
    ldp     x0, x1, [sp, #16]       // Restore registers
    ldp     x29, x30, [sp], #32     // Restore frame pointer and link register
    ret                             // Return

// print_nl: prints a newline character
// Input: none
_print_nl:
    // Function prologue
    stp     x29, x30, [sp, #-16]!   // Save frame pointer and link register
    mov     x29, sp                  // Set up frame pointer
    
    // Prepare arguments for printf
    adrp    x0, printNewline@PAGE   // Load address of newline format string
    add     x0, x0, printNewline@PAGEOFF
    
    // Call printf
    bl      _printf
    
    // Function epilogue
    ldp     x29, x30, [sp], #16     // Restore frame pointer and link register
    ret                             // Return

// print_string: prints a string
// Input: x0 = pointer to null-terminated string
_print_string:
    // Function prologue
    stp     x29, x30, [sp, #-32]!   // Save frame pointer and link register
    mov     x29, sp                  // Set up frame pointer
    stp     x0, x1, [sp, #16]       // Save registers
    
    // Prepare arguments for printf
    mov     x1, x0                  // Move string pointer to second argument (x1)
    adrp    x0, printString@PAGE    // Load address of string format string
    add     x0, x0, printString@PAGEOFF
    
    // Call printf
    bl      _printf
    
    // Function epilogue
    ldp     x0, x1, [sp, #16]       // Restore registers
    ldp     x29, x30, [sp], #32     // Restore frame pointer and link register
    ret                             // Return

// dump_regs: prints all ARM64 general-purpose registers
// Input: none (captures current register state)
_dump_regs:
    // Function prologue - need extra space to preserve registers during printf calls
    stp     x29, x30, [sp, #-0x120]!  // Save frame pointer and link register
    mov     x29, sp
    sub     sp,sp, 0x40 //space for local args

    // Save all general-purpose registers x0-x28 to a safe area (high offsets)
    stp     x0, x1, [x29, #0x10]       // Save original x0, x1 to safe area
    stp     x2, x3, [x29, #0x20]      // Save original x2, x3 to safe area
    stp     x4, x5, [x29, #0x30]      // Save original x4, x5 to safe area
    stp     x6, x7, [x29, #0x40]      // Save original x6, x7 to safe area
    stp     x8, x9, [x29, #0x50]      // Save original x8, x9 to safe area
    stp     x10, x11, [x29, #0x60]    // Save original x10, x11 to safe area
    stp     x12, x13, [x29, #0x70]   // Save original x12, x13 to safe area
    stp     x14, x15, [x29, #0x80]   // Save original x14, x15 to safe area
    stp     x16, x17, [x29, #0x90]   // Save original x16, x17 to safe area
    stp     x18, x19, [x29, #0xa0]   // Save original x18, x19 to safe area
    stp     x20, x21, [x29, #0xb0]   // Save original x20, x21 to safe area
    stp     x22, x23, [x29, #0xc0]   // Save original x22, x23 to safe area
    stp     x24, x25, [x29, #0xd0]   // Save original x24, x25 to safe area
    stp     x26, x27, [x29, #0xe0]   // Save original x26, x27 to safe area
    str     x28, [x29, #0xf0]       // Save original x28 to safe area

    // Print first 8 registers (X0-X7)
    adrp    x0, dump_regs_string@PAGE
    add     x0, x0, dump_regs_string@PAGEOFF

    ldp     x1, x2, [x29, #0x10]       // Load saved x0, x1
    stp     x1,x2, [sp, #0]
    ldp     x1, x2, [x29, #0x20] // Load saved x2, x3
    stp     x1,x2, [sp, #0x10]
    ldp     x1, x2, [x29, #0x30]        // Load saved x4, x5
    stp     x1,x2, [sp, #0x20]
    ldp     x1, x2, [x29, #0x40]        // Load saved x6, x7
    stp     x1,x2, [sp, #0x30]
    bl      _printf
    

    // Print next 8 registers (X8-X15) - reload from saved positions
    adrp    x0, dump_regs_string2@PAGE
    add     x0, x0, dump_regs_string2@PAGEOFF
    ldp     x1, x2, [x29, #0x50]        // Load saved x8, x9
    stp     x1,x2, [sp, #0]
    ldp     x1, x2, [x29, #0x60]       // Load saved x10, x11
    stp     x1,x2, [sp, #0x10]
    ldp     x1, x2, [x29, #0x70]       // Load saved x12, x13
    stp     x1,x2, [sp, #0x20]
    ldp     x1, x2, [x29, #0x80]       // Load saved x14, x15
    stp     x1,x2, [sp, #0x30]
    bl      _printf

    
    // Print next 8 registers (X16-X23) - reload from saved positions
    adrp    x0, dump_regs_string3@PAGE
    add     x0, x0, dump_regs_string3@PAGEOFF
    ldp     x1, x2, [x29, #0x90]       // Load saved x16, x17
    stp     x1,x2, [sp, #0]
    ldp     x1, x2, [x29, #0xa0]       // Load saved x18, x19
    stp     x1,x2, [sp, #0x10]
    ldp     x1, x2, [x29, #0xb0]       // Load saved x20, x21
    stp     x1,x2, [sp, #0x20]
    ldp     x1, x2, [x29, #0xc0]       // Load saved x22, x23
    stp     x1,x2, [sp, #0x30]
    bl      _printf

    
    // Print last registers (X24-X27, X28, X29, X30, SP) - reload from saved positions
    adrp    x0, dump_regs_string4@PAGE
    add     x0, x0, dump_regs_string4@PAGEOFF
    ldp     x1, x2, [x29, #0xd0]       // Load saved x24, x25
    stp     x1,x2, [sp, #0]
    ldp     x1, x2, [x29, #0xe0]       // Load saved x26, x27
    stp     x1,x2, [sp, #0x10]
    ldr     x1, [x29, #0xf0]       // Load saved x28
    ldr     x2, [sp, #0x48]       // Load saved x29 (frame pointer)
    stp     x1,x2, [sp, #0x20]
    ldr     x1, [sp, #0x40]       // Load saved lr
    add     x2, sp, #0x40       // Load saved stack pointer (SP)
    add     x2,x2, #0x120
    stp     x1,x2, [sp, #0x30]
    bl      _printf

    add    sp,sp, #0x40 // adjust stack back
    // Function epilogue - restore all registers from their saved positions
    ldp     x0, x1, [x29, #0x10]
    ldp     x2, x3, [x29, #0x20]
    ldp     x4, x5, [x29, #0x30]
    ldp     x6, x7, [x29, #0x40]
    ldp     x8, x9, [x29, #0x50]
    ldp     x10, x11, [x29, #0x60]
    ldp     x12, x13, [x29, #0x70]
    ldp     x14, x15, [x29, #0x80]
    ldp     x16, x17, [x29, #0x90]
    ldp     x18, x19, [x29, #0xa0]
    ldp     x20, x21, [x29, #0xb0]
    ldp     x22, x23, [x29, #0xc0]
    ldp     x24, x25, [x29, #0xd0]
    ldp     x26, x27, [x29, #0xe0]
    ldr     x28, [x29, #0xf0]
    ldp     x29, x30, [sp], #0x120
  // Restore frame pointer and link register (updated size)
    ret                              // Return
