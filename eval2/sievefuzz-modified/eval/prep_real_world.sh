#!/bin/bash

#########################################################################################
# This script allows for creating all variants for evaluation given name of a CGC binary
#########################################################################################

if [ ! "$#" -eq 2 ]; then
  echo "Usage: $0 <target_folder> <mode> [bitcode, areafuzz_noopt, areafuzz_opt, aflgo, baseline_aflxx]"
  exit 1
fi

TARGET="$1"
MODE="$2"
ROOT="/root/areafuzz/third_party"
AFL_AF="$ROOT/AFL_AF" # AFL with areafuzz specific modifications
AFL_O="$ROOT/AFL_O" # Vanilla AFL with no modifications
AFL_TRACE="$ROOT/AFL_TRACE" # Vanilla AFL with no modifications
AFLGO="$HOME/aflgo" # Location of aflgo base repo 

# Export this variable because we use this variable in build scripts
export TARGET_DIR="/root/areafuzz/benchmarks/$TARGET"
OUTDIR="/root/areafuzz/benchmarks/out_$TARGET"
DATA="/root/areafuzz/eval/data/real-world/$TARGET" # Auxiliary data used required for building binaries for F2 and F3
export DATA=$DATA

AF_LLVM_ROOT="$ROOT/SVF/llvm-10.0.0.obj"
AF_CLANG="$AF_LLVM_ROOT/bin/clang"
AF_CLANGXX="$AF_LLVM_ROOT/bin/clang++"
AF_LLVMCONFIG="$AF_LLVM_ROOT/bin/llvm-config"
AF_AR="$AF_LLVM_ROOT/bin/llvm-ar"
AF_LLVMLINK="$AF_LLVM_ROOT/bin/llvm-link"
AFLGO_CLANG="clang" # Specify the clang compiler
AFLGO_CLANGXX="clang++" # Specify the clang compiler
AFLGO_LLVMCONFIG="llvm-config" # Specify the clang compiler
GCLANG="$ROOT/SVF/Release-build/bin/gclang"
GCLANGXX="$ROOT/SVF/Release-build/bin/gclang++"
GETBC="$ROOT/SVF/Release-build/bin/get-bc"

# Create key-value pairs for final fuzz target names for creating bitcode 
declare -A locs
locs["giflib"]="gifsponge"
locs["lrzip"]="lrzip"
locs["cxxfilt"]="cxxfilt"
locs["mjs_fpe"]="mjs-bin"
locs["jasper"]="bin/jasper"
locs["libming"]="bin/swftophp"

build_target() {
# Trigger script to generate aflgo-asan variant for fuzzing
if [ "$MODE" = "aflgo" -a "$1" = "asan" ]; then
echo "[X] Creating aflgo-asan variant"
/bin/bash $DATA/aflgo_asan.sh
# Trigger script to generate aflgo-distance variant for distance calculation
elif [ "$MODE" = "aflgo" -a "$1" = "distance" ]; then
echo "[X] Creating aflgo-distance variant"
/bin/bash $DATA/aflgo_distance.sh
else 
echo "[X] Creating areafuzz/baseline variant"
/bin/bash $DATA/areafuzz_setup.sh
fi
cd -
}

# Bitcode of target for the purpose of static analysis
make_bitcode() {
    # Sets up the Gclang to use clang-9.0 as the compiler
    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=$HOME/areafuzz/third_party/SVF/Release-build

    export SVFHOME=$HOME/areafuzz/third_party/SVF
    export LLVM_DIR=$SVFHOME/llvm-10.0.0.obj
    export PATH=$LLVM_DIR/bin:$PATH

    export CC=$GCLANG
    export CXX=$GCLANGXX
    export CFLAGS="-g" 
    export LLVM_CONFIG=$AF_LLVMCONFIG
    export PREFIX=$OUTDIR/BITCODE

    clean_counters
    build_target
     
    # Create bitcode
    cd $OUTDIR/BITCODE
    echo ${locs[${TARGET}]}
    echo $PWD
    echo "$GETBC -a $AF_AR -l $AF_LLVMLINK ${locs[${TARGET}]}"
    $GETBC -a $AF_AR -l $AF_LLVMLINK ${locs[${TARGET}]}
    cd -
}

make_bitcode_beacon() {
    # Sets up the Gclang to use clang-9.0 as the compiler
    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=$HOME/areafuzz/third_party/SVF/Release-build

    export CC=$GCLANG
    export CXX=$GCLANGXX
    export CFLAGS="-g" 
    # export LLVM_CONFIG=$AF_LLVMCONFIG
    export PREFIX=$OUTDIR/BITCODE_BEACON

    clean_counters
    build_target
     
    # Create bitcode
    cd $OUTDIR/BITCODE_BEACON
    echo ${locs[${TARGET}]}
    echo $PWD
    echo "$GETBC ${locs[${TARGET}]}"
    $GETBC ${locs[${TARGET}]}
    cd -
}


