#!/bin/bash

topdir="$HOME/Desktop/fuzz-prune/eval2/topr-sf"
sfresdir="$HOME/Desktop/fuzz-prune/eval2/fuzz-results/results/exp_aflxgo_new"

projs="mjs_fpe jasper libming giflib lrzip cxxfilt"

for proj in $projs
do
	projdir="$topdir/$proj"
	cd $projdir
	mkdir fuzz-results2
	fuzzresdir="$projdir/fuzz-results2"
	cd $fuzzresdir

	mkdir sievefuzz && mv "$sfresdir/$proj/F5" $PWD/sievefuzz/out
	$PWD/../aflgo-prune.sh 1h 45m
done
