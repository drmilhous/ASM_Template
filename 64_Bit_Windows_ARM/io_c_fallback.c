/* I/O helpers callable from ARM64 assembly (compiled by cl.exe). Same behavior as io.asm.
 *   print_int    : w0 = integer to print
 *   print_nl     : prints a newline
 *   print_string : x0 = address of a zero-terminated string
 *   print_float  : d0 = double to print
 *   read_int     : reads one line, returns a signed decimal in w0 (sign-extended into x0)
 *   read_float   : reads one line, returns a double in d0
 *   read_string  : x0 = buffer, x1 = size; reads one line without the newline;
 *                  returns x0 = length, or -1 at end of input */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

void print_int(int value)        { printf("%d", value); }
void print_nl(void)              { printf("\n"); }
void print_string(const char *s) { printf("%s", s); }
void print_float(double value)   { printf("%f", value); }

long long read_string(char *buffer, long long size)
{
    size_t length;
    int c;
    if (size < 1) return 0;
    if (size > INT_MAX) size = INT_MAX;
    if (!fgets(buffer, (int)size, stdin)) { buffer[0] = 0; return -1; }
    length = strlen(buffer);
    if (length > 0 && buffer[length - 1] == '\n') {
        buffer[--length] = 0;
    } else {
        while ((c = getchar()) != '\n' && c != EOF) { } /* discard the rest of a long line */
    }
    if (length > 0 && buffer[length - 1] == '\r') buffer[--length] = 0;
    return (long long)length;
}

static char read_line[256];
long long read_int(void)  { read_string(read_line, sizeof read_line); return (int)strtol(read_line, NULL, 10); }
double    read_float(void){ read_string(read_line, sizeof read_line); return strtod(read_line, NULL); }
