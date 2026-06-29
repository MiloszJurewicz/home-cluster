#!/bin/bash
# Restart services that own iptables rules. Each rebuilds its chains on startup.
# Order: k3s -> docker -> netbird. Disruptive — all pods restart.
set -euo pipefail

sudo systemctl restart k3s
until sudo k3s kubectl get nodes &>/dev/null; do sleep 2; done

sudo systemctl restart docker || true

netbird down 2>/dev/null; sleep 2; netbird up
