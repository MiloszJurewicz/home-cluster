# The group your peers belong to — adjust "All" to match your actual group name
# Find it at https://app.netbird.io/groups
data "netbird_group" "peers" {
  name = "All"
}

# This machine acts as the gateway to the home LAN
data "netbird_peer" "home_gateway" {
  name = "quack-ThinkPad-L450"
}
