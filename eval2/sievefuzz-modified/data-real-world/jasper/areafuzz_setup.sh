echo "[X] Entering target's base dir: $TARGET_DIR"
cd $TARGET_DIR
make distclean
echo "[X] Starting compilation"
echo "Running command ./configure --disable-shared --prefix=$PREFIX"
./configure --disable-shared --prefix=$PREFIX
make
make install
