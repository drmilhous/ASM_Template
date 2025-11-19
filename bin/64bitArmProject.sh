#!/bin/bash
if [ ! -d $HOME/projects/ ]; then
	mkdir $HOME/projects
fi
TEMPLATE=$HOME/ASM_Template/64_Bit_ARM
DIR=$HOME/projects/$1
if [ ! -d "$DIR" ]; then
	mkdir $DIR
	cp $TEMPLATE/64bit.s $DIR/$1.s
	cp $TEMPLATE/driver.c $DIR/main.c
	cp $TEMPLATE/io.inc $DIR/
	cp $TEMPLATE/io.s $DIR/
	cat $TEMPLATE/Makefile | sed "s/XX/$1/g" > $DIR/Makefile
	echo  -e "Project Created. $DIR \n"
else
	echo  "Directory Exists! Not Created.\n"
fi
