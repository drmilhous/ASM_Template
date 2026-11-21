# AVX examples (NASM and GNU as; Linux, macOS, Windows)

Six small programs about vector instructions, each written twice so you can compare the two assemblers:

| # | Program | Needs |
|---|---|---|
| 01 | `vector_add_sse` - add two float arrays, 4 at a time (xmm) | SSE |
| 02 | `vector_add_avx` - same, 8 at a time, three-operand VEX form (ymm) | AVX |
| 03 | `dot_product_fma` - `vfmadd231ps` and a horizontal sum | AVX + FMA3 |
| 04 | `avx2_integer_sum` - `vpaddd` on 8 integer lanes plus a scalar tail | AVX2 |
| 05 | `cpuid_detect` - CPUID and XGETBV: what the CPU **and the OS** support | any x86-64 |
| 06 | `avx512_mask` - zmm registers and opmask registers for the loop tail | AVX-512F |

Run `05_cpuid_detect` first; if it says "no" for an extension, the matching example will crash with an illegal instruction.
Every program prints its result and the value it should be, so you can see it worked.

## Two assemblers, same programs

| | `nasm/` | `gas/` |
|---|---|---|
| Assembler | NASM | GNU as (called through gcc/clang as `.S` files) |
| Syntax | Intel: `vaddps ymm1, ymm0, [r9 + rcx]` (destination first) | AT&T: `vaddps (%r10,%rcx), %ymm0, %ymm1` (destination last) |
| Registers / constants | `rax`, `42` | `%rax`, `$42` |
| Memory | `[base + index*4]` | `(base,index,4)` |
| AVX-512 mask | `zmm0{k1}{z}` | `%zmm0{%k1}{z}` (mask on the destination) |
| Portability layer | `platform.inc` (NASM macros) | `platform.h` (C preprocessor) |

The programs are laid out the same way in both folders, so reading one next to the other shows what changes (syntax) and what does not (the instructions).

## Build

Linux and macOS (Intel), from `nasm/` or `gas/`:

    make                    # all six
    make 02_vector_add_avx  # one
    ./02_vector_add_avx

Needs `nasm` (nasm folder only), `make` and `gcc` (Linux) or the Xcode command line tools (macOS).

Windows x64:

| | Command | Needs |
|---|---|---|
| NASM | `.\quickBuild.ps1 [name]` in `nasm\` | NASM and Visual Studio C++ x64 tools (same as the other Windows templates) |
| GNU as | `.\quickBuild.ps1 [name]` in `gas\` | MinGW-w64 gcc, e.g. from MSYS2: `pacman -S mingw-w64-x86_64-gcc make` |

Both folders' Makefiles also work in an MSYS2 MinGW64 shell.

## What the portability layer hides

The vector code is identical on every OS. Only the calls to `printf` differ:

| | Linux | macOS | Windows x64 |
|---|---|---|---|
| Argument registers | rdi, rsi, rdx | rdi, rsi, rdx | rcx, rdx, r8 |
| Symbol names | `printf` (via PLT) | `_printf`, `_main` | `printf` |
| Extra rules | `al` = vector registers used | same | 32 bytes of shadow space; a `double` passed to `printf` goes in an xmm register **and** the matching integer register |
| Object format | `elf64` | `macho64` | `win64` |

The macros are `ARG1`, `ARG2`, `CCALL`, `DOUBLE_ARG2`/`DOUBLE_ARG3` (see `platform.inc` / `platform.h`).
Two more portable details: array base addresses are loaded with `lea` first (RIP-relative addressing cannot also take an index register, and macOS and Windows require it), and data sections carry `align=64` so the aligned loads (`vmovaps`) are safe.

## Which machines can run these

- **Intel or AMD PC with AVX** (almost anything since 2013; AVX2/FMA since about 2015; AVX-512 only on some CPUs): all three OSes.
- **Windows on Arm and Apple Silicon Macs**: these programs build for x86-64, and the emulators on those machines do not run AVX. Use an x64 PC, a cloud Linux VM, or the ARM64 NEON examples.
- On macOS the build targets Intel Macs.

## Testing status

Linux x86-64 (NASM and GNU as): built and run, all twelve programs, outputs match each other.
Windows x64: assembled and linked with NASM `win64` and with MinGW GNU as; **not run** (no Windows machine available), and the Visual Studio `quickBuild.ps1` is untested.
macOS: assembled only (NASM `macho64`, clang for the `.S` files); **not linked or run**.
