# Pi-hole → Technitium Migration — DONE

## Status: ✅ Complete — Technitium fully operational, external-dns working via TSIG

---

## What's Done

### Pi-hole
- Fully uninstalled (releases, namespace gone)
- Removed from `helmfile.yaml`
- `mojo2600` Helm repo removed
- Stale configs cleaned: `values/pihole*.yaml`, `manifests/pihole-admin-secret/`

### Technitium
- Deployed via `charts/technitium-dns` (cloned from `paimonsoror/technitium-dns`)
- Namespace: `dns`, release name: `technitium`
- DNS serving on `192.168.0.110:53` (LoadBalancer via ServiceLB) — **works for external resolution**
- Web UI on `dns.home.arpa` (Ingress via Traefik, TLS from wildcard cert)
- Values: `values/technitium.values.yaml`
- `home.arpa` zone **created** (via API, works)
- Dynamic updates **enabled** on zone (set to `Allow`)
- Admin password: `admin1`

### TSIG Key (Resolved)
- Secret `technitium-tsig` in `kube-system` — Helm chart with `lookup` + `randAlphaNum` for auto-generation
- TSIG key pushed to Technitium via API using **pipe-delimited table format** (`keyName|sharedSecret|algorithmName`)
  - Root cause: JSON array form-encoding has a parser bug in Technitium; the table format is the stable API
  - Also fixed: the JSON field is `algorithmName` (not `algorithm`)
- Bootstrap script uses `jq` for robust JSON parsing throughout

### external-dns
- ✅ Working — successfully authenticating with TSIG, creating A records for all ingresses
- Configured as RFC2136 provider pointing to `technitium-technitium-dns-server-dns-tcp.dns.svc.cluster.local:53`

### Netbird DNS Config
- `terraform/netbird/dns.tf`: DNS forwarder IP updated `192.168.0.52` → `192.168.0.110`
- Description updated from "Pi-hole" → "Technitium DNS"

### Scripts
- `scripts/dns-set-pihole.sh`: IP and variable name updated (`192.168.0.52` → `192.168.0.110`)
- `scripts/dns-revert-pihole.sh`: No changes needed (just clears DNS, doesn't hardcode IP)
- `scripts/technitium-bootstrap.sh`: Fully working, idempotent, uses `jq` for JSON parsing
  - Zone creation ✅
  - TSIG key push ✅ (pipe-delimited table format)
  - Dynamic updates enable ✅

### Stale Configs Cleaned
- `values/pihole.values.yaml` → deleted
- `values/pihole-admin-secret.values.yaml` → deleted
- `values/metallb-pool.values.yaml` → deleted
- `manifests/pihole-admin-secret/` → deleted
- `charts/metallb-pool/` → deleted
- `metallb-system` namespace → deleted (empty, not deployed)
- `pihole` namespace → deleted (empty, release uninstalled)

---

## Files Changed/Created

| File | Status |
|------|--------|
| `charts/technitium-dns/` | New (cloned community chart) |
| `values/technitium.values.yaml` | New |
| `values/external-dns.values.yaml` | Modified (pihole → rfc2136) |
| `manifests/technitium-tsig-secret/` | New (proper Helm chart with auto-gen) |
| `scripts/technitium-bootstrap.sh` | New (idempotent, jq-based, working) |
| `helmfile.yaml` | Modified (removed Pi-hole, added Technitium+TSIG) |
| `terraform/netbird/dns.tf` | Modified (DNS IP 192.168.0.52 → 192.168.0.110) |
| `scripts/dns-set-pihole.sh` | Modified (DNS IP updated) |

## Deleted

| File | Reason |
|------|--------|
| `values/pihole.values.yaml` | Pi-hole uninstalled |
| `values/pihole-admin-secret.values.yaml` | Pi-hole uninstalled |
| `values/metallb-pool.values.yaml` | Not deployed (using ServiceLB) |
| `manifests/pihole-admin-secret/` | Pi-hole uninstalled |
| `charts/metallb-pool/` | Not deployed (using ServiceLB) |
