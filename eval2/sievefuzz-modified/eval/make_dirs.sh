#!/bin/bash

# Creates output folders for each of the fuzz targets where the results of the fuzzing 
# campaigns will be held.

#TARGETS="SFTSCBSISS Kaprica_Script_Interpreter university_enrollment ngiflib jasper_heap_bof libming mjs_fpe tidy_heap_uaf libtiff_TIF007_magma libtiff_TIF014_magma"
# run only realworld benchmarks
TARGETS="mjs_fpe jasper libming giflib lrzip cxxfilt"

# run only sievefuzz
ROOTDIR="$1"
for bin in $TARGETS; do
    mkdir -p $ROOTDIR/$bin/F5
    #mkdir -p $ROOTDIR/$bin/aflgo
    #mkdir -p $ROOTDIR/$bin/B1
done
