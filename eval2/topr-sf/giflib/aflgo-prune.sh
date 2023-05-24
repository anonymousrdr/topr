#!/bin/bash

# Setup parent dir
rm -rf aflgo-prune
mkdir aflgo-prune
cd aflgo-prune
export pdir=$PWD

# Build with AFLGo
git clone https://git.code.sf.net/p/giflib/code giflib
cd giflib; git checkout adf5a1a # latest version
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/egif_lib.c && cp $PWD/../../../pruner-egif_lib.c $PWD/egif_lib.c

# fix error in Makefile to modify CFLAGS
rm $PWD/Makefile && cp $PWD/../../../latest-Makefile $PWD/Makefile

mkdir temp
export TMP_DIR=$PWD/temp
export CC=$AFLGO/afl-clang-fast; export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS="-lstdc++"
export ADDITIONAL="-disable-shared -fno-inline -targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
export COPYCFLAGS="-std=gnu99 -fPIC -Wall -Wno-format-truncation"
export CFLAGS="$COPYCFLAGS $ADDITIONAL"
echo $'egif_lib.c:121' > $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:122' >> $TMP_DIR/BBtargets.txt
make clean; make -j4
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
$AFLGO/scripts/genDistance.sh $PWD $TMP_DIR gifsponge
# Set gllvm compilers (wrapped around aflgo compilers) to extract bitcode
export CC=gclang
export CXX=gclang++
export ADDITIONAL="-disable-shared -fno-inline -distance=$TMP_DIR/distance.cfg.txt"
export CFLAGS="$COPYCFLAGS $ADDITIONAL"
make clean; make -j4
mkdir in; echo "GIF" > in/in
# Pruning
mv gifsponge gifsponge-orig
get-bc -o exed.bc gifsponge-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o gifsponge-origtr.o exetrace.bc
gclang -std=gnu99 -fPIC -Wall -Wno-format-truncation -O2 -disable-shared -fno-inline -distance=$TMP_DIR/distance.cfg.txt -o gifsponge-origtr gifsponge-origtr.o libgif.a libutil.a libgif.a -lm -lstdc++
./gifsponge-origtr < in/in
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <exe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <marked.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f gifsponge gifsponge-exe.o
llc -filetype=obj -o gifsponge-exe.o pruned.bc
gclang -std=gnu99 -fPIC -Wall -Wno-format-truncation -O2 -disable-shared -fno-inline -distance=$TMP_DIR/distance.cfg.txt -o gifsponge gifsponge-exe.o libgif.a libutil.a libgif.a -lm -lstdc++

# 10 trials of 1 core fuzzing
mkdir out
# timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out/output_000 -t 1000 $PWD/gifsponge
instM1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out/output_00"
instM2=" -t 1000 $PWD/gifsponge"
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
rm -rf $pdir/giflib
