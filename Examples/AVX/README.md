# SIMD supplement: x86 SSE, AVX, and AVX-512

For the main **SIMD: AVX and NEON** section, matched examples, automated checks, and cross-platform debugging, start at [Examples/SIMD](../SIMD/README.md). This folder keeps the original x86-only examples and paths.

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

## They are ASM_Template programs

Each example is the usual template program: it defines `asm_main`, and the template's `driver.c` `main()` calls it. Output goes through the template's I/O library (`io.asm`/`io.inc`): `print_int`, `print_string` and `print_nl`. There is no `printf` in the examples. The library is picked from the template folder for your OS (`64_Bit_Intel`, `M1_Mac` or `64_Bit_Windows`) and built to `io.o`; the `gas/` examples link against that NASM-built object like any other, which is also a small demonstration of mixing the two assemblers.

Floats are printed with the library's `print_float`: it takes a **double in `xmm0`** and prints it like `printf("%f")`, so the examples widen a single-precision result with `cvtss2sd` first. `print_float` keeps all registers and `xmm0`; the other print routines may clobber `xmm0` (printf runs inside them), so a float result that must survive a `print_string` is parked in a stack slot. Library calls also clobber the caller-saved registers, so loop counters that live across a print are kept in `rbx`/`r12`/`r13`.

The folders find the template by looking three levels up (`Examples/AVX/nasm` -> `ASM_Template`); set `ASM_TEMPLATE_HOME` or pass `T=/path/to/ASM_Template` to `make` if you moved them.

## Build

Linux and macOS (Intel), from `nasm/` or `gas/`:

    make                    # all six
    make 02_vector_add_avx  # one
    ./02_vector_add_avx

Needs `nasm` (to build the template library, and for the `nasm/` examples), `make` and `gcc` (Linux) or the Xcode command line tools (macOS).

Windows x64:

| | Command | Needs |
|---|---|---|
| NASM | `.\quickBuild.ps1 [name]` in `nasm\` | NASM and Visual Studio C++ x64 tools (same as the other Windows templates) |
| GNU as | `.\quickBuild.ps1 [name]` in `gas\` | NASM (for the library) and MinGW-w64 gcc, e.g. from MSYS2: `pacman -S mingw-w64-x86_64-gcc make` |

Both folders' Makefiles also work in an MSYS2 MinGW64 shell.

## What the portability layer hides

The vector code is identical on every OS. Only the way a value or string reaches the library differs:

| | Linux | macOS | Windows x64 |
|---|---|---|---|
| Library | `64_Bit_Intel/io.asm` | `M1_Mac/io.asm` | `64_Bit_Windows/io.asm` |
| Value / string pointer passed in | `rax` | `rdi` | `rax` |
| Entry point symbol | `asm_main` | `_asm_main` | `asm_main` |
| Object format | `elf64` | `macho64` | `win64` |

The macros are `PRINT_INT`, `PRINT_STR`, `PRINT_PTR`, `PRINT_NL` (see `platform.inc` / `platform.h`).
Two more portable details: array base addresses are loaded with `lea` first (RIP-relative addressing cannot also take an index register, and macOS and Windows require it), and data sections carry `align=64` so the aligned loads (`vmovaps`) are safe.

**Library changes in this folder's PR:** `print_float` (double in `xmm0`) was added to all three libraries (`64_Bit_Intel`, `M1_Mac`, `64_Bit_Windows`).
The old `64_Bit_Windows/io.asm` was a copy of the Linux one (it passed arguments in `rdi`/`rsi` and called `printf wrt ..plt`, which does not assemble for `win64`). It is replaced by a real Windows x64 version with `print_int`/`print_hex`/`print_nl`/`print_string`/`print_float` (value or pointer in `rax`, double in `xmm0`), a working `dump_registers`, and all registers preserved. It handles the Microsoft x64 rules itself: 32 bytes of shadow space, 16-byte stack alignment, a double passed to `printf` in both an xmm and an integer register, and `%llX` for 64-bit hex (`%lX` is only 32 bits on Windows).

## Which machines can run these

- **Intel or AMD PC with AVX** (almost anything since 2013; AVX2/FMA since about 2015; AVX-512 only on some CPUs): all three OSes.
- **Windows on Arm and Apple Silicon Macs**: these programs build for x86-64 (on a Mac the Makefiles pass `-target x86_64-apple-macos13.0` so `make` produces an Intel binary), and they run only as far as the emulator supports the instructions. Windows-on-Arm emulation has no AVX. Rosetta 2 on macOS may run SSE and some AVX/AVX2, but not AVX-512: run `05_cpuid_detect` first. Use an x64 PC, a cloud Linux VM, or the ARM64 NEON examples.
- On macOS the build targets Intel Macs.

## Testing status

Linux x86-64 (NASM and GNU as): built and run, all twelve programs, outputs match each other.
Windows x64: assembled and linked (NASM `win64` plus MinGW for both versions, including the new `io.asm`); **not run** (no Windows machine available), and the Visual Studio `quickBuild.ps1` is untested.
macOS: assembled only (NASM `macho64`, clang for the `.S` files); **not linked or run**.
