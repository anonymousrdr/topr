# TOPr: Enhanced Static Code Pruning for Fast and Precise Directed Fuzzing


## Artifact Evaluation

- System requirements: Ubuntu 20.04 Desktop, 66GB Memory, Intel® Xeon(R) CPU E5-2620 @ 2.00GHz × 24
- To verify results in the paper, run the commands below
- NOTE: The segmentation faults and other errors displayed on the terminal during the below runs are NOT errors in the scripts of TOPr framework but are bugs detected by the fuzzers and reported in the paper
- Estimated time for the below runs to complete is approximately upto 26 days of CPU time

```
    mkdir -p $HOME/Desktop
    cd $HOME/Desktop
    git clone https://github.com/anonymousrdr/topr.git fuzz-prune
    cd fuzz-prune
    ./setup.sh
    ./artifact-eval.sh
```

- Results for TOPr vs. AFLGo evaluation are generated and stored in files named `all-stats.txt` listed below:

```
    find $HOME/Desktop/fuzz-prune/experiments -type f -name "all-stats.txt"
```

- Results  for TOPr vs. SieveFuzz evaluation are generated and stored in files named `sum-stats.txt` listed below:

```
    find $HOME/Desktop/fuzz-prune/eval2 -type f -name "sum-stats.txt"
```
