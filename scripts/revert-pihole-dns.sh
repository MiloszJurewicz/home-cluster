#!/usr/bin/env bash
set -euo pipefail

CONN="${CONN:-Auto TP-Link_6E0B_5G}"

sudo nmcli connection modify "$CONN" ipv4.ignore-auto-dns no ipv4.dns ""
sudo nmcli connection down "$CONN"
sudo nmcli connection up "$CONN"
