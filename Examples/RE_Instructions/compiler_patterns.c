/* Compile at O0 and O2; this fixture is for disassembly, not linking/running.
 * External cases keep switch destinations observable. Compiler output varies. */
#include <stdint.h>
#include <string.h>
extern uint32_t case0(uint32_t);
extern uint32_t case1(uint32_t);
extern uint32_t case2(uint32_t);
extern uint32_t case3(uint32_t);
uint32_t divide_ten(uint32_t x) { return x / 10u; }
uint32_t scaled_value(uint32_t x) { return 3u * x + 5u; }
uint64_t wide_add(uint32_t low, uint32_t high, uint32_t addend) {
    return ((uint64_t)high << 32 | low) + addend;
}
uint32_t switch_dispatch(uint32_t code, uint32_t value) {
    switch (code) {
        case 0: return case0(value);
        case 1: return case1(value);
        case 2: return case2(value);
        case 3: return case3(value);
        default: return 0;
    }
}
uint32_t pointer_dispatch(uint32_t code, uint32_t value) {
    static uint32_t (*const table[])(uint32_t) = {case0, case1, case2, case3};
    return code < 4 ? table[code](value) : 0;
}
void short_copy(void *dst, const void *src) { memcpy(dst, src, 16); }
