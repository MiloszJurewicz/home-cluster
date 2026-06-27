#!/usr/bin/env bash
set -euo pipefail

# Generate a self-signed root CA key + certificate for use by cert-manager.
# Outputs files that the root-ca-bootstrap chart reads at deploy time.
#
# Usage:
#   ./scripts/generate-root-ca.sh           # create if missing
#   ./scripts/generate-root-ca.sh --force   # overwrite existing

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../certs"

FORCE=false
case "${1:-}" in
  --force|-f) FORCE=true ;;
  "") ;;
  *) echo "Usage: $0 [--force]" >&2; exit 1 ;;
esac

KEY_PATH="${OUTPUT_DIR}/root-ca.key"
CRT_PATH="${OUTPUT_DIR}/root-ca.crt"

if [ "$FORCE" = false ] && [ -f "$KEY_PATH" ] && [ -f "$CRT_PATH" ]; then
  echo "Root CA files already exist. Use --force to overwrite." >&2
  echo "  key:  ${KEY_PATH}" >&2
  echo "  cert: ${CRT_PATH}" >&2
  exit 0
fi

mkdir -p "$OUTPUT_DIR"

# Generate private key
openssl genrsa -out "$KEY_PATH" 4096

# Generate self-signed root CA certificate
openssl req -x509 -new -nodes \
  -key "$KEY_PATH" \
  -sha256 -days 3650 \
  -out "$CRT_PATH" \
  -subj "/C=PL/ST=Silesia/L=Warsaw/O=Quack Cluster/OU=Quackerspace/CN=Quack Cluster Root CA"

echo "Root CA generated:"
echo "  key:  ${KEY_PATH}"
echo "  cert: ${CRT_PATH}"

# Show fingerprint
openssl x509 -in "$CRT_PATH" -noout -fingerprint -sha256
