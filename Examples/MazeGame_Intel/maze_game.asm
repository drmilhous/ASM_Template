; ASCII maze platformer - Intel x86-64, NASM syntax.
; One source file for BOTH Linux (elf64) and Windows (win64).  It is the same
; game as the ARM64 version in ../MazeGame_Windows_ARM: small functions, one
; frame per key press, ANSI colours.
;
; Controls: Left/Right walk, Up jumps 3 cells straight up (from the ground),
;           Down / any other key = wait a frame, Q quits (Esc too on Windows).
; Maze:     # wall   M monster   G goal   P player start
; Stomp a monster by landing on it from above; any other contact kills you.
;
; Internal calling convention (our own functions, same on both OSes):
;   arguments in edi, esi, edx - result in eax (or rax for a pointer)
;   rbx, r12-r14 are preserved; rax, rcx, rdx, rsi, rdi may be clobbered
; Calls into the C library use the real OS convention through the 'ccall'
; macro and the CARG1..CARG3 register names below.
;
;   asm_main     rdi/rcx = maze file name        eax = 0
;   load_maze    rdi = file name                 eax = 0 ok, -1 no file, -2 no 'P'
;   find_player  -                               eax = 0 ok, -2 no 'P'
;   row_trim     rdi = row buffer                eax = row length
;   get_cell     edi = x, esi = y                eax = character ('#' outside)
;   set_cell     edi = x, esi = y, edx = char    -
;   read_byte    -                               eax = byte, or -1 at end of input
;   get_key      -                               eax = KEY_*
;   color_for    edi = character                 rax = escape string
;   try_move     edi = dx, esi = dy              eax = 1 moved, 0 blocked
;   step         edi = KEY_*                     -
;   render       -                               -

default rel

%ifidn __OUTPUT_FORMAT__, win64
  %define WINDOWS 1
  %define CARG1 rcx
  %define CARG2 rdx
  %define CARG3 r8
%else
  %define CARG1 rdi
  %define CARG2 rsi
  %define CARG3 rdx
%endif

; ccall <function>: call a C library function with the OS's rules.
;   Windows: 32 bytes of "shadow space" must be reserved below the arguments.
;   Linux:   al = number of vector registers used (0), call through the PLT.
%macro ccall 1
        extern  %1
%ifdef WINDOWS
        sub     rsp, 32
        call    %1
        add     rsp, 32
%else
        xor     eax, eax
        call    %1 wrt ..plt
%endif
%endmacro

; ---- constants ---------------------------------------------------------
MAXW        equ 64              ; row stride in bytes (max maze width is 62)
MAXH        equ 32              ; max rows
C_SPACE     equ 32
C_WALL      equ 35              ; '#'
C_MON       equ 77              ; 'M'
C_GOAL      equ 71              ; 'G'
C_START     equ 80              ; 'P'
C_PLAYER    equ 64              ; '@'
KEY_QUIT    equ 0
KEY_UP      equ 1
KEY_DOWN    equ 2
KEY_LEFT    equ 3
KEY_RIGHT   equ 4
KEY_OTHER   equ 5
STATE_PLAY  equ 0
STATE_WON   equ 1
STATE_DEAD  equ 2
JUMP_HEIGHT equ 3

; ---- the "game" struct: byte offsets from the label 'game' ---------------
G_PX        equ 0               ; player column
G_PY        equ 4               ; player row
G_JUMP      equ 8               ; cells of upward travel left in this jump
G_W         equ 12              ; maze width
G_H         equ 16              ; maze height
G_STATE     equ 20              ; STATE_*
G_MAZE      equ 64              ; MAXW * MAXH bytes of maze follow

segment .bss
game:       resb G_MAZE + MAXW * MAXH

segment .data
mode_read:  db "r", 0
fmt_cell:   db `%s%c\e[0m`, 0
fmt_nl:     db 10, 0
esc_clear:  db `\e[2J\e[?25l`, 0
esc_home:   db `\e[H`, 0
esc_show:   db `\e[0m\e[?25h\n`, 0
col_none:   db `\e[0m`, 0
col_wall:   db `\e[1;37;44m`, 0
col_mon:    db `\e[1;31m`, 0
col_goal:   db `\e[1;33m`, 0
col_player: db `\e[1;32m`, 0
msg_play:   db `Arrows: walk / jump (Up)   Q: quit\e[K\n`, 0
msg_won:    db `You reached the goal - YOU WIN!\e[K\n`, 0
msg_dead:   db `A monster got you. Game over.\e[K\n`, 0
msg_nofile: db `Could not open the maze file.\n`, 0
msg_nostart: db `The maze has no P (player start).\n`, 0

