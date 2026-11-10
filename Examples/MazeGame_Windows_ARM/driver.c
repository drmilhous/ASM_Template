/* Tiny C driver: turns on ANSI colour support in the Windows console and
 * hands the maze file name to the assembly game.  Usage: MazeGame.exe [maze.txt] */
#include <stdio.h>
#include <windows.h>

int asm_main(const char *mazeFile);

int main(int argc, char **argv)
{
  HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
  DWORD mode;
  if (GetConsoleMode(out, &mode))
    SetConsoleMode(out, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
  setvbuf(stdout, NULL, _IOFBF, 1 << 16);   /* one write per frame; asm calls fflush */
  return asm_main(argc > 1 ? argv[1] : "maze.txt");
}