# Create target with native AFL instrumentation
make_aflxx() {
    # Setup environment variables
    export CC=$AFL_O/afl-clang-fast
    export CXX=$AFL_O/afl-clang-fast++
    export LLVM_CONFIG=$AF_LLVMCONFIG
    export AFL_CC=$AF_CLANG
    export AFL_CXX=$AF_CLANGXX
    export AFL_USE_ASAN=1
    export PREFIX=$OUTDIR/B1
    export ASAN_OPTIONS=detect_leaks=0

    build_target

}

make_areafuzz_noasan() {
    # Setup environment variables
    export CC=$AFL_AF/afl-clang-fast
    export CXX=$AFL_AF/afl-clang-fast++
    export LLVM_CONFIG=$AF_LLVMCONFIG
    export AFL_CC=$AF_CLANG
    export AFL_CXX=$AF_CLANGXX
    # export AFL_USE_ASAN=1
    export PREFIX=$OUTDIR/F5_noasan
    # export ASAN_OPTIONS=detect_leaks=0

    clean_counters
    build_target

    # Copy over the function indices list
    cp /tmp/fn_indices.txt $OUTDIR/F5_noasan/fn_indices.txt
    cd -
    echo "Please check that the two numbers are within delta of 1" 
    cat /tmp/fn_indices.txt | wc -l && tail -n1 /tmp/fn_indices.txt
}

# Variant with function activation policy inferred through static analysis
make_areafuzz() {
    # Setup environment variables
    export CC=$AFL_AF/afl-clang-fast
    export CXX=$AFL_AF/afl-clang-fast++
    export LLVM_CONFIG=$AF_LLVMCONFIG
    export AFL_CC=$AF_CLANG
    export AFL_CXX=$AF_CLANGXX
    export AFL_USE_ASAN=1
    export PREFIX=$OUTDIR/F5
    export ASAN_OPTIONS=detect_leaks=0

    clean_counters
    build_target

    # Copy over the function indices list
    cp /tmp/fn_indices.txt $OUTDIR/F5/fn_indices.txt
    cd -
    echo "Please check that the two numbers are within delta of 1" 
    cat /tmp/fn_indices.txt | wc -l && tail -n1 /tmp/fn_indices.txt
}

make_beacon() { 
    # XXX:Trying to build asan-instrumented binary errors out
    # XXX:Does not support multi-target specification

    # Setup env variables
    if [ "$TARGET" = "libming" ]; then
        BITCODE_FILE=/root/areafuzz/benchmarks/out_libming/BITCODE_BEACON/bin/swftophp.bc
        BBREACHES_FILENAME="bbreaches__root_areafuzz_eval_data_real-world_libming_aflgo_targets.txt"
        TARGET_FILE=$DATA/aflgo_targets.txt
        BIN_NAME=swftophp

    elif [ "$TARGET" = "jasper" ]; then
        BITCODE_FILE=/root/areafuzz/benchmarks/out_jasper/BITCODE_BEACON/bin/jasper.bc
        BBREACHES_FILENAME="bbreaches__root_areafuzz_eval_data_real-world_jasper_aflgo_targets.txt"
        TARGET_FILE=$DATA/aflgo_targets.txt
        BIN_NAME=jasper

    elif [ "$TARGET" = "giflib" ]; then
        BITCODE_FILE=/root/areafuzz/benchmarks/out_giflib/BITCODE_BEACON/gifsponge.bc
        BBREACHES_FILENAME="bbreaches__root_areafuzz_eval_data_real-world_giflib_beacon_target.txt"
        TARGET_FILE=$DATA/beacon_target.txt
        BIN_NAME=gifsponge

    fi

    cd $OUTDIR/BEACON
    echo "[X] Inferring preconditions"
    echo "/Beacon/precondInfer $BITCODE_FILE --target-file=$TARGET_FILE --join-bound=5 >precond_log 2>&1"
    /Beacon/precondInfer $BITCODE_FILE --target-file=$TARGET_FILE --join-bound=5 >precond_log 2>&1
    echo "[X] Creating instrumented binary"
    echo "/Beacon/Ins -output=$OUTDIR/BEACON/$TARGET.bc -blocks=$OUTDIR/BEACON/$BBREACHES_FILENAME -afl -log=log.txt -load=$OUTDIR/BEACON/range_res.txt $OUTDIR/BEACON/transed.bc"
    /Beacon/Ins -output=$OUTDIR/BEACON/$TARGET.bc -blocks=$OUTDIR/BEACON/$BBREACHES_FILENAME -afl -log=log.txt -load=$OUTDIR/BEACON/range_res.txt $OUTDIR/BEACON/transed.bc
    clang $OUTDIR/BEACON/$TARGET.bc -o $OUTDIR/BEACON/$BIN_NAME -lm -lz /Beacon/Test/afl-llvm-rt.o

}

