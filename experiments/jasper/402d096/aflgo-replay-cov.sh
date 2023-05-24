#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay
export pdir=$PWD

# Build
git clone https://github.com/mdadams/jasper.git jasper
cd jasper; git checkout 402d096 # v4.0.0 at https://github.com/jasper-software/jasper/tags
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/src/libjasper/base/jas_tvp.c && cp $PWD/../../../replay-jas_tvp.c $PWD/src/libjasper/base/jas_tvp.c
rm $PWD/src/libjasper/base/jas_image.c && cp $PWD/../../../pruner-jas_image.c $PWD/src/libjasper/base/jas_image.c
mkdir obj-aflgo
# custom compilers to wrap gllvm around
export LLVM_COMPILER_PATH="$(dirname $(which clang))"
export LLVM_CC_NAME="clang"
export LLVM_CXX_NAME="clang++"
# Set compilers
export CC=gclang
export CXX=gclang++
export LDFLAGS="-lstdc++ -lpthread"
export ADDITIONAL="-fno-inline"
export CFLAGS="$ADDITIONAL"
export CXXFLAGS="$ADDITIONAL"
cd obj-aflgo
cmake -H$PWD/.. -B$PWD -DCMAKE_INSTALL_PREFIX=$PWD -DJAS_ENABLE_SHARED=false
cmake --build $PWD
mkdir in; cp $pdir/../../../inp.jp2 in
# Pruning
cd src/app
mv jasper jasper-orig
get-bc -o exed.bc jasper-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o jasper-origtr.o exetrace.bc
gclang -fno-inline -pedantic -lstdc++ -lpthread jasper-origtr.o -o jasper-origtr ../libjasper/libjasper.a /usr/lib/x86_64-linux-gnu/libjpeg.so -lm /usr/lib/x86_64-linux-gnu/libpthread.so
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
gclang -fno-inline -pedantic -lstdc++ -lpthread jasper-exe.o -o jasper ../libjasper/libjasper.a /usr/lib/x86_64-linux-gnu/libjpeg.so -lm /usr/lib/x86_64-linux-gnu/libpthread.so
cd -

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
      timeout --foreground 10s $PWD/src/app/jasper -f "$input" -t jp2 -F /tmp/out -T jp2 >> "$1/targstats.txt" 2>&1
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
