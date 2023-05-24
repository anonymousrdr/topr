#!/bin/bash

# Setup parent dir
rm -rf aflgo-prune
mkdir aflgo-prune
cd aflgo-prune
export pdir=$PWD

# Build with AFLGo
git clone https://github.com/Unidata/netcdf-c.git netcdf
cd netcdf
git checkout 63150df # v4.9.1 at https://github.com/Unidata/netcdf-c/tags
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/ncdump/ncdump.c && cp $PWD/../../../pruner-ncdump.c $PWD/ncdump/ncdump.c
mkdir temp
export TMP_DIR=$PWD/temp
export CC=$AFLGO/afl-clang-fast; export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS="-lstdc++ -L/usr/lib/x86_64-linux-gnu/hdf5/serial/lib"
export CFLAGS="-I/usr/lib/x86_64-linux-gnu/hdf5/serial/include"
export CXXFLAGS="-I/usr/lib/x86_64-linux-gnu/hdf5/serial/include"
export ADDITIONAL="-fno-inline -targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
# targets are lines in a primary src file in the repo
echo $'ncdump.c:945' > $TMP_DIR/BBtargets.txt
echo $'ncdump.c:2055' >> $TMP_DIR/BBtargets.txt
CFLAGS="$CFLAGS $ADDITIONAL" CXXFLAGS="$CXXFLAGS $ADDITIONAL" ./configure --disable-dap --disable-dap-remote-tests --disable-shared
make
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
cd $PWD/ncdump; $AFLGO/scripts/genDistance.sh $PWD $TMP_DIR ncdump
# Set gllvm compilers (wrapped around aflgo compilers) to extract bitcode
export CC=gclang
export CXX=gclang++
cd $pdir/netcdf
make distclean
export ADDITIONAL="-fno-inline -distance=$TMP_DIR/distance.cfg.txt"
CFLAGS="$CFLAGS $ADDITIONAL" CXXFLAGS="$CXXFLAGS $ADDITIONAL" ./configure --disable-dap --disable-dap-remote-tests --disable-shared
make
cd $PWD/ncdump
mkdir in; cp $pdir/../../inp.nc in
# Pruning
mv ncdump ncdump-orig
get-bc -o exed.bc ncdump-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o ncdump-origtr.o exetrace.bc
gclang -fno-inline -distance=$TMP_DIR/distance.cfg.txt -I/usr/lib/x86_64-linux-gnu/hdf5/serial/include -fno-strict-aliasing -o ncdump-origtr ncdump-origtr.o -L/usr/lib/x86_64-linux-gnu/hdf5/serial/lib ../liblib/.libs/libnetcdf.a -lstdc++ -lhdf5_hl -lhdf5 -lm -lz -ldl -lsz -lbz2 -lxml2 /usr/lib/x86_64-linux-gnu/libcurl.so -pthread
./ncdump-origtr in/inp.nc
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <exe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <marked.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f ncdump ncdump-exe.o
llc -filetype=obj -o ncdump-exe.o pruned.bc
gclang -fno-inline -distance=$TMP_DIR/distance.cfg.txt -I/usr/lib/x86_64-linux-gnu/hdf5/serial/include -fno-strict-aliasing -o ncdump ncdump-exe.o -L/usr/lib/x86_64-linux-gnu/hdf5/serial/lib ../liblib/.libs/libnetcdf.a -lstdc++ -lhdf5_hl -lhdf5 -lm -lz -ldl -lsz -lbz2 -lxml2 /usr/lib/x86_64-linux-gnu/libcurl.so -pthread

# Run fuzzer instances in parallel - https://github.com/aflgo/aflgo/blob/master/docs/parallel_fuzzing.txt
echo "Spawning nproc-2 instances"
# Master (-M) instance
instM="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -M fuz0 $PWD/ncdump @@"
$instM &
instS_num=$(($(nproc)-3))
# secondary (-S) instances
instS1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -S fuz"
instS2=" $PWD/ncdump @@"
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
rm -rf $pdir/netcdf
