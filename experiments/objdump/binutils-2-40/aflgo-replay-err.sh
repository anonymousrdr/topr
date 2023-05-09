#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay

# Build
git clone git://sourceware.org/git/binutils-gdb.git objdump
cd objdump; git checkout binutils-2_40 # latest tag, hash = 32778522c7d
# build error fix1
rm $PWD/gas/Makefile.in && cp $PWD/../../../../../latest-binutils-gas-Makefile.in $PWD/gas/Makefile.in
mkdir obj-aflgo
# Set compilers
export CC=clang
export CXX=clang++ 
export LDFLAGS="-ldl -lutil -lstdc++"
# debug flag '-g', ASAN flag '-fsanitize=address', ASAN_OPTIONS
export ADDITIONAL="-fno-inline -fsanitize=address"
export LDFLAGS="$LDFLAGS -fsanitize=address"
export ASAN_OPTIONS=detect_leaks=0
cd obj-aflgo; CFLAGS="$ADDITIONAL -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error" ../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld --disable-gprofng --disable-gdbserver
make clean
# build error fix2
while true
do
    make
    if [ $? -eq 0 ]; then
        break
    else
        libars_list=$(find $PWD -type f -name "*.a")
        for libar in $libars_list
        do
            ranlib $libar
        done
    fi
done
export ASAN_OPTIONS=abort_on_error=1
export ASAN_OPTIONS=detect_leaks=1

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
      timeout --foreground 1s $PWD/binutils/objdump -SD "$input" >> "$1/targstats.txt" 2>&1
      echo -e "\nEND OF REPLAY----" >> "$1/targstats.txt"
    done
  done
done
