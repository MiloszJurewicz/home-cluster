# Pi-hole → Technitium Migration

Migrate home DNS from Pi-hole to Technitium, and switch external-dns to the
RFC2136 provider pointed at Technitium.

## 1. Pi-hole → Technitium

- [ ] Export Pi-hole blocklists and custom DNS entries
- [ ] Deploy Technitium (Docker on a host, or K3s pod — decide)
- [ ] Import into Technitium
- [ ] Switch DHCP/router DNS to Technitium
- [ ] Decommission Pi-hole

## 2. external-dns → RFC2136

- [ ] Update external-dns deployment to use the RFC2136 provider:
  https://kubernetes-sigs.github.io/external-dns/latest/docs/tutorials/rfc2136/
- [ ] Point it at Technitium (host, port, TSIG if used)
- [ ] Verify DNS records are created/updated for `external-dns`-annotated services
- [ ] Remove old external-dns provider config
