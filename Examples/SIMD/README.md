# SIMD: AVX and NEON

Start here for the course SIMD section. These matched examples use the ASM_Template pattern: C `main()` calls no-argument assembly `asm_main`, which loads the addresses of arrays declared in `.data` and calls `simd_operation` with pointers and a count. The shared `driver.c` prints the assembly-defined inputs and verifies the outputs. Separate C-generated inputs test `simd_operation` independently. Unlike the older print-only examples, these return a failing process status when a result is wrong. There are no platform-specific print calls in the kernels.

NASM assembles **x86-64**, including AVX/AVX2. It cannot assemble ARM64 NEON. The NEON sources use preprocessed GNU/Clang `.S` syntax and Clang or GCC; Windows ARM64 uses LLVM Clang's assembler with the Microsoft C compiler/linker.

| Example | x86-64 NASM | ARM64 NEON | Contract |
| --- | --- | --- | --- |
| `01_vector_add` | AVX, 8 floats/iteration | NEON, 4 floats/iteration | `out[i] = a[i] + b[i]` |
| `02_dot_product` | AVX multiply/add and horizontal reduction | NEON multiply/add and pairwise reduction | Return float dot product |
| `03_integer_sum` | AVX2 packed integer addition | NEON integer addition and `addv` | Return uint32 sum modulo 2^32 |

All three handle zero elements, unaligned-to-vector inputs (still 4-byte aligned), and scalar tails. Array capacity must be at least `n`; vector addition expects non-overlapping input and output arrays. Dot products regroup additions, so arbitrary floating-point inputs need a numerical tolerance. Neither dot-product example uses fused multiply-add.

## Build and test

Run from this folder. Python 3.8+ is required. Build output is isolated under `build/<system>-<architecture>/`; source files are never overwritten. Builds use debug information and unoptimized C. `--example 01_vector_add` selects one program. Omit `--test` to build without executing.

### macOS

Install Xcode command-line tools; install NASM for x64. Choose the native architecture:

```sh
python3 build.py --arch arm64 --test   # Apple Silicon: native NEON
python3 build.py --arch x64 --test     # Intel Mac: AVX/AVX2 if supported
```

Apple Silicon can build the x64 variants, but executing them requires Rosetta and whatever vector instructions that environment exposes. The C driver checks CPUID and OS-enabled XMM/YMM state before calling AVX code. On unsupported CPUs/emulators the program prints `SKIP` and returns 77 instead of executing unsupported instructions. Do not interpret a skip as a passed arithmetic test.

### Linux

Install Python 3, GCC (or Clang), and NASM for x64. Use a host/VM matching the target architecture:

```sh
python3 build.py --arch x64 --test     # x86-64 Linux
python3 build.py --arch arm64 --test   # AArch64 Linux with Advanced SIMD
```

`make test` selects the native architecture. `CC=clang python3 build.py --test` selects Clang. The driver assumes NEON is enabled in the hosted ARM64 OS; these are not bare-metal examples.

### Windows

Install Python 3 and Visual Studio C++ Build Tools, including the desired target toolchain. Open an **x64 Native Tools** or **ARM64 target Developer Command Prompt/PowerShell**; `VSCMD_ARG_TGT_ARCH` must match the requested architecture. On an x64 host building ARM64, select the cross tools and transfer the executable to Windows ARM64 to run it.

For x64, install NASM on PATH. For ARM64, also install LLVM Clang on PATH. This folder's `.S` files are not input for `armasm64.exe` or the template's generic Windows assembler script.

```powershell
python build.py --arch x64 --test
python build.py --arch arm64 --test
# Equivalent wrapper, from a developer PowerShell:
.\quickBuild.ps1 -Arch arm64 -Test
```

Use only the command matching your developer shell and execution target. The builder uses NASM CodeView debug info for x64, Clang CodeView for ARM64, and MSVC `/Zi` plus linker `/DEBUG`. It invokes tools with argument lists so paths containing spaces work.

## Visible inputs and outputs

Each program prints the fixed **nine-element arrays declared in its assembly `.data` section**, actual output, expected scalar C output, and PASS status. The visible call path is `C main -> asm_main -> simd_operation`. Vector addition stores into `demo_out` in `.data`; dot product returns a float and integer sum returns a uint32.

The array labels are `demo_a`, `demo_b` (float examples), `demo_out` (addition), and `demo_count`. Edit the assembly initializers and count together to change the demonstration. The current values match the worked slide arrays: addition returns nine floats, dot product returns **2.625**, and integer sum returns **456**.

