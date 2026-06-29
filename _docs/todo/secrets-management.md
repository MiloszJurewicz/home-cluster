# Secrets Management

Current approach: plain manifests with manual duplication across namespaces.

- [ ] Create a `charts/cluster-secrets` chart that creates Kubernetes Secrets from values
- [ ] Switch Grafana + Authentik to reference Secrets via `secretKeyRef`/`envValueFrom`
- [ ] Encrypt with [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) (ArgoCD-native, cluster holds the key, no external services needed)
