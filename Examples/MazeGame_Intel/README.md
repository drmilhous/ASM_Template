# ASCII Maze Platformer (Intel x86-64, assembly)

The same game as `../MazeGame_Windows_ARM`, written in NASM for Intel x86-64.
**One source file, `maze_game.asm`, builds on both Linux and Windows**; a few `%ifdef WINDOWS`
blocks hold the only differences. A small C driver sets up the console.

## Build and run

Linux (needs `nasm` and `gcc`), from this folder, in a real terminal:

```sh
make
./MazeGame            # or ./MazeGame other_maze.txt
```

Windows x64 (needs NASM on PATH and Visual Studio C++ x64 tools), in Windows Terminal:

```powershell
.\quickBuild.ps1      # or .\quickBuild.ps1 other_maze.txt
```

## Playing and the maze format

Identical to the ARM64 version: see `../MazeGame_Windows_ARM/README.md`.
Each key press is one frame. Left/Right walk, Up jumps 3 cells (hold Left/Right while rising to
move forward), any other key waits a frame, Q quits (Esc too on Windows). On Linux, a
lone Esc is not a quit key, because arrow keys start with Esc.

## What differs between Linux and Windows

| | Linux (System V) | Windows x64 |
|---|---|---|
| C call arguments | rdi, rsi, rdx, rcx | rcx, rdx, r8, r9 |
| Extra rules | `al` = number of vector registers; call through the PLT | 32 bytes of shadow space |
| Keyboard | `read()` on a raw-mode terminal; arrows are `ESC [ A/B/C/D` | `_getch()`; arrows are 0 or 224, then 72/80/75/77 |
| Colours | terminal understands ANSI already | driver turns on virtual-terminal mode |
| Callee-saved extras | - | rdi and rsi (`asm_main` saves them) |

The `ccall` macro hides the call rules, and `CARG1`..`CARG3` name the first three argument registers.
Our own functions use one private convention on both systems (arguments in edi, esi, edx, result in
eax), listed at the top of the source.

## Status

Linux: built and played end to end (a scripted win, a monster death, quit, and colour codes all checked).
Windows: assembled with NASM, but not yet built or run.
