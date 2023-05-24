#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay

# Build
git clone https://github.com/cesanta/mjs.git mjs
cd mjs; git checkout 2827bd0 # v1.20.1 at https://github.com/cesanta/mjs/tags?after=2.2
mkdir obj-aflgo
# Set compilers
export CC=clang
export CXX=clang++
export LDFLAGS="-lstdc++"
# debug flag '-g', ASAN flag '-fsanitize=address', ASAN_OPTIONS
export ADDITIONAL="-fsanitize=address"
export LDFLAGS="$LDFLAGS -fsanitize=address"
export ASAN_OPTIONS=abort_on_error=1
$CC -DMJS_MAIN mjs.c $ADDITIONAL -ldl -g -o mjs-bin $LDFLAGS
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
      echo -e "\nEND OF REPLAY----" >> "$1/targstats.txt"
    done
  done
done
