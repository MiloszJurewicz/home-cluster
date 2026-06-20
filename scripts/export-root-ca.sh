#!/usr/bin/env bash
set -euo pipefail

# Export the cert-manager-issued root CA certificate so it can be imported into
# the system or browser trust store.
# Override defaults via environment variables, e.g.:
#   CERT_NAME=root-ca SECRET_NAME=root-ca-secret ./export-root-ca.sh

NAMESPACE="${NAMESPACE:-kube-system}"
SECRET_NAME="${SECRET_NAME:-root-ca-secret}"
CERT_NAME="${CERT_NAME:-root-ca}"
OUTPUT_PATH="${OUTPUT_PATH:-${CERT_NAME}.crt}"

kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" -o jsonpath='{.data.tls\.crt}' | base64 -d > "$OUTPUT_PATH"

if ! openssl x509 -in "$OUTPUT_PATH" -noout >/dev/null 2>&1; then
  echo "Exported certificate is not a valid X.509 certificate" >&2
  exit 1
fi

echo "Exported ${SECRET_NAME} from namespace ${NAMESPACE} to ${OUTPUT_PATH}."
