#!/bin/bash

# fix certificate issues in docker container during 'git clone'
git config --global http.sslverify false

# install dependencies
apt-get install -y gawk
apt-get install -y libtool-bin
apt-get install -y autoconf
apt-get install -y bison
apt-get install -y flex
apt-get install -y libbz2-dev
apt-get install -y liblzo2-dev
apt-get install -y liblz4-dev
apt-get install -y texinfo
apt-get install -y xmlto
apt-get install -y m4
apt-get install -y libcurl4-openssl-dev libxml2-dev libhdf5-dev
apt-get install -y libgmp-dev libmpfr-dev


cd /root/areafuzz/eval

projs="mjs_fpe jasper libming giflib lrzip cxxfilt"
for proj in $projs
do
	projdir="/root/areafuzz/eval/data/real-world/$proj"
	cp $PWD/reachable_functions.txt $projdir
done

# Create directories where the results will be held
./make_dirs.sh /root/areafuzz/results/exp_aflxgo_new

# get the source code of all the fuzz targets
./get_targets.sh

# Create all targets corresponding to experimental evaluation of SieveFuzz
./create_all.sh

# Flush the job queue thrice to ensure that there are no stale jobs in the queue
python3 create_fuzz_script.py -c aflxgo.config -n 2 --flush
python3 create_fuzz_script.py -c aflxgo.config -n 2 --flush
python3 create_fuzz_script.py -c aflxgo.config -n 2 --flush

# Put the jobs in the queue
python3 create_fuzz_script.py -c aflxgo.config -n 2 --put

# Get the jobs in the queue. 
# WARNING: `-n` represents the number of cores that # are available for #
# fuzzing. We recommend setting this number to roughly 95% of the available #
# cores.  So if you have 16 cores, we recommend using 15.
# Do not put `-n` greater than the number of cores that you may have available.
python3 create_fuzz_script.py -c aflxgo.config -n 2 --get
