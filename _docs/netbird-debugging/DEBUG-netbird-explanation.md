What happens technically

Phone packet (src=100.72.58.127, dst=192.168.0.110:443) enters the laptop through the wt0 interface.

Step 1 — NetBird marks the packet in the mangle prerouting chain with 0x0001bd20. This is NetBird's identifier for "this came from my tunnel."

Step 2 — kube-proxy modifies the packet in the nat prerouting chain:
- Changes the mark: adds 0x4000 on top → mark becomes 0x0001fd20
- Changes the destination: DNAT from 192.168.0.110:443 to 10.42.0.147:8443 (the Traefik pod)

Step 3 — NetBird's forward ACL filter inspects the packet. It has two accept rules:
- meta mark 0x0001bd20 accept — fails because the mark is now 0x0001fd20
- ip saddr @nb-set ip daddr 192.168.0.0/24 accept — fails because DNAT changed the destination to 10.42.0.147
- Neither matches, so it reaches iifname "wt0" drop — packet dropped.

SSH and port 3001 work because kube-proxy doesn't DNAT them and doesn't add the 0x4000 mark. NetBird's original rules match the unmodified packets.

The fix adds two rules before the drop in NetBird's routing-forward chain that accept traffic to and from the pod network (10.42.0.0/16) regardless of marks or original destination.
