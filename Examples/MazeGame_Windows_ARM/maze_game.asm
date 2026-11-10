; ASCII maze platformer - native Windows ARM64 (armasm64 syntax).
;
; The whole game lives in this file as small functions.  The C driver only
; turns on ANSI colour support and passes in the maze file name.
;
; Controls (every key press = one frame):
;   Left / Right arrow : walk one cell
;   Up arrow           : jump straight up (3 cells), only from the ground
;   Down / any other   : wait one frame (gravity still applies)
;   Q or Esc           : quit
;
; Maze characters:  # wall   M monster   G goal   P player start
; Stomp a monster by landing on it from above.  Touch it any other way and you die.
;
; Functions                      in                      out
;   asm_main                     x0 = maze file name     w0 = 0
;   load_maze                    x0 = maze file name     w0 = 0 ok, -1 no file, -2 no 'P'
;   find_player                  -                       w0 = 0 ok, -2 no 'P'
;   row_trim                     x0 = row buffer         w0 = row length
;   get_cell                     w0 = x, w1 = y          w0 = character ('#' if outside)
;   set_cell                     w0 = x, w1 = y, w2 = ch -
;   get_key                      -                       w0 = KEY_* code
;   color_for                    w0 = character          x0 = escape string
;   try_move                     w0 = dx, w1 = dy        w0 = 1 moved, 0 blocked
;   step                         w0 = KEY_* code         -
;   render                       -                       -

; ---- constants ---------------------------------------------------------
MAXW        EQU     64          ; row stride in bytes (max maze width is 62)
MAXH        EQU     32          ; max rows

C_SPACE     EQU     32
C_WALL      EQU     35          ; '#'
C_MON       EQU     77          ; 'M'
C_GOAL      EQU     71          ; 'G'
C_START     EQU     80          ; 'P'
C_PLAYER    EQU     64          ; '@'

KEY_QUIT    EQU     0
KEY_UP      EQU     1
KEY_DOWN    EQU     2
KEY_LEFT    EQU     3
KEY_RIGHT   EQU     4
KEY_OTHER   EQU     5

STATE_PLAY  EQU     0
STATE_WON   EQU     1
STATE_DEAD  EQU     2

JUMP_HEIGHT EQU     3

; ---- the "game" struct: byte offsets from the label 'game' -------------
G_PX        EQU     0           ; player column
G_PY        EQU     4           ; player row
G_JUMP      EQU     8           ; cells of upward travel left in this jump
G_W         EQU     12          ; maze width
G_H         EQU     16          ; maze height
G_STATE     EQU     20          ; STATE_*
G_MAZE      EQU     64          ; MAXW * MAXH bytes of maze follow

    AREA    |.text|, CODE, READONLY, ALIGN=4
    EXPORT  asm_main
    IMPORT  printf
    IMPORT  fopen
    IMPORT  fgets
    IMPORT  fclose
    IMPORT  fflush
    IMPORT  _getch

