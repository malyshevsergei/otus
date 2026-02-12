resource "yandex_compute_instance" "instance" {
  name        = var.instance_name
  hostname    = var.hostname
  platform_id = var.platform_id
  zone        = var.zone
  folder_id   = var.folder_id

  resources {
    cores         = var.cores
    memory        = var.memory
    core_fraction = var.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.boot_disk_image_id != null ? var.boot_disk_image_id : data.yandex_compute_image.image[0].id
      size     = var.boot_disk_size
      type     = var.boot_disk_type
    }
  }

  network_interface {
    subnet_id = var.subnet_id
    nat       = var.nat
  }

  metadata = {ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"}

  labels = var.labels

  scheduling_policy {
    preemptible = var.preemptible
  }
}

data "yandex_compute_image" "image" {
  count  = var.boot_disk_image_id == null ? 1 : 0
  family = var.boot_disk_image_family
}
