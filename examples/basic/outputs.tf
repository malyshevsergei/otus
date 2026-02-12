output "instance_id" {
  description = "ID of the created instance"
  value       = module.vm.instance_id
}

output "internal_ip" {
  description = "Internal IP address"
  value       = module.vm.internal_ip_address
}

output "external_ip" {
  description = "External IP address"
  value       = module.vm.external_ip_address
}

output "fqdn" {
  description = "FQDN of the instance"
  value       = module.vm.fqdn
}
