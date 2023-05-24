echo "[X] Entering target's base dir: $TARGET_DIR"
cd $TARGET_DIR
echo "[X] Starting compilation"
./autogen.sh
make distclean
echo "Running command ./configure --disable-shared --prefix=$PREFIX"
export LDFLAGS="-lpthread -lstdc++"
./configure --disable-shared --prefix=`pwd`
make clean
make all
cp $PWD/lrzip $PREFIX
