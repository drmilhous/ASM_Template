#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/asm_env.sh"
if [ ! -d "$ASM_PROJECTS" ]; then
	mkdir -p "$ASM_PROJECTS"
fi
TEMPLATE=$ASM_TEMPLATE_HOME/M1_Mac
# if [ ! -d $TEMPLATE ] ; then
# 	TEMPLATE=/usr/local/bin/templateMake
# fi
DIR=$ASM_PROJECTS/$1
if [ ! -d "$DIR" ]; then
	mkdir "$DIR"
	cp $TEMPLATE/Arm.s $DIR/$1_arm.s
	cp $TEMPLATE/io_arm.s $DIR/io_arm.s
	cp $TEMPLATE/Intel.asm $DIR/$1_intel.asm
	cp $TEMPLATE/driver_intel.c $DIR/main_intel.c
	cp $TEMPLATE/driver_arm.c $DIR/main_arm.c
	cp $TEMPLATE/io.inc $DIR/
	cp $TEMPLATE/io.asm $DIR/
	cat $TEMPLATE/Makefile | sed "s/XX/$1/g" > $DIR/Makefile
	echo  "Project Created. $DIR \n"
else
	echo  "Directory Exists! Not Created.\n"
fi
