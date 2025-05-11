#!/bin/bash
set -euo pipefail
VERSION=master
#VERSION=0.1.0
ARCH=arm64
echo ${VERSION}

docker buildx build \
    --push \
    --platform linux/amd64,linux/${ARCH} \
    --tag riemerk/mr-do-upnp-c:${VERSION} \
    --tag riemerk/mr-do-upnp-c:latest \
    --file carts-api/docker/Dockerfile \
    ./carts-api


docker buildx build \
    --platform linux/arm64 \
    --tag riemerk/mr-do-upnp-c:latest .



docker buildx create --name riemerk/mr-do-upnp-c:latest --use --bootstrap


docker buildx build -t riemerk/mr-do-upnp-c --platform linux/amd64,linux/arm64 --build-arg ARCH=${ARCH} .
docker tag riemerk/mr-do-upnp-c:latest riemer/mr-do-upnp-c:${VERSION}-${ARCH}
