# Linux x86-64 build:  make && ./MazeGame
all: MazeGame

MazeGame: maze_game.o driver.c
	gcc -z noexecstack -o $@ driver.c maze_game.o

maze_game.o: maze_game.asm
	nasm -f elf64 maze_game.asm -o maze_game.o

clean:
	rm -f MazeGame *.o
