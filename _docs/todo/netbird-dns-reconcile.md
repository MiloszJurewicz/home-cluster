# Netbird DNS Reconciliation

Netbird peers need to resolve LAN hosts by name, not just IP. DNS config
exists in `dns.tf` (`netbird_nameserver_group` forwarding `*.home.arpa` to
Pi-hole) but was removed during testing to limit moving parts.

## Tasks

- [ ] Re-enable the `netbird_nameserver_group` resource in `dns.tf` (or
  recreate if it was destroyed)
- [ ] Update the nameserver IP if Pi-hole → Technitium migration changes it
- [ ] Verify `*.home.arpa` resolves from a remote Netbird peer
- [ ] Extend to cover other domains if needed (e.g., non-arpa local hostnames)
