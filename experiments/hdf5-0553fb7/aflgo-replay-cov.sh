#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay
export pdir=$PWD

# Build
git clone https://github.com/HDFGroup/hdf5.git hdf5
cd hdf5
git checkout 0553fb7 # v1.14.0 at https://github.com/HDFGroup/hdf5/tags
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/src/H5Faccum.c && cp $PWD/../../../pruner-H5Faccum.c $PWD/src/H5Faccum.c
rm $PWD/src/H5Fquery.c && cp $PWD/../../../replay-H5Fquery.c $PWD/src/H5Fquery.c
# custom compilers to wrap gllvm around
export LLVM_COMPILER_PATH="$(dirname $(which clang))"
export LLVM_CC_NAME="clang"
export LLVM_CXX_NAME="clang++"
# Set compilers
export CC=gclang
export CXX=gclang++
export LDFLAGS="-lstdc++"
export ADDITIONAL="-fno-inline"
CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ./configure --disable-shared
make
cd $PWD/tools/src/h5dump
mkdir in; cp $pdir/../../inp.h5 in
# Pruning
mv h5dump h5dump-orig
get-bc -o exed.bc h5dump-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o h5dump-origtr.o exetrace.bc
gclang -fno-inline -std=c99 -Wall -Warray-bounds -Wcast-qual -Wconversion -Wdouble-promotion -Wextra -Wformat=2 -Wframe-larger-than=16384 -Wimplicit-fallthrough -Wnull-dereference -Wunused-const-variable -Wwrite-strings -Wpedantic -Wvolatile-register-var -Wno-c++-compat -Wbad-function-cast -Wimplicit-function-declaration -Wincompatible-pointer-types -Wmissing-declarations -Wpacked -Wshadow -Wswitch -Wno-error=incompatible-pointer-types-discards-qualifiers -Wunused-function -Wunused-variable -Wunused-parameter -Wcast-align -Wformat -Wno-missing-noreturn -O3 -o h5dump-origtr h5dump-origtr.o ../../../tools/lib/.libs/libh5tools.a ../../../src/.libs/libhdf5.a -lstdc++ -lz -ldl -lm
./h5dump-origtr in/inp.h5
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
gclang++ -c -emit-llvm -std=c++11 $HOME/Desktop/fuzz-prune/covm/pruner-replay.cpp
llvm-link -o lexe.bc exe.bc pruner-replay.bc
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <lexe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/covm/build/proj/libbtrace.so -btrace <marked.bc>markedc.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <markedc.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f h5dump h5dump-exe.o
llc -filetype=obj -o h5dump-exe.o pruned.bc
gclang -fno-inline -std=c99 -Wall -Warray-bounds -Wcast-qual -Wconversion -Wdouble-promotion -Wextra -Wformat=2 -Wframe-larger-than=16384 -Wimplicit-fallthrough -Wnull-dereference -Wunused-const-variable -Wwrite-strings -Wpedantic -Wvolatile-register-var -Wno-c++-compat -Wbad-function-cast -Wimplicit-function-declaration -Wincompatible-pointer-types -Wmissing-declarations -Wpacked -Wshadow -Wswitch -Wno-error=incompatible-pointer-types-discards-qualifiers -Wunused-function -Wunused-variable -Wunused-parameter -Wcast-align -Wformat -Wno-missing-noreturn -O3 -o h5dump h5dump-exe.o ../../../tools/lib/.libs/libh5tools.a ../../../src/.libs/libhdf5.a -lstdc++ -lz -ldl -lm

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
      timeout --foreground 10s $PWD/h5dump "$input" >> "$1/targstats.txt" 2>&1
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
