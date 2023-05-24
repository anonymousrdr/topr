#!/bin/bash

# Setup parent dir
rm -rf aflgo-only
mkdir aflgo-only
cd aflgo-only
export pdir=$PWD

# Build with AFLGo
git clone https://git.code.sf.net/p/giflib/code giflib
cd giflib; git checkout adf5a1a # latest version
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/gifsponge.c && cp $PWD/../../../pruner-gifsponge.c $PWD/gifsponge.c
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
# targets are latest modified lines in a primary/previously used src file in the repo
echo $'gifsponge.c:48' > $TMP_DIR/BBtargets.txt
echo $'gifsponge.c:49' >> $TMP_DIR/BBtargets.txt
echo $'gifsponge.c:87' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:122' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:802' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:841' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:842' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:843' >> $TMP_DIR/BBtargets.txt
echo $'egif_lib.c:844' >> $TMP_DIR/BBtargets.txt
make clean; make -j4
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
$AFLGO/scripts/genDistance.sh $PWD $TMP_DIR gifsponge
export ADDITIONAL="-disable-shared -fno-inline -distance=$TMP_DIR/distance.cfg.txt"
export CFLAGS="$COPYCFLAGS $ADDITIONAL"
make clean; make -j4
mkdir in; echo "GIF" > in/in

# Run fuzzer instances in parallel - https://github.com/aflgo/aflgo/blob/master/docs/parallel_fuzzing.txt
echo "Spawning nproc-2 instances"
# Master (-M) instance
instM="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -M fuz0 $PWD/gifsponge"
$instM &
instS_num=$(($(nproc)-3))
# secondary (-S) instances
instS1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -S fuz"
instS2=" $PWD/gifsponge"
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
