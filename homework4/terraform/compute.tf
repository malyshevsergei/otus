# Nginx instances
resource "yandex_compute_instance" "nginx" {
  count = var.nginx_count

  name        = "nginx-${count.index + 1}"
  hostname    = "nginx-${count.index + 1}"
  platform_id = "standard-v2"
  zone        = var.yc_zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.yc_image_id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.main.id
    security_group_ids = [yandex_vpc_security_group.nginx.id]
    nat                = true
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
  }

  scheduling_policy {
    preemptible = false
  }
}

# Backend instances
resource "yandex_compute_instance" "backend" {
  count = var.backend_count

  name        = "backend-${count.index + 1}"
  hostname    = "backend-${count.index + 1}"
  platform_id = "standard-v2"
  zone        = var.yc_zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = var.yc_image_id
      size     = 30
      type     = "network-hdd"
    }
  }

  # Additional disk for NFS
  secondary_disk {
    disk_id = yandex_compute_disk.nfs[count.index].id
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.main.id
    security_group_ids = [yandex_vpc_security_group.backend.id]
    nat                = true
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
  }

  scheduling_policy {
    preemptible = false
  }
}

# Additional disks for NFS on backend servers
resource "yandex_compute_disk" "nfs" {
  count = var.backend_count

  name = "nfs-disk-${count.index + 1}"
  type = "network-hdd"
  zone = var.yc_zone
  size = 10
}

# Database instance
resource "yandex_compute_instance" "database" {
  name        = "database"
  hostname    = "database"
  platform_id = "standard-v2"
  zone        = var.yc_zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = var.yc_image_id
      size     = 40
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.main.id
    security_group_ids = [yandex_vpc_security_group.database.id]
    nat                = true
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
  }

  scheduling_policy {
    preemptible = false
  }
}
