#!/usr/bin/env bash
set -euo pipefail

# Install the root CA certificate into the local system trust store.
# Override defaults via environment variables, e.g.:
#   CERT_NAME=root-ca SECRET_NAME=root-ca-secret ./install-root-ca-trust-store.sh

NAMESPACE="${NAMESPACE:-kube-system}"
SECRET_NAME="${SECRET_NAME:-root-ca-secret}"
CERT_NAME="${CERT_NAME:-root-ca}"
TRUST_STORE_DIR="${TRUST_STORE_DIR:-/usr/local/share/ca-certificates}"
TRUST_STORE_FILE="${TRUST_STORE_FILE:-${CERT_NAME}.crt}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cert_path="${tmp_dir}/${CERT_NAME}.crt"
kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$cert_path"

if ! openssl x509 -in "$cert_path" -noout >/dev/null 2>&1; then
  echo "Fetched certificate is not a valid X.509 certificate" >&2
  exit 1
fi

sudo install -d -m 0755 "$TRUST_STORE_DIR"
sudo install -m 0644 "$cert_path" "${TRUST_STORE_DIR}/${TRUST_STORE_FILE}"
sudo update-ca-certificates

echo "Installed ${SECRET_NAME} from namespace ${NAMESPACE} into the system trust store."
