output "resource_groups" {
  description = "Resource groups per environment."
  value = {
    for env, mod in module.three_tier : env => mod.resource_group_name
  }
}

output "web_lb_public_ips" {
  description = "Public IPs for the web tier load balancers."
  value = {
    for env, mod in module.three_tier : env => mod.web_lb_public_ip
  }
}
