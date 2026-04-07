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

resource "yandex_vpc_network" "elk" {
  name = "elk-network"
}

resource "yandex_vpc_subnet" "elk" {
  name           = "elk-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.elk.id
  v4_cidr_blocks = ["10.131.0.0/24"]
}

# --- Security Group ---

resource "yandex_vpc_security_group" "elk" {
  name       = "elk-sg"
  network_id = yandex_vpc_network.elk.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "SSH"
  }

  ingress {
    protocol       = "TCP"
    port           = 9200
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Elasticsearch HTTP"
  }

  ingress {
    protocol       = "TCP"
    port           = 9300
    v4_cidr_blocks = ["10.131.0.0/24"]
    description    = "Elasticsearch transport"
  }

  ingress {
    protocol       = "TCP"
    port           = 5601
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Kibana"
  }

  ingress {
    protocol       = "TCP"
    port           = 5044
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Logstash Beats input"
  }

  ingress {
    protocol       = "TCP"
    port           = 5432
    v4_cidr_blocks = ["10.131.0.0/24"]
    description    = "PostgreSQL (for log sources)"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outbound"
  }
}

# --- Elasticsearch Nodes (3x) ---

resource "yandex_compute_instance" "elastic" {
  count       = 3
  name        = "elastic-${count.index + 1}"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = var.es_cores
    memory = var.es_memory
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.es_disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.elk.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.elk.id]
    ip_address         = "10.131.0.${11 + count.index}"
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.ssh_public_key_path)}"
    user-data = file("${path.module}/cloud-init.yml")
  }
}

# --- Logstash + Kibana Node ---

resource "yandex_compute_instance" "logstash" {
  name        = "logstash-1"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.elk.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.elk.id]
    ip_address         = "10.131.0.20"
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.ssh_public_key_path)}"
    user-data = file("${path.module}/cloud-init.yml")
  }
}
