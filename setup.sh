#!/bin/bash

# install dependencies
cd $HOME
sudo apt-get update
sudo apt-get install -y cmake
sudo apt-get install -y gawk
sudo apt-get install -y libtool-bin
sudo apt-get install -y autoconf
sudo apt-get install -y bison
sudo apt-get install -y flex
sudo apt-get install -y libbz2-dev
sudo apt-get install -y liblzo2-dev
sudo apt-get install -y liblz4-dev
sudo apt-get install -y texinfo
sudo apt-get install -y xmlto
sudo apt-get install -y m4
sudo apt-get install -y libcurl4-openssl-dev libxml2-dev libhdf5-dev
sudo apt-get install -y libgmp-dev libmpfr-dev

# install aflgo
cd $HOME
mkdir aflgo-top
cd aflgo-top
git clone https://github.com/aflgo/aflgo.git
cd aflgo
git checkout b170fad
cd scripts/build
rm aflgo-build.sh && cp $HOME/Desktop/fuzz-prune/aflgo-build.sh .
./aflgo-build.sh
export AFLGO="$HOME/aflgo-top/build/llvm_tools/build-llvm/msan/aflgo"

# build passes
cd $HOME/Desktop/fuzz-prune/btrace
rm -rf build && mkdir build && cd build && cmake .. && make
cd $HOME/Desktop/fuzz-prune/callog
rm -rf build && mkdir build && cd build && cmake .. && make
cd $HOME/Desktop/fuzz-prune/covm
rm -rf build && mkdir build && cd build && cmake .. && make
cd $HOME/Desktop/fuzz-prune/tse
rm -rf build && mkdir build && cd build && cmake .. && make

# install gllvm
cd $HOME
wget https://storage.googleapis.com/golang/go1.6.2.linux-amd64.tar.gz
tar -xf *tar.gz
rm *tar.gz
sudo mv go /usr/local
export PATH="/usr/local/go/bin:$PATH"
cd $HOME
cp -r $HOME/Desktop/fuzz-prune/gllvm $HOME
export GOPATH=$HOME/gllvm
export PATH=$PATH:$GOPATH/bin
export LLVM_COMPILER_PATH=$AFLGO
export LLVM_CC_NAME="afl-clang-fast"
export LLVM_CXX_NAME="afl-clang-fast++"
go get github.com/SRI-CSL/gllvm/cmd/...
ln -s $HOME/aflgo-top/build/llvm_tools/build-llvm/llvm/bin/* $AFLGO
