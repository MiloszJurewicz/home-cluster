#!/usr/bin/env bash
set -euo pipefail

TOKEN=$(bw get item 3d436106-fa28-4e7b-853e-b477017f277e \
  | jq -r '.fields[] | select(.name=="AccessToken") | .value')

cat > terraform/netbird/netbird.auto.tfvars.json <<EOF
{"netbird_token": "$TOKEN"}
EOF

echo "Wrote terraform/netbird/netbird.auto.tfvars.json"
