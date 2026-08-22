# Terraform — Cloud Provisioning

Provisions the AWS and Azure sides of the hybrid design documented in [`../documentation/cloud-networking.md`](../documentation/cloud-networking.md). All CIDRs, ASNs, and tunnel endpoints match that document and [`../documentation/architecture.md`](../documentation/architecture.md) exactly — this is the implementation of that design, not an independent one.

```
terraform/
  aws/       Prod + Dev VPC, Transit Gateway, Site-to-Site VPN (primary + backup)
  azure/     Prod + Dev VNet, per-VNet VPN Gateway, UDRs
```

The two clouds are deliberately independent Terraform root modules (separate state, separate `terraform apply`) rather than one combined module, because they use different providers/credentials and, per the architecture, don't peer with each other directly — there's no shared resource between them to justify combining state.

## Usage

```bash
cd terraform/aws
terraform init
terraform plan -var-file=terraform.tfvars   # see variables.tf for required vars
terraform apply

cd ../azure
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply
```

Never commit a populated `terraform.tfvars` — it holds environment-specific values (account/subscription IDs, customer-gateway public IPs, pre-shared keys). `.gitignore` at the repo root excludes `*.tfvars` and Terraform state; only `*.tfvars.example` files are tracked.

Pre-shared keys for the VPN connections are read from variables (`aws_vpn_psk_primary`, `aws_vpn_psk_backup`, `azure_vpn_psk_primary`, `azure_vpn_psk_backup`) — pass them via `TF_VAR_...` environment variables or a secrets manager, never in a checked-in `.tfvars` file, matching the "PSKs should be 32+ characters, random, never in version control" guidance already in [`../lab-notes/implementation-notes.md`](../lab-notes/implementation-notes.md).

## What Terraform does *not* provision

The on-premises routers (CORE-R1/R2, SITE1-4) are simulated GNS3/lab devices, not cloud resources — their configuration lives in [`../documentation/routing.md`](../documentation/routing.md) as router config blocks, applied manually or via the [Ansible/Netmiko automation](../automation/), not Terraform. Terraform's job here stops at the cloud edge: VPCs/VNets, subnets, route tables/UDRs, Transit Gateway, VPN Gateway, and the customer/local network gateway objects that define where the on-prem side of each tunnel terminates.

## Validating what Terraform built

After `apply`, cross-check the outputs against [`../documentation/cloud-networking.md`](../documentation/cloud-networking.md) §4's `aws`/`az` CLI commands, and against the on-prem `show ip bgp summary` output in [`../documentation/routing.md`](../documentation/routing.md) §6 — a healthy hybrid path requires both the Terraform-provisioned cloud state and the on-prem BGP state to agree.
