# C standard library calls from assembly

Same folders as `Syscalls`, but these programs call the C library (and, on Windows, the Win32 API) instead of the kernel directly. Each program does four things and prints the result:

1. **File I/O:** `fopen` / `fwrite` / `fclose`, then `fopen` / `fread` / `fclose` to read it back
2. **Memory allocation:** `malloc`, store a value, `free`
3. **Create a process:** Linux and macOS use `fork` + `execv("/bin/echo")` + `waitpid`; Windows has no fork, so it uses `CreateProcessA("cmd.exe /c echo ...")` + `WaitForSingleObject` + `GetExitCodeProcess`
4. **Execute generated code:** get a page of executable memory (`mmap` with `PROT_EXEC`, or `VirtualAlloc` with `PAGE_EXECUTE_READWRITE`), copy in a tiny function that returns 42, call it, print the result, release the page

| Folder | Assembler | Build | Calling convention notes | Tested here |
|---|---|---|---|---|
| `Linux_x64` | NASM | `make` | SysV: `rdi rsi rdx rcx r8 r9`, `al`=0 before `printf` | built and run |
| `Linux_x86_32` | NASM | `make` (needs `gcc-multilib`) | cdecl, args on the stack, 16-byte aligned | built and run |
| `Linux_ARM64` | GNU `as` | `make` | `x0`-`x7` | built, run under qemu-user |
| `Linux_ARM32` | GNU `as` | `make` | `r0`-`r3`, then stack; needs `__clear_cache` for step 4 | built, run under qemu-user |
| `macOS_ARM64` | Apple `as` | `make` | `printf` variadic arguments go on the **stack**; step 4 needs `MAP_JIT` and `pthread_jit_write_protect_np` | assembled only |
| `macOS_x64` | NASM | `make` | SysV with `_` symbol prefix | assembled only |
| `Windows_x64` | NASM | `.\quickBuild.ps1` | `rcx rdx r8 r9` + 32 bytes shadow space | assembled only |
| `Windows_ARM64` | armasm64 | `.\quickBuild.ps1` | `x0`-`x7`; step 4 needs `FlushInstructionCache` | built and run on Windows ARM64 |

Things to point out: ARM needs a cache flush after writing code; Apple silicon forbids writable+executable memory unless you use `MAP_JIT`; `fflush(NULL)` before `fork` stops the child repeating buffered output; on x64 and ARM the stack must stay 16-byte aligned at every call.