segment .text
        global  asm_main

; ------------------------------------------------------------------------
asm_main:
        push    rbp
        mov     rbp, rsp
        push    rbx
        push    rdi                     ; rdi/rsi must be preserved on Windows
        push    rsi
        push    r12                     ; 4 pushes + rbp keeps rsp 16-aligned
%ifdef WINDOWS
        mov     rdi, rcx                ; file name arrives in rcx
%endif
        call    load_maze
        test    eax, eax
        jz      .loaded
        cmp     eax, -1
        lea     CARG1, [msg_nofile]
        lea     rax, [msg_nostart]
        cmovne  CARG1, rax              ; -1 -> "no file", otherwise "no P"
        ccall   printf
        mov     eax, 1
        jmp     .exit
.loaded:
        lea     CARG1, [esc_clear]      ; clear the screen once, hide the cursor
        ccall   printf
.loop:
        call    render
        cmp     dword [game + G_STATE], STATE_PLAY
        jne     .over                   ; won or dead: stop
        call    get_key
        test    eax, eax
        jz      .over                   ; quit key
        mov     edi, eax
        call    step
        jmp     .loop
.over:
        lea     CARG1, [esc_show]       ; show the cursor again
        ccall   printf
        mov     CARG1, 0
        ccall   fflush
        xor     eax, eax
.exit:
        pop     r12
        pop     rsi
        pop     rdi
        pop     rbx
        pop     rbp
        ret

; ------------------------------------------------------------------------
; load_maze(rdi = file name) -> eax
load_maze:
        push    rbp
        mov     rbp, rsp
        push    rbx                     ; FILE *
        push    r12                     ; row number
        push    r13                     ; widest row so far
        push    r14                     ; address of 'game'
        mov     CARG1, rdi
        lea     CARG2, [mode_read]
        ccall   fopen
        test    rax, rax
        jz      .nofile
        mov     rbx, rax
        lea     r14, [game]
        xor     r12d, r12d
        xor     r13d, r13d
.read:
        cmp     r12d, MAXH
        jae     .done
        mov     eax, r12d
        shl     eax, 6                  ; row * MAXW (64)
        lea     CARG1, [r14 + G_MAZE]
        add     CARG1, rax
        mov     CARG2, MAXW
        mov     CARG3, rbx
        ccall   fgets                   ; rax = buffer, or 0 at end of file
        test    rax, rax
        jz      .done
        mov     rdi, rax
        call    row_trim                ; eax = row length
        cmp     eax, r13d
        cmova   r13d, eax               ; keep the maximum
        inc     r12d
        jmp     .read
.done:
        mov     CARG1, rbx
        ccall   fclose
        mov     [r14 + G_W], r13d
        mov     [r14 + G_H], r12d
        mov     dword [r14 + G_JUMP], 0
        mov     dword [r14 + G_STATE], STATE_PLAY
        call    find_player
        jmp     .exit
.nofile:
        mov     eax, -1
.exit:
        pop     r14
        pop     r13
        pop     r12
        pop     rbx
        pop     rbp
        ret

; ------------------------------------------------------------------------
; row_trim(rdi = buffer) -> eax = length.  Cuts the row at the first control
; character (newline, return, NUL).  Leaf function.
row_trim:
        xor     eax, eax
.loop:
        movzx   ecx, byte [rdi + rax]
        cmp     ecx, 32
        jb      .end
        inc     eax
        jmp     .loop
.end:
        mov     byte [rdi + rax], 0
        ret

; ------------------------------------------------------------------------
; find_player() -> eax.  Stores the start position and erases the 'P'.
find_player:
        push    rbp
        mov     rbp, rsp
        push    rbx                     ; x
        push    r12                     ; y
        xor     r12d, r12d
.row:
        cmp     r12d, [game + G_H]
        jae     .none
        xor     ebx, ebx
.col:
        cmp     ebx, [game + G_W]
        jae     .next
        mov     edi, ebx
        mov     esi, r12d
        call    get_cell
        cmp     eax, C_START
        je      .found
        inc     ebx
        jmp     .col
.next:
        inc     r12d
        jmp     .row
.found:
        mov     [game + G_PX], ebx
        mov     [game + G_PY], r12d
        mov     edi, ebx
        mov     esi, r12d
        mov     edx, C_SPACE
        call    set_cell
        xor     eax, eax
        jmp     .exit
.none:
        mov     eax, -2
.exit:
        pop     r12
        pop     rbx
        pop     rbp
        ret

