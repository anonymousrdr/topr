#!/bin/bash

topdir="$HOME/Desktop/fuzz-prune/experiments"

# aflgo repo eval verions
old_projs="libming/CVE-2018-8807 libming/CVE-2018-8962 cxxfilt/CVE-2016-4487 giflib/bug-74 jasper/CVE-2015-5221 libxml2/ef709ce2 lrzip/CVE-2017-8846 lrzip/CVE-2018-11496 mjs/issue-57 mjs/issue-78 objdump/CVE-2017-8392"
# latest versions
latest_projs="hdf5-0553fb7 netcdf-63150df lrzip/e5e9a61 giflib/adf5a1a mjs/b1b6eac jasper/402d096 libxml2/f507d167 cxxfilt/binutils-2-40 objdump/binutils-2-40"
allprojs="$old_projs $latest_projs"

for proj in $allprojs
do
	projdir="$topdir/$proj"
	cd $projdir
	mkdir fuzz-results2
	fuzzresdir="$projdir/fuzz-results2"
	cd $fuzzresdir

	$PWD/../aflgo-prune.sh 1h 45m
	$PWD/../aflgo.sh 1h 45m
done
