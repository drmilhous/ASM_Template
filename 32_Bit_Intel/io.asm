; ;RDI, RSI, RDX, RCX, R8, R9 (R10) XMM0, XMM1, XMM2, XMM3, XMM4, XMM5, XMM6 and XMM7 are used for the first floating point arguments.
segment .data
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