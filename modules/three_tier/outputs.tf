output "resource_group_name" {
  description = "Resource group name for the environment."
  value       = azurerm_resource_group.this.name
}

output "web_lb_public_ip" {
  description = "Web tier load balancer public IP address."
  value       = try(azurerm_public_ip.lb["web"].ip_address, null)
}

output "subnet_ids" {
  description = "Subnet IDs by name."
  value = {
    for key, subnet in azurerm_subnet.this : key => subnet.id
  }
}
