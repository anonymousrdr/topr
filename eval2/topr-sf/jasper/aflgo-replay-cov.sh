#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay
export pdir=$PWD

# Build
git clone https://github.com/mdadams/jasper.git jasper
cd jasper; git checkout 142245b
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/src/libjasper/base/jas_image.c && cp $PWD/../../../replay-jas_image.c $PWD/src/libjasper/base/jas_image.c
mkdir obj-aflgo
# custom compilers to wrap gllvm around
export LLVM_COMPILER_PATH="$(dirname $(which clang))"
export LLVM_CC_NAME="clang"
export LLVM_CXX_NAME="clang++"
# Set compilers
export CC=gclang
export CXX=gclang++
export LDFLAGS="-lstdc++"
export ADDITIONAL="-fno-inline"
cd obj-aflgo; CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ../configure --disable-shared --prefix=`pwd`
make clean; make -j4

mkdir in; cp $pdir/../../inp.jp2 in
# Pruning
cd src/appl
mv jasper jasper-orig
get-bc -o exed.bc jasper-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o jasper-origtr.o exetrace.bc
gclang -fno-inline -o jasper-origtr jasper-origtr.o ../libjasper/.libs/libjasper.a -lstdc++ /usr/lib/x86_64-linux-gnu/libjpeg.so -lm
./jasper-origtr -f ../../in/inp.jp2 -t jp2 -F /tmp/out -T jp2
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
gclang++ -c -emit-llvm -std=c++11 $HOME/Desktop/fuzz-prune/covm/pruner-replay.cpp
llvm-link -o lexe.bc exe.bc pruner-replay.bc
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <lexe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/covm/build/proj/libbtrace.so -btrace <marked.bc>markedc.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <markedc.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f jasper jasper-exe.o
llc -filetype=obj -o jasper-exe.o pruned.bc
gclang -fno-inline -o jasper jasper-exe.o ../libjasper/.libs/libjasper.a -lstdc++ /usr/lib/x86_64-linux-gnu/libjpeg.so -lm
cd -

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
      timeout --foreground 1s $PWD/src/appl/jasper -f "$input" -t jp2 -F /tmp/out -T jp2 >> "$1/targstats.txt" 2>&1
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