; ------------------------------------------------------------------------
; get_cell(edi = x, esi = y) -> eax.  Outside the maze counts as a wall; the
; unsigned compare also catches negative coordinates.  Empty cells read as ' '.
get_cell:
        cmp     edi, [game + G_W]
        jae     .outside
        cmp     esi, [game + G_H]
        jae     .outside
        mov     eax, esi
        shl     eax, 6
        lea     rcx, [game + G_MAZE]
        add     rcx, rax
        movzx   eax, byte [rcx + rdi]
        test    eax, eax
        jnz     .ret
        mov     eax, C_SPACE            ; NUL padding -> space
.ret:
        ret
.outside:
        mov     eax, C_WALL
        ret

; set_cell(edi = x, esi = y, edx = character)
set_cell:
        mov     eax, esi
        shl     eax, 6
        lea     rcx, [game + G_MAZE]
        add     rcx, rax
        mov     [rcx + rdi], dl
        ret

; ------------------------------------------------------------------------
; read_byte() -> eax = next input byte, or -1 at end of input.
read_byte:
        push    rbp
        mov     rbp, rsp
%ifdef WINDOWS
        ccall   _getch                  ; waits for one key, no echo
%else
        sub     rsp, 16                 ; room for one byte, keeps alignment
        mov     CARG1, 0                ; stdin
        lea     CARG2, [rsp]
        mov     CARG3, 1
        ccall   read
        cmp     rax, 1
        jne     .eof
        movzx   eax, byte [rsp]
        jmp     .out
.eof:
        mov     eax, -1
.out:
%endif
        mov     rsp, rbp
        pop     rbp
        ret

; ------------------------------------------------------------------------
; get_key() -> eax = KEY_*
; Windows: arrow keys are two _getch() values, 0 or 224 then 72/80/75/77.
; Linux:   arrow keys are three bytes, ESC '[' then A/B/D/C (up/down/left/right).
get_key:
        push    rbp
        mov     rbp, rsp
        call    read_byte
        cmp     eax, -1
        je      .quit                   ; end of input
        cmp     eax, 'q'
        je      .quit
        cmp     eax, 'Q'
        je      .quit
%ifdef WINDOWS
        cmp     eax, 27                 ; Esc
        je      .quit
        cmp     eax, 0
        je      .special
        cmp     eax, 224
        jne     .other
.special:
        call    read_byte
        cmp     eax, 72
        je      .up
        cmp     eax, 80
        je      .down
        cmp     eax, 75
        je      .left
        cmp     eax, 77
        je      .right
%else
        cmp     eax, 27                 ; ESC starts an arrow-key sequence
        jne     .other
        call    read_byte               ; '['
        call    read_byte               ; A, B, C or D
        cmp     eax, 'A'
        je      .up
        cmp     eax, 'B'
        je      .down
        cmp     eax, 'D'
        je      .left
        cmp     eax, 'C'
        je      .right
%endif
.other:
        mov     eax, KEY_OTHER
        jmp     .exit
.quit:
        mov     eax, KEY_QUIT
        jmp     .exit
.up:
        mov     eax, KEY_UP
        jmp     .exit
.down:
        mov     eax, KEY_DOWN
        jmp     .exit
.left:
        mov     eax, KEY_LEFT
        jmp     .exit
.right:
        mov     eax, KEY_RIGHT
.exit:
        pop     rbp
        ret

; ------------------------------------------------------------------------
; color_for(edi = character) -> rax = ANSI escape string.  Leaf function.
color_for:
        cmp     edi, C_WALL
        je      .wall
        cmp     edi, C_MON
        je      .mon
        cmp     edi, C_GOAL
        je      .goal
        cmp     edi, C_PLAYER
        je      .player
        lea     rax, [col_none]
        ret
.wall:
        lea     rax, [col_wall]
        ret
.mon:
        lea     rax, [col_mon]
        ret
.goal:
        lea     rax, [col_goal]
        ret
.player:
        lea     rax, [col_player]
        ret

; ------------------------------------------------------------------------
; try_move(edi = dx, esi = dy) -> eax = 1 moved, 0 blocked.
; Walls block.  Moving down into a monster stomps it (it vanishes and the
; player bounces).  Any other contact with a monster kills.  The goal wins.
try_move:
        push    rbp
        mov     rbp, rsp
        push    rbx                     ; new x
        push    r12                     ; new y
        push    r13                     ; dy
        mov     ebx, [game + G_PX]
        add     ebx, edi
        mov     r12d, [game + G_PY]
        add     r12d, esi
        mov     r13d, esi
        mov     edi, ebx
        mov     esi, r12d
        call    get_cell
        cmp     eax, C_WALL
        je      .blocked
        cmp     eax, C_MON
        jne     .notmon
        cmp     r13d, 0
        jg      .stomp                  ; moving down = landing on it
        mov     dword [game + G_STATE], STATE_DEAD
        jmp     .move
