#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay

# Build
git clone https://github.com/mdadams/jasper.git jasper
cd jasper; git checkout 402d096 # v4.0.0 at https://github.com/jasper-software/jasper/tags
mkdir obj-aflgo
cd obj-aflgo
# Set compilers
export CC=clang
export CXX=clang++ 
export LDFLAGS="-lstdc++ -lpthread"
# debug flag '-g', ASAN flag '-fsanitize=address', ASAN_OPTIONS
export ADDITIONAL="-g -fno-inline -fsanitize=address"
export LDFLAGS="$LDFLAGS -fsanitize=address"
export ASAN_OPTIONS=abort_on_error=1
export CFLAGS="$ADDITIONAL"
export CXXFLAGS="$ADDITIONAL"
cmake -H$PWD/.. -B$PWD -DCMAKE_INSTALL_PREFIX=$PWD -DJAS_ENABLE_SHARED=false
cmake --build $PWD

# Replay aflgo generated inputs
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
      echo "INPUT: $input" >> "$1/targstats.txt"
      timeout --foreground 1s $PWD/src/app/jasper -f "$input" -t jp2 -F /tmp/out -T jp2 >> "$1/targstats.txt" 2>&1
      echo -e "\nEND OF REPLAY----" >> "$1/targstats.txt"
    done
  done
done
