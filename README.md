# Azure 3-Tier VMSS Terraform (Module-based)

This repository provides a reusable, module-driven Terraform layout for a **3-tier architecture** on Azure using **VM Scale Sets**. It is designed to be:

- **Environment-aware** (sev, stage, prod)
- **Readable and reusable** through `for_each`, `dynamic` blocks, and data-driven configuration
- **Easy to test and modify** by editing a single environment map

## Architecture Summary

Each environment provisions:

- Resource group
- Virtual network + subnets (web, app, data)
- NSGs with dynamic rules per subnet
- Load balancers (public web tier, internal app tier)
- VM scale sets for **web** and **app** tiers
- Single VM for **database** tier (baseline example; replace with PaaS if desired)

## Structure

```
.
├── main.tf
├── outputs.tf
├── providers.tf
├── versions.tf
└── modules
    └── three_tier
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

## How to Use

### 1) Configure environments
All environments live in `main.tf` under `local.environments`. Add or modify entries for `sev`, `stage`, and `prod`.

Key inputs per environment:

- `location`
- `address_space`
- `subnets` (web/app/data)
- `nsg_rules` (per subnet)
- `vmss_tiers` (web/app)
- `db_vm` (data tier VM)
- `tags`

### 2) Initialize and plan

```bash
terraform init
terraform plan
```

### 3) Apply

```bash
terraform apply
```

## Customization Tips

- **Security rules**: Update `nsg_rules` in `main.tf`. Each subnet accepts a list of rules.
- **Scale set size**: Change `instance_count` or `sku` for each tier in `vmss_tiers`.
- **Database tier**: Replace `azurerm_linux_virtual_machine` with managed database services as needed.
- **Load balancers**: The module uses a local map in `modules/three_tier/main.tf`. Extend to add rules or tiers.

## Notes

- SSH keys are placeholder values in the module. Replace them before production use.
- This layout is intentionally generic so it can be adapted for different industries or compliance needs.

## Outputs

- `resource_groups`: RG name per environment
- `web_lb_public_ips`: web LB public IP per environment
- `subnet_ids`: subnet IDs per environment (module output)
