#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay

# Build
git clone https://github.com/Unidata/netcdf-c.git netcdf
cd netcdf
git checkout 63150df # v4.9.1 at https://github.com/Unidata/netcdf-c/tags
# Set compilers
export CC=clang
export CXX=clang++ 
export LDFLAGS="-lstdc++ -L/usr/lib/x86_64-linux-gnu/hdf5/serial/lib"
export CFLAGS="-I/usr/lib/x86_64-linux-gnu/hdf5/serial/include"
export CXXFLAGS="-I/usr/lib/x86_64-linux-gnu/hdf5/serial/include"
# debug flag '-g', ASAN flag '-fsanitize=address', ASAN_OPTIONS
export ADDITIONAL="-g -fno-inline -fsanitize=address"
export LDFLAGS="$LDFLAGS -fsanitize=address"
export ASAN_OPTIONS=abort_on_error=1
CFLAGS="$CFLAGS $ADDITIONAL" CXXFLAGS="$CXXFLAGS $ADDITIONAL" ./configure --disable-dap --disable-dap-remote-tests --disable-shared
make
cd $PWD/ncdump

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
      timeout --foreground 1s $PWD/ncdump "$input" >> "$1/targstats.txt" 2>&1
      echo -e "\nEND OF REPLAY----" >> "$1/targstats.txt"
    done
  done
done
