#!/usr/bin/env bash
set -euo pipefail
# Bootstrap Technitium: create zone, push TSIG key, enable RFC2136 dynamic updates.
# Idempotent — safe to run repeatedly.
# TODO: convert to Helm post-install Job.

: "${TECHNITIUM_URL:=http://127.0.0.1:5380}"
: "${ADMIN_PASS:=admin1}"
: "${ZONE:=home.arpa}"
: "${TSIG_KEY_NAME:=external-dns}"
: "${NAMESPACE:=kube-system}"
: "${SECRET_NAME:=technitium-tsig}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

# --- Get API token ---
log "Authenticating to Technitium..."
TOKEN=$(curl -sf "${TECHNITIUM_URL}/api/user/login?user=admin&pass=${ADMIN_PASS}&includeInfo=false" \
  | jq -r '.token')
log "Authenticated"

# --- Create zone if missing ---
log "Checking zone '${ZONE}'..."
if curl -sf "${TECHNITIUM_URL}/api/zones/list?token=${TOKEN}" \
    | jq -e --arg zone "${ZONE}" '.response.zones[]? | select(.name == $zone)' > /dev/null; then
  log "Zone '${ZONE}' already exists"
else
  log "Creating zone '${ZONE}'..."
  curl -sf "${TECHNITIUM_URL}/api/zones/create?zone=${ZONE}&type=Primary&token=${TOKEN}" \
    | jq -e '.status == "ok"' > /dev/null
  log "  -> created"
fi

# --- Read TSIG secret from Kubernetes ---
log "Reading TSIG secret from ${NAMESPACE}/${SECRET_NAME}..."
TSIG_SECRET=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{.data.secret}' | base64 -d)
log "Got TSIG secret"

# --- Push TSIG key to Technitium if missing ---
log "Checking TSIG key '${TSIG_KEY_NAME}'..."
if curl -sf "${TECHNITIUM_URL}/api/settings/get?token=${TOKEN}" \
    | jq -e --arg key "${TSIG_KEY_NAME}" '.response.tsigKeys[]? | select(.keyName == $key)' > /dev/null; then
  log "TSIG key '${TSIG_KEY_NAME}' already exists"
else
  log "Creating TSIG key '${TSIG_KEY_NAME}'..."

  # Use pipe-delimited table format: keyName|sharedSecret|algorithmName
  # (JSON array format has a form-parsing bug in Technitium)
  TSIG_TABLE="${TSIG_KEY_NAME}|${TSIG_SECRET}|hmac-sha256"

  curl -sf "${TECHNITIUM_URL}/api/settings/set?token=${TOKEN}" \
    --data-urlencode "tsigKeys=${TSIG_TABLE}" \
    | jq -e '.status == "ok"' > /dev/null
  log "  -> created"
fi

# --- Enable RFC2136 dynamic updates ---
log "Enabling dynamic updates on '${ZONE}'..."
curl -sf "${TECHNITIUM_URL}/api/zones/options/set?zone=${ZONE}&token=${TOKEN}&update=Allow" \
  | jq -e '.status == "ok"' > /dev/null
log "  -> enabled"

log "Bootstrap complete."
