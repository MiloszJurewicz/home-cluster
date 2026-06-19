# Secret Management Improvements

Current approach: Plain manifests (manual duplication across namespaces).

### Recommended Tools:
1. **[Reflector](https://github.com/emberstack/kubernetes-reflector)** or **[Kubed](https://appscode.com/products/kubed/)**: Automatically sync secrets/configmaps across namespaces using annotations.
2. **[SOPS](https://github.com/getsops/sops)**: Encrypt secrets in Git (works natively with Helmfile's `secrets` plugin).
3. **[HashiCorp Vault](https://www.vaultproject.io/) + [External Secrets Operator](https://external-secrets.io/)**: Securely store secrets in Vault and use ESO to inject them into Kubernetes namespaces as native Secrets.

