#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay
export pdir=$PWD

# Build
git clone https://github.com/cesanta/mjs.git mjs
cd mjs; git checkout 2827bd0 # v1.20.1 at https://github.com/cesanta/mjs/tags?after=2.2
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/mjs.c && cp $PWD/../../../replay-mjs.c $PWD/mjs.c
mkdir obj-aflgo
# custom compilers to wrap gllvm around
export LLVM_COMPILER_PATH="$(dirname $(which clang))"
export LLVM_CC_NAME="clang"
export LLVM_CXX_NAME="clang++"
# Set compilers
export CC=gclang
export CXX=gclang++
export LDFLAGS="-lstdc++"
$CC -DMJS_MAIN mjs.c -ldl -g -o mjs-bin $LDFLAGS
cd obj-aflgo

mkdir in; echo "A" > in/in
cd ..
# Pruning
mv mjs-bin mjs-bin-orig
get-bc -o exed.bc mjs-bin-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o mjs-bin-origtr.o exetrace.bc
gclang -DMJS_MAIN mjs-bin-origtr.o -ldl -g -o mjs-bin-origtr $LDFLAGS
./mjs-bin-origtr -f obj-aflgo/in/in
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
gclang++ -c -emit-llvm -std=c++11 $HOME/Desktop/fuzz-prune/covm/pruner-replay.cpp
llvm-link -o lexe.bc exe.bc pruner-replay.bc
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <lexe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/covm/build/proj/libbtrace.so -btrace <marked.bc>markedc.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <markedc.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f mjs-bin mjs-bin-exe.o
llc -filetype=obj -o mjs-bin-exe.o pruned.bc
gclang -DMJS_MAIN mjs-bin-exe.o -ldl -g -o mjs-bin $LDFLAGS
cd obj-aflgo

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
      timeout 1s $PWD/../mjs-bin -f "$input" >> "$1/targstats.txt" 2>&1
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
