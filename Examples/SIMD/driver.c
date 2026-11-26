/* ASM_Template convention: C main calls assembly asm_main.
 * The demonstration arrays are defined in assembly .data. asm_main passes
 * their addresses to simd_operation. Separate generated inputs test that function.
 * CASE: 1=vector add, 2=dot product, 3=uint32 sum. */
#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if CASE == 1
extern void asm_main(void);
extern void simd_operation(const float *, const float *, float *, size_t);
extern float demo_a[], demo_b[], demo_out[];
#elif CASE == 2
extern float asm_main(void);
extern float simd_operation(const float *, const float *, size_t);
extern float demo_a[], demo_b[];
#elif CASE == 3
extern uint32_t asm_main(void);
extern uint32_t simd_operation(const uint32_t *, size_t);
extern uint32_t demo_a[];
#else
#error CASE must be 1, 2, or 3
#endif
extern const uint64_t demo_count; /* .quad / dq in the assembly data section */
#ifdef SIMD_X64
extern unsigned simd_features(void);
#endif
/* Print one representative run, not hundreds of test vectors. The actual
 * output always comes from asm_main; expected output is computed in C. */
#if CASE != 3
static void print_floats(const char *label, const float *values, size_t n) {
    printf("%s [", label);
    for (size_t i = 0; i < n; ++i) printf("%s%g", i ? ", " : "", (double)values[i]);
    puts("]");
}
#else
static void print_integers(const uint32_t *values, size_t n) {
    printf("Input: [");
    for (size_t i = 0; i < n; ++i) printf("%s%" PRIu32, i ? ", " : "", values[i]);
    puts("]");
}
#endif
/* SIMD reductions regroup additions, so compare floats with a tolerance.
 * The integer reference instead uses exact unsigned wrapping arithmetic. */
static int close_float(float a, float b) {
    float d = a - b;
    if (d < 0) d = -d;
    if (b < 0) b = -b;
    return d <= 0.0001f * (1.0f + b); /* NaNs fail this comparison. */
}
/* Show the assembly-defined arrays before calling the assembly entry point.
 * No C-generated inputs are used in this worked demonstration. */
static int demonstrate(void) {
    const size_t n = (size_t)demo_count;
    printf("\nExample %d: %zu elements from assembly .data\n", CASE, n);
    puts("Call path: C main -> asm_main -> simd_operation");
#if CASE == 3
    print_integers(demo_a, n);
    uint32_t expected = 0;
    for (size_t i = 0; i < n; ++i) expected += demo_a[i];
    uint32_t actual = asm_main();
    printf("Actual output: %" PRIu32 "\nExpected output: %" PRIu32 "\n", actual, expected);
    if (actual != expected) return 1;
#else
    print_floats("Input a:", demo_a, n);
    print_floats("Input b:", demo_b, n);
#if CASE == 1
    /* The assembly wrapper passes demo_out to the operation for memory stores. */
    asm_main();
    print_floats("Actual output:", demo_out, n);
    printf("Expected output: [");
    int failed = 0;
    for (size_t i = 0; i < n; ++i) {
        float expected = demo_a[i] + demo_b[i];
        printf("%s%g", i ? ", " : "", (double)expected);
        if (!close_float(demo_out[i], expected)) failed = 1;
    }
    puts("]");
    if (failed) return 1;
#else
    float expected = 0;
    for (size_t i = 0; i < n; ++i) expected += demo_a[i] * demo_b[i];
    float actual = asm_main();
    printf("Actual output: %g\nExpected output: %g\n", (double)actual, (double)expected);
    if (!close_float(actual, expected)) return 1;
#endif
#endif
    puts("Displayed result: PASS\n");
    return 0;
}

int main(int argc, char **argv) {
    size_t first = 0, last = 65, cases = 0;
    if (argc > 2) { fprintf(stderr, "Usage: %s [length 0..65]\n", argv[0]); return 2; }
    if (argc == 2) {
        char *end;
        unsigned long n = strtoul(argv[1], &end, 10);
        if (!argv[1][0] || *end || n > 65) return 2;
        first = last = (size_t)n;
    }
#ifdef SIMD_X64
    unsigned required = CASE == 3 ? 2 : 1;
    if (!(simd_features() & required)) {
        puts(CASE == 3 ? "SKIP: AVX2 or OS vector state unavailable" : "SKIP: AVX or OS vector state unavailable");
        return 77;
    }
#endif
    /* Feature checks must precede the .data demo as well as the test loop. */
    if (demonstrate()) { fputs("FAIL: .data demonstration\n", stderr); return 1; }
    /* Optional CLI length selects test inputs only; the .data demo stays fixed. */
    for (size_t n = first; n <= last; ++n) {
        for (size_t offset = 0; offset < 8; ++offset) {
            /* Offset sweeps move the starting address in 4-byte steps. Extra
             * capacity holds the longest input plus offset and guard values. */
            float a[80], b[80], out[80];
            uint32_t integers[80];
            /* Signed fractional floats make the lane values easy to inspect;
             * UINT32_MAX forces the integer example to exercise wraparound. */
            for (size_t i = 0; i < 80; ++i) {
                a[i] = (float)((int)(i % 13) - 6) * 0.25f;
                b[i] = (float)((int)(i % 7) - 3) * 0.5f;
                integers[i] = (i % 3 == 0) ? UINT32_MAX : (uint32_t)(i * 17);
                out[i] = -12345.0f;
            }
#if CASE == 1
            /* Only the requested output span may change. All other entries
             * must retain the sentinel, checked exactly (without tolerance). */
            simd_operation(a + offset, b + offset, out + offset, n);
            for (size_t i = 0; i < 80; ++i) {
                float expected = (i >= offset && i < offset + n) ? a[i] + b[i] : -12345.0f;
                if ((i < offset || i >= offset + n) ? out[i] != expected : !close_float(out[i], expected)) {
                    fprintf(stderr, "FAIL add n=%zu offset=%zu lane=%zu: %g != %g\n", n, offset, i, out[i], expected);
                    return 1;
                }
            }
#elif CASE == 2
            float expected = 0;
            for (size_t i = 0; i < n; ++i) expected += a[offset+i] * b[offset+i];
            float actual = simd_operation(a + offset, b + offset, n);
            if (!close_float(actual, expected)) {
                fprintf(stderr, "FAIL dot n=%zu offset=%zu: %g != %g\n", n, offset, actual, expected);
                return 1;
            }
#else
            uint32_t expected = 0;
            for (size_t i = 0; i < n; ++i) expected += integers[offset+i];
            uint32_t actual = simd_operation(integers + offset, n);
            if (actual != expected) {
                fprintf(stderr, "FAIL sum n=%zu offset=%zu: %u != %u\n", n, offset, actual, expected);
                return 1;
            }
#endif
            ++cases;
        }
    }
    printf("PASS case %d: %zu length/alignment combinations\n", CASE, cases);
    return 0;
}
