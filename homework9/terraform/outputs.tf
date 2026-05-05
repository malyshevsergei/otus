output "bastion_public_ip" {
  description = "Public IP of consul-server-1 (SSH bastion + Consul UI)"
  value       = yandex_compute_instance.consul_server[0].network_interface[0].nat_ip_address
}

output "consul_server_internal_ips" {
  description = "Internal IPs of all Consul server nodes"
  value       = yandex_compute_instance.consul_server[*].network_interface[0].ip_address
}

output "web_internal_ips" {
  description = "Internal IPs of web server nodes (no public IP — use ProxyJump)"
  value       = yandex_compute_instance.web[*].network_interface[0].ip_address
}

output "consul_ui" {
  description = "Consul Web UI"
  value       = "http://${yandex_compute_instance.consul_server[0].network_interface[0].nat_ip_address}:8500"
}

output "dns_lookup_example" {
  description = "Query webapp DNS through Consul (run from inside the cluster)"
  value       = "dig @10.132.0.11 -p 8600 webapp.service.consul"
}

output "ssh_bastion" {
  description = "SSH command for the bastion node"
  value       = "ssh ubuntu@${yandex_compute_instance.consul_server[0].network_interface[0].nat_ip_address}"
}

output "ssh_web1_via_bastion" {
  description = "SSH to web-1 through the bastion"
  value       = "ssh -J ubuntu@${yandex_compute_instance.consul_server[0].network_interface[0].nat_ip_address} ubuntu@10.132.0.21"
}
