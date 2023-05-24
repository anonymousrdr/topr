## Running Fuzzing Campaigns from scratch

- Install docker by following instructions for Ubuntu [here](https://docs.docker.com/engine/install/ubuntu/)
- After installation, configure Docker to make it run as a non-root user using instructions [here](https://docs.docker.com/engine/install/linux-postinstall/)

### Santity Check

- Note: 4 core system is sufficient for a quick santity check to verify that the fuzzers run correctly
- System requirements: Ubuntu 20.04, 66GB Memory, Intel® Xeon(R) CPU E5-2620 @ 2.00GHz × 4
- To run the fuzzers:

```
    cd $HOME/Desktop/fuzz-prune/eval2
    mkdir fuzz-results
    cd fuzz-results
    ../run_seivefuzz_docker.sh
```

- Run the following commands inside the Docker container:

```
    beanstalkd &
    ./run_sievefuzz.sh
    exit
```

- Run the following commands after exiting the container:

```
    cd $HOME/Desktop/fuzz-prune/eval2/fuzz-results
    sudo cp -r results_raw results && sudo chmod -R 777 results
    cd $HOME/Desktop/fuzz-prune 
    ./run-fuzz.sh
```

### Complete Runs

- Note: 24 core system is required for the complete runs of fuzzers
- System requirements: Ubuntu 20.04, 66GB Memory, Intel® Xeon(R) CPU E5-2620 @ 2.00GHz × 24
- To run the fuzzers, run the above set of commands listed in [Sanity Check](https://github.com/anonymousrdr/topr/tree/main/docs#santity-check)
