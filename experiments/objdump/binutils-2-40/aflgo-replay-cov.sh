#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay
export pdir=$PWD

# Build
git clone git://sourceware.org/git/binutils-gdb.git objdump
cd objdump; git checkout binutils-2_40 # latest tag, hash = 32778522c7d
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/binutils/objdump.c && cp $PWD/../../../pruner-objdump.c $PWD/binutils/objdump.c
rm $PWD/bfd/dwarf2.c && cp $PWD/../../../replay-dwarf2.c $PWD/bfd/dwarf2.c
rm $PWD/bfd/elf.c && cp $PWD/../../../pruner-elf.c $PWD/bfd/elf.c
rm $PWD/bfd/section.c && cp $PWD/../../../pruner-section.c $PWD/bfd/section.c
# build error fix1
rm $PWD/gas/Makefile.in && cp $PWD/../../../../../latest-binutils-gas-Makefile.in $PWD/gas/Makefile.in
mkdir obj-aflgo
# custom compilers to wrap gllvm around
export LLVM_COMPILER_PATH="$(dirname $(which clang))"
export LLVM_CC_NAME="clang"
export LLVM_CXX_NAME="clang++"
# Set compilers
export CC=gclang
export CXX=gclang++
export LDFLAGS="-ldl -lutil -lstdc++"
export ADDITIONAL="-fno-inline"
cd obj-aflgo; CFLAGS="$ADDITIONAL -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error" ../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld --disable-gprofng --disable-gdbserver
make clean
# build error fix2
while true
do
    make
    if [ $? -eq 0 ]; then
        break
    else
        libars_list=$(find $PWD -type f -name "*.a")
        for libar in $libars_list
        do
            ranlib $libar
        done
    fi
done
mkdir in; echo "" > in/in
# Pruning
cd binutils
mv objdump objdump-orig
get-bc -o exed.bc objdump-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o objdump-origtr.o exetrace.bc
gclang -W -Wall -Wstrict-prototypes -Wmissing-prototypes -Wshadow -Werror -I../../binutils/../zlib -fno-inline -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -o objdump-origtr objdump-origtr.o ../opcodes/.libs/libopcodes.a ../bfd/.libs/libbfd.a -L$HOME/Desktop/fuzz-prune/experiments/objdump/fuzz-results/aflgo-prune/objdump/obj-dist/zlib -ldl -lutil -lstdc++ -lz ../libiberty/libiberty.a
./objdump-origtr -SD ../in/in
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
gclang++ -c -emit-llvm -std=c++11 $HOME/Desktop/fuzz-prune/covm/pruner-replay.cpp
llvm-link -o lexe.bc exe.bc pruner-replay.bc
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <lexe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/covm/build/proj/libbtrace.so -btrace <marked.bc>markedc.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <markedc.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f objdump objdump-exe.o
llc -filetype=obj -o objdump-exe.o pruned.bc
gclang -W -Wall -Wstrict-prototypes -Wmissing-prototypes -Wshadow -Werror -I../../binutils/../zlib -fno-inline -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -o objdump objdump-exe.o ../opcodes/.libs/libopcodes.a ../bfd/.libs/libbfd.a -L$HOME/Desktop/fuzz-prune/experiments/objdump/fuzz-results/aflgo-prune/objdump/obj-dist/zlib -ldl -lutil -lstdc++ -lz ../libiberty/libiberty.a
cd ..

# Replay aflgo generated inputs
count_ip=0
search_dir="$1/out"
subdirs="queue crashes hangs"
for subdir in $subdirs
do
  list_indirs=$(find $search_dir -type d -name $subdir)
  for indir in $list_indirs
  do
    if [ "$(ls -A $indir)" ]; then
      :
    else # skip empty dir
      continue
    fi
    for input in "$indir"/*
    do
      count_ip=$((count_ip+1))
      echo "INPUT: $input" >> "$1/targstats.txt"
      timeout --foreground 10s $PWD/binutils/objdump -SD "$input" >> "$1/targstats.txt" 2>&1
      echo "" >> "$1/targstats.txt"
      echo -n "REACHED TARGET: 0" >> "$1/targstats.txt"
      [ -f tmpcount.txt ] && cat tmpcount.txt >> "$1/targstats.txt"
      echo -e "\nEND OF REPLAY----" >> "$1/targstats.txt"
    done
  done
done
rm -f tmpcount.txt
echo "$(basename $1): Total number of inputs = $count_ip" >> "$1/../all-stats.txt"
mv $(find $pdir -type f -name "mbbls.txt") $1
mv $(find $pdir -type f -name "vbbls.txt") $1
