# Loki

Loki has no built-in auth (`auth_enabled` is multi-tenant isolation, not login).
Protect at the network/access layer.

- [ ] Configure basic auth on the loki-gateway (nginx)
- [ ] Set those credentials in Grafana's Loki datasource
- [ ] Add NetworkPolicy to restrict ingress to `monitoring` namespace (only Grafana + Alloy)
- [ ] If Loki gets an ingress, add Traefik `BasicAuth` or `ForwardAuth` middleware
