# Hardcoded Passwords in Values Files

**Date identified:** 2026-07-01

## Files to fix

### `values/authentik.values.yaml`
- [ ] L6: `secret_key` — move to Kubernetes Secret / external secret
- [ ] L8: `bootstrap_password_hash` — move to Kubernetes Secret / external secret
- [ ] L16: `authentik.postgresql.password` — move to Kubernetes Secret
- [ ] L59: `postgresql.auth.password` — move to Kubernetes Secret (same password, deduplicate)

### `values/technitium.values.yaml`
- [ ] L10: `dnsServer.adminPassword` — plaintext `admin1`, move to Kubernetes Secret

### `values/prometheus.values.yaml`
- [ ] L83: `GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET` — move to Kubernetes Secret / external secret
