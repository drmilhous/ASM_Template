all: XX
XX: XX.o io.o main.c
	gcc -z noexecstack  -o $@ $+ 

XX.o: XX.s 
	as XX.s -o XX.o

io.o: io.s 
	as io.s -o io.o

clean:
	rm -f XX *.o
