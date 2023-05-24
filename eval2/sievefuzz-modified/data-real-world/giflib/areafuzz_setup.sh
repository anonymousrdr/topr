echo "[X] Entering target's base dir: $TARGET_DIR"
cd $TARGET_DIR
echo "[X] Starting compilation"
export LDFLAGS="-lstdc++"
rm $PWD/Makefile && cp /root/areafuzz/eval/data/real-world/giflib/latest-Makefile $PWD/Makefile
export COPYCFLAGS="$CFLAGS -g -std=gnu99 -fPIC -Wall -Wno-format-truncation"
export CFLAGS="$COPYCFLAGS"
make clean
make all
cp $PWD/gifsponge $PREFIX
