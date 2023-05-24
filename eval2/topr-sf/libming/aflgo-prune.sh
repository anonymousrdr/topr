#!/bin/bash

# Setup parent dir
rm -rf aflgo-prune
mkdir aflgo-prune
cd aflgo-prune
export pdir=$PWD

# Clone subject repository
git clone https://github.com/libming/libming.git libming
export SUBJECT=$PWD/libming

# Setup directory containing all temporary files
mkdir temp
export TMP_DIR=$PWD/temp

# Generate BBtargets from commit
pushd $SUBJECT
  git checkout b72cc2f # version 0.4.8
popd

# Integrate custom pruner functions, edit targets accordingly
rm $SUBJECT/util/read.c && cp $PWD/../../pruner-read.c $SUBJECT/util/read.c
echo $'read.c:119' > $TMP_DIR/BBtargets.txt
echo $'read.c:120' >> $TMP_DIR/BBtargets.txt

# Print new targets. 
echo "Targets:"
cat $TMP_DIR/BBtargets.txt

# Set aflgo-instrumenter
export CC=$AFLGO/afl-clang-fast
export CXX=$AFLGO/afl-clang-fast++
export CFLAGS+=-fcommon
export CXXFLAGS+=-fcommon

# Set aflgo-instrumentation flags
export COPY_CFLAGS=$CFLAGS
export COPY_CXXFLAGS=$CXXFLAGS
export ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
export CFLAGS="$CFLAGS $ADDITIONAL"
export CXXFLAGS="$CXXFLAGS $ADDITIONAL"

# Build (in order to generate CG and CFGs).
# Meanwhile go have a coffee ☕️
pushd $SUBJECT
  ./autogen.sh
  ./configure --disable-shared --disable-freetype --prefix=`pwd`
  make clean
  make
popd
# * If the linker (CCLD) complains that you should run ranlib, make
#   sure that libLTO.so and LLVMgold.so (from building LLVM with Gold)
#   can be found in /usr/lib/bfd-plugins
# * If the compiler crashes, there is some problem with LLVM not 
#   supporting our instrumentation (afl-llvm-pass.so.cc:540-577).
#   LLVM has changed the instrumentation-API very often :(
#   -> Check LLVM-version, fix problem, and prepare pull request.
# * You can speed up the compilation with a parallel build. However,
#   this may impact which BBs are identified as targets. 
#   See https://github.com/aflgo/aflgo/issues/41.

# Clean up
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt

# Generate distance ☕️
# $AFLGO/scripts/genDistance.sh is the original, but significantly slower, version
$AFLGO/scripts/genDistance.sh $SUBJECT $TMP_DIR $SUBJECT/util/swftophp

# Check distance file
echo "Distance values:"
head -n5 $TMP_DIR/distance.cfg.txt
echo "..."
tail -n5 $TMP_DIR/distance.cfg.txt

# Set gllvm compilers (wrapped around aflgo compilers) to extract bitcode
export CC=gclang
export CXX=gclang++

export CFLAGS="$COPY_CFLAGS -distance=$TMP_DIR/distance.cfg.txt"
export CXXFLAGS="$COPY_CXXFLAGS -distance=$TMP_DIR/distance.cfg.txt"

# Clean and build subject with distance instrumentation ☕️
pushd $SUBJECT
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
gclang -DSWFPHP -fcommon -distance=$TMP_DIR/distance.cfg.txt -Wall -fPIC -DSWF_LITTLE_ENDIAN -o swftophp-origtr swftophp-origtr.o ./.libs/libutil.a ../src/.libs/libming.a -lpng -lm -lz
./swftophp-origtr ../../in/bumble-bee1.swf
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <exe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <marked.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f swftophp swftophp-exe.o
llc -filetype=obj -o swftophp-exe.o pruned.bc
gclang -DSWFPHP -fcommon -distance=$TMP_DIR/distance.cfg.txt -Wall -fPIC -DSWF_LITTLE_ENDIAN -o swftophp swftophp-exe.o ./.libs/libutil.a ../src/.libs/libming.a -lpng -lm -lz
popd

# 10 trials of 1 core fuzzing
mkdir out
# timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out/output_000 -t 1000 $SUBJECT/util/swftophp @@
instM1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out/output_00"
instM2=" -t 1000 $SUBJECT/util/swftophp @@"
for i in `seq 0 9`;
do
    instM="$instM1$i$instM2"
    $instM &
done
wait -f
echo "Finished 10 trials of fuzzing"

rm -rf $(find $PWD/out -type d -name ".*")
rm -f $(find $PWD/out -type f -name "README.txt")

mv $PWD/out $pdir
rm -rf $SUBJECT
rm -rf $pdir/temp 
rm -rf $pdir/in
