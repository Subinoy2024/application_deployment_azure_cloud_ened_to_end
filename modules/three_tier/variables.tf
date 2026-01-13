variable "environment" {
  description = "Environment name (sev/stage/prod)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "address_space" {
  description = "VNet address space."
  type        = list(string)
}

variable "subnets" {
  description = "Subnet map keyed by tier with CIDR ranges."
  type = map(object({
    cidr = string
  }))
}

variable "nsg_rules" {
  description = "NSG rules per subnet key."
  type = map(list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  })))
}

variable "vmss_tiers" {
  description = "Map of VM scale set tiers to create."
  type = map(object({
    instance_count = number
    sku            = string
    subnet_key     = string
  }))
}

variable "db_vm" {
  description = "Configuration for the database VM."
  type = object({
    size       = string
    subnet_key = string
  })
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
