all: XX
XX: XX.o io.o main.c
	gcc -m32 -z noexecstack  -o $@ $+ 

XX.o: XX.asm 
	nasm -f elf32 XX.asm -o XX.o

io.o: io.asm 
	nasm -f elf32 -d ELF_TYPE io.asm -o io.o

clean:
	rm -f XX *.o
