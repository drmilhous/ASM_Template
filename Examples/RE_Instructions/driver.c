/* Demo: main -> asm_main -> re_operation. The shown arrays are assembly .data.
 * Tests call re_operation directly with independent inputs and scalar references. */
#include <stdint.h>
#include <inttypes.h>
#include <stdio.h>
#include <string.h>
extern void asm_main(void);
extern void re_operation(uint32_t *input, uint32_t *output);
extern uint32_t demo_input[4], demo_output[8];
static float as_float(uint32_t bits) { float f; memcpy(&f, &bits, 4); return f; }
static uint32_t as_bits(float f) { uint32_t u; memcpy(&u, &f, 4); return u; }
static const char *names[] = {"", "width and branchless conditions", "bits and byte order",
    "scalar floating point", "atomic increment", "vector rearrangement", "compiler idioms"};
static size_t count(void) { return CASE == 5 ? 8 : CASE == 4 ? 2 : 4; }
static void reference(const uint32_t in[4], uint32_t out[8]) {
    memset(out, 0, 8 * sizeof(*out));
#if CASE == 1
    out[0] = ((in[0] & 255u) ^ 128u) - 128u; /* signed byte represented as uint32 */
    out[1] = in[0] & 255u;
    out[2] = (int32_t)in[1] < (int32_t)in[2] ? in[1] : in[2];
    out[3] = in[1] < in[2];
#elif CASE == 2
    out[0] = (in[0]>>24) | ((in[0]>>8)&0xff00u) | ((in[0]<<8)&0xff0000u) | (in[0]<<24);
    out[1] = (in[0]>>8) | (in[0]<<24);
    out[2] = (in[0]>>8) & 255u;
    out[3] = 32;
    for (unsigned bit=0; bit<32; ++bit) if (in[1] & (1u << (31-bit))) { out[3]=bit; break; }
#elif CASE == 3
    float a=as_float(in[0]), b=as_float(in[1]), q=as_float(in[3]);
    out[0]=as_bits(a+b);
    /* Tests keep this conversion finite/in range: out-of-range semantics differ. */
    out[1]=(uint32_t)(int32_t)a;
    out[2]=a<b;
    out[3]=q!=q;
#elif CASE == 4
    out[0]=in[0]; out[1]=in[0]+1u;
#elif CASE == 5
    for (size_t i=0;i<4;++i) { out[i]=in[3-i]; out[4+i]=in[i]==1 ? UINT32_MAX : 0; }
#elif CASE == 6
    out[0]=in[0]/10u; out[1]=in[0]*3u+5u;
    uint64_t sum=((uint64_t)in[2]<<32 | in[1]) + in[3];
    out[2]=(uint32_t)sum; out[3]=(uint32_t)(sum>>32);
#endif
}
static void show(const char *label, const uint32_t *words, size_t n) {
    printf("%s [",label);
    for(size_t i=0;i<n;++i) printf("%s0x%08" PRIx32,i?", ":"",words[i]);
    puts("]");
}
static int verify(const uint32_t *actual, const uint32_t *expected, size_t test) {
    for(size_t i=0;i<count();++i) if(actual[i]!=expected[i]) {
        fprintf(stderr,"FAIL test=%zu slot=%zu actual=0x%08" PRIx32 " expected=0x%08" PRIx32 "\n",test,i,actual[i],expected[i]);
        return 1;
    }
    return 0;
}
int main(void) {
    uint32_t expected[8], original[4];
    memcpy(original,demo_input,sizeof original);
    printf("\n%s: assembly .data demo\n",names[CASE]);
    puts("main -> asm_main -> re_operation");
    show("Input words:",demo_input,4);
    reference(original,expected);
    asm_main();
    show("Actual output:",demo_output,count());
    show("Expected output:",expected,count());
#if CASE == 3
    printf("Floats: %g + %g = %g; truncated=%" PRId32 "; ordered-less=%u; unordered=%u\n",
        as_float(original[0]),as_float(original[1]),as_float(demo_output[0]),(int32_t)demo_output[1],demo_output[2],demo_output[3]);
#elif CASE == 4
    show("Input after atomic update:",demo_input,4);
    if(demo_input[0]!=expected[1]) return 1;
#endif
    if(verify(demo_output,expected,0)) return 1;
    uint32_t state=0x12345678u;
    for(size_t test=1;test<=128;++test) {
        uint32_t input[4], output[8]={0};
        for(size_t i=0;i<4;++i) { state=state*1664525u+1013904223u;input[i]=state; }
        /* Explicit boundaries complement the deterministic varied inputs. */
        if(test==1) memset(input,0,sizeof input);
        if(test==2) for(size_t i=0;i<4;++i) input[i]=UINT32_MAX;
        if(test==3) {input[0]=9;input[1]=UINT32_MAX;input[2]=0;input[3]=1;}
        if(test==4) input[0]=10;
#if CASE == 3
        input[0]=as_bits(((int)(test%31)-15)*0.25f);
        input[1]=as_bits(((int)(test%19)-9)*0.5f);
        input[3]=test%2 ? 0x7fc00000u : as_bits(1.0f);
        if(test==1) input[1]=0x7fc00000u; /* unordered < must produce false */
#endif
        reference(input,expected);
        re_operation(input,output);
#if CASE == 4
        if(input[0]!=expected[1]) return 1;
#endif
        if(verify(output,expected,test)) return 1;
    }
    puts("PASS: .data demonstration + 128 independent reference cases");
    return 0;
}
