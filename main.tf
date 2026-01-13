locals {
  common_tags = {
    project     = "three-tier-azure"
    managed_by  = "terraform"
    environment = "shared"
  }

  environments = {
    sev = {
      location      = "eastus"
      address_space = ["10.10.0.0/16"]
      subnets = {
        web = {
          cidr = "10.10.1.0/24"
        }
        app = {
          cidr = "10.10.2.0/24"
        }
        data = {
          cidr = "10.10.3.0/24"
        }
      }
      nsg_rules = {
        web = [
          {
            name                       = "allow-http"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_port_range          = "*"
            destination_port_range     = "80"
            source_address_prefix      = "*"
            destination_address_prefix = "*"
          }
        ]
        app = [
          {
            name                       = "allow-web"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_port_range          = "*"
            destination_port_range     = "8080"
            source_address_prefix      = "10.10.1.0/24"
            destination_address_prefix = "*"
          }
        ]
        data = [
          {
            name                       = "allow-app"
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_port_range          = "*"
            destination_port_range     = "5432"
            source_address_prefix      = "10.10.2.0/24"
            destination_address_prefix = "*"
          }
        ]
      }
      vmss_tiers = {
        web = {
          instance_count = 2
          sku            = "Standard_B2s"
          subnet_key     = "web"
        }
        app = {
          instance_count = 2
          sku            = "Standard_B2s"
          subnet_key     = "app"
        }
      }
      db_vm = {
        size       = "Standard_B2s"
        subnet_key = "data"
      }
      tags = {
        environment = "sev"
        cost_center = "1001"
      }
    }
    stage = {
      location      = "eastus"
      address_space = ["10.20.0.0/16"]
      subnets = {
        web = {
          cidr = "10.20.1.0/24"
        }
        app = {
          cidr = "10.20.2.0/24"
        }
        data = {
          cidr = "10.20.3.0/24"
        }
      }
      nsg_rules = {
        web  = local.environments.sev.nsg_rules.web
        app  = local.environments.sev.nsg_rules.app
        data = local.environments.sev.nsg_rules.data
      }
      vmss_tiers = {
        web = {
          instance_count = 2
          sku            = "Standard_B2s"
          subnet_key     = "web"
        }
        app = {
          instance_count = 2
          sku            = "Standard_B2s"
          subnet_key     = "app"
        }
      }
      db_vm = {
        size       = "Standard_B2s"
        subnet_key = "data"
      }
      tags = {
        environment = "stage"
        cost_center = "2001"
      }
    }
    prod = {
      location      = "eastus2"
      address_space = ["10.30.0.0/16"]
      subnets = {
        web = {
          cidr = "10.30.1.0/24"
        }
        app = {
          cidr = "10.30.2.0/24"
        }
        data = {
          cidr = "10.30.3.0/24"
        }
      }
      nsg_rules = {
        web  = local.environments.sev.nsg_rules.web
        app  = local.environments.sev.nsg_rules.app
        data = local.environments.sev.nsg_rules.data
      }
      vmss_tiers = {
        web = {
          instance_count = 3
          sku            = "Standard_B4ms"
          subnet_key     = "web"
        }
        app = {
          instance_count = 3
          sku            = "Standard_B4ms"
          subnet_key     = "app"
        }
      }
      db_vm = {
        size       = "Standard_B4ms"
        subnet_key = "data"
      }
      tags = {
        environment = "prod"
        cost_center = "3001"
      }
    }
  }
}

module "three_tier" {
  source   = "./modules/three_tier"
  for_each = local.environments

  environment   = each.key
  location      = each.value.location
  address_space = each.value.address_space
  subnets       = each.value.subnets
  nsg_rules     = each.value.nsg_rules
  vmss_tiers    = each.value.vmss_tiers
  db_vm         = each.value.db_vm
  tags          = merge(local.common_tags, each.value.tags)
}
