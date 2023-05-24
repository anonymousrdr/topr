#!/bin/bash

# Setup parent dir
rm -rf aflgo-only
mkdir aflgo-only
cd aflgo-only
export pdir=$PWD

# Build with AFLGo
git clone git://sourceware.org/git/binutils-gdb.git cxxfilt
cd cxxfilt; git checkout binutils-2_40 # latest tag, hash = 32778522c7d
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/libiberty/cplus-dem.c && cp $PWD/../../../pruner-cplus-dem.c $PWD/libiberty/cplus-dem.c
# build error fix1
rm $PWD/gas/Makefile.in && cp $PWD/../../../../../latest-binutils-gas-Makefile.in $PWD/gas/Makefile.in
mkdir obj-aflgo; mkdir obj-aflgo/temp
export TMP_DIR=$PWD/obj-aflgo/temp
export CC=$AFLGO/afl-clang-fast; export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS="-ldl -lutil -lstdc++"
export ADDITIONAL="-fno-inline -targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
# targets are latest modified lines in a primary/previously used src file in the repo
echo $'cplus-dem.c:183' > $TMP_DIR/BBtargets.txt
echo $'cplus-dem.c:184' >> $TMP_DIR/BBtargets.txt
echo $'cplus-dem.c:185' >> $TMP_DIR/BBtargets.txt
echo $'cplus-dem.c:186' >> $TMP_DIR/BBtargets.txt
echo $'cplus-dem.c:215' >> $TMP_DIR/BBtargets.txt
cd obj-aflgo; CFLAGS="-DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error $ADDITIONAL" ../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld --disable-gprofng --disable-gdbserver
make clean
# build error fix2
while true
do
    make
    if [ $? -eq 0 ]; then
        break
    else
        libars_list=$(find $PWD -type f -name "*.a")
        for libar in $libars_list
        do
            ranlib $libar
        done
    fi
done
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
cd binutils; $AFLGO/scripts/genDistance.sh $PWD $TMP_DIR cxxfilt
cd ../../; mkdir obj-dist; cd obj-dist; # work around because cannot run make distclean
CFLAGS="-fno-inline -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -distance=$TMP_DIR/distance.cfg.txt" ../configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld --disable-gprofng --disable-gdbserver
# build error fix2
while true
do
    make
    if [ $? -eq 0 ]; then
        break
    else
        libars_list=$(find $PWD -type f -name "*.a")
        for libar in $libars_list
        do
            ranlib $libar
        done
    fi
done
mkdir in; echo "" > in/in

# Run fuzzer instances in parallel - https://github.com/aflgo/aflgo/blob/master/docs/parallel_fuzzing.txt
echo "Spawning nproc-2 instances"
# Master (-M) instance
instM="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -M fuz0 $PWD/binutils/cxxfilt"
$instM &
instS_num=$(($(nproc)-3))
# secondary (-S) instances
instS1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -S fuz"
instS2=" $PWD/binutils/cxxfilt"
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
rm -rf $pdir/cxxfilt