; ------------------------------------------------------------------------
; asm_main(x0 = maze file name)
asm_main PROC
    stp     fp, lr, [sp, #-32]!
    mov     fp, sp
    stp     x19, x20, [sp, #16]

    bl      load_maze
    cmp     w0, #0
    b.eq    am_loaded
    cmn     w0, #1                  ; was it -1 ?
    adrp    x0, msg_nofile
    add     x0, x0, msg_nofile
    adrp    x1, msg_nostart
    add     x1, x1, msg_nostart
    csel    x0, x0, x1, eq
    bl      printf
    mov     w0, #1
    b       am_exit

am_loaded
    adrp    x0, esc_clear           ; clear screen once, hide the cursor
    add     x0, x0, esc_clear
    bl      printf
    adrp    x19, game
    add     x19, x19, game

am_loop
    bl      render
    ldr     w9, [x19, #G_STATE]
    cbnz    w9, am_over             ; won or dead: stop
    bl      get_key
    cbz     w0, am_over             ; quit key
    bl      step
    b       am_loop

am_over
    adrp    x0, esc_show            ; show the cursor again
    add     x0, x0, esc_show
    bl      printf
    mov     x0, #0
    bl      fflush
    mov     w0, #0
am_exit
    ldp     x19, x20, [sp, #16]
    ldp     fp, lr, [sp], #32
    ret
    ENDP

; ------------------------------------------------------------------------
; load_maze(x0 = file name) -> w0
; Reads up to MAXH lines into the maze area, records width/height, then
; finds the player start.
load_maze PROC
    stp     fp, lr, [sp, #-48]!
    mov     fp, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]

    adrp    x1, mode_read
    add     x1, x1, mode_read
    bl      fopen
    cbz     x0, lm_nofile
    mov     x19, x0                 ; FILE *
    adrp    x20, game
    add     x20, x20, game
    mov     w21, #0                 ; row number
    mov     w22, #0                 ; widest row so far

lm_read
    cmp     w21, #MAXH
    b.hs    lm_done
    add     x0, x20, #G_MAZE
    add     x0, x0, x21, lsl #6     ; + row * MAXW (64)
    mov     w1, #MAXW
    mov     x2, x19
    bl      fgets                   ; x0 = buffer, or 0 at end of file
    cbz     x0, lm_done
    bl      row_trim                ; w0 = row length
    cmp     w0, w22
    csel    w22, w0, w22, hi        ; keep the maximum
    add     w21, w21, #1
    b       lm_read

lm_done
    mov     x0, x19
    bl      fclose
    str     w22, [x20, #G_W]
    str     w21, [x20, #G_H]
    str     wzr, [x20, #G_JUMP]
    str     wzr, [x20, #G_STATE]
    bl      find_player
    b       lm_exit

lm_nofile
    movn    w0, #0                  ; -1
lm_exit
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     fp, lr, [sp], #48
    ret
    ENDP

; ------------------------------------------------------------------------
; row_trim(x0 = row buffer) -> w0 = length
; Cuts the row at the first control character (newline, return, NUL).
; Leaf function: no stack frame needed.
row_trim PROC
    mov     w1, #0
rt_loop
    ldrb    w2, [x0, x1]
    cmp     w2, #32
    b.lo    rt_end
    add     w1, w1, #1
    b       rt_loop
rt_end
    strb    wzr, [x0, x1]
    mov     w0, w1
    ret
    ENDP

; ------------------------------------------------------------------------
; find_player() -> w0 = 0 ok, -2 if there is no 'P'.
; Scans the maze, stores the start position, and erases the 'P'.
find_player PROC
    stp     fp, lr, [sp, #-48]!
    mov     fp, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    adrp    x9, game
    add     x9, x9, game
    ldr     w21, [x9, #G_W]
    ldr     w22, [x9, #G_H]
    mov     w20, #0                 ; y
fp_row
    cmp     w20, w22
    b.hs    fp_none
    mov     w19, #0                 ; x
fp_col
    cmp     w19, w21
    b.hs    fp_next
    mov     w0, w19
    mov     w1, w20
    bl      get_cell
    cmp     w0, #C_START
    b.eq    fp_found
    add     w19, w19, #1
    b       fp_col
fp_next
    add     w20, w20, #1
    b       fp_row
fp_found
    adrp    x9, game
    add     x9, x9, game
    str     w19, [x9, #G_PX]
    str     w20, [x9, #G_PY]
    mov     w0, w19
    mov     w1, w20
    mov     w2, #C_SPACE
    bl      set_cell
    mov     w0, #0
    b       fp_exit
fp_none
    movn    w0, #1                  ; -2
fp_exit
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     fp, lr, [sp], #48
    ret
    ENDP

; ------------------------------------------------------------------------
; get_cell(w0 = x, w1 = y) -> w0 = character.
; Anything outside the maze counts as a wall; empty cells read as a space.
; The unsigned compare also catches negative coordinates.
get_cell PROC
    adrp    x9, game
    add     x9, x9, game
    ldr     w10, [x9, #G_W]
    cmp     w0, w10
    b.hs    gc_outside
    ldr     w10, [x9, #G_H]
    cmp     w1, w10
    b.hs    gc_outside
    add     x9, x9, #G_MAZE
    add     x9, x9, x1, lsl #6
    ldrb    w0, [x9, x0]
    cmp     w0, #0
    mov     w10, #C_SPACE
    csel    w0, w10, w0, eq         ; NUL padding -> space
    ret
gc_outside
    mov     w0, #C_WALL
    ret
    ENDP

; set_cell(w0 = x, w1 = y, w2 = character)  (caller keeps x,y inside the maze)
set_cell PROC
    adrp    x9, game
    add     x9, x9, game
    add     x9, x9, #G_MAZE
    add     x9, x9, x1, lsl #6
    strb    w2, [x9, x0]
    ret
    ENDP

; ------------------------------------------------------------------------
; get_key() -> w0 = KEY_*
; Arrow keys arrive as two _getch() values: 0 or 224, then 72/80/75/77.
get_key PROC
    stp     fp, lr, [sp, #-16]!
    mov     fp, sp
    bl      _getch
    cmp     w0, #0
    b.eq    gk_special
    cmp     w0, #224
    b.eq    gk_special
    cmp     w0, #113                ; 'q'
    b.eq    gk_quit
    cmp     w0, #81                 ; 'Q'
    b.eq    gk_quit
    cmp     w0, #27                 ; Esc
    b.eq    gk_quit
    b       gk_other
gk_special
    bl      _getch
    cmp     w0, #72
    b.eq    gk_up
    cmp     w0, #80
    b.eq    gk_down
    cmp     w0, #75
    b.eq    gk_left
    cmp     w0, #77
    b.eq    gk_right
gk_other
    mov     w0, #KEY_OTHER
    b       gk_exit
gk_quit
    mov     w0, #KEY_QUIT
    b       gk_exit
gk_up
    mov     w0, #KEY_UP
    b       gk_exit
gk_down
    mov     w0, #KEY_DOWN
    b       gk_exit
gk_left
    mov     w0, #KEY_LEFT
    b       gk_exit
gk_right
    mov     w0, #KEY_RIGHT
gk_exit
    ldp     fp, lr, [sp], #16
    ret
    ENDP

; ------------------------------------------------------------------------
; color_for(w0 = character) -> x0 = ANSI escape string for that character
color_for PROC
    cmp     w0, #C_WALL
    b.eq    cf_wall
    cmp     w0, #C_MON
    b.eq    cf_mon
    cmp     w0, #C_GOAL
    b.eq    cf_goal
    cmp     w0, #C_PLAYER
    b.eq    cf_player
    adrp    x0, col_none
    add     x0, x0, col_none
    ret
cf_wall
    adrp    x0, col_wall
    add     x0, x0, col_wall
    ret
cf_mon
    adrp    x0, col_mon
    add     x0, x0, col_mon
    ret
cf_goal
    adrp    x0, col_goal
    add     x0, x0, col_goal
    ret
cf_player
    adrp    x0, col_player
    add     x0, x0, col_player
    ret
    ENDP

; ------------------------------------------------------------------------
; try_move(w0 = dx, w1 = dy) -> w0 = 1 if the player moved, 0 if blocked.
; Walls block.  Moving down into a monster stomps it (the monster vanishes,
; the player bounces).  Any other contact with a monster kills the player.
; Entering the goal wins.
try_move PROC
    stp     fp, lr, [sp, #-48]!
    mov     fp, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    adrp    x19, game
    add     x19, x19, game
    ldr     w9, [x19, #G_PX]
    add     w20, w9, w0             ; new x
    ldr     w9, [x19, #G_PY]
    add     w21, w9, w1             ; new y
    mov     w22, w1                 ; remember dy
    mov     w0, w20
    mov     w1, w21
    bl      get_cell
    cmp     w0, #C_WALL
    b.eq    tm_blocked
    cmp     w0, #C_MON
    b.ne    tm_notmon
    cmp     w22, #0
    b.gt    tm_stomp                ; moving down = landing on it
    mov     w9, #STATE_DEAD
    str     w9, [x19, #G_STATE]
    b       tm_move
tm_stomp
    mov     w0, w20
    mov     w1, w21
    mov     w2, #C_SPACE
    bl      set_cell
    mov     w9, #2                  ; small bounce
    str     w9, [x19, #G_JUMP]
    b       tm_blocked
tm_notmon
    cmp     w0, #C_GOAL
    b.ne    tm_move
    mov     w9, #STATE_WON
    str     w9, [x19, #G_STATE]
tm_move
    str     w20, [x19, #G_PX]
    str     w21, [x19, #G_PY]
    mov     w0, #1
    b       tm_exit
tm_blocked
    mov     w0, #0
tm_exit
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     fp, lr, [sp], #48
    ret
    ENDP

; ------------------------------------------------------------------------
; step(w0 = KEY_*) advances the game by one frame:
;   1. sideways move (left/right), 2. start a jump (up, from the ground),
;   3. one cell of vertical motion: up while the jump lasts, else gravity.
step PROC
    stp     fp, lr, [sp, #-32]!
    mov     fp, sp
    stp     x19, x20, [sp, #16]
    mov     w19, w0                 ; key
    adrp    x20, game
    add     x20, x20, game

    cmp     w19, #KEY_LEFT
    b.ne    st_not_left
    movn    w0, #0                  ; dx = -1
    mov     w1, #0
    bl      try_move
    b       st_vertical
st_not_left
    cmp     w19, #KEY_RIGHT
    b.ne    st_not_right
    mov     w0, #1
    mov     w1, #0
    bl      try_move
    b       st_vertical
st_not_right
    cmp     w19, #KEY_UP
    b.ne    st_vertical
    ldr     w9, [x20, #G_JUMP]
    cbnz    w9, st_vertical         ; already in a jump
    ldr     w0, [x20, #G_PX]
    ldr     w1, [x20, #G_PY]
    add     w1, w1, #1              ; the cell under the player
    bl      get_cell
    cmp     w0, #C_WALL
    b.ne    st_vertical             ; not standing on anything
    mov     w9, #JUMP_HEIGHT
    str     w9, [x20, #G_JUMP]

st_vertical
    ldr     w9, [x20, #G_STATE]
    cbnz    w9, st_exit             ; already won or died
    ldr     w9, [x20, #G_JUMP]
    cbz     w9, st_fall
    sub     w9, w9, #1
    str     w9, [x20, #G_JUMP]
    mov     w0, #0
    movn    w1, #0                  ; dy = -1 (up)
    bl      try_move
    cbnz    w0, st_exit
    str     wzr, [x20, #G_JUMP]     ; bumped our head: stop rising
    b       st_exit
st_fall
    mov     w0, #0
    mov     w1, #1                  ; dy = +1 (down)
    bl      try_move
st_exit
    ldp     x19, x20, [sp, #16]
    ldp     fp, lr, [sp], #32
    ret
    ENDP

; ------------------------------------------------------------------------
; render() draws the whole maze in colour, the player on top, then a status line.
; Each cell is printed as: <colour escape> <char> <reset escape>.
render PROC
    stp     fp, lr, [sp, #-64]!
    mov     fp, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    adrp    x21, game
    add     x21, x21, game

    adrp    x0, esc_home            ; cursor to top-left (no flicker)
    add     x0, x0, esc_home
    bl      printf
    mov     w20, #0                 ; row
rd_row
    ldr     w9, [x21, #G_H]
    cmp     w20, w9
    b.hs    rd_status
    mov     w19, #0                 ; column
rd_col
    ldr     w9, [x21, #G_W]
    cmp     w19, w9
    b.hs    rd_endrow
    mov     w0, w19
    mov     w1, w20
    bl      get_cell
    ldr     w9, [x21, #G_PX]
    cmp     w19, w9
    b.ne    rd_draw
    ldr     w9, [x21, #G_PY]
    cmp     w20, w9
    b.ne    rd_draw
    mov     w0, #C_PLAYER           ; the player is drawn over the maze
rd_draw
    mov     w22, w0
    bl      color_for               ; x0 = escape string
    mov     x1, x0
    mov     w2, w22
    adrp    x0, fmt_cell
    add     x0, x0, fmt_cell
    bl      printf
    add     w19, w19, #1
    b       rd_col
rd_endrow
    adrp    x0, fmt_nl
    add     x0, x0, fmt_nl
    bl      printf
    add     w20, w20, #1
    b       rd_row

rd_status
    ldr     w9, [x21, #G_STATE]
    adrp    x0, msg_play
    add     x0, x0, msg_play
    cmp     w9, #STATE_WON
    b.ne    rd_not_won
    adrp    x0, msg_won
    add     x0, x0, msg_won
rd_not_won
    cmp     w9, #STATE_DEAD
    b.ne    rd_print
    adrp    x0, msg_dead
    add     x0, x0, msg_dead
rd_print
    bl      printf
    mov     x0, #0
    bl      fflush                  ; show the finished frame now
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     fp, lr, [sp], #64
    ret
    ENDP

; ---- read-only data -----------------------------------------------------
    AREA    |.rdata|, DATA, READONLY
mode_read   DCB     "r", 0
fmt_cell    DCB     "%s%c", 27, "[0m", 0
fmt_nl      DCB     10, 0
esc_clear   DCB     27, "[2J", 27, "[?25l", 0
esc_home    DCB     27, "[H", 0
esc_show    DCB     27, "[0m", 27, "[?25h", 10, 0
col_none    DCB     27, "[0m", 0
col_wall    DCB     27, "[1;37;44m", 0
col_mon     DCB     27, "[1;31m", 0
col_goal    DCB     27, "[1;33m", 0
col_player  DCB     27, "[1;32m", 0
msg_play    DCB     "Arrows: walk / jump (Up)   Q: quit", 27, "[K", 10, 0
msg_won     DCB     "You reached the goal - YOU WIN!", 27, "[K", 10, 0
msg_dead    DCB     "A monster got you. Game over.", 27, "[K", 10, 0
msg_nofile  DCB     "Could not open the maze file.", 10, 0
msg_nostart DCB     "The maze has no P (player start).", 10, 0

; ---- game state (read/write) --------------------------------------------
    AREA    |.data|, DATA, READWRITE, ALIGN=4
game        SPACE   64 + 2048       ; header (see G_* offsets) + MAXW*MAXH maze bytes

    END
