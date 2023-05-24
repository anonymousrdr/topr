#!/bin/bash

# Setup parent dir
rm -rf aflgo-prune
mkdir aflgo-prune
cd aflgo-prune
export pdir=$PWD

# Build with AFLGo
git clone https://git.code.sf.net/p/giflib/code giflib
cd giflib; git checkout 72e31ff
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/util/gifsponge.c && cp $PWD/../../../pruner-gifsponge.c $PWD/util/gifsponge.c
rm $PWD/lib/egif_lib.c && cp $PWD/../../../pruner-egif_lib.c $PWD/lib/egif_lib.c
mkdir obj-aflgo; mkdir obj-aflgo/temp
export TMP_DIR=$PWD/obj-aflgo/temp
export CC=$AFLGO/afl-clang-fast; export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS="-lstdc++"
export ADDITIONAL="-fno-inline -targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
echo $'gifsponge.c:46' > $TMP_DIR/BBtargets.txt
echo $'gifsponge.c:47' >> $TMP_DIR/BBtargets.txt
echo $'gifsponge.c:83' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:111' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:112' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:784' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:785' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:823' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:824' >> $TMP_DIR/BBtargets.txt
./autogen.sh; make distclean
cd obj-aflgo; CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ../configure --disable-shared --prefix=`pwd`
make clean; make -j4
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
$AFLGO/scripts/genDistance.sh $PWD $TMP_DIR gifsponge
# Set gllvm compilers (wrapped around aflgo compilers) to extract bitcode
export CC=gclang
export CXX=gclang++
CFLAGS="-fno-inline -distance=$TMP_DIR/distance.cfg.txt" CXXFLAGS="-fno-inline -distance=$TMP_DIR/distance.cfg.txt" ../configure --disable-shared --prefix=`pwd`
make clean; make -j4
mkdir in; echo "GIF" > in/in
# Pruning
cd util
mv gifsponge gifsponge-orig
get-bc -o exed.bc gifsponge-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o gifsponge-origtr.o exetrace.bc
gclang -fno-inline -distance=$TMP_DIR/distance.cfg.txt -Wall -o gifsponge-origtr gifsponge-origtr.o libgetarg.a ../lib/.libs/libgif.a -lstdc++
./gifsponge-origtr < ../in/in
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <exe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <marked.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f gifsponge gifsponge-exe.o
llc -filetype=obj -o gifsponge-exe.o pruned.bc
gclang -fno-inline -distance=$TMP_DIR/distance.cfg.txt -Wall -o gifsponge gifsponge-exe.o libgetarg.a ../lib/.libs/libgif.a -lstdc++
cd ..

# Run fuzzer instances in parallel - https://github.com/aflgo/aflgo/blob/master/docs/parallel_fuzzing.txt
echo "Spawning nproc-2 instances"
# Master (-M) instance
instM="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -M fuz0 $PWD/util/gifsponge"
$instM &
instS_num=$(($(nproc)-3))
# secondary (-S) instances
instS1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -S fuz"
instS2=" $PWD/util/gifsponge"
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
rm -rf $pdir/giflib
