#!/bin/bash

# run only sievefuzz
#MODES="bitcode aflxx aflgo areafuzz"
#SYNTHETIC_TARGETS="Kaprica_Script_Interpreter SFTSCBSISS university_enrollment"
MODES="bitcode areafuzz"
# run only realworld benchmarks
REALWORLD_TARGETS="mjs_fpe jasper libming giflib lrzip cxxfilt"

for mode in $MODES; do
	# for target in $SYNTHETIC_TARGETS; do
    #             CMD="./prep_cgc_target.sh $target $mode"
	# 	$CMD
	# done
	for target in $REALWORLD_TARGETS; do
                CMD="./prep_real_world.sh $target $mode"
		$CMD
	done
done
