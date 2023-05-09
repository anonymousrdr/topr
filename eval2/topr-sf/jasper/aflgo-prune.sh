#!/bin/bash

# Setup parent dir
rm -rf aflgo-prune
mkdir aflgo-prune
cd aflgo-prune
export pdir=$PWD

# Build with AFLGo
git clone https://github.com/mdadams/jasper.git jasper
cd jasper; git checkout 142245b
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/src/libjasper/base/jas_image.c && cp $PWD/../../../pruner-jas_image.c $PWD/src/libjasper/base/jas_image.c
mkdir obj-aflgo; mkdir obj-aflgo/temp
export TMP_DIR=$PWD/obj-aflgo/temp
export CC=$AFLGO/afl-clang-fast; export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS="-lstdc++"
export ADDITIONAL="-fno-inline -targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
echo $'jas_image.c:391' > $TMP_DIR/BBtargets.txt
echo $'jas_image.c:393' >> $TMP_DIR/BBtargets.txt
cd obj-aflgo; CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ../configure --disable-shared --prefix=`pwd`
make clean; make -j4
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
cd src/appl; $AFLGO/scripts/genDistance.sh $PWD $TMP_DIR jasper
# Set gllvm compilers (wrapped around aflgo compilers) to extract bitcode
export CC=gclang
export CXX=gclang++
cd -; CFLAGS="-fno-inline -distance=$TMP_DIR/distance.cfg.txt" CXXFLAGS="-fno-inline -distance=$TMP_DIR/distance.cfg.txt" ../configure --disable-shared --prefix=`pwd`
make clean; make -j4
mkdir in; cp $pdir/../../inp.jp2 in
# Pruning
cd src/appl
mv jasper jasper-orig
get-bc -o exed.bc jasper-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o jasper-origtr.o exetrace.bc
gclang -fno-inline -distance=$TMP_DIR/distance.cfg.txt -o jasper-origtr jasper-origtr.o ../libjasper/.libs/libjasper.a -lstdc++ /usr/lib/x86_64-linux-gnu/libjpeg.so -lm
./jasper-origtr -f ../../in/inp.jp2 -t jp2 -F /tmp/out -T jp2
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <exe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <marked.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f jasper jasper-exe.o
llc -filetype=obj -o jasper-exe.o pruned.bc
gclang -fno-inline -distance=$TMP_DIR/distance.cfg.txt -o jasper jasper-exe.o ../libjasper/.libs/libjasper.a -lstdc++ /usr/lib/x86_64-linux-gnu/libjpeg.so -lm
cd -

# 10 trials of 1 core fuzzing
mkdir out
# timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out/output_000 -t 1000 $PWD/src/appl/jasper -f @@ -t jp2 -F /tmp/out -T jp2
instM1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out/output_00"
instM2=" -t 1000 $PWD/src/appl/jasper -f @@ -t jp2 -F /tmp/out -T jp2"
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
rm -rf $pdir/jasper
