; ;RDI, RSI, RDX, RCX, R8, R9 (R10) XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6 and XMM7 are used for the first floating point arguments.
segment .data
dumpMessage db "EAX: %08X EBX: %08X ECX: %08X EDX: %08X", 10
        dl3 db "ESI: %08X EDI: %08X ESP: %08X EBP: %08X", 10,0
print_int_format db "%d",10,0 
print_hex_format db "%08X",10,0
scan_int_format db "%d", 0
print_string_format db "%s", 0


; printInt: db "%d",0
; printNewline: db 10,0
; printString: db "%s",0
; dump_regs_string: db "RAX =0x%16X", 10,0
; global print_nl
; global print_string
; global dump_regs

extern printf
extern scanf
extern puts


segment .text 
    global print_int 
    global print_hex
    global read_int
    global print_string
    global dump_registers

    global get_GOT_EAX
    extern  _GLOBAL_OFFSET_TABLE_




%macro  get_GOT 0 
        call    %%getgot 
  %%getgot: 
        pop     ebx 
        add     ebx,_GLOBAL_OFFSET_TABLE_+$$-%%getgot wrt ..gotpc 
%endmacro
%macro  get_GOT_A 0 
        call    %%getgot_a 
  %%getgot_a: 
        pop     eax 
        add     eax,_GLOBAL_OFFSET_TABLE_+$$-%%getgot_a wrt ..gotpc 
%endmacro

get_GOT_EAX:
        get_GOT_A
        ret

print_int:
        push   ebp
        mov    ebp, esp
        push   eax
        push   ebx

        push eax
        ; -no-pie 
        get_GOT
        lea     eax,[ebx+print_int_format wrt ..gotoff]
        push eax
        call printf WRT ..plt
        add esp, 8

        pop ebx
        pop eax
        pop ebp
        ret
print_hex:
        push   ebp
        mov    ebp, esp
        push   eax
        push ebx

        push eax
        ; -no-pie 
        get_GOT
        lea     eax,[ebx+print_hex_format wrt ..gotoff]
        push eax
        call printf WRT ..plt
        add esp, 8
        pop ebx
        pop eax
        pop ebp
        ret
read_int:
        push    ebp
        mov     ebp, esp
        sub     esp, 4
        lea     eax, [ebp-4]
        push    eax
        call    get_GOT_EAX
        lea     eax,[eax+scan_int_format wrt ..gotoff]
        push    eax
        call    scanf WRT ..plt
        add     esp, 8

        mov eax, [ebp-4]
        add     esp, 4
        mov     esp, ebp
        pop     ebp
        ret
print_string:
        push ebp
        mov ebp, esp
        push eax
        call    get_GOT_EAX
        lea     eax,[eax+print_string_format wrt ..gotoff]
        push eax
        call printf WRT ..plt
        add esp, 8
        pop ebp
        ret
dump_registers:
        ; original stack 0x4C
        ; return 0x48
        push ebp; 0x44
        mov ebp, esp ; 0x40
        pusha ; 0x20 +0x3C
        sub esp, 4;   ;ebp; 0x1C
        sub esp, 4;  <-esp 0x18
        
        push    edi; + 0x14
        push    esi; + 0x10
        push    edx; + 0xc
        push    ecx; + 0x8
        push    ebx; + 0x4
        push    eax; <-esp
        mov eax, ebp ; get esp from ebp
        add eax, 0x8; add 8 for ret and ebp
        mov [esp+0x1C], eax ; esp
        mov eax, [ebp]
        mov [esp+0x18], eax
        call get_GOT_EAX
        lea eax, [eax+dumpMessage wrt ..gotoff]
        push eax
        call    printf wrt ..plt
        add     esp, 4*9
        popa
        mov esp, ebp
        pop ebp
        ret