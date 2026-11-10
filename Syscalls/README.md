# System call examples (no C library)

One folder per operating system and CPU. Every Linux and macOS program does the same five things, so you can compare them side by side:

1. `write` a greeting to stdout
2. `getpid` and print the number (a small decimal-conversion routine is included)
3. `open` / `read` / `close` the file `/etc/hosts` and echo its first 40 bytes
4. `mmap` an anonymous page, copy text into it, print it, then `munmap`
5. `exit(0)`

The Windows folders do the same steps through the Win32 API, plus a second program that shows the real system call mechanism.

| Folder | Assembler | Instruction | Number in | Arguments | Error reporting | Tested here |
|---|---|---|---|---|---|---|
| `Linux_x64` | NASM `elf64` | `syscall` | `rax` | `rdi rsi rdx r10 r8 r9` | `rax` = -errno | built and run |
| `Linux_x86_32` | NASM `elf32` | `int 0x80` | `eax` | `ebx ecx edx esi edi ebp` | `eax` = -errno | built and run |
| `Linux_ARM64` | GNU `as` | `svc #0` | `x8` | `x0`-`x5` | `x0` = -errno | built, run under qemu-user |
| `Linux_ARM32` | GNU `as` | `svc #0` | `r7` | `r0`-`r6` | `r0` = -errno | built, run under qemu-user |
| `macOS_ARM64` | Apple `as` | `svc #0x80` | `x16` | `x0`-`x5` | carry flag set, `x0` = errno | assembled only |
| `macOS_x64` | NASM `macho64` | `syscall` | `rax` = `0x2000000` + n | `rdi rsi rdx r10 r8 r9` | carry flag set, `rax` = errno | assembled only |
| `Windows_x64` | NASM `win64` | `syscall` | `eax` (SSN) | `rcx rdx r8 r9`, stack; copy `rcx` to `r10` | NTSTATUS in `eax` | assembled and linked only |
| `Windows_ARM64` | armasm64 | `svc #N` (N is part of the instruction) | immediate | `x0`-`x7`, stack | NTSTATUS in `x0` | built and run on Windows ARM64 (api + raw) |

## Things worth pointing out in class

* **Call numbers differ everywhere.** `write` is 1 on Linux x64, 4 on Linux x86/ARM32 and macOS, and 64 on Linux ARM64. Linux ARM64 has no `open` at all (use `openat`, with `AT_FDCWD` = -100).
* **Linux ARM64 and x86-32 `mmap`:** x86-32 and ARM32 use `mmap2` (offset counted in 4096-byte pages). Flag values also differ between Linux and macOS (`MAP_ANONYMOUS` 0x20 vs `MAP_ANON` 0x1000).
* **Error handling differs.** Linux returns -errno in the result register; macOS sets the carry flag and returns a positive errno.
* **macOS** officially supports only the C library (libSystem); raw syscalls can change between releases. We still link libSystem because the loader needs it. Apple-silicon pages are 16 KB, so the ARM64 example maps 16384 bytes.
* **Windows system call numbers are not stable.** They change between Windows versions and builds. Real programs go through `kernel32.dll` (`*_api.asm`). The `*_raw.asm` programs show the mechanism safely: x64 reads the number out of the `ntdll.dll` stub at run time and executes `syscall` itself; ARM64 puts the number inside the `svc` instruction, so the example decodes and prints it and then calls the ntdll stub. Security products may hook those stubs; the programs detect an unexpected stub and stop with a message.

## Build and run

Linux / macOS: `cd` into the folder and run `make && ./syscalls`.

* ARM Linux cross-build on an x86 machine: `make AS=aarch64-linux-gnu-as LD=aarch64-linux-gnu-ld` (or the `arm-linux-gnueabihf-` pair) and run with `qemu-aarch64` / `qemu-arm`.
* `Linux_x86_32` runs on a 64-bit Linux kernel built with 32-bit emulation (the default on most distros).
* `macOS_x64` also runs on Apple silicon through Rosetta.

Windows: open PowerShell in the folder and run `.\quickBuild.ps1`. `Windows_x64` needs NASM plus the MSVC x64 tools (edit `$TOOL_DIR` in the script if NASM is not on PATH). `Windows_ARM64` uses the same ARM64 Build Tools as the `64_Bit_Windows_ARM` template and finds them through `bin\findTools.ps1`.

## Searchable viewer

Open `Explorer/index.html` in a browser (theme: auto, dark or light; each call links to its man page or Microsoft Learn page): filter by operating system, platform and kind (system calls or C library) and search the tables and source code. Regenerate it after editing an example with `python3 Explorer/build_viewer.py`.
