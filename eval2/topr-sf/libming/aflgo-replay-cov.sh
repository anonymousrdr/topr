#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay
export pdir=$PWD

# Clone subject repository
git clone https://github.com/libming/libming.git libming
export SUBJECT=$PWD/libming
pushd $SUBJECT
  git checkout b72cc2f # version 0.4.8
popd

# Integrate custom pruner functions, edit targets accordingly
rm $SUBJECT/util/read.c && cp $PWD/../../replay-read.c $SUBJECT/util/read.c

# custom compilers to wrap gllvm around
export LLVM_COMPILER_PATH="$(dirname $(which clang))"
export LLVM_CC_NAME="clang"
export LLVM_CXX_NAME="clang++"
# Set compilers
export CC=gclang
export CXX=gclang++
export LDFLAGS="-lstdc++"
export CFLAGS+=-fcommon
export CXXFLAGS+=-fcommon

# Build
# Meanwhile go have a coffee ☕️
pushd $SUBJECT
  ./autogen.sh
  ./configure --disable-shared --disable-freetype --prefix=`pwd`
  make clean
  make
popd

# Construct seed corpus
mkdir in
wget -P in http://condor.depaul.edu/sjost/hci430/flash-examples/swf/bumble-bee1.swf

# Pruning
pushd $SUBJECT/util
mv swftophp swftophp-orig
get-bc -o exed.bc swftophp-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o swftophp-origtr.o exetrace.bc
gclang -DSWFPHP -fcommon -Wall -fPIC -DSWF_LITTLE_ENDIAN -o swftophp-origtr swftophp-origtr.o ./.libs/libutil.a ../src/.libs/libming.a -lpng -lm -lz -lstdc++
./swftophp-origtr ../../in/bumble-bee1.swf
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
gclang++ -c -emit-llvm -std=c++11 $HOME/Desktop/fuzz-prune/covm/pruner-replay.cpp
llvm-link -o lexe.bc exe.bc pruner-replay.bc
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <lexe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/covm/build/proj/libbtrace.so -btrace <marked.bc>markedc.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <markedc.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f swftophp swftophp-exe.o
llc -filetype=obj -o swftophp-exe.o pruned.bc
gclang -DSWFPHP -fcommon -Wall -fPIC -DSWF_LITTLE_ENDIAN -o swftophp swftophp-exe.o ./.libs/libutil.a ../src/.libs/libming.a -lpng -lm -lz -lstdc++
popd

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
      timeout 1s $SUBJECT/util/swftophp "$input" >> "$1/targstats.txt" 2>&1
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
