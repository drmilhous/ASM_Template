segment .data
dumpMessage db "EAX: %08X EBX: %08X ECX: %08X EDX: %08X", 10
        dumpMessage2: db "ESI: %08X EDI: %08X ESP: %08X EBP: %08X", 10
        dumpMessage3: db "EFLAGS %08X  ",0
; flags_format db "CF %c PF %c AF %c ZF %c SF %c TF %c IF %c DF %c OF %c", 10,0
flags_format db "CF %c ZF %c", 10,0
print_int_format db "%d",10,0 
print_nl_format db 10,0
print_hex_format db "%08X",10,0
scan_int_format db "%d", 0
print_string_format db "%s", 0

extern printf
extern scanf
extern puts


segment .text 
    global print_int 
    global print_hex
    global read_int
    global print_nl
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

print_nl:
        push   ebp
        mov    ebp, esp
        push   eax
        push   ebx

        push eax
        ; -no-pie 
        get_GOT
        lea     eax,[ebx+print_nl_format wrt ..gotoff]
        push eax
        call printf WRT ..plt
        add esp, 8

        pop ebx
        pop eax
        pop ebp
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
dump_registers: ; ebx has the got address
        ; original stack 0x4C
        ; return 0x48
        push ebp; 0x44
        mov ebp, esp ; 0x40
        pusha ; 0x20 +0x3C
        pushfd
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
        lea eax, [ebx+dumpMessage wrt ..gotoff]
        push eax
        call    printf wrt ..plt
        
        add     esp, 4*9
        popfd
        call dump_flags
        popa
        mov esp, ebp
        pop ebp
        ret

dump_flags: ; ebx points to the got table
        push ebp
        mov ebp, esp
        push eax
        push ecx
        pushf
        
z_check:
        mov ecx, [ebp - 0xC]; get the flagss
        
        mov eax, '0'
        push eax
        test ecx, 0x0040 ; zero flags
        jz cf_check
                add eax, 1
                mov [esp], eax
                jmp cf_check
cf_check:
        mov eax, '0'
        push eax
        test ecx, 0x0001 ; carry flag
        jz print_flags
                add eax, 1
                mov [esp], eax
                jmp print_flags
print_flags:
        lea eax, [ebx+flags_format wrt ..gotoff]
        push eax
        call printf wrt ..plt
        add esp, 4 * 3
        popf
        pop ecx
        pop eax
        mov esp, ebp
        pop ebp
        ret