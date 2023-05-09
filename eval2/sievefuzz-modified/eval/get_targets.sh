#!/bin/bash

# This downloads the various real-world target repositiories

TARGET_DIR="/root/areafuzz/benchmarks"

# # Get MJS
# if [ ! -d $TARGET_DIR/mjs_fpe ]; then
#     cd "$TARGET_DIR/../eval/data/real-world/mjs_fpe"
#     mkdir $TARGET_DIR/mjs_fpe
#     tar -xf 1.20.1.tar.gz --strip-components=1 -C $TARGET_DIR/mjs_fpe
# fi

# Get MJS
if [ ! -d $TARGET_DIR/mjs_fpe ]; then
    cd $TARGET_DIR
    git clone https://github.com/cesanta/mjs.git mjs_fpe
    cd mjs_fpe
    git checkout 2827bd0
fi

# Get jasper
if [ ! -d $TARGET_DIR/jasper ]; then
    cd $TARGET_DIR
    git clone https://github.com/mdadams/jasper.git jasper
    cd jasper
    git checkout 142245b
fi

# Get libming
if [ ! -d $TARGET_DIR/libming ]; then
    cd $TARGET_DIR
    git clone https://github.com/libming/libming.git libming
    cd libming
    git checkout b72cc2f
fi

# Get giflib 
if [ ! -d $TARGET_DIR/giflib ]; then
    cd $TARGET_DIR
    git clone https://git.code.sf.net/p/giflib/code giflib
    cd giflib
    git checkout adf5a1a
fi

# Get lrzip 
if [ ! -d $TARGET_DIR/lrzip ]; then
    cd $TARGET_DIR
    git clone https://github.com/ckolivas/lrzip.git lrzip
    cd lrzip
    git checkout ed51e14
fi

# Get cxxfilt 
if [ ! -d $TARGET_DIR/cxxfilt ]; then
    cd $TARGET_DIR
    git clone git://sourceware.org/git/binutils-gdb.git cxxfilt
    cd cxxfilt
    git checkout 2c49145
fi
