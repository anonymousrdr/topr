#!/bin/bash

# Setup parent dir
rm -rf aflgo-replay
mkdir aflgo-replay
cd aflgo-replay

# Clone subject repository
git clone https://gitlab.gnome.org/GNOME/libxml2 libxml2
export SUBJECT=$PWD/libxml2
# Generate BBtargets from commit
pushd $SUBJECT
  git checkout f507d167 # v2.10.3 at https://gitlab.gnome.org/GNOME/libxml2/-/tags
popd

#force build with older version of automake 1.16.1
rm $SUBJECT/configure.ac && cp $PWD/../../latest-configure.ac $SUBJECT/configure.ac

# Set compilers
export CC=clang
export CXX=clang++
export LDFLAGS="-lpthread -lstdc++"

# debug flag '-g', ASAN flag '-fsanitize=address', ASAN_OPTIONS
export ADDITIONAL="-g -fno-inline -fsanitize=address"
export CFLAGS="$CFLAGS $ADDITIONAL"
export CXXFLAGS="$CXXFLAGS $ADDITIONAL"
export LDFLAGS="$LDFLAGS -fsanitize=address"
export ASAN_OPTIONS=abort_on_error=1

# Build
# Meanwhile go have a coffee ☕️
pushd $SUBJECT
  ./autogen.sh
  ./configure --disable-shared
  make clean
  make xmllint
popd

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
      timeout 5s $SUBJECT/xmllint --valid --recover "$input" >> "$1/targstats.txt" 2>&1
      echo -e "\nEND OF REPLAY----" >> "$1/targstats.txt"
    done
  done
done
