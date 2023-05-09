#!/bin/bash

# Setup parent dir
rm -rf aflgo-prune
mkdir aflgo-prune
cd aflgo-prune
export pdir=$PWD

# Build with AFLGo
git clone https://github.com/cesanta/mjs.git mjs
cd mjs; git checkout b1b6eac # v2.20.0 at https://github.com/cesanta/mjs/tags
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/mjs.c && cp $PWD/../../../pruner-mjs.c $PWD/mjs.c
mkdir obj-aflgo; mkdir obj-aflgo/temp
export TMP_DIR=$PWD/obj-aflgo/temp
export CC=$AFLGO/afl-clang-fast; export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS="-lstdc++"
export ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
echo $'mjs.c:4073' > $TMP_DIR/BBtargets.txt
echo $'mjs.c:4074' >> $TMP_DIR/BBtargets.txt
$CC -DMJS_MAIN mjs.c $ADDITIONAL -ldl -g -o mjs-bin $LDFLAGS
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
$AFLGO/scripts/genDistance.sh $PWD $TMP_DIR mjs-bin
# Set gllvm compilers (wrapped around aflgo compilers) to extract bitcode
export CC=gclang
export CXX=gclang++
$CC -DMJS_MAIN mjs.c -distance=$TMP_DIR/distance.cfg.txt -ldl -g -o mjs-bin $LDFLAGS
cd obj-aflgo; mkdir in; echo "" > in/in
cd ..
# Pruning
mv mjs-bin mjs-bin-orig
get-bc -o exed.bc mjs-bin-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o mjs-bin-origtr.o exetrace.bc
gclang -DMJS_MAIN mjs-bin-origtr.o -distance=$TMP_DIR/distance.cfg.txt -ldl -g -o mjs-bin-origtr $LDFLAGS
./mjs-bin-origtr -f obj-aflgo/in/in
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <exe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <marked.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f mjs-bin mjs-bin-exe.o
llc -filetype=obj -o mjs-bin-exe.o pruned.bc
gclang -DMJS_MAIN mjs-bin-exe.o -distance=$TMP_DIR/distance.cfg.txt -ldl -g -o mjs-bin $LDFLAGS
cd obj-aflgo

# Run fuzzer instances in parallel - https://github.com/aflgo/aflgo/blob/master/docs/parallel_fuzzing.txt
echo "Spawning nproc-2 instances"
# Master (-M) instance
instM="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -M fuz0 $PWD/../mjs-bin -f @@"
$instM &
instS_num=$(($(nproc)-3))
# secondary (-S) instances
instS1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -S fuz"
instS2=" $PWD/../mjs-bin -f @@"
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
rm -rf $pdir/mjs
