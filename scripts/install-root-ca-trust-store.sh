#!/usr/bin/env bash
set -euo pipefail

# Install the root CA certificate into the local system trust store.
# Override defaults via environment variables, e.g.:
#   CERT_NAME=root-ca SECRET_NAME=root-ca-secret ./install-root-ca-trust-store.sh

NAMESPACE="${NAMESPACE:-cert-manager}"
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

# Install into Chrome/Chromium and Firefox NSS databases
CERT_NICKNAME="${CERT_NICKNAME:-$(openssl x509 -in "$cert_path" -noout -subject | sed 's/.*CN=//')}"

nss_install() {
  local nssdb="$1"
  # Initialize the DB if it doesn't exist yet (Chrome creates it lazily)
  if [ ! -f "${nssdb}/cert9.db" ]; then
    mkdir -p "$nssdb"
    certutil -d "sql:${nssdb}" -N --empty-password
  fi
  certutil -d "sql:${nssdb}" -D -n "$CERT_NICKNAME" 2>/dev/null || true
  certutil -d "sql:${nssdb}" -A -n "$CERT_NICKNAME" -t "CT,," -i "$cert_path"
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
  # Merge into existing policy if it exists
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
