output "patroni_public_ips" {
  value = yandex_compute_instance.patroni[*].network_interface[0].nat_ip_address
}

output "patroni_internal_ips" {
  value = yandex_compute_instance.patroni[*].network_interface[0].ip_address
}

output "haproxy_public_ip" {
  value = yandex_compute_instance.haproxy.network_interface[0].nat_ip_address
}

output "haproxy_internal_ip" {
  value = yandex_compute_instance.haproxy.network_interface[0].ip_address
}

output "connection_string" {
  value = "psql -h ${yandex_compute_instance.haproxy.network_interface[0].nat_ip_address} -p 5000 -U appuser -d project_db"
}

output "haproxy_stats" {
  value = "http://${yandex_compute_instance.haproxy.network_interface[0].nat_ip_address}:7000/stats"
}
