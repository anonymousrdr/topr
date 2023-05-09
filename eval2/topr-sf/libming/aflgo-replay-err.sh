#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay

# Clone subject repository
git clone https://github.com/libming/libming.git libming
export SUBJECT=$PWD/libming
pushd $SUBJECT
  git checkout b72cc2f # version 0.4.8
popd

# Set compilers
export CC=clang
export CXX=clang++
export LDFLAGS="-lstdc++"
export CFLAGS+=-fcommon
export CXXFLAGS+=-fcommon

# debug flag '-g', ASAN flag '-fsanitize=address', ASAN_OPTIONS
export ADDITIONAL="-g -fsanitize=address"
export CFLAGS="$CFLAGS $ADDITIONAL"
export CXXFLAGS="$CXXFLAGS $ADDITIONAL"
export LDFLAGS="$LDFLAGS -fsanitize=address"
export ASAN_OPTIONS=abort_on_error=1

# Build
# Meanwhile go have a coffee ☕️
pushd $SUBJECT
  ./autogen.sh
  ./configure --disable-shared --disable-freetype --prefix=`pwd`
  make clean
  make
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
      echo -e "\nEND OF REPLAY----" >> "$1/targstats.txt"
    done
  done
done
