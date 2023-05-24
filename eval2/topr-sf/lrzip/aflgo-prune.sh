#!/bin/bash

# Setup parent dir
rm -rf aflgo-prune
mkdir aflgo-prune
cd aflgo-prune
export pdir=$PWD

# Build with AFLGo
git clone https://github.com/ckolivas/lrzip.git lrzip
cd lrzip/; git checkout ed51e14
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/stream.c && cp $PWD/../../../pruner-stream.c $PWD/stream.c
mkdir obj-aflgo; mkdir obj-aflgo/temp
export TMP_DIR=$PWD/obj-aflgo/temp
export CC=$AFLGO/afl-clang-fast; export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS="-lpthread -lstdc++"
export ADDITIONAL="-fno-inline -targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
echo $'stream.c:1775' > $TMP_DIR/BBtargets.txt
echo $'stream.c:1776' >> $TMP_DIR/BBtargets.txt
./autogen.sh; make distclean
cd obj-aflgo; CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ../configure --disable-shared --prefix=`pwd`
make clean; make -j4
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
$AFLGO/scripts/genDistance.sh $PWD $TMP_DIR lrzip
# Set gllvm compilers (wrapped around aflgo compilers) to extract bitcode
export CC=gclang
export CXX=gclang++
export ADDITIONAL="-fno-inline -distance=$TMP_DIR/distance.cfg.txt"
CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ../configure --disable-shared --prefix=`pwd`
make clean; make -j4
mkdir in; echo "" > in/in
$PWD/lrzip in/in
rm in/in
# Pruning
mv lrzip lrzip-orig
get-bc -o exed.bc lrzip-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o lrzip-origtr.o exetrace.bc
gclang++ -I. -I lzma/C -DNDEBUG -fno-inline -distance=$TMP_DIR/distance.cfg.txt -o lrzip-origtr lrzip-origtr.o ./.libs/libtmplrzip.a -llzo2 -lbz2 -lz -lm -lpthread
./lrzip-origtr -t in/in.lrz
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <exe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <marked.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f lrzip lrzip-exe.o
llc -filetype=obj -o lrzip-exe.o pruned.bc
gclang++ -I. -I lzma/C -DNDEBUG -fno-inline -distance=$TMP_DIR/distance.cfg.txt -o lrzip lrzip-exe.o ./.libs/libtmplrzip.a -llzo2 -lbz2 -lz -lm -lpthread

# 10 trials of 1 core fuzzing
mkdir out
# timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out/output_000 -t 1000 $PWD/lrzip -t @@
instM1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out/output_00"
instM2=" -t 1000 $PWD/lrzip -t @@"
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
rm -rf $pdir/lrzip
