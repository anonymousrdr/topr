echo "[X] Entering target's base dir: $TARGET_DIR"
cd $TARGET_DIR
echo "[X] Starting compilation"
make distclean
./autogen.sh
echo "Running command ./configure --disable-shared --prefix=$PREFIX"
./configure --disable-shared --disable-freetype --prefix=$PREFIX
make clean
make install
