#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay
export pdir=$PWD

# Build
git clone https://git.code.sf.net/p/giflib/code giflib
cd giflib; git checkout adf5a1a # latest version
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/gifsponge.c && cp $PWD/../../../pruner-gifsponge.c $PWD/gifsponge.c
rm $PWD/egif_lib.c && cp $PWD/../../../replay-egif_lib.c $PWD/egif_lib.c

# fix error in Makefile to modify CFLAGS
rm $PWD/Makefile && cp $PWD/../../../latest-Makefile $PWD/Makefile

# custom compilers to wrap gllvm around
export LLVM_COMPILER_PATH="$(dirname $(which clang))"
export LLVM_CC_NAME="clang"
export LLVM_CXX_NAME="clang++"
# Set compilers
export CC=gclang
export CXX=gclang++
export LDFLAGS="-lstdc++"
export ADDITIONAL="-disable-shared -fno-inline"
export COPYCFLAGS="-std=gnu99 -fPIC -Wall -Wno-format-truncation"
export CFLAGS="$COPYCFLAGS $ADDITIONAL"
make clean; make -j4
mkdir in; echo "GIF" > in/in
# Pruning
mv gifsponge gifsponge-orig
get-bc -o exed.bc gifsponge-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o gifsponge-origtr.o exetrace.bc
gclang -std=gnu99 -fPIC -Wall -Wno-format-truncation -O2 -disable-shared -fno-inline -o gifsponge-origtr gifsponge-origtr.o libgif.a libutil.a libgif.a -lm -lstdc++
./gifsponge-origtr < in/in
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
gclang++ -c -emit-llvm -std=c++11 $HOME/Desktop/fuzz-prune/covm/pruner-replay.cpp
llvm-link -o lexe.bc exe.bc pruner-replay.bc
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <lexe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/covm/build/proj/libbtrace.so -btrace <marked.bc>markedc.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <markedc.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f gifsponge gifsponge-exe.o
llc -filetype=obj -o gifsponge-exe.o pruned.bc
gclang -std=gnu99 -fPIC -Wall -Wno-format-truncation -O2 -disable-shared -fno-inline -o gifsponge gifsponge-exe.o libgif.a libutil.a libgif.a -lm -lstdc++

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
      timeout --foreground 10s $PWD/gifsponge < "$input" >> "$1/targstats.txt" 2>&1
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
