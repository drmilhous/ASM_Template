all: XX
XX: XX.o io.o main.c
	gcc -z noexecstack  -o $@ $+ 

XX.o: XX.asm 
	nasm -f elf64 XX.asm -o XX.o

io.o: io.asm 
	nasm -f elf64 -d ELF_TYPE io.asm -o io.o

clean:
	rm -f XX *.o
