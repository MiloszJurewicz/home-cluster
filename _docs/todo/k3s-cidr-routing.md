# Netbird Routing Peer + K3s on Same Host: Pod/Service CIDRs

## Problem

When the Netbird routing peer and K3s share the same machine, traffic from
remote Netbird peers to K3s LoadBalancer services gets dropped by Netbird's
FORWARD ACL. The chain of events:

1. Remote peer sends packet: `src=100.72.x.x, dst=192.168.0.110:443`
2. Netbird mangle marks it: `0x0001bd20` — "this came from my tunnel"
3. kube-proxy DNAT in nat PREROUTING rewrites it:
   - Destination: `192.168.0.110:443` → `10.42.0.x:8443` (pod IP)
   - Mark: adds `0x4000` → mark becomes `0x0001fd20`
4. Netbird FORWARD ACL inspects the modified packet:
   - `mark == 0x0001bd20` ? No (it's `0x0001fd20` now) — **fail**
   - `dst in 192.168.0.0/24` ? No (it's `10.42.0.x` now) — **fail**
   - Fallthrough: `iifname wt0 drop` — **packet gone**

SSH and non-K8s ports work fine because kube-proxy doesn't touch them.

## Current State (Manual Fix)

The fix in place today is two hand-cut iptables rules that accept traffic
to and from the pod network regardless of marks:

```
iptables -t filter -I KUBE-ROUTER-FORWARD -d 10.42.0.0/16 -j ACCEPT
iptables -t filter -I KUBE-ROUTER-FORWARD -s 10.42.0.0/16 -j ACCEPT
```

**Downsides:** Rules are ephemeral. A reboot, a Netbird restart, or a Netbird
client update can wipe them. They are invisible to Netbird's dashboard and
not tracked in version control or `iptables-save`.

## Proposed Fix: Add CIDRs as Netbird Resources

Instead of manual iptables rules, tell Netbird about the cluster CIDRs so
its agent auto-generates the firewall rules and keeps them in sync.

### What Changes

Add two extra `netbird_network_resource` entries to `dns.tf` for the pod
and service CIDRs, assigned to the same `home-lan` group so the existing
access policy covers them:

```hcl
# NEW — K3s pod network
resource "netbird_network_resource" "k3s_pods" {
  network_id  = netbird_network.home_lan.id
  name        = "K3s Pod Network"
  address     = "10.42.0.0/16"
  groups      = [netbird_group.home_lan.id]
}

# NEW — K3s service network
resource "netbird_network_resource" "k3s_services" {
  network_id  = netbird_network.home_lan.id
  name        = "K3s Service Network"
  address     = "10.43.0.0/16"
  groups      = [netbird_group.home_lan.id]
}
```

That's it. No changes to the router, policy, or nameserver config needed.
The existing `home_lan_access` policy already allows `All` → `home-lan`
group, and these resources are in that group.

### What Netbird Does With This

Netbird's agent on the routing peer sees the new CIDRs and adds FORWARD
ACL rules accepting traffic to/from `10.42.0.0/16` and `10.43.0.0/16`.
This achieves the same effect as the manual iptables rules, but:
- Rules survive reboots and Netbird restarts
- Rules are tied to a declarative resource visible in the dashboard
- Rules update automatically if the policy or group membership changes

### CIDR Stability

`10.42.0.0/16` and `10.43.0.0/16` are K3s hardcoded defaults. They are
not set in `/etc/rancher/k3s/config.yaml` or any k3s flag. They will not
change unless someone explicitly adds `--cluster-cidr` or `--service-cidr`
arguments to the k3s server command.

### Applying

```bash
cd terraform/netbird
export TF_VAR_netbird_token=$(cat ~/.netbird-token) # or however the token is sourced
terraform plan
terraform apply
```

After apply, verify the routing peer received the new resources (check
the Netbird dashboard or `netbird status` on the host).

### What About the Manual iptables Rules?

Once this is in place and verified, the manual rules can be removed:

```bash
iptables -t filter -D KUBE-ROUTER-FORWARD -d 10.42.0.0/16 -j ACCEPT
iptables -t filter -D KUBE-ROUTER-FORWARD -s 10.42.0.0/16 -j ACCEPT
```

Then make sure nothing re-adds them (check systemd oneshots, rc.local, etc.).

## Open Questions / Things to Watch

1. **Does this actually solve the mark mismatch?** Netbird's FORWARD ACL
   checks both the mark AND the destination. Adding the pod CIDR as a
   resource gives the ACL a CIDR-based accept path, but the mark check
   (`meta mark 0x0001bd20 accept`) still fails because kube-proxy added
   `0x4000`. The fix relies on the CIDR-based accept rule matching
   (`ip saddr <allowed> ip daddr 10.42.0.0/16 accept`) which Netbird
   generates from resources. This should work — but verify.

2. **Service CIDR necessity.** The service CIDR (`10.43.0.0/16`) may not
   be strictly needed since kube-proxy only DNATs to pods (`10.42.0.0/16`)
   not to services. Remote peers don't reach ClusterIPs directly. However,
   adding it is harmless and covers edge cases (e.g., if `externalTrafficPolicy:
   Local` ever changes the DNAT target).

3. **Return traffic.** Packets flowing back from pods to remote peers
   should be covered by Netbird's `ESTABLISHED,RELATED` connection tracking
   rules, but the CIDR accept rules in both directions don't hurt.

4. **Netbird provider version.** The current provider is `~> 0.0.9`.
   `netbird_network_resource` may have different attribute names in newer
   versions. Check the provider docs before applying:
   https://registry.terraform.io/providers/netbirdio/netbird/latest/docs
