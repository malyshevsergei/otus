terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.199.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "yandex" {
  zone = var.zone
}

# --- Network ---

resource "yandex_vpc_network" "consul" {
  name = "consul-network"
}

# NAT gateway — provides outbound internet to VMs that have no public IP
resource "yandex_vpc_gateway" "nat" {
  name = "consul-nat-gateway"
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "nat" {
  name       = "consul-nat-route"
  network_id = yandex_vpc_network.consul.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

resource "yandex_vpc_subnet" "consul" {
  name           = "consul-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.consul.id
  v4_cidr_blocks = ["10.132.0.0/24"]
  route_table_id = yandex_vpc_route_table.nat.id
}

# --- Security Group ---

resource "yandex_vpc_security_group" "consul" {
  name       = "consul-sg"
  network_id = yandex_vpc_network.consul.id

  # SSH — only to bastion from outside; other nodes via ProxyJump
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "SSH (bastion)"
  }

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "HTTP web portal"
  }

  ingress {
    protocol       = "TCP"
    port           = 8500
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Consul HTTP UI/API"
  }

  # Consul internal ports — cluster only
  ingress {
    protocol       = "TCP"
    port           = 8300
    v4_cidr_blocks = ["10.132.0.0/24"]
    description    = "Consul server RPC"
  }

  ingress {
    protocol       = "TCP"
    port           = 8301
    v4_cidr_blocks = ["10.132.0.0/24"]
    description    = "Consul LAN serf TCP"
  }

  ingress {
    protocol       = "UDP"
    port           = 8301
    v4_cidr_blocks = ["10.132.0.0/24"]
    description    = "Consul LAN serf UDP"
  }

  ingress {
    protocol       = "TCP"
    port           = 8302
    v4_cidr_blocks = ["10.132.0.0/24"]
    description    = "Consul WAN serf TCP"
  }

  ingress {
    protocol       = "UDP"
    port           = 8302
    v4_cidr_blocks = ["10.132.0.0/24"]
    description    = "Consul WAN serf UDP"
  }

  ingress {
    protocol       = "TCP"
    port           = 8600
    v4_cidr_blocks = ["10.132.0.0/24"]
    description    = "Consul DNS TCP"
  }

  ingress {
    protocol       = "UDP"
    port           = 8600
    v4_cidr_blocks = ["10.132.0.0/24"]
    description    = "Consul DNS UDP"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outbound"
  }
}

# --- Consul Server Nodes (3x) ---
# consul-server-1 (index 0) is the bastion — the only VM with a public IP.
# consul-server-2 and consul-server-3 reach the internet via the NAT gateway.

resource "yandex_compute_instance" "consul_server" {
  count       = 3
  name        = "consul-server-${count.index + 1}"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = var.consul_server_cores
    memory = var.consul_server_memory
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.consul.id
    nat                = count.index == 0   # public IP only on consul-server-1
    security_group_ids = [yandex_vpc_security_group.consul.id]
    ip_address         = "10.132.0.${11 + count.index}"
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.ssh_public_key_path)}"
    user-data = file("${path.module}/cloud-init.yml")
  }
}

# --- Web Server Nodes (2x) — nginx + Consul client ---
# No public IPs; reached via ProxyJump through consul-server-1.

resource "yandex_compute_instance" "web" {
  count       = 2
  name        = "web-${count.index + 1}"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = var.web_cores
    memory = var.web_memory
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.consul.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.consul.id]
    ip_address         = "10.132.0.${21 + count.index}"
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.ssh_public_key_path)}"
    user-data = file("${path.module}/cloud-init.yml")
  }
}
