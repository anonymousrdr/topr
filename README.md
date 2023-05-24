# TOPr: Enhanced Static Code Pruning for Fast and Precise Directed Fuzzing


## Artifact Evaluation

- System requirements: Ubuntu 20.04, 66GB Memory
- To verify results in the paper:

```
    cd $HOME/Desktop
    git clone https://github.com/anonymousrdr/topr.git fuzz-prune
    cd fuzz-prune
    ./setup.sh
    ./artifact-eval.sh
```

- Results for TOPr vs. AFLGo evaluation are generated and stored in files named `all-stats.txt` listed below:

```
    ls $(find $HOME/Desktop/fuzz-prune/experiments -type f -name "all-stats.txt")
```

- Results  for TOPr vs. SieveFuzz evaluation are generated and stored in files named `sum-stats.txt` listed below:

```
    ls $(find $HOME/Desktop/fuzz-prune/eval2 -type f -name "sum-stats.txt")
```
