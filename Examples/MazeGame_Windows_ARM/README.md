# ASCII Maze Platformer (Windows ARM64, assembly)

A small side-view platformer written in native ARM64 assembly (`armasm64`) as a teaching
example of function-based design. No x86 emulation involved. A tiny C driver only enables
ANSI colours in the console and passes the maze file name to `asm_main`.

## Build and run

From a real console (Windows Terminal recommended), in this folder:

```powershell
.\quickBuild.ps1            # builds and runs with maze.txt
.\quickBuild.ps1 mine.txt   # run with another maze
```

`quickBuild.ps1` uses `findTools.ps1` (same folder or `bin\`) to locate the Visual Studio ARM64 tools.

## Playing

Each key press draws exactly one frame.

| Key | Action |
|---|---|
| Left / Right | walk one cell |
| Up | jump straight up 3 cells (only from the ground); hold Left/Right while rising to move forward like Mario |
| Down or any other key | wait one frame (gravity still applies, so press a key to fall) |
| Q / Esc | quit |

Land on a monster from above to stomp it. Touch it any other way and you die. Reach `G` to win.

## Maze file format

Plain text, at most 62 columns by 32 rows.

| Char | Meaning | Colour |
|---|---|---|
| `#` | wall | white on blue |
| `M` | monster | bold red |
| `G` | goal | bold yellow |
| `P` | player start (required, shown as `@`) | bold green |
| space | empty | default |

## Code tour (`maze_game.asm`)

The game state is one "struct" (`game`) with field offsets defined by `G_*` constants.

| Function | Job |
|---|---|
| `load_maze` | `fopen`/`fgets` each line into a 64-byte-stride grid, tracks width/height |
| `row_trim`, `find_player` | strip newlines (leaf function); locate `P` |
| `get_cell`, `set_cell` | grid access; out-of-range counts as wall (one unsigned compare catches negatives) |
| `get_key` | `_getch`, decoding the two-part arrow-key codes |
| `try_move` | collision rules: wall, stomp, death, goal |
| `step` | one frame: sideways move, start jump, rise or fall |
| `render`, `color_for` | draw each cell with an ANSI colour escape picked by character |

Ideas for exercises: patrolling monsters, a score, WASD keys, a "lives" counter, a second maze level.
