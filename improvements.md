# Loki

- **`auth_enabled: false` is correct** — Loki's `auth_enabled` isn't password auth; it's multi-tenant data isolation (partitions data by `X-Scope-OrgID` header). For a single-tenant home cluster it's unnecessary overhead.
- **Loki should be protected at the network/access layer** — Loki has no built-in login, so access control belongs in front of it:
  1. **Loki gateway basic auth** — the `loki-gateway` (nginx) already fronts Loki; configure it with basic auth credentials, then set those in Grafana's Loki datasource.
  2. **Traefik middleware** — if Loki gets an ingress, use Traefik's `BasicAuth` or `ForwardAuth` middleware.
  3. **NetworkPolicies** — restrict ingress to the `monitoring` namespace so only Grafana and Alloy can reach Loki.

# Scraping Consolidation — DONE

Alloy is now the sole scraper. kps Prometheus is receive-only via remote write (except 4 self-monitoring ServiceMonitors: grafana, prometheus, alertmanager, operator).

### Final architecture

| Component | Alloy feature | job label | kps ServiceMonitor |
|-----------|--------------|-----------|:---:|
| kubelet | `clusterMetrics.kubelet` | `kubelet` | disabled |
| cadvisor | `clusterMetrics.cadvisor` | `kubelet` | disabled |
| kube-state-metrics | `clusterMetrics.kube-state-metrics` | `kube-state-metrics` | disabled |
| node-exporter | `hostMetrics.linuxHosts` | `node-exporter` | disabled |
| apiserver | `clusterMetrics.apiServer` | `apiserver` | disabled |
| coredns | `clusterMetrics.kubeDNS` | `coredns` | disabled |
| kube-proxy | ❌ K3s embeds it — not discoverable | — | — |
| kube-scheduler | ❌ K3s embeds it — not discoverable | — | — |
| kube-controller-manager | ❌ K3s embeds it — not discoverable | — | — |

### Key config patterns learned

- **`cluster` label** is added globally by Alloy's `prometheus.remote_write.external_labels` (derived from `cluster.name`). No per-job relabeling needed.
- **`extraMetricProcessingRules`** uses Alloy `rule {}` block syntax, NOT YAML lists (`rule { target_label = "foo"; replacement = "bar" }`). YAML `- target_label:` syntax silently breaks Alloy config reload.
- **Feature keys go at the TOP LEVEL** of the values file, not nested under `features:`. The defaults are misleading.
- **`kube-state-metrics.nameOverride`** exists in kps (since v56.0.2) but **`job="node-exporter"` is hardcoded** in kps rules — no override. Confirmed in GH PR #4160.
- **Direction**: align Alloy job labels → kps expectations (kps is the less flexible side).

### Collector presets for multi-node

For a single-node homelab: `alloy-metrics: [small, deployment]`. For multi-node:

| Collector | Presets | Notes |
|-----------|---------|-------|
| `alloy-logs` | `[small, daemonset, filesystem-log-reader]` | Scales automatically 1 per node |
| `alloy-metrics` | `[medium, clustered, statefulset]` + `replicas: N` | `clustered` distributes scrape targets; StatefulSet gives stable hash-ring identities |
| `alloy-singleton` | `[small, deployment]` | Must stay 1 replica (cluster events duplicate otherwise) |

---

# Secret Management Improvements

Current approach: Plain manifests (manual duplication across namespaces).

### Recommended Tools:
1. **[Reflector](https://github.com/emberstack/kubernetes-reflector)** or **[Kubed](https://appscode.com/products/kubed/)**: Automatically sync secrets/configmaps across namespaces using annotations.
2. **[SOPS](https://github.com/getsops/sops)**: Encrypt secrets in Git (works natively with Helmfile's `secrets` plugin).
3. **[HashiCorp Vault](https://www.vaultproject.io/) + [External Secrets Operator](https://external-secrets.io/)**: Securely store secrets in Vault and use ESO to inject them into Kubernetes namespaces as native Secrets.

---

# Authentik

## Immediate tasks

- [ ] **Move Grafana `client_secret` into Kubernetes Secret** — Currently hardcoded in `values/prometheus.values.yaml`.
  Ref: [Grafana Helm chart docs](https://github.com/grafana-community/helm-charts/blob/main/charts/grafana/README.md#how-to-securely-reference-secrets-in-grafanaini)
  and [Authentik integration docs](https://integrations.goauthentik.io/monitoring/grafana/).
  - Create a Secret with the OAuth client secret
  - Reference it via Grafana's `envValueFrom` or `secretKeyRefs`
  - Eventually extend to Authentik's `bootstrap_password_hash` + DB password

- [ ] **Groups & entitlements** — Set up Authentik groups for Grafana role mapping.
  - Create groups via blueprint: `Grafana Admins`, `Grafana Editors`, `Grafana Viewers`
  - Add application entitlements to the Grafana app
  - Assign `akadmin` to `Grafana Admins` group
  - Role mapping is already configured: `contains(entitlements[*], 'Grafana Admins') && 'Admin' || ...`

## To do

- [ ] **Add intermediate CA** — Currently `leaf-cert` is signed directly by the root CA. Best practice:
  root CA should stay offline, only sign an intermediate; the intermediate issues leaf certs.
  - Root CA key stays on disk (`certs/`), never pushed to cluster
  - Add intermediate CA chart (or extend `root-ca-bootstrap`) — creates an intermediate cert signed by root
  - Switch `leaf-cert` issuer from `root-ca-issuer` → intermediate issuer
  - Intermediate key lives in cluster; compromise doesn't require root CA rotation
  - Browsers/OS trust root CA; cert chain is root → intermediate → leaf (3 levels)

- [ ] **Technitium DNS** — replace Pi-hole. Research done:
  - OIDC support (v15.1+) → direct Authentik integration, no ForwardAuth
  - Native clustering (v14+) — no third-party sync tools needed
  - Full authoritative DNS + ad blocking in one app
  - ExternalDNS community webhook available
  - Better chart: `paimonsoror/technitium-dns` — `dnsServer.blockListUrls`, `customCA`, `pfxCertificate`
  - Blocklists configurable as Helm values (unlike Pi-hole chart which requires UI)

## Future apps

- [ ] **Headlamp** — OIDC via Authentik (native support)
- [ ] **Homepage** — authenticate via Authentik (OIDC or forward auth)

## Notes

### Backchannel vs front-channel logout

Official [Grafana integration docs](https://integrations.goauthentik.io/monitoring/grafana/)
recommend setting the provider's **Logout Method** to `Front-channel`. However neither `front_channel`
nor `front` is accepted by the blueprint validator (only `backchannel` is valid). The UI may expose
a front-channel option that maps to a different internal value. Logout works correctly with
`backchannel` in practice — revisit this if issues arise. The internal enum is in
`authentik_providers_oauth2.models` → `LogoutMethod`.

