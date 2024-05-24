
if [ "$#" -eq 2 ]; then
    objdump -M intel --disassemble=$2 $1
fi
if [ "$#" -eq 1 ]; then
    objdump -M intel --disassemble=main $1 
fi
if [ "$#" -eq 0 ]; then
    echo "Usage: dump.sh <executable> [function]"
fi