variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "image_id" {
  description = "Ubuntu 22.04 LTS image ID"
  type        = string
  default     = "fd81radk00nmm2jpqh94"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "es_cores" {
  type    = number
  default = 2
}

variable "es_memory" {
  type    = number
  default = 4
}

variable "es_disk_size" {
  type    = number
  default = 30
}
