/* I/O helpers callable from ARM64 assembly (compiled by cl.exe).
 *   print_int    : w0 = integer to print
 *   print_nl     : prints a newline
 *   print_string : x0 = address of a zero-terminated string */
#include <stdio.h>

void print_int(int value)        { printf("%d", value); }
void print_nl(void)              { printf("\n"); }
void print_string(const char *s) { printf("%s", s); }
