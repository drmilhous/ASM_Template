/* Tiny C driver for the Intel maze game.  Sets the console up (ANSI colours
 * on Windows, raw keyboard input on Linux) and hands the maze file name to the
 * assembly.  Usage: MazeGame [maze.txt] */
#include <stdio.h>
#include <stdlib.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <termios.h>
#include <unistd.h>
static struct termios saved;
static void restore(void) { tcsetattr(0, TCSANOW, &saved); }
#endif

int asm_main(const char *mazeFile);

int main(int argc, char **argv)
{
#ifdef _WIN32
  HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
  DWORD mode;
  if (GetConsoleMode(out, &mode))
    SetConsoleMode(out, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
#else
  if (isatty(0)) {                       /* one key press at a time, no echo */
    struct termios raw;
    tcgetattr(0, &saved);
    raw = saved;
    raw.c_lflag &= ~(ICANON | ECHO);
    raw.c_cc[VMIN] = 1;
    raw.c_cc[VTIME] = 0;
    tcsetattr(0, TCSANOW, &raw);
    atexit(restore);
  }
#endif
  setvbuf(stdout, NULL, _IOFBF, 1 << 16);   /* one write per frame; asm calls fflush */
  return asm_main(argc > 1 ? argv[1] : "maze.txt");
}
