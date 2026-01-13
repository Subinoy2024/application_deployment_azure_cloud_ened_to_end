locals {
  name_prefix = "${var.environment}-3tier"

  load_balancers = {
    web = {
      public         = true
      subnet_key     = "web"
      frontend_port  = 80
      backend_port   = 80
      probe_port     = 80
      tier_name      = "web"
      protocol       = "Tcp"
    }
    app = {
      public         = false
      subnet_key     = "app"
      frontend_port  = 8080
      backend_port   = 8080
      probe_port     = 8080
      tier_name      = "app"
      protocol       = "Tcp"
    }
  }

  admin_username = "azureuser"
}

resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.address_space
  tags                = var.tags
}

resource "azurerm_network_security_group" "this" {
  for_each            = var.subnets
  name                = "${local.name_prefix}-${each.key}-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = lookup(var.nsg_rules, each.key, [])
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
}

resource "azurerm_subnet" "this" {
  for_each             = var.subnets
  name                 = "${local.name_prefix}-${each.key}-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value.cidr]
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

resource "azurerm_public_ip" "lb" {
  for_each            = { for name, lb in local.load_balancers : name => lb if lb.public }
  name                = "${local.name_prefix}-${each.key}-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_lb" "this" {
  for_each            = local.load_balancers
  name                = "${local.name_prefix}-${each.key}-lb"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "${each.key}-frontend"
    subnet_id            = each.value.public ? null : azurerm_subnet.this[each.value.subnet_key].id
    public_ip_address_id = each.value.public ? azurerm_public_ip.lb[each.key].id : null
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  for_each        = local.load_balancers
  name            = "${local.name_prefix}-${each.key}-backend"
  loadbalancer_id = azurerm_lb.this[each.key].id
}

resource "azurerm_lb_probe" "this" {
  for_each        = local.load_balancers
  name            = "${local.name_prefix}-${each.key}-probe"
  loadbalancer_id = azurerm_lb.this[each.key].id
  protocol        = each.value.protocol
  port            = each.value.probe_port
}

resource "azurerm_lb_rule" "this" {
  for_each                       = local.load_balancers
  name                           = "${local.name_prefix}-${each.key}-rule"
  loadbalancer_id                = azurerm_lb.this[each.key].id
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  frontend_ip_configuration_name = "${each.key}-frontend"
  probe_id                       = azurerm_lb_probe.this[each.key].id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this[each.key].id]
}

resource "azurerm_linux_virtual_machine_scale_set" "this" {
  for_each            = var.vmss_tiers
  name                = "${local.name_prefix}-${each.key}-vmss"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = each.value.sku
  instances           = each.value.instance_count
  admin_username      = local.admin_username
  tags                = var.tags

  admin_ssh_key {
    username   = local.admin_username
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDcEXAMPLEKEY"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "${local.name_prefix}-${each.key}-nic"
    primary = true

    ip_configuration {
      name      = "${local.name_prefix}-${each.key}-ipcfg"
      primary   = true
      subnet_id = azurerm_subnet.this[each.value.subnet_key].id
      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.this[each.key].id
      ]
    }
  }
}

resource "azurerm_network_interface" "db" {
  name                = "${local.name_prefix}-db-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  ip_configuration {
    name      = "${local.name_prefix}-db-ipcfg"
    subnet_id = azurerm_subnet.this[var.db_vm.subnet_key].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "db" {
  name                = "${local.name_prefix}-db"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  size                = var.db_vm.size
  admin_username      = local.admin_username
  tags                = var.tags
  network_interface_ids = [
    azurerm_network_interface.db.id
  ]

  admin_ssh_key {
    username   = local.admin_username
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDcEXAMPLEKEY"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}
