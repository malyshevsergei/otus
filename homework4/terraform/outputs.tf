output "load_balancer_ip" {
  description = "External IP address of the load balancer"
  value       = yandex_lb_network_load_balancer.web.listener.*.external_address_spec[0].*.address
}

output "nginx_instances" {
  description = "Nginx instances information"
  value = [
    for instance in yandex_compute_instance.nginx : {
      name       = instance.name
      internal_ip = instance.network_interface[0].ip_address
      external_ip = instance.network_interface[0].nat_ip_address
    }
  ]
}

output "backend_instances" {
  description = "Backend instances information"
  value = [
    for instance in yandex_compute_instance.backend : {
      name       = instance.name
      internal_ip = instance.network_interface[0].ip_address
      external_ip = instance.network_interface[0].nat_ip_address
    }
  ]
}

output "database_instance" {
  description = "Database instance information"
  value = {
    name       = yandex_compute_instance.database.name
    internal_ip = yandex_compute_instance.database.network_interface[0].ip_address
    external_ip = yandex_compute_instance.database.network_interface[0].nat_ip_address
  }
}

output "ansible_inventory" {
  description = "Ansible inventory in INI format"
  value = templatefile("${path.module}/templates/inventory.tpl", {
    nginx_instances   = yandex_compute_instance.nginx
    backend_instances = yandex_compute_instance.backend
    database_instance = yandex_compute_instance.database
    ssh_user         = var.ssh_user
  })
}
