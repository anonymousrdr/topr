#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay
export pdir=$PWD

# Build
git clone git://sourceware.org/git/binutils-gdb.git cxxfilt
cd cxxfilt; git checkout 2c49145
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/libiberty/cplus-dem.c && cp $PWD/../../../replay-cplus-dem.c $PWD/libiberty/cplus-dem.c
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
cd obj-aflgo; CFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error $ADDITIONAL" ../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld --disable-gprofng --disable-gdbserver
make clean; make

mkdir in; echo "" > in/in
# Pruning
cd binutils
mv cxxfilt cxxfilt-orig
get-bc -o exed.bc cxxfilt-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o cxxfilt-origtr.o exetrace.bc
gclang -W -Wall -Wstrict-prototypes -Wmissing-prototypes -Wshadow -Werror -I../../binutils/../zlib -fno-inline -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -o cxxfilt-origtr cxxfilt-origtr.o ../bfd/.libs/libbfd.a -L$HOME/Desktop/fuzz-prune/experiments/objdump/fuzz-results/aflgo-prune/objdump/obj-dist/zlib -ldl -lutil -lstdc++ -lz ../libiberty/libiberty.a
./cxxfilt-origtr < ../in/in
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
gclang++ -c -emit-llvm -std=c++11 $HOME/Desktop/fuzz-prune/covm/pruner-replay.cpp
llvm-link -o lexe.bc exe.bc pruner-replay.bc
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <lexe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/covm/build/proj/libbtrace.so -btrace <marked.bc>markedc.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <markedc.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f cxxfilt cxxfilt-exe.o
llc -filetype=obj -o cxxfilt-exe.o pruned.bc
gclang -W -Wall -Wstrict-prototypes -Wmissing-prototypes -Wshadow -Werror -I../../binutils/../zlib -fno-inline -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -o cxxfilt cxxfilt-exe.o ../bfd/.libs/libbfd.a -L$HOME/Desktop/fuzz-prune/experiments/objdump/fuzz-results/aflgo-prune/objdump/obj-dist/zlib -ldl -lutil -lstdc++ -lz ../libiberty/libiberty.a
cd ..

# Replay aflgo generated inputs
search_dir="$1/out/$2"
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
      echo "INPUT: $input" >> "$1/targstats.txt"
      timeout --foreground 1s $PWD/binutils/cxxfilt < "$input" >> "$1/targstats.txt" 2>&1
      echo "" >> "$1/targstats.txt"
      echo -n "REACHED TARGET: 0" >> "$1/targstats.txt"
      [ -f tmpcount.txt ] && cat tmpcount.txt >> "$1/targstats.txt"
      echo -e "\nEND OF REPLAY----" >> "$1/targstats.txt"
    done
  done
done
rm -f tmpcount.txt
mv $(find $pdir -type f -name "mbbls.txt") $1
mv $(find $pdir -type f -name "vbbls.txt") $1
