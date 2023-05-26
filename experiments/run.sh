#!/bin/bash

topdir="$HOME/Desktop/fuzz-prune/experiments"
artifactdir="$HOME/Desktop/fuzz-prune/topr-fuzz/topr-vs-aflgo"

# aflgo repo eval verions
old_projs="cxxfilt/CVE-2016-4487 giflib/bug-74 jasper/CVE-2015-5221 libxml2/ef709ce2 lrzip/CVE-2017-8846 lrzip/CVE-2018-11496 mjs/issue-57 mjs/issue-78 objdump/CVE-2017-8392 libming/CVE-2018-8807 libming/CVE-2018-8962"
# latest versions
latest_projs="hdf5-0553fb7 netcdf-63150df lrzip/e5e9a61 giflib/adf5a1a mjs/b1b6eac jasper/402d096 libxml2/f507d167 cxxfilt/binutils-2-40 objdump/binutils-2-40"
allprojs="$latest_projs $old_projs"

for proj in $allprojs
do
	projdir="$topdir/$proj"
	cd $projdir
	cp $artifactdir/$proj/fuzz-results.zip $PWD
	unzip -q $PWD/fuzz-results.zip -d $PWD
	fuzzresdir="$projdir/fuzz-results"
	cd $fuzzresdir

	$HOME/Desktop/fuzz-prune/experiments/run-aflgo-prune-an.sh
	$HOME/Desktop/fuzz-prune/experiments/run-aflgo-an.sh
done
sed -i "/Total number of inputs = /d" $(find $HOME/Desktop/fuzz-prune -type f -name "all-stats.txt")
