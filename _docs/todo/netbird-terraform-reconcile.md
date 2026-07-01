# Netbird Terraform Reconciliation

**Status: Terraform reconciled (2026-07-01). K3s CIDR routing pending.**

The terraform in `terraform/netbird/` is now reconciled with live state. Code
and infrastructure match with zero drift.

Related: [[k3s-cidr-routing.md]]

## 1. Survey Drift ✅

- [x] Run `terraform plan`, review all diffs
- [x] Compare the live Netbird dashboard against what's in `dns.tf` / `data.tf`
- [x] Note any manually-created resources that need `terraform import`
- [x] Check if peer names or group memberships changed since last apply

**Findings:**
- `netbird_nameserver_group.home_arpa` — deleted from dashboard, needed creation
- `netbird_network_router.home_gateway` — deleted and manually recreated (new ID `d913qpbl0ubs73d95g40`, same config)
- `netbird_policy.home_lan_access` — deleted and manually recreated as "Home LAN Subnet Access" (new ID `d90sc82fadhs73evqrfg`)
- `netbird_group.home_lan` — 2 extra peers added (bangkk_ge, DESKTOP-LLS0Q38)
- Nameserver was still Pi-hole (192.168.0.52), code had been updated to Technitium (192.168.0.110) but never applied

**Resolution:**
- Removed 3 stale state entries (`terraform state rm`)
- Updated `dns.tf` + `data.tf` to match live config
- Imported live router and policy
- Applied — created nameserver group pointing to Technitium
- `terraform plan` shows zero drift

## 2. K3s CIDR Routing (Deferred — Manual Fix In Place)

The analysis in [[k3s-cidr-routing.md]] is **correct**. Netbird's nftables
`netbird-acl-forward-filter` is active and drops packets when kube-proxy DNAT
changes both the destination and the mark:

```
netbird-mangle-prerouting:  mark = 0x0001bd20  (from tunnel)
kube-proxy DNAT + mark:     mark = 0x0001fd20  (0x4000 added)
netbird-acl-forward-filter:  mark 0x0001bd20? → NO → drop
```

For now, manual iptables ACCEPT rules in KUBE-ROUTER-FORWARD work around it.
The proper Terraform fix (adding K3s pod/service CIDRs as
`netbird_network_resource` entries so Netbird's agent generates ACL rules
for them) is still pending — see [[k3s-cidr-routing.md]].

- [ ] Reproduce from a remote peer: confirm traffic to K3s services fails
  without the manual iptables rules
- [ ] Remove the manual rules, create the CIDR resources via the Netbird
  dashboard, and test
- [ ] If it works → codify in `dns.tf`
- [ ] If not → document why, find the real fix

## 3. Clean Up Ephemeral Fixes

- [ ] Find and remove manual iptables rules, systemd oneshots, or rc.local
  hacks — replace with declarative equivalents or drop once no longer needed
- [ ] Reboot-test after applying CIDR resource fix

## Current Terraform State

```
netbird_group.home_lan               (existing, imported)
netbird_network.home_lan             (existing)
netbird_network_resource.home_lan    (existing)
netbird_network_router.home_gateway  (imported d913qpbl0ubs73d95g40)
netbird_policy.home_lan_access       (imported d90sc82fadhs73evqrfg)
netbird_nameserver_group.home_arpa   (created 2026-07-01, Technitium DNS)
```

## Open Items

- [ ] Clean up group peer list — remote peers shouldn't be in routing group
- [ ] K3s CIDR routing fix (above) — replace manual iptables with Terraform resources
- [ ] Handle root CA for Technitium DNS (separate task)
