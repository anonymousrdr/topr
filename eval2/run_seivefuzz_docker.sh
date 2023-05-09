#!/bin/bash

docker kill $(docker ps -aq)
docker rm $(docker ps -aq)
docker pull prashast94/sievefuzz:artifact
docker run -d --name="sievefuzz_artifact" -it -v $PWD/results_raw:/root/areafuzz/results --network='host' --cap-add=SYS_PTRACE prashast94/sievefuzz:artifact /bin/bash

#copy my modified scripts from host to container
docker cp $PWD/../sievefuzz-modified/eval/. sievefuzz_artifact:/root/areafuzz/eval
docker cp $PWD/../sievefuzz-modified/run_sievefuzz.sh sievefuzz_artifact:/root/areafuzz


# run sievefuzz on new/modified benchmarks

docker exec -it sievefuzz_artifact rm -rf /root/areafuzz/eval/data/real-world/jasper_heap_bof
docker cp $PWD/../sievefuzz-modified/data-real-world/jasper sievefuzz_artifact:/root/areafuzz/eval/data/real-world
docker exec -it sievefuzz_artifact mkdir /root/areafuzz/eval/data/seeds/jasper
docker exec -it sievefuzz_artifact mv /root/areafuzz/eval/data/real-world/jasper/in.jp2 /root/areafuzz/eval/data/seeds/jasper

docker exec -it sievefuzz_artifact rm -rf /root/areafuzz/eval/data/real-world/libming
docker cp $PWD/../sievefuzz-modified/data-real-world/libming sievefuzz_artifact:/root/areafuzz/eval/data/real-world
docker exec -it sievefuzz_artifact mkdir /root/areafuzz/eval/data/seeds/libming
docker exec -it sievefuzz_artifact mv /root/areafuzz/eval/data/real-world/libming/in.swf /root/areafuzz/eval/data/seeds/libming

docker exec -it sievefuzz_artifact rm -rf /root/areafuzz/eval/data/real-world/ngiflib
docker cp $PWD/../sievefuzz-modified/data-real-world/giflib sievefuzz_artifact:/root/areafuzz/eval/data/real-world
docker exec -it sievefuzz_artifact mkdir /root/areafuzz/eval/data/seeds/giflib
docker exec -it sievefuzz_artifact mv /root/areafuzz/eval/data/real-world/giflib/in /root/areafuzz/eval/data/seeds/giflib

docker cp $PWD/../sievefuzz-modified/data-real-world/lrzip sievefuzz_artifact:/root/areafuzz/eval/data/real-world
docker exec -it sievefuzz_artifact mkdir /root/areafuzz/eval/data/seeds/lrzip
docker exec -it sievefuzz_artifact mv /root/areafuzz/eval/data/real-world/lrzip/in.lrz /root/areafuzz/eval/data/seeds/lrzip

docker cp $PWD/../sievefuzz-modified/data-real-world/cxxfilt sievefuzz_artifact:/root/areafuzz/eval/data/real-world
docker exec -it sievefuzz_artifact mkdir /root/areafuzz/eval/data/seeds/cxxfilt
docker exec -it sievefuzz_artifact mv /root/areafuzz/eval/data/real-world/cxxfilt/in /root/areafuzz/eval/data/seeds/cxxfilt

# run sievefuzz with my modifications
docker exec -it sievefuzz_artifact /bin/bash
