# VPC Network
resource "yandex_vpc_network" "main" {
  name        = "otus-network"
  description = "Network for OTUS homework"
}

# Subnet for all VMs
resource "yandex_vpc_subnet" "main" {
  name           = "otus-subnet"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

# Security group for Nginx servers
resource "yandex_vpc_security_group" "nginx" {
  name        = "nginx-sg"
  description = "Security group for Nginx servers"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow HTTP"
  }

  ingress {
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow HTTPS"
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow SSH"
  }

  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.1.0/24"]
    description    = "Allow internal traffic"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outbound"
  }
}

# Security group for Backend servers
resource "yandex_vpc_security_group" "backend" {
  name        = "backend-sg"
  description = "Security group for Backend servers"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 8000
    v4_cidr_blocks = ["10.0.1.0/24"]
    description    = "Allow uWSGI from nginx"
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow SSH"
  }

  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.1.0/24"]
    description    = "Allow internal traffic"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outbound"
  }
}

# Security group for Database server
resource "yandex_vpc_security_group" "database" {
  name        = "database-sg"
  description = "Security group for Database server"
  network_id  = yandex_vpc_network.main.id

  ingress {
    protocol       = "TCP"
    port           = 5432
    v4_cidr_blocks = ["10.0.1.0/24"]
    description    = "Allow PostgreSQL from backend"
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow SSH"
  }

  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = ["10.0.1.0/24"]
    description    = "Allow internal traffic"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outbound"
  }
}
