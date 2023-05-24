#!/bin/bash

# Setup parent dir
rm -rf aflgo-prune
mkdir aflgo-prune
cd aflgo-prune
export pdir=$PWD

# Build with AFLGo
git clone https://github.com/HDFGroup/hdf5.git hdf5
cd hdf5
git checkout 0553fb7 # v1.14.0 at https://github.com/HDFGroup/hdf5/tags
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/src/H5Faccum.c && cp $PWD/../../../pruner-H5Faccum.c $PWD/src/H5Faccum.c
rm $PWD/src/H5Fquery.c && cp $PWD/../../../pruner-H5Fquery.c $PWD/src/H5Fquery.c
mkdir temp
export TMP_DIR=$PWD/temp
export CC=$AFLGO/afl-clang-fast; export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS="-lstdc++"
export ADDITIONAL="-fno-inline -targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
# targets are crash locations found by afl++ fuzzing
echo $'H5Faccum.c:195' > $TMP_DIR/BBtargets.txt
echo $'H5Faccum.c:196' >> $TMP_DIR/BBtargets.txt
echo $'H5Fquery.c:588' >> $TMP_DIR/BBtargets.txt
echo $'H5Fquery.c:589' >> $TMP_DIR/BBtargets.txt
echo $'H5Fquery.c:590' >> $TMP_DIR/BBtargets.txt
CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ./configure --disable-shared
make
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
cd $PWD/tools/src/h5dump; $AFLGO/scripts/genDistance.sh $PWD $TMP_DIR h5dump
# Set gllvm compilers (wrapped around aflgo compilers) to extract bitcode
export CC=gclang
export CXX=gclang++
cd $pdir/hdf5
make distclean
export ADDITIONAL="-fno-inline -distance=$TMP_DIR/distance.cfg.txt"
CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ./configure --disable-shared
make
cd $PWD/tools/src/h5dump
mkdir in; cp $pdir/../../inp.h5 in
# Pruning
mv h5dump h5dump-orig
get-bc -o exed.bc h5dump-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o h5dump-origtr.o exetrace.bc
gclang -fno-inline -distance=$TMP_DIR/distance.cfg.txt -std=c99 -Wall -Warray-bounds -Wcast-qual -Wconversion -Wdouble-promotion -Wextra -Wformat=2 -Wframe-larger-than=16384 -Wimplicit-fallthrough -Wnull-dereference -Wunused-const-variable -Wwrite-strings -Wpedantic -Wvolatile-register-var -Wno-c++-compat -Wbad-function-cast -Wimplicit-function-declaration -Wincompatible-pointer-types -Wmissing-declarations -Wpacked -Wshadow -Wswitch -Wno-error=incompatible-pointer-types-discards-qualifiers -Wunused-function -Wunused-variable -Wunused-parameter -Wcast-align -Wformat -Wno-missing-noreturn -O3 -o h5dump-origtr h5dump-origtr.o ../../../tools/lib/.libs/libh5tools.a ../../../src/.libs/libhdf5.a -lstdc++ -lz -ldl -lm
./h5dump-origtr in/inp.h5
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <exe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <marked.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f h5dump h5dump-exe.o
llc -filetype=obj -o h5dump-exe.o pruned.bc
gclang -fno-inline -distance=$TMP_DIR/distance.cfg.txt -std=c99 -Wall -Warray-bounds -Wcast-qual -Wconversion -Wdouble-promotion -Wextra -Wformat=2 -Wframe-larger-than=16384 -Wimplicit-fallthrough -Wnull-dereference -Wunused-const-variable -Wwrite-strings -Wpedantic -Wvolatile-register-var -Wno-c++-compat -Wbad-function-cast -Wimplicit-function-declaration -Wincompatible-pointer-types -Wmissing-declarations -Wpacked -Wshadow -Wswitch -Wno-error=incompatible-pointer-types-discards-qualifiers -Wunused-function -Wunused-variable -Wunused-parameter -Wcast-align -Wformat -Wno-missing-noreturn -O3 -o h5dump h5dump-exe.o ../../../tools/lib/.libs/libh5tools.a ../../../src/.libs/libhdf5.a -lstdc++ -lz -ldl -lm

# Run fuzzer instances in parallel - https://github.com/aflgo/aflgo/blob/master/docs/parallel_fuzzing.txt
echo "Spawning nproc-2 instances"
# Master (-M) instance
instM="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -M fuz0 $PWD/h5dump @@"
$instM &
instS_num=$(($(nproc)-3))
# secondary (-S) instances
instS1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -S fuz"
instS2=" $PWD/h5dump @@"
for i in `seq 1 $instS_num`;
do
    instS="$instS1$i$instS2"
    $instS &
done
wait -f
echo "Finished parallel fuzzing"

rm -rf $(find $PWD/out -type d -name ".*")
rm -f $(find $PWD/out -type f -name "README.txt")

mv $PWD/out $pdir
rm -rf $pdir/hdf5
