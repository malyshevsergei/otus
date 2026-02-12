variable "cloud_id" {
  description = "Yandex Cloud cloud ID where resources will be created"
  type = string
}

variable "folder_id" {
  description = "Yandex Cloud folder ID where resources will be created"
  type        = string
}

variable "zone" {
  description = "Yandex Cloud availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "token" {
  description = "Token for yandex cloud"
  type = string
}

variable "instance_name" {
  description = "Name of the compute instance"
  type        = string
}

variable "hostname" {
  description = "Hostname of the instance"
  type        = string
  default     = null
}

variable "platform_id" {
  description = "Platform ID (e.g., standard-v3)"
  type        = string
  default     = "standard-v3"
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Amount of memory in GB"
  type        = number
  default     = 2
}

variable "core_fraction" {
  description = "Core fraction (percentage of CPU performance)"
  type        = number
  default     = 100
}

variable "boot_disk_image_id" {
  description = "ID of the boot disk image"
  type        = string
  default     = null
}

variable "boot_disk_image_family" {
  description = "Family of the boot disk image (e.g., ubuntu-2204-lts)"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "boot_disk_size" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 20
}

variable "boot_disk_type" {
  description = "Type of the boot disk (network-hdd, network-ssd, network-ssd-nonreplicated)"
  type        = string
  default     = "network-hdd"
}

variable "subnet_id" {
  description = "ID of the subnet to attach the instance to"
  type        = string
}

variable "nat" {
  description = "Enable NAT for the instance"
  type        = bool
  default     = true
}

variable "user_data" {
  description = "User data (cloud-init) for instance initialization"
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels to assign to the instance"
  type        = map(string)
  default     = {}
}

variable "preemptible" {
  description = "Create preemptible (spot) instance"
  type        = bool
  default     = true
}
