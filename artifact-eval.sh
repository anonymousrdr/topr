#!/bin/bash

export AFLGO="$HOME/aflgo-top/build/llvm_tools/build-llvm/msan/aflgo"
export PATH="/usr/local/go/bin:$PATH"
export GOPATH=$HOME/gllvm
export PATH=$PATH:$GOPATH/bin
export LLVM_COMPILER_PATH=$AFLGO
export LLVM_CC_NAME="afl-clang-fast"
export LLVM_CXX_NAME="afl-clang-fast++"

cd $HOME/Desktop/fuzz-prune
wget https://zenodo.org/record/7909114/files/topr-fuzz.zip?download=1
mv topr-fuzz.zip?download=1 topr-fuzz.zip
unzip -q $PWD/topr-fuzz.zip -d $PWD

bash $HOME/Desktop/fuzz-prune/experiments/run.sh
bash $HOME/Desktop/fuzz-prune/eval2/topr-sf/run.sh
