# Groups: separate peer groups from resource groups (follows the guide pattern)
# "home-lan" group holds the routing peer (resource association is handled
# by netbird_network_resource.groups, avoiding a circular dependency)
resource "netbird_group" "home_lan" {
  name  = "home-lan"
  peers = [
    data.netbird_peer.home_gateway.id,
    data.netbird_peer.bangkk_ge.id,
    data.netbird_peer.desktop_lls0q38.id,
  ]
}

# Network: maps home LAN into Netbird overlay so peers can reach 192.168.0.x
resource "netbird_network" "home_lan" {
  name        = "Home LAN"
  description = "Access to home LAN via this machine"
}

# Resources reachable on the home LAN — assigned to dedicated "home-lan" group
resource "netbird_network_resource" "home_lan" {
  network_id  = netbird_network.home_lan.id
  name        = "Home LAN Subnet"
  address     = "192.168.0.0/24"
  groups      = [netbird_group.home_lan.id]
}

# This machine is the routing peer — forwards tunnel traffic to the LAN
resource "netbird_network_router" "home_gateway" {
  network_id = netbird_network.home_lan.id
  peer       = data.netbird_peer.home_gateway.id
  masquerade = true
}

# Grant access: "All" peers → "home-lan" resources (group-based destination
# triggers route distribution; destinationResource does not)
resource "netbird_policy" "home_lan_access" {
  name        = "Home LAN Subnet Access"
  description = "Home LAN, Access to home LAN via this machine"
  rule {
    name          = "Home LAN Subnet Access"
    description   = "Home LAN, Access to home LAN via this machine"
    action        = "accept"
    protocol      = "all"
    bidirectional = false
    sources       = [data.netbird_group.peers.id]
    destinations  = [netbird_group.home_lan.id]
  }
}

# Forward *.home.arpa queries to Technitium DNS at 192.168.0.110
resource "netbird_nameserver_group" "home_arpa" {
  name        = "Home ARPA DNS"
  description = "Forward *.home.arpa to Technitium DNS"
  nameservers = [
    {
      ip      = "192.168.0.110"
      ns_type = "udp"
      port    = 53
    }
  ]
  domains                 = ["home.arpa"]
  groups                  = [data.netbird_group.peers.id]
  search_domains_enabled  = true
}
