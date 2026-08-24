#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "usage: $0 BASE_IMAGE TRUSTED_IMAGE CA_FILE" >&2
  exit 2
fi

BASE_IMAGE="$1"
TRUSTED_IMAGE="$2"
CA_FILE="$3"
CONTAINER_ENGINE="${SAW_CONTAINER_ENGINE:-podman}"
BUILD_CONTEXT="${SAW_BUILD_CONTEXT:-}"
REMOVE_CONTEXT=false

if ! "$CONTAINER_ENGINE" image exists "$BASE_IMAGE"; then
  "$CONTAINER_ENGINE" pull "$BASE_IMAGE"
fi

BASE_USER="$("$CONTAINER_ENGINE" image inspect "$BASE_IMAGE" --format '{{.Config.User}}')"

if [[ -z "$BASE_USER" ]]; then
  BASE_USER=0
fi
if [[ ! "$BASE_USER" =~ ^[A-Za-z0-9_.-]+(:[A-Za-z0-9_.-]+)?$ ]]; then
  echo "base image has an unsupported runtime user value" >&2
  exit 1
fi

if [[ ! -s "$CA_FILE" ]]; then
  echo "integration CA file is missing or empty: $CA_FILE" >&2
  exit 1
fi

if [[ -z "$BUILD_CONTEXT" ]]; then
  BUILD_CONTEXT="$(mktemp -d)"
  REMOVE_CONTEXT=true
else
  mkdir -p "$BUILD_CONTEXT"
fi

cleanup() {
  if [[ "$REMOVE_CONTEXT" == true ]]; then
    rm -rf "$BUILD_CONTEXT"
  fi
}
trap cleanup EXIT

cp "$CA_FILE" "$BUILD_CONTEXT/saw-integration-ca.crt"

cat >"$BUILD_CONTEXT/Containerfile" <<EOF
FROM $BASE_IMAGE
USER 0
COPY saw-integration-ca.crt /tmp/saw-integration-ca.crt
RUN set -eu; \
    if [ -f /etc/ssl/certs/ca-certificates.crt ]; then \
      cat /tmp/saw-integration-ca.crt >> /etc/ssl/certs/ca-certificates.crt; \
    elif [ -f /etc/pki/tls/certs/ca-bundle.crt ]; then \
      cat /tmp/saw-integration-ca.crt >> /etc/pki/tls/certs/ca-bundle.crt; \
    else \
      mkdir -p /etc/ssl/certs; \
      cp /tmp/saw-integration-ca.crt /etc/ssl/certs/ca-certificates.crt; \
    fi; \
    rm -f /tmp/saw-integration-ca.crt
USER $BASE_USER
EOF

"$CONTAINER_ENGINE" build --tag "$TRUSTED_IMAGE" "$BUILD_CONTEXT"
