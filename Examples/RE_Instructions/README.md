# Instruction patterns for reverse engineering

Six paired x86-64 NASM / ARM64 Clang-GNU assembly examples support the core course. Inputs and writable outputs are in each file's `.data` section. The C driver calls `asm_main`, which passes their addresses to `re_operation`; the function reads memory, performs the operation, and stores the results. Comments explain the instruction semantics and the ABI setup.

The driver prints input words, actual output, and independently calculated expected output. Hex preserves exact bit patterns; the floating-point example also decodes its values. Test inputs generated in C are separate from the visible `.data` demonstration.

| Example | Demo input words | Expected output words / meaning |
| --- | --- | --- |
| 01_width_conditions | ff, fffffff9, 3, 0 | ffffffff, ff, fffffff9, 0: signed byte, unsigned byte, signed minimum, unsigned less |
| 02_bits_endian | 12345678, 80000000, 0, 0 | 78563412, 78123456, 56, 0: byte reversal, rotate, field, leading zeros |
| 03_scalar_float | c0700000, 40100000, 0, 7fc00000 | bfc00000, fffffffd, 1, 1: -1.5, -3, ordered-less, unordered |
| 04_atomic_increment | 29, 0, 0, 0 | 29, 2a: old 41, new 42; input memory becomes 42 |
| 05_vector_rearrange | 1, 2, 1, 4 | 4, 1, 2, 1, ffffffff, 0, ffffffff, 0: reversed elements then equality masks |
| 06_compiler_idioms | 7b, ffffffff, 0, 1 | c, 176, 0, 1: /10, 3*x+5, low/high wide sum |

All table values are hexadecimal unless explicitly decoded. The atomics example modifies its input. Results are not benchmark measurements.

## Build and run

Python 3.8+, a C compiler, and NASM for x86-64 are required. From this directory:

```sh
python3 build.py --arch arm64 --test
python3 build.py --arch x64 --test
# Select one example:
python3 build.py --arch arm64 --example 02_bits_endian --test
```

Choose the matching host architecture on Linux. On macOS install Xcode command-line tools; Apple Silicon can build x64 and execute through Rosetta when installed. These examples need only baseline x86-64/SSE2 or hosted ARM64 FP/Advanced SIMD; they do not require AVX, SSSE3, LSE, AES, or pointer authentication. Optional advanced instructions are recognition material in the slides, not unguarded runtime prerequisites.

On Windows use `python` in a Visual Studio developer shell with the **matching x64 or ARM64 target** (`VSCMD_ARG_TGT_ARCH`). Install NASM for x64; install LLVM Clang for ARM64 `.S` assembly. MSVC compiles C and links the objects. These sources do not use Microsoft's armasm64 syntax. Cross-built executables must run on a matching Windows target.

`make test` chooses the native architecture on macOS/Linux. Build products and debug information stay under `build/<system>-<arch>/`. Omit `--test` to build without running. A failed command or reference check fails the build runner; each program returns zero only after its demo and 128 reference cases pass.

## Debugger exercise

For macOS ARM64:

```sh
lldb --no-lldbinit -- ./build/darwin-arm64/02_bits_endian
```

```text
breakpoint set --name asm_main
run
disassemble --name asm_main
breakpoint set --name re_operation
continue
register read x0 x1
memory read --format x --size 4 --count 4 $x0
thread step-inst
```

At `asm_main`, observe pointer setup and the call. At `re_operation`, x0/x1 are input/output pointers. For x64, pointers arrive in RDI/RSI on macOS/Linux and RCX/RDX on Windows, then are copied to R10/R11. Use `register read r10 r11` after those copies. In GDB use `break re_operation`, `run`, `disassemble /r re_operation`, `stepi`, and `x/4wx $rdi` (System V x64).

In Visual Studio open the built executable and matching PDB, set a function breakpoint at `re_operation`, and use Disassembly/Registers/Memory. In WinDbg use `bp <module>!re_operation`, `g`, `u`, and `t`. On macOS use symbol/instruction stepping for assembly; assembly line breakpoints are toolchain-dependent. C objects and dSYM information are retained for the driver.

Before running, predict the outputs. Afterward, annotate the inputs' widths and types, the instruction that supplies flags, and any memory mutation. Recheck your prediction against the scalar reference rather than treating a familiar mnemonic as proof of the algorithm.

## Correctness scope

Each example checks its `.data` demonstration plus 128 deterministic independent reference cases, including zero, all-one bit patterns, conversion-safe signed fractions, NaN comparisons, overflow, and division boundaries as applicable. Floating-point conversion inputs remain finite and representable. The atomic example checks a single-threaded fetch-add, wrapping, and memory modification; it does **not** establish concurrent correctness or memory-ordering behavior.

## Compiler fixture: O0 versus O2

The C fixture deliberately leaves case handlers undefined. Compile it to assembly or objects for inspection; do not try to link it as a complete program.

macOS/Linux, from this directory:

```sh
mkdir -p build/patterns
cc -O0 -S compiler_patterns.c -o build/patterns/O0.s
cc -O2 -S compiler_patterns.c -o build/patterns/O2.s
```

Windows developer shell:

```powershell
New-Item -ItemType Directory -Force build\patterns
cl /nologo /c /Od /FAs /Fabuild\patterns\O0.asm /Fobuild\patterns\O0.obj compiler_patterns.c
cl /nologo /c /O2 /FAs /Fabuild\patterns\O2.asm /Fobuild\patterns\O2.obj compiler_patterns.c
```

Find constant division, arithmetic address forms, function-pointer dispatch, the switch, and the small copy. The compiler may choose branches instead of a jump table; record what it actually generated. This is a comparison exercise, not a test that demands one specific instruction sequence.

## Instructor checkpoints

- Width/conditions: signed -7 is smaller than 3; its unsigned representation is larger. A SETcc result writes one byte, so note the extension before a full-width store.
- Bits: zero handling distinguishes BSR from CLZ. REV/BSWAP reverse bytes; ROR rotates bits without discarding them.
- Float: -3.75 truncates to -3, not -4. Unordered comparisons require special handling; an ARM LT condition after FCMP includes unordered.
- Atomics: old/new output is the successful update's values. ST LXR status is not the counter value. Other threads can change memory after the operation returns.
- Vector: masks are all-one lanes. PSHUFD reverses words; REV64 alone only swaps word pairs, so EXT is also needed.
- Compiler arithmetic: unsigned division-by-ten needs the full 64-bit product and shift 35. LEA brackets do not imply a memory read. Carry propagates into the high word.

## Validation

On 2026-11-25, all six examples built and passed on macOS ARM64 and macOS x64 under Rosetta: **129 checks per executable, 774 per architecture**. Windows/Linux object formats are checked separately; native linking, debugger behavior, and runtime testing on those OSes remain to be confirmed. The macOS x64 results are Rosetta results, not a claim of testing on physical Intel/AMD hardware.

## Recognition-only extensions

The core slides also cover LSE atomics, feature-dependent bit/vector instructions, x87, control-flow hardening, and compiler instrumentation. Crypto is the separate optional end-of-course module. Neither hardening nor crypto snippets are installed as unconditional executable labs.
