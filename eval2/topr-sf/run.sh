#!/bin/bash

topdir="$HOME/Desktop/fuzz-prune/eval2/topr-sf"
artifactdir="$HOME/Desktop/fuzz-prune/topr-fuzz/topr-vs-sievefuzz"

projs="mjs_fpe jasper libming giflib lrzip cxxfilt"

for proj in $projs
do
	projdir="$topdir/$proj"
	cd $projdir
	cp $artifactdir/$proj/fuzz-results.zip $PWD
	unzip -q $PWD/fuzz-results.zip -d $PWD
	fuzzresdir="$projdir/fuzz-results"
	cd $fuzzresdir

	mv $fuzzresdir/sievefuzz $fuzzresdir/aflgo-only
	for i in `seq 0 9`;
	do
		trialdir="output_00$i"

	    $HOME/Desktop/fuzz-prune/experiments/run-aflgo-an.sh $trialdir
		sed -i "s/aflgo-only:/sievefuzz-trial$i:/g" $fuzzresdir/all-stats.txt
		echo -e >> $fuzzresdir/all-stats.txt
		if [ -f "$fuzzresdir/aflgo-only-crashinfo_unique_stack.txt" ]; then
			mv $fuzzresdir/aflgo-only-crashinfo_unique_stack.txt $fuzzresdir/sievefuzz-trial$i-crashinfo_unique_stack.txt
	     	mv $fuzzresdir/aflgo-only-crashinfo_unique_loc1.txt $fuzzresdir/sievefuzz-trial$i-crashinfo_unique_loc1.txt
	    fi

	    $HOME/Desktop/fuzz-prune/experiments/run-aflgo-prune-an.sh $trialdir
		sed -i "s/aflgo-prune:/aflgo-prune-trial$i:/g" $fuzzresdir/all-stats.txt
		echo -e >> $fuzzresdir/all-stats.txt
		if [ -f "$fuzzresdir/aflgo-prune-crashinfo_unique_stack.txt" ]; then
			mv $fuzzresdir/aflgo-prune-crashinfo_unique_stack.txt $fuzzresdir/aflgo-prune-trial$i-crashinfo_unique_stack.txt
	     	mv $fuzzresdir/aflgo-prune-crashinfo_unique_loc1.txt $fuzzresdir/aflgo-prune-trial$i-crashinfo_unique_loc1.txt
	    fi
	done
	mv $fuzzresdir/aflgo-only $fuzzresdir/sievefuzz
	python3 $HOME/Desktop/fuzz-prune/eval2/topr-sf/stats-summary-gen.py $fuzzresdir/all-stats.txt
done
