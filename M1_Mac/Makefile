FLAGS=-target x86_64-apple-macos10.12 -Wl,-ld_classic
FLAGS_ARM=-lSystem -syslibroot `xcrun -sdk macosx --show-sdk-path` -arch arm64
all: XX_intel XX_arm
XX_intel: XX_intel.o io.o
	gcc ${FLAGS} -o $@ $+ main_intel.c

# XX_arm: XX_arm.o io.o
# 	gcc -o $@ $+ main_arm.c
XX_arm: XX_arm.o
	ld -o XX_arm XX_arm.o ${FLAGS_ARM} -e _asm_main 

XX_arm.o: XX_arm.s 
	as XX_arm.s -o XX_arm.o

XX_intel.o: XX_intel.asm 
	nasm -f macho64 XX_intel.asm -o XX_intel.o


io.o: io.asm 
	nasm -f macho64 -d ELF_TYPE io.asm -o io.o

clean:
	rm -f XX_intel XX_arm *.o
