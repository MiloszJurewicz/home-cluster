terraform {
  required_providers {
    netbird = {
      source  = "netbirdio/netbird"
      version = "~> 0.0.9"
    }
  }
}

variable "netbird_token" {
  type        = string
  sensitive   = true
  description = "NetBird admin PAT from https://app.netbird.io/account"
}

provider "netbird" {
  token          = var.netbird_token
  management_url = "https://api.netbird.io"
}