# AFLGo variant 
make_aflgo() {
    # Check if this is being run in the shell with static analysis component (clang-9.0)
    which gclang
    if [ $? -eq 0 ]; then
        echo "Please do not run in the static analysis initialized shell (using the command source ./build.sh). This has 'clang' initialized with
              clang-9.0 and not clang-4.0"
    exit 1
    fi

    # Create directory to hold aflgo-specific metadata
    mkdir -p $OUTDIR/aflgo/obj-aflgo/temp

    # Setup env variables
    export DATA=$DATA 
    export SUBJECT=$TARGET_DIR
    export FUZZTARGET=`cat $DATA/aflgo_fuzztarget.txt`
    export TMP_DIR=$OUTDIR/aflgo/obj-aflgo/temp
    export AFL_CC=$AFLGO_CLANG
    export AFL_CXX=$AFLGO_CLANGXX
    export LLVM_CONFIG=$AFLGO_LLVMCONFIG
    export CC=$AFLGO/afl-clang-fast
    export CXX=$AFLGO/afl-clang-fast++
    export LDFLAGS=-lpthread
    export ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
    export CFLAGS="$ADDITIONAL"
    export CXXFLAGS="$ADDITIONAL"
    # Setup destination dirs for both variants
    export DISTVARIANT=$OUTDIR/aflgo/obj-aflgo
    export FUZZVARIANT=$OUTDIR/aflgo/obj-fuzz

    # Removing stale build directories if they exist and recreating them
    rm -rf $DISTVARIANT && mkdir -p $DISTVARIANT/temp
    rm -rf $FUZZVARIANT && mkdir -p $FUZZVARIANT

    # Setup target location(s) for directed fuzzing
    cp $DATA/aflgo_targets.txt $TMP_DIR/BBtargets.txt

    # Compute distances with non-ASAN version 
    build_target "distance"
    
    start=`date +%s`
    cat $TMP_DIR/BBnames.txt | rev | cut -d: -f2- | rev | sort | uniq > $TMP_DIR/BBnames2.txt && mv $TMP_DIR/BBnames2.txt $TMP_DIR/BBnames.txt
    cat $TMP_DIR/BBcalls.txt | sort | uniq > $TMP_DIR/BBcalls2.txt && mv $TMP_DIR/BBcalls2.txt $TMP_DIR/BBcalls.txt
    echo "Running $AFLGO/scripts/genDistance.sh $DISTVARIANT $TMP_DIR $FUZZTARGET"
    $AFLGO/scripts/genDistance.sh $DISTVARIANT $TMP_DIR $FUZZTARGET
    end=`date +%s`
    runtime=$((end-start))
    echo $runtime > $DISTVARIANT/timetaken.txt

    # Create ASAN-version with calculated distances
    export AFL_USE_ASAN=1
    export ASAN_OPTIONS=detect_leaks=0
    export CFLAGS="-g -distance=$TMP_DIR/distance.cfg.txt"
    export CXXFLAGS="-g -distance=$TMP_DIR/distance.cfg.txt"
    build_target "asan"

}

clean_counters() {
    rm -f /tmp/fn_indices.txt
    rm -f /tmp/fn_counter.txt
}

# Script is being run to generate baseline afl variant
if [ "$MODE" = "aflxx" ]; then
    echo "[X] Generating baseline_aflxx variant of target"
    rm -rf $OUTDIR/B1
    mkdir -p $OUTDIR/B1
    make_aflxx
    exit 0
fi


# Script is being run to generate areafuzz-opt variant
if [ "$MODE" = "areafuzz" ]; then
    echo "[X] Generating areafuzz-opt variant of target"
    rm -rf $OUTDIR/F5
    mkdir -p $OUTDIR/F5
    make_areafuzz
    exit 0
fi

if [ "$MODE" = "areafuzz_noasan" ]; then
    echo "[X] Generating areafuzz-opt variant of target with noasan"
    rm -rf $OUTDIR/F5_noasan
    mkdir -p $OUTDIR/F5_noasan
    make_areafuzz_noasan
    exit 0
fi

# Generate bitcode file for static analysis
if [ "$MODE" = "bitcode" ]; then
    echo "[X] Generating bitcode for target"
    rm -rf $OUTDIR/BITCODE
    mkdir -p $OUTDIR/BITCODE
    make_bitcode
    exit 0
fi

# Script is being run to generate aflgo variant
if [ "$MODE" = "aflgo" ]; then
    echo "[X] Generating aflgo variant of target"
    rm -rf $OUTDIR/aflgo
    mkdir -p $OUTDIR/aflgo
    make_aflgo
    exit 0
fi

if [ "$MODE" = "beacon" ]; then
    echo "[X] Running script to create beacon-compatible bitcode"
    rm -rf $OUTDIR/BITCODE_BEACON
    mkdir -p $OUTDIR/BITCODE_BEACON
    make_bitcode_beacon

    echo "[X] Running script to create beacon-instrumented binary"
    rm -rf $OUTDIR/BEACON
    mkdir -p $OUTDIR/BEACON
    make_beacon
    exit 0
fi
