# Intermediate CA

Currently `leaf-cert` is signed directly by the root CA. Add an intermediate
CA so the root can stay offline.

- [ ] Create intermediate CA cert signed by root CA
- [ ] Root CA key stays on disk (`certs/`), never pushed to cluster
- [ ] Switch `leaf-cert` issuer from `root-ca-issuer` to intermediate issuer
- [ ] Intermediate key lives in cluster; compromise doesn't require root CA rotation
- [ ] Verify cert chain: root → intermediate → leaf (3 levels)
