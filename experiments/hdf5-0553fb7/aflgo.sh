#!/bin/bash

# Setup parent dir
rm -rf aflgo-only
mkdir aflgo-only
cd aflgo-only
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
cd $pdir/hdf5
make distclean
export ADDITIONAL="-fno-inline -distance=$TMP_DIR/distance.cfg.txt"
CFLAGS="$ADDITIONAL" CXXFLAGS="$ADDITIONAL" ./configure --disable-shared
make
cd $PWD/tools/src/h5dump
mkdir in; cp $pdir/../../inp.h5 in

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
