#!/usr/bin/env bash
set -euo pipefail

# Install the root CA certificate into the local system trust store and browsers.
# Reads from the local cert file (the external source of truth), not from the cluster.
#
# Override defaults via environment variables, e.g.:
#   CERT_FILE=~/my-ca.crt ./scripts/install-root-ca-trust-store.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERT_FILE="${CERT_FILE:-${SCRIPT_DIR}/../certs/root-ca.crt}"
TRUST_STORE_DIR="${TRUST_STORE_DIR:-/usr/local/share/ca-certificates}"
TRUST_STORE_FILE="${TRUST_STORE_FILE:-root-ca.crt}"

if [ ! -f "$CERT_FILE" ]; then
  echo "Root CA certificate not found at ${CERT_FILE}" >&2
  echo "Generate one with: ./scripts/generate-root-ca.sh" >&2
  exit 1
fi

if ! openssl x509 -in "$CERT_FILE" -noout >/dev/null 2>&1; then
  echo "File ${CERT_FILE} is not a valid X.509 certificate" >&2
  exit 1
fi

# System trust store
sudo install -d -m 0755 "$TRUST_STORE_DIR"
sudo install -m 0644 "$CERT_FILE" "${TRUST_STORE_DIR}/${TRUST_STORE_FILE}"
sudo update-ca-certificates

echo "Installed ${CERT_FILE} into the system trust store."

# Install into Chrome/Chromium and Firefox NSS databases
CERT_NICKNAME="${CERT_NICKNAME:-$(openssl x509 -in "$CERT_FILE" -noout -subject | sed 's/.*CN=//')}"

nss_install() {
  local nssdb="$1"
  if [ ! -f "${nssdb}/cert9.db" ]; then
    mkdir -p "$nssdb"
    certutil -d "sql:${nssdb}" -N --empty-password
  fi
  certutil -d "sql:${nssdb}" -D -n "$CERT_NICKNAME" 2>/dev/null || true
  certutil -d "sql:${nssdb}" -A -n "$CERT_NICKNAME" -t "CT,," -i "$CERT_FILE"
  echo "Installed into NSS database: ${nssdb}"
}

for nssdb in "$HOME/.pki/nssdb" "$HOME/snap/chromium/current/.pki/nssdb"; do
  [ -d "$nssdb" ] || [ "$nssdb" = "$HOME/.pki/nssdb" ] && nss_install "${nssdb}"
done

# Firefox profiles each have their own NSS database
while IFS= read -r -d '' profile_dir; do
  [ -f "${profile_dir}/cert9.db" ] && nss_install "${profile_dir}"
done < <(find "$HOME/.mozilla/firefox" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

# Configure Firefox to trust OS/system certificates via enterprise policy
FIREFOX_POLICY_DIR="${FIREFOX_POLICY_DIR:-/etc/firefox/policies}"
FIREFOX_POLICY_FILE="${FIREFOX_POLICY_DIR}/policies.json"
sudo install -d -m 0755 "$FIREFOX_POLICY_DIR"
if [ -f "$FIREFOX_POLICY_FILE" ]; then
  existing="$(sudo cat "$FIREFOX_POLICY_FILE")"
  if echo "$existing" | grep -q '"ImportEnterpriseRoots"'; then
    echo "Firefox policy already has ImportEnterpriseRoots set, skipping."
  else
    echo "Warning: ${FIREFOX_POLICY_FILE} exists but lacks ImportEnterpriseRoots. Add manually:" >&2
    echo '  "ImportEnterpriseRoots": true' >&2
  fi
else
  echo '{ "policies": { "ImportEnterpriseRoots": true } }' | sudo tee "$FIREFOX_POLICY_FILE" > /dev/null
  echo "Firefox policy installed: ${FIREFOX_POLICY_FILE}"
fi

echo ""
echo "Done. Restart Chrome and Firefox for changes to take effect."
