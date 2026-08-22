# Defaults match documentation/architecture.md and documentation/cloud-networking.md.

variable "location" {
  type    = string
  default = "East US"
}

variable "resource_group_name" {
  type    = string
  default = "rg-enterprise-hybrid-sim"
}

variable "prod_vnet_cidr" {
  type    = string
  default = "172.32.0.0/16"
}

variable "dev_vnet_cidr" {
  type    = string
  default = "172.33.0.0/16"
}

variable "onprem_aggregate_cidr" {
  description = "On-prem summary route advertised by the enterprise, per routing.md section 4."
  type        = string
  default     = "10.0.0.0/8"
}

variable "vpn_gateway_asn" {
  description = "Azure's default VPN Gateway BGP ASN, per cloud-networking.md section 2.3."
  type        = number
  default     = 65515
}

variable "core_r1_public_ip" {
  description = "CORE-R1 public/WAN IP — used as the backup Azure VPN's local network gateway address."
  type        = string
  default     = "203.0.113.21"
}

variable "core_r2_public_ip" {
  description = "CORE-R2 public/WAN IP — used as the primary Azure VPN's local network gateway address."
  type        = string
  default     = "203.0.113.20"
}

variable "azure_vpn_psk_primary" {
  description = "Pre-shared key for the primary (CORE-R2) VPN connection. Pass via TF_VAR_azure_vpn_psk_primary, never in a committed file."
  type        = string
  sensitive   = true
}

variable "azure_vpn_psk_backup" {
  description = "Pre-shared key for the backup (CORE-R1) VPN connection. Pass via TF_VAR_azure_vpn_psk_backup, never in a committed file."
  type        = string
  sensitive   = true
}

variable "tags" {
  type = map(string)
  default = {
    project     = "enterprise-hybrid-network-sim"
    managed_by  = "terraform"
    environment = "lab"
  }
}
