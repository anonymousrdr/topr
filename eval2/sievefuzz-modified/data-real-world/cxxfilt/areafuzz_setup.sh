echo "[X] Entering target's base dir: $TARGET_DIR"
cd $TARGET_DIR
echo "[X] Starting compilation"
echo "Running command ./configure --disable-shared --prefix=$PREFIX"
make distclean
export LDFLAGS="-ldl -lutil -lstdc++"
export COPYCFLAGS="$CFLAGS -DFORTIFY_SOURCE=2 -fstack-protector-all -fno-omit-frame-pointer -g -Wno-error"
export CFLAGS="$COPYCFLAGS"
./configure --disable-shared --disable-gdb --disable-libdecnumber --disable-readline --disable-sim --disable-ld --disable-gprofng --disable-gdbserver
make clean
make all
cp $PWD/binutils/cxxfilt $PREFIX
