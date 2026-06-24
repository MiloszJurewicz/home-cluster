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

