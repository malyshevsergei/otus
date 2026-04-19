terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.87"
    }
  }
}

provider "yandex" {}

# Network
resource "yandex_vpc_network" "homework8_network" {
  name = "homework8-network"
}

resource "yandex_vpc_subnet" "homework8_subnet" {
  name           = "homework8-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.homework8_network.id
  v4_cidr_blocks = ["10.132.0.0/24"]
}

# Security Group
resource "yandex_vpc_security_group" "homework8_sg" {
  name       = "homework8-sg"
  network_id = yandex_vpc_network.homework8_network.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTPS"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol       = "TCP"
    description    = "Kafka"
    v4_cidr_blocks = ["10.132.0.0/24"]
    port           = 9092
  }

  ingress {
    protocol       = "TCP"
    description    = "Elasticsearch HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 9200
  }

  ingress {
    protocol       = "TCP"
    description    = "Kibana"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 5601
  }

  egress {
    protocol       = "ANY"
    description    = "All outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web node (nginx + wordpress)
resource "yandex_compute_instance" "web" {
  name        = "web-1"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = var.web_cores
    memory = var.web_memory
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.web_disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.homework8_subnet.id
    nat                = true
    ip_address         = "10.132.0.11"
    security_group_ids = [yandex_vpc_security_group.homework8_sg.id]
  }

  metadata = {
    user-data = file("cloud-init.yml")
  }
}

# Kafka node
resource "yandex_compute_instance" "kafka" {
  name        = "kafka-1"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = var.kafka_cores
    memory = var.kafka_memory
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.kafka_disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.homework8_subnet.id
    nat                = true
    ip_address         = "10.132.0.20"
    security_group_ids = [yandex_vpc_security_group.homework8_sg.id]
  }

  metadata = {
    user-data = file("cloud-init.yml")
  }
}

# ELK node (Elasticsearch + Logstash + Kibana)
resource "yandex_compute_instance" "elk" {
  name        = "elk-1"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = var.elk_cores
    memory = var.elk_memory
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = var.elk_disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.homework8_subnet.id
    nat                = true
    ip_address         = "10.132.0.30"
    security_group_ids = [yandex_vpc_security_group.homework8_sg.id]
  }

  metadata = {
    user-data = file("cloud-init.yml")
  }
}
