#!/bin/bash

# Setup parent dir
rm -rf aflgo-prune
mkdir aflgo-prune
cd aflgo-prune
export pdir=$PWD

# Clone subject repository
git clone https://gitlab.gnome.org/GNOME/libxml2 libxml2
export SUBJECT=$PWD/libxml2

# Setup directory containing all temporary files
mkdir temp
export TMP_DIR=$PWD/temp

# Generate BBtargets from commit
pushd $SUBJECT
  git checkout ef709ce2
popd

# Integrate custom pruner functions, edit targets accordingly
rm $SUBJECT/valid.c && cp $PWD/../../pruner-valid.c $SUBJECT/valid.c
echo $'valid.c:183' > $TMP_DIR/BBtargets.txt
echo $'valid.c:184' >> $TMP_DIR/BBtargets.txt
echo $'valid.c:185' >> $TMP_DIR/BBtargets.txt
echo $'valid.c:186' >> $TMP_DIR/BBtargets.txt
echo $'valid.c:187' >> $TMP_DIR/BBtargets.txt
echo $'valid.c:188' >> $TMP_DIR/BBtargets.txt

# Print targets. 
echo "Targets:"
cat $TMP_DIR/BBtargets.txt

# Set aflgo-instrumenter
export CC=$AFLGO/afl-clang-fast
export CXX=$AFLGO/afl-clang-fast++
export LDFLAGS="-lpthread -lstdc++"

# Set aflgo-instrumentation flags
export COPY_CFLAGS=$CFLAGS
export COPY_CXXFLAGS=$CXXFLAGS
export ADDITIONAL="-fno-inline -targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
export CFLAGS="$CFLAGS $ADDITIONAL"
export CXXFLAGS="$CXXFLAGS $ADDITIONAL"

# Build (in order to generate CG and CFGs).
# Meanwhile go have a coffee ☕️
pushd $SUBJECT
  ./autogen.sh
  ./configure --disable-shared
  make clean
  make xmllint
popd
# * If the linker (CCLD) complains that you should run ranlib, make
#   sure that libLTO.so and LLVMgold.so (from building LLVM with Gold)
#   can be found in /usr/lib/bfd-plugins
# * If the compiler crashes, there is some problem with LLVM not 
#   supporting our instrumentation (afl-llvm-pass.so.cc:540-577).
#   LLVM has changed the instrumentation-API very often :(
#   -> Check LLVM-version, fix problem, and prepare pull request.
# * You can speed up the compilation with a parallel build. However,
#   this may impact which BBs are identified as targets. 
#   See https://github.com/aflgo/aflgo/issues/41.


# Test whether CG/CFG extraction was successful
$SUBJECT/xmllint --valid --recover $SUBJECT/test/dtd3
ls $TMP_DIR/dot-files
echo "Function targets"
cat $TMP_DIR/Ftargets.txt

# Clean up
cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt

# Generate distance ☕️
# $AFLGO/scripts/genDistance.sh is the original, but significantly slower, version
$AFLGO/scripts/genDistance.sh $SUBJECT $TMP_DIR xmllint

# Check distance file
echo "Distance values:"
head -n5 $TMP_DIR/distance.cfg.txt
echo "..."
tail -n5 $TMP_DIR/distance.cfg.txt

# Set gllvm compilers (wrapped around aflgo compilers) to extract bitcode
export CC=gclang
export CXX=gclang++

export CFLAGS="$COPY_CFLAGS -fno-inline -distance=$TMP_DIR/distance.cfg.txt"
export CXXFLAGS="$COPY_CXXFLAGS -fno-inline -distance=$TMP_DIR/distance.cfg.txt"

# Clean and build subject with distance instrumentation ☕️
pushd $SUBJECT
  make clean
  ./configure --disable-shared
  make xmllint
popd

# Construct seed corpus
mkdir in
cp -r $SUBJECT/test/dtd* in
cp $SUBJECT/test/dtds/* in

# Pruning
pushd $SUBJECT
mv xmllint xmllint-orig
get-bc -o exed.bc xmllint-orig
opt -strip-debug <exed.bc>exe.bc
clang -c -emit-llvm $HOME/Desktop/fuzz-prune/callog/logcall.c
llvm-link -o exel.bc exe.bc logcall.bc
opt -load $HOME/Desktop/fuzz-prune/callog/build/proj/libdtrace.so -dtrace <exel.bc>exetrace.bc
llc -filetype=obj -o xmllint-origtr.o exetrace.bc
gclang -D_REENTRANT -distance=$TMP_DIR/distance.cfg.txt -pedantic -W -Wformat -Wunused -Wimplicit -Wreturn-type -Wswitch -Wcomment -Wtrigraphs -Wformat -Wchar-subscripts -Wuninitialized -Wparentheses -Wshadow -Wpointer-arith -Wcast-align -Wwrite-strings -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wnested-externs -Winline -Wredundant-decls -Wno-long-long -o xmllint-origtr xmllint-origtr.o ./.libs/libxml2.a -ldl -lpthread -lstdc++ -lz -lm
./xmllint-origtr --valid --recover ../in/dtd1
python3 $HOME/Desktop/fuzz-prune/experiments/get-init-fns.py
opt -load $HOME/Desktop/fuzz-prune/btrace/build/proj/libbtrace.so -btrace <exe.bc>marked.bc
opt -load $HOME/Desktop/fuzz-prune/tse/build/proj/libtse.so -tse <marked.bc>pruned.bc
# Generate exe from pruned bitcode
rm -f xmllint xmllint-exe.o
llc -filetype=obj -o xmllint-exe.o pruned.bc
gclang -D_REENTRANT -distance=$TMP_DIR/distance.cfg.txt -pedantic -W -Wformat -Wunused -Wimplicit -Wreturn-type -Wswitch -Wcomment -Wtrigraphs -Wformat -Wchar-subscripts -Wuninitialized -Wparentheses -Wshadow -Wpointer-arith -Wcast-align -Wwrite-strings -Waggregate-return -Wstrict-prototypes -Wmissing-prototypes -Wnested-externs -Winline -Wredundant-decls -Wno-long-long -o xmllint xmllint-exe.o ./.libs/libxml2.a -ldl -lpthread -lstdc++ -lz -lm
popd

# Run fuzzer instances in parallel - https://github.com/aflgo/aflgo/blob/master/docs/parallel_fuzzing.txt
echo "Spawning nproc-2 instances"
# Master (-M) instance
instM="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 5000 -M fuz0 $SUBJECT/xmllint --valid --recover @@"
$instM &
instS_num=$(($(nproc)-3))
# secondary (-S) instances
instS1="timeout $1 $AFLGO/afl-fuzz -m none -z exp -c $2 -i in -o out -t 5000 -S fuz"
instS2=" $SUBJECT/xmllint --valid --recover @@"
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
rm -rf $SUBJECT
rm -rf $pdir/temp 
rm -rf $pdir/in