.stomp:
        mov     edi, ebx
        mov     esi, r12d
        mov     edx, C_SPACE
        call    set_cell
        mov     dword [game + G_JUMP], 2        ; small bounce
        jmp     .blocked
.notmon:
        cmp     eax, C_GOAL
        jne     .move
        mov     dword [game + G_STATE], STATE_WON
.move:
        mov     [game + G_PX], ebx
        mov     [game + G_PY], r12d
        mov     eax, 1
        jmp     .exit
.blocked:
        xor     eax, eax
.exit:
        pop     r13
        pop     r12
        pop     rbx
        pop     rbp
        ret

; ------------------------------------------------------------------------
; step(edi = KEY_*) advances one frame: sideways move, start a jump (Up, from
; the ground), then one cell of vertical motion - up during a jump, else gravity.
step:
        push    rbp
        mov     rbp, rsp
        push    rbx
        mov     ebx, edi                ; key
        cmp     ebx, KEY_LEFT
        jne     .not_left
        mov     edi, -1
        xor     esi, esi
        call    try_move
        jmp     .vertical
.not_left:
        cmp     ebx, KEY_RIGHT
        jne     .not_right
        mov     edi, 1
        xor     esi, esi
        call    try_move
        jmp     .vertical
.not_right:
        cmp     ebx, KEY_UP
        jne     .vertical
        cmp     dword [game + G_JUMP], 0
        jne     .vertical               ; already in a jump
        mov     edi, [game + G_PX]
        mov     esi, [game + G_PY]
        inc     esi                     ; the cell under the player
        call    get_cell
        cmp     eax, C_WALL
        jne     .vertical               ; not standing on anything
        mov     dword [game + G_JUMP], JUMP_HEIGHT
.vertical:
        cmp     dword [game + G_STATE], STATE_PLAY
        jne     .exit                   ; already won or died
        mov     eax, [game + G_JUMP]
        test    eax, eax
        jz      .fall
        dec     eax
        mov     [game + G_JUMP], eax
        xor     edi, edi
        mov     esi, -1                 ; dy = -1 (up)
        call    try_move
        test    eax, eax
        jnz     .exit
        mov     dword [game + G_JUMP], 0        ; bumped our head: stop rising
        jmp     .exit
.fall:
        xor     edi, edi
        mov     esi, 1                  ; dy = +1 (down)
        call    try_move
.exit:
        pop     rbx
        pop     rbp
        ret

; ------------------------------------------------------------------------
; render() draws the maze with colours, the player on top, then a status line.
; Each cell is printed as: <colour escape> <char> <reset escape>.
render:
        push    rbp
        mov     rbp, rsp
        push    rbx                     ; column
        push    r12                     ; row
        push    r13                     ; character being drawn
        push    r14                     ; (padding: keeps rsp 16-aligned)
        lea     CARG1, [esc_home]       ; cursor to top-left (no flicker)
        ccall   printf
        xor     r12d, r12d
.row:
        cmp     r12d, [game + G_H]
        jae     .status
        xor     ebx, ebx
.col:
        cmp     ebx, [game + G_W]
        jae     .endrow
        mov     edi, ebx
        mov     esi, r12d
        call    get_cell
        cmp     ebx, [game + G_PX]
        jne     .draw
        cmp     r12d, [game + G_PY]
        jne     .draw
        mov     eax, C_PLAYER           ; the player is drawn over the maze
.draw:
        mov     r13d, eax
        mov     edi, eax
        call    color_for               ; rax = escape string
        mov     CARG2, rax
        mov     CARG3, r13
        lea     CARG1, [fmt_cell]
        ccall   printf
        inc     ebx
        jmp     .col
.endrow:
        lea     CARG1, [fmt_nl]
        ccall   printf
        inc     r12d
        jmp     .row
.status:
        mov     eax, [game + G_STATE]
        lea     CARG1, [msg_play]
        lea     r13, [msg_won]
        cmp     eax, STATE_WON
        cmove   CARG1, r13
        lea     r13, [msg_dead]
        cmp     eax, STATE_DEAD
        cmove   CARG1, r13
        ccall   printf
        mov     CARG1, 0
        ccall   fflush                  ; show the finished frame now
        pop     r14
        pop     r13
        pop     r12
        pop     rbx
        pop     rbp
        ret
