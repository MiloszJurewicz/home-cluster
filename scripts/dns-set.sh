#!/usr/bin/env bash
set -euo pipefail

CONN="${CONN:-Auto TP-Link_6E0B_5G}"
DNS_PRIMARY="${DNS_PRIMARY:-192.168.0.110}"
FALLBACK_DNS="${FALLBACK_DNS:-192.168.0.1}"

sudo nmcli connection modify "$CONN" ipv4.ignore-auto-dns yes ipv4.dns "$DNS_PRIMARY,$FALLBACK_DNS"
sudo nmcli connection down "$CONN"
sudo nmcli connection up "$CONN"
