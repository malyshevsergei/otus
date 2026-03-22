variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "yc_folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "yc_zone" {
  description = "Yandex Cloud Zone"
  type        = string
  default     = "ru-central1-a"
}

variable "yc_image_id" {
  description = "Boot image ID for VMs (AlmaLinux 9)"
  type        = string
  default     = "fd8079v2kd3a5h10ba5k" # AlmaLinux 9
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_user" {
  description = "SSH user name"
  type        = string
  default     = "almalinux"
}

variable "nginx_count" {
  description = "Number of Nginx instances"
  type        = number
  default     = 2
}

variable "backend_count" {
  description = "Number of Backend instances"
  type        = number
  default     = 2
}
