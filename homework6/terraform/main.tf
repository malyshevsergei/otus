terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.195.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "yandex" {
  zone = var.zone
}

# --- Network ---

resource "yandex_vpc_network" "patroni" {
  name = "patroni-network"
}

resource "yandex_vpc_subnet" "patroni" {
  name           = "patroni-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.patroni.id
  v4_cidr_blocks = ["10.130.0.0/24"]
}

# --- Security Group ---

resource "yandex_vpc_security_group" "patroni" {
  name       = "patroni-sg"
  network_id = yandex_vpc_network.patroni.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "SSH"
  }

  ingress {
    protocol       = "TCP"
    port           = 5432
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "PostgreSQL"
  }

  ingress {
    protocol       = "TCP"
    port           = 5000
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "HAProxy PostgreSQL RW"
  }

  ingress {
    protocol       = "TCP"
    port           = 5001
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "HAProxy PostgreSQL RO"
  }

  ingress {
    protocol       = "TCP"
    port           = 7000
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "HAProxy Stats"
  }

  ingress {
    protocol       = "TCP"
    port           = 2379
    v4_cidr_blocks = ["10.130.0.0/24"]
    description    = "etcd client"
  }

  ingress {
    protocol       = "TCP"
    port           = 2380
    v4_cidr_blocks = ["10.130.0.0/24"]
    description    = "etcd peer"
  }

  ingress {
    protocol       = "TCP"
    port           = 8008
    v4_cidr_blocks = ["10.130.0.0/24"]
    description    = "Patroni REST API"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outbound"
  }
}

# --- Patroni Nodes (etcd + patroni + postgresql) ---

resource "yandex_compute_instance" "patroni" {
  count       = 3
  name        = "patroni-${count.index + 1}"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = var.vm_cores
    memory = var.vm_memory
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.patroni.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.patroni.id]
    ip_address         = "10.130.0.${11 + count.index}"
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.ssh_public_key_path)}"
    user-data = file("${path.module}/cloud-init.yml")
  }
}

# --- HAProxy Node ---

resource "yandex_compute_instance" "haproxy" {
  name        = "haproxy-1"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 15
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.patroni.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.patroni.id]
    ip_address         = "10.130.0.20"
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.ssh_public_key_path)}"
    user-data = file("${path.module}/cloud-init.yml")
  }
}
