.global print_int

.section .rodata
        format: .string "%d\n"

.section .text

print_int:
        // x0 contains the integer to print
        stp x29, x30, [sp, #-16]!   // Save frame pointer and link register
        mov x29, sp                  // Set frame pointer
        
        mov x1, x0                  // Move integer to second argument
        adr x0, format              // Load format string address
        bl printf                   // Call printf
        
        ldp x29, x30, [sp], #16     // Restore frame pointer and link register
        ret
