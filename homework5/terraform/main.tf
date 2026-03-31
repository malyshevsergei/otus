terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.195.0"
    }
  }
  required_version = ">= 1.0"
}

provider "yandex" {
  # token     = var.yc_token  # Или используйте: export YC_TOKEN=<your_token>
  # cloud_id  = var.cloud_id
  # folder_id = var.folder_id
  zone = var.zone
}

# Переменные
variable "zone" {
  description = "Yandex Cloud zone"
  type        = string
  default     = "ru-central1-a"
}

variable "vm_name" {
  description = "VM name"
  type        = string
  default     = "mysql-innodb-cluster"
}

variable "vm_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 4
}

variable "vm_memory" {
  description = "RAM size in GB"
  type        = number
  default     = 8
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 50
}

variable "ssh_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# Создание сети
resource "yandex_vpc_network" "mysql_network" {
  name = "mysql-cluster-network"
}

# Создание подсети
resource "yandex_vpc_subnet" "mysql_subnet" {
  name           = "mysql-cluster-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.mysql_network.id
  v4_cidr_blocks = ["10.128.0.0/24"]
}

# Security Group для MySQL кластера
resource "yandex_vpc_security_group" "mysql_sg" {
  name       = "mysql-cluster-sg"
  network_id = yandex_vpc_network.mysql_network.id

  # SSH
  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # MySQL Router Read-Write
  ingress {
    protocol       = "TCP"
    port           = 6446
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # MySQL Router Read-Only
  ingress {
    protocol       = "TCP"
    port           = 6447
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # MySQL Server 1
  ingress {
    protocol       = "TCP"
    port           = 3311
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # MySQL Server 2
  ingress {
    protocol       = "TCP"
    port           = 3312
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # MySQL Server 3
  ingress {
    protocol       = "TCP"
    port           = 3313
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # Исходящий трафик
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# Создание VM
resource "yandex_compute_instance" "mysql_cluster_vm" {
  name        = var.vm_name
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = var.vm_cores
    memory = var.vm_memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.mysql_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.mysql_sg.id]
  }

  metadata = {
    ssh-keys  = "ubuntu:${file(var.ssh_key_path)}"
    user-data = templatefile("${path.module}/cloud-init.yml", {})
  }

  scheduling_policy {
    preemptible = false
  }
}

# Получение образа Ubuntu
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# Outputs
output "external_ip" {
  description = "External IP address of the VM"
  value       = yandex_compute_instance.mysql_cluster_vm.network_interface[0].nat_ip_address
}

output "internal_ip" {
  description = "Internal IP address of the VM"
  value       = yandex_compute_instance.mysql_cluster_vm.network_interface[0].ip_address
}

output "ssh_connection" {
  description = "SSH connection command"
  value       = "ssh ubuntu@${yandex_compute_instance.mysql_cluster_vm.network_interface[0].nat_ip_address}"
}

output "mysql_rw_connection" {
  description = "MySQL Read-Write connection"
  value       = "mysql -h ${yandex_compute_instance.mysql_cluster_vm.network_interface[0].nat_ip_address} -P 6446 -uappuser -papppass project_db"
}

output "mysql_ro_connection" {
  description = "MySQL Read-Only connection"
  value       = "mysql -h ${yandex_compute_instance.mysql_cluster_vm.network_interface[0].nat_ip_address} -P 6447 -uappuser -papppass project_db"
}
