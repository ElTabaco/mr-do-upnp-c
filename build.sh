#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  Build mr-do-upnp-c locally (single-arch, for testing).
#  Multi-arch CI builds run in GitHub Actions (see .github/workflows/).
# ═══════════════════════════════════════════════════════════
set -euo pipefail

VERSION="${VERSION:-0.1.0}"
IMAGE="riemerk/mr-do-upnp-c"
CONTEXT="$(cd "$(dirname "$0")" && pwd)"

echo "Building ${IMAGE}:${VERSION} (local, native arch)"

docker build \
    --file "${CONTEXT}/docker/Dockerfile" \
    --tag "${IMAGE}:${VERSION}" \
    --tag "${IMAGE}:latest" \
    "${CONTEXT}"

echo ""
echo "Done. Image size:"
docker images "${IMAGE}:${VERSION}" --format "{{.Repository}}:{{.Tag}}  {{.Size}}"
