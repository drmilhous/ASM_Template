# SIMD examples: x86-64 AVX (NASM) and ARM64 NEON (GNU as)

Vector instructions on the two CPU families the template covers, as small programs that print their result and the value they should print.

| Folder | CPU | Assembler | Platforms |
|---|---|---|---|
| `nasm/` | x86-64: SSE, AVX, FMA, AVX2, AVX-512 | NASM (Intel syntax) | Linux, macOS (Intel), Windows x64 |
| `gas/` | ARM64: NEON, SVE | GNU as syntax (AArch64) | Linux ARM64, macOS (Apple Silicon), Windows on Arm |

The two folders show the same ideas, program for program:

| # | x86-64 (`nasm/`) | ARM64 (`gas/`) |
|---|---|---|
| 01 | `vector_add_sse` - 4 floats per xmm register | `vector_add_neon` - 4 floats per v register (`fadd v2.4s, v0.4s, v1.4s`) |
| 02 | `vector_add_avx` - 8 floats per ymm, three-operand VEX form | `vector_add_pairs` - 8 floats per pass with two registers and `ldp`/`stp` pairs |
| 03 | `dot_product_fma` - `vfmadd231ps`, horizontal sum | `dot_product_fmla` - `fmla`, horizontal sum with `faddp` |
| 04 | `avx2_integer_sum` - `vpaddd` on 8 lanes plus a scalar tail | `integer_sum` - `add` on 4 lanes, `addv`, scalar tail |
| 05 | `cpuid_detect` - CPUID and XGETBV (CPU **and** OS support) | `feature_detect` - `getauxval` / `sysctlbyname` / `IsProcessorFeaturePresent` |
| 06 | `avx512_mask` - zmm registers and opmask registers for the loop tail | `masked_tail` - NEON has no masks: `cmgt` builds one and `bsl` merges |
| 07 | | `sve_predicate` - SVE `whilelt` predicates: the real equivalent of AVX-512 masks (needs an SVE CPU) |

Run `05` first on either side. If a feature is missing, the matching example would stop with an illegal instruction (the x86 examples) or says so (07).

## They are ASM_Template programs

Each example is the usual template program: it defines `asm_main`, and the template's `driver.c` `main()` calls it. Output goes through the template's I/O library for the platform, so there is no `printf` in the examples. The library is built to `io.o` from the template folder; both Makefiles find the template two folders up (`Examples/AVX/nasm` -> `ASM_Template`). Set `ASM_TEMPLATE_HOME`, or pass `T=/path/to/ASM_Template` to `make`, if you moved them.

| | Library | Print an integer | Print a string | Print a double | Newline |
|---|---|---|---|---|---|
| x86-64 Linux | `64_Bit_Intel/io.asm` | `rax` | `rax` = address | `xmm0` | `print_nl` |
| x86-64 macOS | `M1_Mac/io.asm` | `rdi` | `rdi` = address | `xmm0` | `print_nl` |
| x86-64 Windows | `64_Bit_Windows/io.asm` | `rax` | `rax` = address | `xmm0` | `print_nl` |
| ARM64 Linux | `64_Bit_ARM/io.s` | `w0` | `x0` = address | `d0` | `print_nl` |
| ARM64 macOS | `M1_Mac/io_arm.s` | `w0` | `x0` = address | `d0` | `print_nl` |
| ARM64 Windows | `64_Bit_Windows_ARM/io_c_fallback.c` (C) or `io.asm` (armasm64) | `w0` | `x0` = address | `d0` | `print_nl` |

Floats are printed with `print_float`, which takes a **double** (like `printf("%f")`), so the examples widen a single-precision result first (`cvtss2sd` on x86, `fcvt d0, s0` on ARM64). Library calls clobber the caller-saved registers because printf runs inside them, so anything that must survive a print lives in a callee-saved register (`rbx`, `r12`... / `x19`...`x28`) or a stack slot. `platform.inc` (NASM macros) and `platform.h` (C preprocessor, used by the `.S` files) hide the per-platform differences behind `PRINT_INT`, `PRINT_STR`, `PRINT_FLOAT`, `PRINT_NL`.

## Build

Linux and macOS, from `nasm/` or `gas/` (the `gas/` folder is for ARM machines):

    make                    # all of them
    make 03_dot_product_fma # one (use the name of the program in that folder)
    ./03_dot_product_fma

