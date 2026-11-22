# ASM_Template
Assembly template for online courses. Linux (64-bit), Mac, and Windows are supported.

## Linux: install required libraries

    sudo apt install nasm make gcc-multilib vim gdb

(ARM64 Linux: `sudo apt install make gcc gdb binutils`; `nasm` is not needed.)

## Mac

    xcode-select --install
    brew install nasm

## Windows

1. Install **NASM**: https://www.nasm.us/pub/nasm/releasebuilds/ (open the newest version folder, then `win64`, run the installer, and make sure `nasm` is on your PATH).
2. Install **Build Tools for Visual Studio**: https://visualstudio.microsoft.com/downloads/ (under "All downloads" > "Tools for Visual Studio"). In the installer, tick **Desktop development with C++**.
3. Open PowerShell in the `ASM_Template` folder and run the setup script (see below), then open a new terminal.

## Windows on Arm (native, PowerShell)

NASM is for Intel/AMD, so it is not used here. The `64_Bit_Windows_ARM` template uses the ARM64 tools in Visual Studio Build Tools (`armasm64`, `cl`, `link`) and builds native ARM64 programs with no emulation.

1. Install **Build Tools for Visual Studio**: https://visualstudio.microsoft.com/downloads/ ("All downloads" > "Tools for Visual Studio"). Tick **Desktop development with C++**, and under Individual components add **MSVC v143 - VS 2022 C++ ARM64 build tools**.
2. In PowerShell, from the `ASM_Template` folder, run `.\bin\install.ps1 [project_folder]` (it also checks that the tools are installed) and open a new terminal.
3. Create a project: `WindowsArmProject.ps1 hello` (use `.\bin\WindowsArmProject.ps1 hello` if `bin` is not on your PATH).
4. `cd` to the project folder and run `.\quickBuild.ps1`. It builds with `armasm64`, links with the C runtime, and runs the program.

The template files use armasm64 syntax (`AREA`, `PROC`, `DCB`), not the GNU syntax of the Linux ARM64 template. If you prefer Linux tools, WSL2 with `64bitArmProject.sh` also runs natively on these machines.

## Alternative Windows builders (x64 and ARM64)

Use `bin/Build-Windows-x64.ps1` for Intel/AMD x64 binaries and
`bin/Build-Windows-arm64.ps1` for ARM64 binaries. The suffix selects the target;
neither entry script needs an `-Architecture` argument. Both delegate to
`bin/Build-Windows.ps1`, keeping the build logic shared. The existing project generators,
`build.ps1`, `quickBuild.ps1`, and tool-discovery scripts are unchanged.
These opt-in builders work with the Windows templates and existing generated projects containing
one program `.asm` file, `driver.c`, and `io.asm`.

From the `ASM_Template` folder:

```powershell
# Build the Intel/AMD x64 template without running it.
.\bin\Build-Windows-x64.ps1 -ProjectDirectory .\64_Bit_Windows

# Build the ARM64 template without running it.
.\bin\Build-Windows-arm64.ps1 -ProjectDirectory .\64_Bit_Windows_ARM

# Build and run an existing project (choose the script matching its architecture).
.\bin\Build-Windows-x64.ps1 -ProjectDirectory "$env:USERPROFILE\Projects\hello" -Run

# Select a program explicitly if there are multiple assembly files.
.\bin\Build-Windows-x64.ps1 -ProjectDirectory .\64_Bit_Windows -Source 64bit.asm -Configuration Release

# Clean only the selected architecture/configuration's output directory.
.\bin\Build-Windows-arm64.ps1 -ProjectDirectory .\64_Bit_Windows_ARM -Clean
```

### Create projects with local build/run commands

Use the separate `bin/New-WindowsProject.ps1` generator to create a project
without copying any legacy build scripts:

```powershell
.\bin\New-WindowsProject.ps1 hello -Architecture x64
.\bin\New-WindowsProject.ps1 hello-arm -Architecture arm64
```

Each project gets its own folder under `ASM_PROJECTS`, or your user profile's
`Projects` folder by default. Override the destination with
`-ProjectsDirectory C:\MyProjects`. The generator honors `ASM_TEMPLATE_HOME`
and refuses to overwrite an existing project directory. Compiler installation
is checked at build time, not during project creation.

Inside the generated project:

```powershell
.\build.ps1                       # Build only
.\run.ps1                         # Build, then run on success
.\build.ps1 -Configuration Release
.\run.ps1 -Configuration Release
.\build.ps1 -Clean                # Clean Debug output for this project's target
```

