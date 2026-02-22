output "instance_id" {
  description = "ID of the created compute instance"
  value       = yandex_compute_instance.instance.id
}

output "instance_name" {
  description = "Name of the compute instance"
  value       = yandex_compute_instance.instance.name
}

output "internal_ip_address" {
  description = "Internal IP address of the instance"
  value       = yandex_compute_instance.instance.network_interface[0].ip_address
}

output "external_ip_address" {
  description = "External IP address of the instance (if NAT is enabled)"
  value       = var.nat ? yandex_compute_instance.instance.network_interface[0].nat_ip_address : null
}

output "fqdn" {
  description = "Fully qualified domain name of the instance"
  value       = yandex_compute_instance.instance.fqdn
}

output "status" {
  description = "Status of the instance"
  value       = yandex_compute_instance.instance.status
}