An optional command-line length selects the **independent tests only**; the `.data` demonstration remains nine elements. This keeps the memory declarations visible in the source rather than synthesizing the classroom inputs in C. Unsupported x86 features print SKIP before either the demo or tests execute.

The assembly comments explain pointer arguments, lane accumulation, vector bounds, reductions, scalar tails, and return registers. The driver comments explain input generation, sentinels, and the independent reference checks.

## What the tests check

Each executable compares assembly results with scalar C for **66 lengths (0..65) × 8 starting offsets = 528 cases**. This includes both vector widths, multiple vectors, every tail length, negative/fractional float inputs, and unsigned integer overflow. Vector addition also checks output sentinels outside the requested range. These are correctness checks, not benchmarks or exhaustive memory-safety proofs.

Exit codes: **0** passed, **1** wrong result, **2** invalid test argument, **77** unsupported x86 feature. The build runner reports passed and skipped counts separately; a build or test failure stops execution. Pass a length directly to a built program to select the independent test length (the fixed demo runs first):

```sh
./build/darwin-arm64/01_vector_add 17
```

After the fixed `.data` demo, that runs eight alignment cases at length 17. Break at `asm_main` to see pointer setup and the call, or at `simd_operation` to see the vector loop.

## Debugging

### macOS: LLDB

```sh
lldb --no-lldbinit -- ./build/darwin-arm64/01_vector_add 17
```

```text
breakpoint set --name simd_operation
run
register read x0 x1 x2 x3
nexti
register read v0 v1 v2
disassemble --name simd_operation
```

Step through the loads and `fadd` before inspecting lanes. Use `memory read --format f --size 4 --count 4 $x0` to inspect input (post-indexed NEON loads advance x0). Use symbol breakpoints and instruction stepping for the assembly. The ARM64 objects contain DWARF, but this Apple toolchain did not resolve assembly source-line breakpoints after linking; NASM Mach-O does not emit DWARF line info. C objects and a dSYM are retained for driver source/locals. `--no-lldbinit` avoids interference from custom debugger hooks. A skipped x64 program will never hit either assembly function. `ldr q0` loads the same 128 bits named `v0.4s` by the arithmetic; Q and V are views of the same register.

### Linux: GDB

```sh
gdb --args ./build/linux-x64/01_vector_add 17
```

```text
break simd_operation
run
disassemble /r simd_operation
info registers rdi rsi rdx rcx
stepi
info registers ymm0 ymm1
```

For Linux ARM64 use `build/linux-arm64`, argument registers x0–x3, and vector registers v0–v2. NASM ELF and ARM64 `.S` builds include debug information. Watch the index/count cross the vector-loop boundary and verify that the tail writes only one element at a time.

### Windows: Visual Studio or WinDbg

Open the executable under `build/windows-x64` or `build/windows-arm64` in Visual Studio as a debugging target, set argument `17`, and set a function breakpoint at `simd_operation`. Keep its matching PDB in the output directory. Open Disassembly, Registers, and Memory; instruction-step the loop. In WinDbg, use `bp <module>!simd_operation`, `g`, `u`, and `t`; vector-register presentation depends on the debugger version.

Windows x64 vector-add arguments are RCX/RDX/R8/R9; Linux/macOS x64 use RDI/RSI/RDX/RCX. ARM64 uses x0/x1/x2/x3. The operation functions remain leaf functions using volatile registers. The calling `asm_main` wrapper aligns the x64 stack and reserves Windows shadow space, or saves/restores ARM64 x29/x30 around `bl`. The CPU probe preserves RBX across CPUID.

## Additional x86 material

The existing [SSE, AVX, FMA, AVX2, CPUID, and AVX-512 examples](../AVX/README.md) remain at their original paths for compatibility, with NASM and AT&T/GNU-as versions and template I/O. Use those for instruction-family extensions after the paired AVX/NEON labs. Their older quick-build scripts execute programs directly: check CPU support first. The new SIMD runner only builds/tests the three matched examples here.

## Validation on 2026-11-22

- macOS ARM64: all three compiled, linked, and passed 528 cases each. LLDB stopped at `asm_main` and instruction-stepped the vector-add program; assembly source-line breakpoints did not resolve with this toolchain.
- macOS x64: all three compiled and linked; the current Rosetta environment reported no usable AVX, so all three correctly skipped. Arithmetic execution remains unverified on x64 hardware.
- Linux and Windows: all four NASM sources assembled to ELF64 and Win64/CodeView; all three NEON sources cross-assembled to AArch64 ELF and Windows ARM64 COFF. Native linking and runtime verification are still required; object generation does not prove either.
