#!/bin/bash

if [ $1 ]; then # topr+aflgo vs. sievefuzz
	$PWD/../aflgo-replay-cov.sh $PWD/aflgo-only $1
else # topr+aflgo vs. aflgo
	$PWD/../aflgo-replay-cov.sh $PWD/aflgo-only
fi
python3 $HOME/Desktop/fuzz-prune/experiments/cov-info-parser.py $PWD/aflgo-only
rm $PWD/aflgo-only/mbbls.txt $PWD/aflgo-only/vbbls.txt
python3 $HOME/Desktop/fuzz-prune/experiments/target-info-parser.py $PWD/aflgo-only
rm $PWD/aflgo-only/targstats.txt
rm -rf $PWD/aflgo-replay

# replay only if there are inputs that reach target
if [ -f $PWD/targ-ips.txt ]; then
	if [ $1 ]; then # topr+aflgo vs. sievefuzz
		$PWD/../aflgo-replay-err.sh $PWD/aflgo-only $1
	else # topr+aflgo vs. aflgo
		$PWD/../aflgo-replay-cov.sh $PWD/aflgo-only
	fi
	python3 $HOME/Desktop/fuzz-prune/experiments/err-info-parser.py $PWD/aflgo-only/targstats.txt
	rm $PWD/aflgo-only/targstats.txt
	rm $PWD/targ-ips.txt
	rm -rf $PWD/aflgo-replay
fi

if [ $1 ]; then # topr+aflgo vs. sievefuzz
	python3 $HOME/Desktop/fuzz-prune/experiments/std-metrics-parser.py $PWD/aflgo-only $1
else # topr+aflgo vs. aflgo
	python3 $HOME/Desktop/fuzz-prune/experiments/std-metrics-parser.py $PWD/aflgo-only
fi
