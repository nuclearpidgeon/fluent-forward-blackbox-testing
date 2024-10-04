#!/bin/bash

DOCKER_IMAGE_NAME=fluent/fluent-bit:latest

if ! (which json2msgpack > /dev/null); then
    echo "ERROR: required CLI tool \`json2msgpack\` not found - check out https://github.com/ludocode/msgpack-tools"
    exit 1
fi
if ! (which nc > /dev/null); then
    echo "ERROR: required CLI tool netcat (\`nc\`) not found"
    exit 1
fi
if ! (which xxd > /dev/null); then
    echo "ERROR: required CLI tool \`xxd\` not found"
    exit 1
fi

CTR_ID=$(docker run --rm --detach \
    -p 127.0.0.1:24224:24224 \
    ${DOCKER_IMAGE_NAME} \
    /opt/fluent-bit/bin/fluent-bit \
        -i forward \
        -o stdout -m '*')
echo "fluentbit container started: $CTR_ID"
docker logs "$CTR_ID"
CHUNK='p8n9gmxTQVC8/nh2wlKKeQ=='
read -p "Push any key to start netcat. You'll need to ctrl-C to quit it"
echo "[\"probetag\",[[$(date +%s), {}]],{\"chunk\":\"${CHUNK}\"}]" | json2msgpack | nc localhost 24224 | tee resp.bin | xxd
echo ""
echo "full response was:"
xxd resp.bin
read -p "Push any key to kill docker container and quit"

docker stop "$CTR_ID"