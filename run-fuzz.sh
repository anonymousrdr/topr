#!/bin/bash

export AFLGO="$HOME/aflgo-top/build/llvm_tools/build-llvm/msan/aflgo"
export PATH="/usr/local/go/bin:$PATH"
export GOPATH=$HOME/gllvm
export PATH=$PATH:$GOPATH/bin
export LLVM_COMPILER_PATH=$AFLGO
export LLVM_CC_NAME="afl-clang-fast"
export LLVM_CXX_NAME="afl-clang-fast++"

bash $HOME/Desktop/fuzz-prune/experiments/run-fuzz.sh
bash $HOME/Desktop/fuzz-prune/eval2/topr-sf/run-fuzz.sh
