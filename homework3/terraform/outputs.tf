output "lb_public_ip" {
  description = "Load balancer public IP — open this in a browser"
  value       = yandex_compute_instance.lb.network_interface[0].nat_ip_address
}

output "backend_public_ips" {
  description = "Backend public IPs (for Ansible management)"
  value       = [for b in yandex_compute_instance.backend : b.network_interface[0].nat_ip_address]
}

output "backend_private_ips" {
  description = "Backend private IPs (used in Nginx upstream)"
  value       = [for b in yandex_compute_instance.backend : b.network_interface[0].ip_address]
}

output "db_public_ip" {
  description = "Database VM public IP (for Ansible management)"
  value       = yandex_compute_instance.db.network_interface[0].nat_ip_address
}
