#!/bin/bash

# Setup parent dir
rm -rf aflgo-prune
mkdir aflgo-prune
cd aflgo-prune
export pdir=$PWD

# Build with AFLGo
git clone https://github.com/mdadams/jasper.git jasper
cd jasper; git checkout 402d096 # v4.0.0 at https://github.com/jasper-software/jasper/tags
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/src/libjasper/base/jas_tvp.c && cp $PWD/../../../pruner-jas_tvp.c $PWD/src/libjasper/base/jas_tvp.c
rm $PWD/src/libjasper/base/jas_image.c && cp $PWD/../../../pruner-jas_image.c $PWD/src/libjasper/base/jas_image.c
mkdir obj-aflgo; mkdir obj-aflgo/temp
export TMP_DIR=$PWD/obj-aflgo/temp
export CC=$AFLGO/afl-clang-fast; export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS="-lstdc++ -lpthread"
export ADDITIONAL="-fno-inline -targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
# targets are latest modified lines in a primary/previously used src file in the repo
echo $'jas_tvp.c:115' > $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:116' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:131' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:132' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:151' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:152' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:164' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:165' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:173' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:174' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:189' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:190' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:203' >> $TMP_DIR/BBtargets.txt
echo $'jas_tvp.c:204' >> $TMP_DIR/BBtargets.txt
echo $'jas_image.c:447' >> $TMP_DIR/BBtargets.txt
echo $'jas_image.c:448' >> $TMP_DIR/BBtargets.txt
echo $'jas_image.c:449' >> $TMP_DIR/BBtargets.txt
echo $'jas_image.c:1016' >> $TMP_DIR/BBtargets.txt
export CFLAGS="$ADDITIONAL"
export CXXFLAGS="$ADDITIONAL"
cd obj-aflgo
cmake -H$PWD/.. -B$PWD -DCMAKE_INSTALL_PREFIX=$PWD -DJAS_ENABLE_SHARED=false
cmake --build $PWD
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
cd src/app; $AFLGO/scripts/genDistance.sh $PWD $TMP_DIR jasper
# Set gllvm compilers (wrapped around aflgo compilers) to extract bitcode
export CC=gclang
export CXX=gclang++
cd -
cd ..
mkdir obj-aflgo2; cd obj-aflgo2
export ADDITIONAL="-fno-inline -distance=$TMP_DIR/distance.cfg.txt"
export CFLAGS="$ADDITIONAL"
export CXXFLAGS="$ADDITIONAL"
cmake -H$PWD/.. -B$PWD -DCMAKE_INSTALL_PREFIX=$PWD -DJAS_ENABLE_SHARED=false
cmake --build $PWD
mkdir in; cp $pdir/../../../inp.jp2 in
# Pruning
cd src/app
mv jasper jasper-orig
get-bc -o exed.bc jasper-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o jasper-origtr.o exetrace.bc
gclang -fno-inline -distance=$TMP_DIR/distance.cfg.txt -pedantic -lstdc++ -lpthread jasper-origtr.o -o jasper-origtr ../libjasper/libjasper.a /usr/lib/x86_64-linux-gnu/libjpeg.so -lm /usr/lib/x86_64-linux-gnu/libpthread.so
./jasper-origtr -f ../../in/inp.jp2 -t jp2 -F /tmp/out -T jp2
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <exe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <marked.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f jasper jasper-exe.o
llc -filetype=obj -o jasper-exe.o pruned.bc
gclang -fno-inline -distance=$TMP_DIR/distance.cfg.txt -pedantic -lstdc++ -lpthread jasper-exe.o -o jasper ../libjasper/libjasper.a /usr/lib/x86_64-linux-gnu/libjpeg.so -lm /usr/lib/x86_64-linux-gnu/libpthread.so
cd -

# Run fuzzer instances in parallel - https://github.com/aflgo/aflgo/blob/master/docs/parallel_fuzzing.txt
echo "Spawning nproc-2 instances"
# Master (-M) instance
instM="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -M fuz0 $PWD/src/app/jasper -f @@ -t jp2 -F /tmp/out -T jp2"
$instM &
instS_num=$(($(nproc)-3))
# secondary (-S) instances
instS1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -S fuz"
instS2=" $PWD/src/app/jasper -f @@ -t jp2 -F /tmp/out -T jp2"
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
rm -rf $pdir/jasper
