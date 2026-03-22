data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# ── Network ───────────────────────────────────────────────────────────────────
resource "yandex_vpc_network" "net" {
  name      = "lb-network"
  folder_id = var.folder_id
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "lb-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.net.id
  folder_id      = var.folder_id
  v4_cidr_blocks = ["10.0.0.0/24"]
}

# ── Load balancer VM ──────────────────────────────────────────────────────────
resource "yandex_compute_instance" "lb" {
  name        = "lb"
  hostname    = "lb"
  zone        = var.zone
  folder_id   = var.folder_id
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.subnet.id
    ip_address = "10.0.0.10"
    nat        = true   # public IP — entry point for users
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  scheduling_policy { preemptible = true }
}

# ── Database VM ───────────────────────────────────────────────────────────────
resource "yandex_compute_instance" "db" {
  name        = "db"
  hostname    = "db"
  zone        = var.zone
  folder_id   = var.folder_id
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.subnet.id
    ip_address = "10.0.0.20"
    nat        = true   # NAT for Ansible access and package installs
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  scheduling_policy { preemptible = true }
}

# ── Backend VMs ───────────────────────────────────────────────────────────────
resource "yandex_compute_instance" "backend" {
  count       = 2
  name        = "backend-${count.index + 1}"
  hostname    = "backend-${count.index + 1}"
  zone        = var.zone
  folder_id   = var.folder_id
  platform_id = "standard-v3"

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.subnet.id
    ip_address = "10.0.0.${11 + count.index}"
    nat        = true   # NAT for Ansible access and package installs
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  scheduling_policy { preemptible = true }
}
