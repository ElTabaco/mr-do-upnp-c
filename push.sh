#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Build + push multi-arch images via docker buildx.
#  Expects DOCKER_USERNAME / DOCKER_PASSWORD env vars (or token).
# ═══════════════════════════════════════════════════════════
set -euo pipefail

VERSION="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null | sed 's/^v//' | cut -d- -f1)}"
[ -z "$VERSION" ] && VERSION="0.0.0-dev"
IMAGE="riemerk/mr-do-upnp-c"
CONTEXT="$(cd "$(dirname "$0")" && pwd)"

echo "Building + pushing ${IMAGE}:${VERSION} (multi-arch)"

# Ensure buildx builder exists
if ! docker buildx inspect mr-do-builder >/dev/null 2>&1; then
    docker buildx create --name mr-do-builder --use --bootstrap
else
    docker buildx use mr-do-builder
fi

docker buildx build \
    --push \
    --platform linux/amd64,linux/arm64/v8 \
    --file "${CONTEXT}/docker/Dockerfile" \
    --tag "${IMAGE}:${VERSION}" \
    --tag "${IMAGE}:latest" \
    "${CONTEXT}"

echo ""
echo "Pushed: ${IMAGE}:${VERSION} and ${IMAGE}:latest"
echo "https://hub.docker.com/r/${IMAGE}/tags"
