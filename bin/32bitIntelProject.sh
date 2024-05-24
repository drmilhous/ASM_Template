if [ ! -d $HOME/projects/ ]; then
	mkdir $HOME/projects
fi
TEMPLATE=$HOME/ASM_Template/32_Bit_Intel
# if [ ! -d $TEMPLATE ] ; then
# 	TEMPLATE=/usr/local/bin/templateMake
# fi
DIR=$HOME/projects/$1
if [ ! -d "$DIR" ]; then
	mkdir $DIR
	cp $TEMPLATE/32bit.asm $DIR/$1.asm
	cp $TEMPLATE/driver.c $DIR/main.c
	cp $TEMPLATE/io.inc $DIR/
	cp $TEMPLATE/io.asm $DIR/
	cat $TEMPLATE/Makefile | sed "s/XX/$1/g" > $DIR/Makefile
	echo  -e "Project Created. $DIR \n"
else
	echo  "Directory Exists! Not Created.\n"
fi
