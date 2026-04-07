output "elastic_public_ips" {
  value = yandex_compute_instance.elastic[*].network_interface[0].nat_ip_address
}

output "elastic_internal_ips" {
  value = yandex_compute_instance.elastic[*].network_interface[0].ip_address
}

output "logstash_public_ip" {
  value = yandex_compute_instance.logstash.network_interface[0].nat_ip_address
}

output "logstash_internal_ip" {
  value = yandex_compute_instance.logstash.network_interface[0].ip_address
}

output "kibana_url" {
  value = "http://${yandex_compute_instance.logstash.network_interface[0].nat_ip_address}:5601"
}

output "elasticsearch_url" {
  value = "http://${yandex_compute_instance.elastic[0].network_interface[0].nat_ip_address}:9200"
}
