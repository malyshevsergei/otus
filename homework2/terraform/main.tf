# Image
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# iSCSI disk
resource "yandex_compute_disk" "iscsi_disk" {
  name = "iscsi-disk"
  size = 20
  type = "network-hdd"
}

# iSCSI VM
resource "yandex_compute_instance" "iscsi" {
  name = "iscsi-target"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
    }
  }

  secondary_disk {
    disk_id = yandex_compute_disk.iscsi_disk.id
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.gfs_subnet.id
    ip_address = "10.0.0.10"
    nat        = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# GFS nodes
resource "yandex_compute_instance" "gfs" {
  count = 3
  name  = "gfs-node-${count.index + 1}"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.gfs_subnet.id
    ip_address = "10.0.0.${11 + count.index}"
    nat        = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}