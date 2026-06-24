# Loki

- **`auth_enabled: false` is correct** — Loki's `auth_enabled` isn't password auth; it's multi-tenant data isolation (partitions data by `X-Scope-OrgID` header). For a single-tenant home cluster it's unnecessary overhead.
- **Loki should be protected at the network/access layer** — Loki has no built-in login, so access control belongs in front of it:
  1. **Loki gateway basic auth** — the `loki-gateway` (nginx) already fronts Loki; configure it with basic auth credentials, then set those in Grafana's Loki datasource.
  2. **Traefik middleware** — if Loki gets an ingress, use Traefik's `BasicAuth` or `ForwardAuth` middleware.
  3. **NetworkPolicies** — restrict ingress to the `monitoring` namespace so only Grafana and Alloy can reach Loki.

# Scraping Consolidation

Currently there's split responsibility for metrics scraping:

| Component | Scraped by | How |
|-----------|-----------|-----|
| kube-state-metrics | **Alloy** | Remote write → Prometheus |
| cadvisor / kubelet | **Alloy** | Remote write → Prometheus |
| node-exporter | **Prometheus** | ServiceMonitor → direct scrape |
| kubelet (kps-side) | **Prometheus** | ServiceMonitor → direct scrape |
| apiserver, coredns, etc. | **Prometheus** | ServiceMonitor → direct scrape |

**Goal**: Alloy should be the sole scraper. Prometheus should only receive via remote write, not scrape anything directly.

### What needs to happen:
1. **node-exporter**: Configure Alloy's `clusterMetrics` or `hostMetrics` to discover and scrape the node-exporter deployed by `telemetryServices`, then forward via remote write. Remove the ServiceMonitor + `additionalLabels` hack.
2. **kubelet / cadvisor**: Alloy already scrapes these — the duplicate kps ServiceMonitors (`kps-kube-prometheus-stack-kubelet`, etc.) should be disabled to avoid Prometheus scraping them directly.
3. **apiserver / coredns**: Either configure Alloy to scrape these (via `clusterMetrics.apiServer`, `clusterMetrics.kubeDNS`, etc.) or accept that these few control-plane ServiceMonitors are fine as direct Prometheus scrapes.

### Why:
- Single path for metrics → simpler debugging, no duplicate series
- WAL buffering in Alloy protects against Prometheus downtime
- Consistent with the "Alloy as unified collector" architecture

---

# Secret Management Improvements

Current approach: Plain manifests (manual duplication across namespaces).

### Recommended Tools:
1. **[Reflector](https://github.com/emberstack/kubernetes-reflector)** or **[Kubed](https://appscode.com/products/kubed/)**: Automatically sync secrets/configmaps across namespaces using annotations.
2. **[SOPS](https://github.com/getsops/sops)**: Encrypt secrets in Git (works natively with Helmfile's `secrets` plugin).
3. **[HashiCorp Vault](https://www.vaultproject.io/) + [External Secrets Operator](https://external-secrets.io/)**: Securely store secrets in Vault and use ESO to inject them into Kubernetes namespaces as native Secrets.

