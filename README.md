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

## System call examples

The `Syscalls` folder has raw system call programs (write, getpid, open/read/close, mmap, exit) for every platform and CPU above. See `Syscalls/README.md`.

## Setup: choose install and project folders

Run from the `ASM_Template` folder (or its parent). The current folder becomes the install location; the optional argument is where projects are created (default `~/projects`, or `%USERPROFILE%\Projects` on Windows).

    ./bin/setup.sh [project_folder]        # Linux / Mac
    .\bin\install.ps1 [project_folder]     # Windows (setup + PATH + tool check)

The locations are stored in the variables `ASM_TEMPLATE_HOME` and `ASM_PROJECTS` (Linux/Mac: `~/.asm_template.conf`; Windows: user environment variables). You can override either per run, e.g. `ASM_PROJECTS=/some/dir 64bitIntelProject.sh hello`.

## Create a new project called hello

    64bitIntelProject.sh hello             # Linux (or ./bin/64bitIntelProject.sh hello)
    .\bin\WindowsProject.ps1 hello         # Windows
