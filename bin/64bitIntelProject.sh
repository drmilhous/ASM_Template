#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/asm_env.sh"
if [ ! -d "$ASM_PROJECTS" ]; then
	mkdir -p "$ASM_PROJECTS"
fi
TEMPLATE=$ASM_TEMPLATE_HOME/64_Bit_Intel
# if [ ! -d $TEMPLATE ] ; then
# 	TEMPLATE=/usr/local/bin/templateMake
# fi
DIR=$ASM_PROJECTS/$1
if [ ! -d "$DIR" ]; then
	mkdir "$DIR"
	cp $TEMPLATE/64bit.asm $DIR/$1.asm
	cp $TEMPLATE/driver.c $DIR/main.c
	cp $TEMPLATE/io.inc $DIR/
	cp $TEMPLATE/io.asm $DIR/
	cat $TEMPLATE/Makefile | sed "s/XX/$1/g" > $DIR/Makefile
	echo  -e "Project Created. $DIR \n"
else
	echo  "Directory Exists! Not Created.\n"
fi
