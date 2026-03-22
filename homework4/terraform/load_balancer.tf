# Network Load Balancer
resource "yandex_lb_network_load_balancer" "web" {
  name = "web-load-balancer"

  listener {
    name = "http-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.nginx.id

    healthcheck {
      name = "http-check"
      http_options {
        port = 80
        path = "/health"
      }
    }
  }
}

# Target group for Nginx instances
resource "yandex_lb_target_group" "nginx" {
  name = "nginx-target-group"

  dynamic "target" {
    for_each = yandex_compute_instance.nginx
    content {
      subnet_id = yandex_vpc_subnet.main.id
      address   = target.value.network_interface[0].ip_address
    }
  }
}