The generated folder contains `<name>.asm`, `driver.c`, `io.asm`, `io.inc`
(x64 only), `.asm-template.json`, and **new** `build.ps1` / `run.ps1` launchers.
These are small forwarding scripts, not copies of the old builders and not
filesystem symbolic links, so creating them requires no symlink privileges.
They select the architecture-suffixed builder automatically and resolve the
project directory from their own location, even when invoked from elsewhere.
The configured program source stays selected even if other `.asm` files are
added; use `-Source` to override it.

Build logic remains in the ASM_Template installation, so shared-builder updates
apply to generated projects. The installation must remain available. If it moves,
set `ASM_TEMPLATE_HOME` to its new location or update `templateHome` in the
project's `.asm-template.json`. Moving the project itself needs no changes.
Outputs remain in `build/<architecture>/<configuration>/`. The old generators
continue to work unchanged.

### Manual use and build details

You can also copy the appropriate entry script **and** `Build-Windows.ps1` into
a generated project, keeping them in the same directory, and run
`.\Build-Windows-x64.ps1 -Run` or `.\Build-Windows-arm64.ps1 -Run` there.
`ProjectDirectory` defaults
to the current working directory; explicit project paths are resolved from the
caller, and relative `Source` paths are resolved inside the project.

- Outputs go in `build/<architecture>/<configuration>/`, including the executable,
  objects, and Debug PDB. Debug is the default; use `-Configuration Release` for
  optimized C driver compilation. Assembly is not automatically rewritten or optimized.
- The builder discovers Visual Studio on each invocation and initializes its
  environment in a child `cmd.exe`; it does not modify the parent PowerShell PATH
  or use the legacy tool-location cache.
- Install the x64/x86 C++ tools and a Windows SDK through the Desktop development
  with C++ workload. For ARM64 output, also install the ARM64 C++ tools. This
  builder deliberately uses the x64-hosted toolchain (`amd64` or `amd64_arm64`);
  on Windows on Arm that requires x64 emulation. It produces ARM64 binaries with
  the latter target, but is not a native-ARM64-host-only build workflow.
- x64 builds additionally require NASM on PATH. Use NASM Windows x64 sources for
  `x64`, and Microsoft `armasm64` sources for `arm64`. Selecting another target
  does not translate assembly between instruction sets.
- Both the program and `io.asm` are assembled, `driver.c` is compiled separately,
  and the objects are linked once. Extra assembly files are not automatically included.
- Debug enables C debug information and, for NASM, CodeView information. ARM64
  assembly source-level debug information is not enabled by this script.
- Failed build stages stop the build and prevent execution. `-Run` returns the
  program's exit code; without it, a successful build returns zero. The x64
  starter deliberately returns 42, which is not a build failure.
- `-Clean` only cleans; it does not build. It removes the entire selected output
  directory, so keep handwritten files outside `build/`. Paths containing spaces
  are supported; percent signs, quotes, and newlines in build paths are rejected.

## System call examples

The `Syscalls` folder has raw system call programs (write, getpid, open/read/close, mmap, exit) for every platform and CPU above. See `Syscalls/README.md`. The `Libc` folder has the same platforms using the C library (fopen/fwrite/fread, malloc, creating processes, executable memory). `Explorer/index.html` is a searchable web page of all of them with OS and platform dropdowns.

The `Examples/AVX` folder has six SIMD programs (SSE, AVX, FMA, AVX2, CPUID detection, AVX-512) in both NASM and GNU as syntax (using the template's io library), for Linux, macOS (Intel) and Windows x64. See `Examples/AVX/README.md`.

## Setup: choose install and project folders

Run from the `ASM_Template` folder (or its parent). The current folder becomes the install location; the optional argument is where projects are created (default `~/projects`, or `%USERPROFILE%\Projects` on Windows).

    ./bin/setup.sh [project_folder]        # Linux / Mac
    .\bin\install.ps1 [project_folder]     # Windows (setup + PATH + tool check)

The locations are stored in the variables `ASM_TEMPLATE_HOME` and `ASM_PROJECTS` (Linux/Mac: `~/.asm_template.conf`; Windows: user environment variables). You can override either per run, e.g. `ASM_PROJECTS=/some/dir 64bitIntelProject.sh hello`.

## Create a new project called hello

    64bitIntelProject.sh hello             # Linux (or ./bin/64bitIntelProject.sh hello)
    .\bin\WindowsProject.ps1 hello         # Windows
