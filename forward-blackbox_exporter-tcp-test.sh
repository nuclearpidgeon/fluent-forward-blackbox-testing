#!/bin/bash

DOCKER_IMAGE_NAME=fluent/fluent-bit:latest

if ! (which curl > /dev/null); then
    echo "ERROR: required CLI tool \`curl\` not found"
    exit 1
fi
if ! (which jq > /dev/null); then
    echo "ERROR: required CLI tool \`jq\` not found - see https://jqlang.github.io/jq/"
    exit 1
fi

FB_CTR_ID=$(docker run --rm --detach \
    -p 127.0.0.1:24224:24224 \
    ${DOCKER_IMAGE_NAME} \
    /opt/fluent-bit/bin/fluent-bit \
        -i forward \
        -o stdout -m '*')
echo "fluentbit container started: $FB_CTR_ID"
docker logs "$FB_CTR_ID"

BB_CTR_ID=$(docker run --rm --detach \
  -p 127.0.0.1:9115:9115/tcp \
  --name blackbox_exporter \
  -v $(pwd):/config \
  quay.io/prometheus/blackbox-exporter:latest --config.file=/config/tcp-forward-probe.yml)
echo "blackbox_exporter container started: $BB_CTR_ID"
docker logs "$BB_CTR_ID"

FB_IP_ADDR=$(docker inspect "${FB_CTR_ID}" | jq -r '.[0].NetworkSettings.IPAddress')
read -p "Push any key to start probe (to IP address ${FB_IP_ADDR})"
curl -v "http://localhost:9115/probe?target=${FB_IP_ADDR}%3A24224&module=fluent_forward_ackcheck&debug=true"
echo ""
echo "bb_probe logs again:"
docker logs "$BB_CTR_ID"
read -p "Push any key to kill docker containers and quit"

docker stop "$FB_CTR_ID" "$BB_CTR_ID"