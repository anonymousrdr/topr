#!/bin/bash

# Setup parent dir
rm -rf aflgo-prune
mkdir aflgo-prune
cd aflgo-prune
export pdir=$PWD

# Build with AFLGo
git clone git://sourceware.org/git/binutils-gdb.git objdump
cd objdump; git checkout binutils-2_40 # latest tag, hash = 32778522c7d
# Integrate custom pruner functions, edit targets accordingly
rm $PWD/binutils/objdump.c && cp $PWD/../../../pruner-objdump.c $PWD/binutils/objdump.c
rm $PWD/bfd/dwarf2.c && cp $PWD/../../../pruner-dwarf2.c $PWD/bfd/dwarf2.c
rm $PWD/bfd/elf.c && cp $PWD/../../../pruner-elf.c $PWD/bfd/elf.c
rm $PWD/bfd/section.c && cp $PWD/../../../pruner-section.c $PWD/bfd/section.c
# build error fix1
rm $PWD/gas/Makefile.in && cp $PWD/../../../../../latest-binutils-gas-Makefile.in $PWD/gas/Makefile.in
mkdir obj-aflgo; mkdir obj-aflgo/temp
export TMP_DIR=$PWD/obj-aflgo/temp
export CC=$AFLGO/afl-clang-fast; export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS="-ldl -lutil -lstdc++"
export ADDITIONAL="-fno-inline -targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
# targets are latest modified lines in a primary/previously used src file in the repo
echo $'objdump.c:4235' > $TMP_DIR/BBtargets.txt
echo $'objdump.c:4236' >> $TMP_DIR/BBtargets.txt
echo $'objdump.c:4237' >> $TMP_DIR/BBtargets.txt
echo $'objdump.c:4238' >> $TMP_DIR/BBtargets.txt
echo $'objdump.c:4239' >> $TMP_DIR/BBtargets.txt
echo $'objdump.c:4240' >> $TMP_DIR/BBtargets.txt
echo $'objdump.c:4241' >> $TMP_DIR/BBtargets.txt
echo $'objdump.c:2175' >> $TMP_DIR/BBtargets.txt
echo $'objdump.c:2176' >> $TMP_DIR/BBtargets.txt
echo $'objdump.c:2177' >> $TMP_DIR/BBtargets.txt
echo $'objdump.c:2178' >> $TMP_DIR/BBtargets.txt
echo $'objdump.c:2180' >> $TMP_DIR/BBtargets.txt
echo $'dwarf2.c:1432' >> $TMP_DIR/BBtargets.txt
echo $'dwarf2.c:1433' >> $TMP_DIR/BBtargets.txt
echo $'dwarf2.c:1434' >> $TMP_DIR/BBtargets.txt
echo $'dwarf2.c:1435' >> $TMP_DIR/BBtargets.txt
echo $'dwarf2.c:1436' >> $TMP_DIR/BBtargets.txt
echo $'dwarf2.c:5863' >> $TMP_DIR/BBtargets.txt
echo $'dwarf2.c:5864' >> $TMP_DIR/BBtargets.txt
echo $'dwarf2.c:5865' >> $TMP_DIR/BBtargets.txt
echo $'elf.c:1115' >> $TMP_DIR/BBtargets.txt
echo $'elf.c:1116' >> $TMP_DIR/BBtargets.txt
echo $'elf.c:1117' >> $TMP_DIR/BBtargets.txt
echo $'elf.c:9323' >> $TMP_DIR/BBtargets.txt
echo $'section.c:1367' >> $TMP_DIR/BBtargets.txt
echo $'section.c:1368' >> $TMP_DIR/BBtargets.txt
echo $'section.c:1369' >> $TMP_DIR/BBtargets.txt
echo $'section.c:1370' >> $TMP_DIR/BBtargets.txt
echo $'section.c:1559' >> $TMP_DIR/BBtargets.txt
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
cd binutils; $AFLGO/scripts/genDistance.sh $PWD $TMP_DIR objdump
# Set gllvm compilers (wrapped around aflgo compilers) to extract bitcode
export CC=gclang
export CXX=gclang++
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
# Pruning
cd binutils
mv objdump objdump-orig
get-bc -o exed.bc objdump-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o objdump-origtr.o exetrace.bc
gclang -W -Wall -Wstrict-prototypes -Wmissing-prototypes -Wshadow -Werror -I../../binutils/../zlib -fno-inline -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -distance=$TMP_DIR/distance.cfg.txt -o objdump-origtr objdump-origtr.o ../opcodes/.libs/libopcodes.a ../bfd/.libs/libbfd.a -L$HOME/Desktop/fuzz-prune/experiments/objdump/fuzz-results/aflgo-prune/objdump/obj-dist/zlib -ldl -lutil -lstdc++ -lz ../libiberty/libiberty.a
./objdump-origtr -SD ../in/in
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <exe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <marked.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f objdump objdump-exe.o
llc -filetype=obj -o objdump-exe.o pruned.bc
gclang -W -Wall -Wstrict-prototypes -Wmissing-prototypes -Wshadow -Werror -I../../binutils/../zlib -fno-inline -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error -distance=$TMP_DIR/distance.cfg.txt -o objdump objdump-exe.o ../opcodes/.libs/libopcodes.a ../bfd/.libs/libbfd.a -L$HOME/Desktop/fuzz-prune/experiments/objdump/fuzz-results/aflgo-prune/objdump/obj-dist/zlib -ldl -lutil -lstdc++ -lz ../libiberty/libiberty.a
cd ..

# Run fuzzer instances in parallel - https://github.com/aflgo/aflgo/blob/master/docs/parallel_fuzzing.txt
echo "Spawning nproc-2 instances"
# Master (-M) instance
instM="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -M fuz0 $PWD/binutils/objdump -SD @@"
$instM &
instS_num=$(($(nproc)-3))
# secondary (-S) instances
instS1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 1000 -S fuz"
instS2=" $PWD/binutils/objdump -SD @@"
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
rm -rf $pdir/objdump
