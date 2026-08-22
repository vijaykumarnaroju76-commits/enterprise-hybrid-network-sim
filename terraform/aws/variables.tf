# Defaults match documentation/architecture.md and documentation/cloud-networking.md.
# Override environment-specific values (account/region/public IPs/PSKs) via
# a terraform.tfvars file (never committed) or TF_VAR_ environment variables.

variable "aws_region" {
  description = "AWS region to provision into."
  type        = string
  default     = "us-east-1"
}

variable "prod_vpc_cidr" {
  type    = string
  default = "172.31.0.0/16"
}

variable "dev_vpc_cidr" {
  type    = string
  default = "172.30.0.0/16"
}

variable "onprem_aggregate_cidr" {
  description = "On-prem summary route advertised by the enterprise, per routing.md section 4."
  type        = string
  default     = "10.0.0.0/8"
}

variable "tgw_asn" {
  description = "Transit Gateway BGP ASN, per routing.md section 2."
  type        = number
  default     = 64512
}

variable "core_r1_public_ip" {
  description = "CORE-R1 public/WAN IP — customer gateway for the primary AWS VPN connection."
  type        = string
  default     = "203.0.113.21"
}

variable "core_r2_public_ip" {
  description = "CORE-R2 public/WAN IP — customer gateway for the backup AWS VPN connection."
  type        = string
  default     = "203.0.113.20"
}

variable "aws_vpn_psk_primary" {
  description = "Pre-shared key for the primary (CORE-R1) VPN connection. Pass via TF_VAR_aws_vpn_psk_primary, never in a committed file."
  type        = string
  sensitive   = true
}

variable "aws_vpn_psk_backup" {
  description = "Pre-shared key for the backup (CORE-R2) VPN connection. Pass via TF_VAR_aws_vpn_psk_backup, never in a committed file."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Common resource tags."
  type        = map(string)
  default = {
    Project     = "enterprise-hybrid-network-sim"
    ManagedBy   = "terraform"
    Environment = "lab"
  }
}
