#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay
export pdir=$PWD

# Clone subject repository
git clone https://gitlab.gnome.org/GNOME/libxml2 libxml2
export SUBJECT=$PWD/libxml2
# Generate BBtargets from commit
pushd $SUBJECT
  git checkout f507d167 # v2.10.3 at https://gitlab.gnome.org/GNOME/libxml2/-/tags
popd

#force build with older version of automake 1.16.1
rm $SUBJECT/configure.ac && cp $PWD/../../latest-configure.ac $SUBJECT/configure.ac

# Integrate custom pruner functions, edit targets accordingly
rm $SUBJECT/valid.c && cp $PWD/../../replay-valid.c $SUBJECT/valid.c

# custom compilers to wrap gllvm around
export LLVM_COMPILER_PATH="$(dirname $(which clang))"
export LLVM_CC_NAME="clang"
export LLVM_CXX_NAME="clang++"
# Set compilers
export CC=gclang
export CXX=gclang++
export LDFLAGS="-lpthread -lstdc++"
export ADDITIONAL="-fno-inline"
export CFLAGS="$CFLAGS $ADDITIONAL"
export CXXFLAGS="$CXXFLAGS $ADDITIONAL"

# Build
# Meanwhile go have a coffee ☕️
pushd $SUBJECT
  ./autogen.sh
  ./configure --disable-shared
  make clean
  make xmllint
popd

# Construct seed corpus
mkdir in
cp -r $SUBJECT/test/dtd* in
cp $SUBJECT/test/dtds/* in

# Pruning
pushd $SUBJECT
mv xmllint xmllint-orig
get-bc -o exed.bc xmllint-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o xmllint-origtr.o exetrace.bc
gclang -fno-inline -D_REENTRANT -pedantic -W -Wformat -Wunused -Wimplicit -Wreturn-type -Wswitch -Wcomment -Wtrigraphs -Wformat -Wchar-subscripts -Wuninitialized -Wparentheses -Wshadow -Wpointer-arith -Wcast-align -Wwrite-strings -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wnested-externs -Winline -Wredundant-decls -Wno-long-long -o xmllint-origtr xmllint-origtr.o ./.libs/libxml2.a -ldl -lpthread -lstdc++ -lz -lm
./xmllint-origtr --valid --recover ../in/dtd1
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
gclang++ -c -emit-llvm -std=c++11 $HOME/Desktop/fuzz-prune/covm/pruner-replay.cpp
llvm-link -o lexe.bc exe.bc pruner-replay.bc
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <lexe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/covm/build/proj/libbtrace.so -btrace <marked.bc>markedc.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <markedc.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f xmllint xmllint-exe.o
llc -filetype=obj -o xmllint-exe.o pruned.bc
gclang -fno-inline -D_REENTRANT -pedantic -W -Wformat -Wunused -Wimplicit -Wreturn-type -Wswitch -Wcomment -Wtrigraphs -Wformat -Wchar-subscripts -Wuninitialized -Wparentheses -Wshadow -Wpointer-arith -Wcast-align -Wwrite-strings -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wnested-externs -Winline -Wredundant-decls -Wno-long-long -o xmllint xmllint-exe.o ./.libs/libxml2.a -ldl -lpthread -lstdc++ -lz -lm
popd

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
      timeout 14s $SUBJECT/xmllint --valid --recover "$input" >> "$1/targstats.txt" 2>&1
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
