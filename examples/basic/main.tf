terraform {
  required_version = ">= 1.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.100"
    }
  }
}

provider "yandex" {
  # Authentication is done via environment variables:
  # YC_TOKEN or YC_SERVICE_ACCOUNT_KEY_FILE
  # YC_CLOUD_ID
  # YC_FOLDER_ID
  zone = var.zone
}

# Use the module to create a VM
module "vm" {
  source = "../../"

  folder_id     = var.folder_id
  instance_name = "${var.name_prefix}-instance"
  subnet_id     = yandex_vpc_subnet.subnet.id
  zone          = var.zone

  cores  = var.cores
  memory = var.memory

  boot_disk_image_family = var.image_family
  boot_disk_size         = var.disk_size

  ssh_keys = var.ssh_keys

  labels = {
    environment = "example"
    managed_by  = "terraform"
  }
}
