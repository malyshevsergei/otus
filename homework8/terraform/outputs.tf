output "web_public_ip" {
  value = yandex_compute_instance.web.network_interface[0].nat_ip_address
}

output "web_internal_ip" {
  value = yandex_compute_instance.web.network_interface[0].ip_address
}

output "kafka_public_ip" {
  value = yandex_compute_instance.kafka.network_interface[0].nat_ip_address
}

output "kafka_internal_ip" {
  value = yandex_compute_instance.kafka.network_interface[0].ip_address
}

output "elk_public_ip" {
  value = yandex_compute_instance.elk.network_interface[0].nat_ip_address
}

output "elk_internal_ip" {
  value = yandex_compute_instance.elk.network_interface[0].ip_address
}

output "kibana_url" {
  value = "http://${yandex_compute_instance.elk.network_interface[0].nat_ip_address}:5601"
}

output "web_url" {
  value = "http://${yandex_compute_instance.web.network_interface[0].nat_ip_address}"
}
