#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay
export pdir=$PWD

# Build
git clone https://github.com/Unidata/netcdf-c.git netcdf
cd netcdf
git checkout 63150df # v4.9.1 at https://github.com/Unidata/netcdf-c/tags
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/ncdump/ncdump.c && cp $PWD/../../../replay-ncdump.c $PWD/ncdump/ncdump.c
# custom compilers to wrap gllvm around
export LLVM_COMPILER_PATH="$(dirname $(which clang))"
export LLVM_CC_NAME="clang"
export LLVM_CXX_NAME="clang++"
# Set compilers
export CC=gclang
export CXX=gclang++
export LDFLAGS="-lstdc++ -L/usr/lib/x86_64-linux-gnu/hdf5/serial/lib"
export CFLAGS="-I/usr/lib/x86_64-linux-gnu/hdf5/serial/include"
export CXXFLAGS="-I/usr/lib/x86_64-linux-gnu/hdf5/serial/include"
export ADDITIONAL="-fno-inline"
CFLAGS="$CFLAGS $ADDITIONAL" CXXFLAGS="$CXXFLAGS $ADDITIONAL" ./configure --disable-dap --disable-dap-remote-tests --disable-shared
make
cd $PWD/ncdump
mkdir in; cp $pdir/../../inp.nc in
# Pruning
mv ncdump ncdump-orig
get-bc -o exed.bc ncdump-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o ncdump-origtr.o exetrace.bc
gclang -fno-inline -I/usr/lib/x86_64-linux-gnu/hdf5/serial/include -fno-strict-aliasing -o ncdump-origtr ncdump-origtr.o -L/usr/lib/x86_64-linux-gnu/hdf5/serial/lib ../liblib/.libs/libnetcdf.a -lstdc++ -lhdf5_hl -lhdf5 -lm -lz -ldl -lsz -lbz2 -lxml2 /usr/lib/x86_64-linux-gnu/libcurl.so -pthread
./ncdump-origtr in/inp.nc
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
gclang++ -c -emit-llvm -std=c++11 $HOME/Desktop/fuzz-prune/covm/pruner-replay.cpp
llvm-link -o lexe.bc exe.bc pruner-replay.bc
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <lexe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/covm/build/proj/libbtrace.so -btrace <marked.bc>markedc.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <markedc.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f ncdump ncdump-exe.o
llc -filetype=obj -o ncdump-exe.o pruned.bc
gclang -fno-inline -I/usr/lib/x86_64-linux-gnu/hdf5/serial/include -fno-strict-aliasing -o ncdump ncdump-exe.o -L/usr/lib/x86_64-linux-gnu/hdf5/serial/lib ../liblib/.libs/libnetcdf.a -lstdc++ -lhdf5_hl -lhdf5 -lm -lz -ldl -lsz -lbz2 -lxml2 /usr/lib/x86_64-linux-gnu/libcurl.so -pthread

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
      timeout --foreground 10s $PWD/ncdump "$input" >> "$1/targstats.txt" 2>&1
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