Needs `make` and `gcc` (Linux) or the Xcode command line tools (macOS). The `nasm/` folder also needs `nasm`.

Windows:

| | Command | Needs |
|---|---|---|
| x86-64 (`nasm\`) | `.\quickBuild.ps1 [name]` | NASM and Visual Studio C++ x64 tools (same as the other Windows templates) |
| ARM64 (`gas\`) | `.\quickBuild.ps1 [name]` | ARM64 `clang` that can link Windows programs: MSYS2 CLANGARM64 (`pacman -S mingw-w64-clang-aarch64-clang`), or LLVM for Windows on Arm with the Visual Studio ARM64 C++ tools |

Both folders' Makefiles also work in an MSYS2 shell (`MINGW64` for x86-64, `CLANGARM64` for ARM64).

## Syntax in one table

| | NASM (x86-64) | GNU syntax (ARM64) |
|---|---|---|
| Operand order | destination first: `vaddps ymm1, ymm0, [r9 + rcx]` | destination first: `fadd v2.4s, v0.4s, v1.4s` |
| Registers / constants | `rax`, `42` | `x0`/`w0`, `#42` |
| Memory | `[base + index*4]` | `[base, index, lsl #2]` |
| Vector lane shapes | `ymm0` = 8 floats (register name sets the width) | `v0.4s` = 4 floats (the suffix sets the shape: `.4s`, `.2d`, `.16b`...) |
| Comments | `;` | `//` (the `.S` files go through the C preprocessor) |

(On ARM, GNU as and the built-in clang assembler accept the same syntax. Windows' own `armasm64` uses a different one and is not used here.)

## What the portability layers hide

x86-64: the first `printf` arguments are in `rdi, rsi, rdx` (Linux, macOS) or `rcx, rdx, r8` (Windows); macOS puts an underscore in front of C names (`_asm_main`); Windows wants 32 bytes of shadow space and a double passed to a variadic function in both an xmm and an integer register. Array base addresses are loaded with `lea` first (RIP-relative addressing cannot also take an index register), and data sections carry `align=64` so the aligned loads are safe. The **Windows x64 library** (`64_Bit_Windows/io.asm`) used to be a copy of the Linux one and did not assemble for `win64`; it is now a real Windows version with a working `dump_registers`.

ARM64: addresses are formed with `adrp` + `add`, written `sym` / `:lo12:sym` on Linux and Windows but `sym@PAGE` / `sym@PAGEOFF` on macOS (the `ADDR` macro). macOS also puts an underscore in front of C names, and Apple's ARM64 passes the arguments of a variadic function such as `printf` on the stack, which `print_float` in `io_arm.s` handles. Windows on Arm passes a variadic double in an integer register (handled in `io.asm`).

## Which machines can run these

- **x86-64**: an Intel or AMD PC with AVX (almost anything since 2013; AVX2/FMA since about 2015; AVX-512 only on some CPUs): all three OSes. On an Apple Silicon Mac the Makefile builds an Intel binary (`-target x86_64-apple-macos13.0`) that runs through Rosetta 2, which may run SSE and some AVX/AVX2 but not AVX-512. Windows on Arm emulation has no AVX. Run `05_cpuid_detect` first.
- **ARM64**: NEON is on every ARM64 CPU, so 01-06 run on Apple Silicon Macs, Windows on Arm PCs and any ARM64 Linux (Raspberry Pi 4/5, Graviton, ...). 07 needs SVE (AWS Graviton 3/4, Neoverse V1/V2, A64FX...). On an x86 Linux machine you can run the ARM64 programs with `apt install qemu-user gcc-aarch64-linux-gnu`, then `make CC=aarch64-linux-gnu-gcc` and `qemu-aarch64 -cpu max -L /usr/aarch64-linux-gnu ./03_dot_product_fmla`.

## Testing status

- x86-64 Linux: all six NASM programs built and run on an AVX-512 CPU.
- ARM64 Linux: all seven programs built with `aarch64-linux-gnu-gcc` and run under `qemu-aarch64 -cpu max` (SVE included); 05/07 also run under `-cpu cortex-a57` and correctly report no DotProd/SVE.
- x86-64 Windows: assembled and linked (NASM `win64` + MinGW), **not run**. ARM64 Windows and ARM64/x86-64 macOS: assembled with `clang -target` only, **not linked or run**. The `quickBuild.ps1` scripts are untested.
