# Technitium Bootstrap → Helm Post-Install Job

Convert `scripts/technitium-bootstrap.sh` into a Helm post-install Job on the `technitium-dns` chart so it auto-runs on `helmfile apply` instead of requiring manual script execution.

## Requirements

- The TSIG secret (`technitium-tsig` in `kube-system`) must already exist before the Job runs
- Job must be idempotent (safe to re-run on upgrades)
- Job should run after Technitium pod is ready (use `helm.sh/hook-weight` or init container wait)

## Key pieces

- Script: `scripts/technitium-bootstrap.sh` (already idempotent, uses `jq`)
- TSIG secret chart: `manifests/technitium-tsig-secret/` (uses `lookup` to preserve on upgrades)
- Technitium web service: `technitium-technitium-dns-server-web.dns.svc.cluster.local:5380`

## Approach

Add a `templates/bootstrap-job.yaml` to the technitium-dns chart that:
1. Uses `helm.sh/hook: post-install,post-upgrade` 
2. Waits for the web service to be reachable
3. Runs the bootstrap logic inline (or from a ConfigMap)
4. Has `ttlSecondsAfterFinished` to auto-cleanup
