variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "image_id" {
  description = "Ubuntu 22.04 LTS image ID in Yandex Cloud"
  type        = string
  default     = "fd81radk00nmm2jpqh94"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "consul_server_cores" {
  type    = number
  default = 2
}

variable "consul_server_memory" {
  type    = number
  default = 2
}

variable "web_cores" {
  type    = number
  default = 2
}

variable "web_memory" {
  type    = number
  default = 2
}

variable "disk_size" {
  type    = number
  default = 15
}
