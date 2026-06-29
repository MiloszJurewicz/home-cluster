# Netbird Terraform Reconciliation

The terraform in `terraform/netbird/` is stale — the commit `358ea09` ("netbird
working with outdated terraform") reflects manual changes made to get things
working that haven't been brought back into code.

Related: [[k3s-cidr-routing.md]]

## 1. Survey Drift

- [ ] Run `terraform plan`, review all diffs
- [ ] Compare the live Netbird dashboard against what's in `dns.tf` / `data.tf`
- [ ] Note any manually-created resources that need `terraform import`
- [ ] Check if peer names or group memberships changed since last apply

## 2. K3s CIDR Routing (Validate First)

`k3s-cidr-routing.md` documents the problem: Netbird's FORWARD ACL drops
kube-proxy DNAT'd packets because the mark and destination both change. Manual
iptables rules are working around it right now.

The proposed fix is adding K3s pod/service CIDRs (`10.42.0.0/16`,
`10.43.0.0/16`) as `netbird_network_resource` entries so Netbird's agent
generates FORWARD ACL rules for them. Unclear if this actually works given the
mark-mismatch issue.

**Before writing Terraform:**

- [ ] Reproduce from a remote peer: confirm traffic to K3s services fails
  without the manual iptables rules
- [ ] Remove the manual rules, create the CIDR resources via the Netbird
  dashboard, and test
- [ ] If it works → codify in `dns.tf`
- [ ] If not → document why, find the real fix

## 3. Clean Up Ephemeral Fixes

- [ ] Find and remove manual iptables rules, systemd oneshots, or rc.local
  hacks added during testing — replace with declarative equivalents or drop
  once no longer needed
- [ ] Reboot-test after applying reconciled Terraform
