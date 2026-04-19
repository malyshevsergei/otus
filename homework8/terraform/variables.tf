variable "zone" {
  default = "ru-central1-a"
}

variable "image_id" {
  description = "Ubuntu 22.04 LTS image ID in Yandex Cloud"
  default     = "fd81radk00nmm2jpqh94"
}

variable "ssh_key_path" {
  description = "Path to SSH public key"
  default     = "~/.ssh/id_rsa.pub"
}

variable "web_cores" {
  default = 2
}

variable "web_memory" {
  default = 2
}

variable "web_disk_size" {
  default = 20
}

variable "kafka_cores" {
  default = 2
}

variable "kafka_memory" {
  default = 4
}

variable "kafka_disk_size" {
  default = 30
}

variable "elk_cores" {
  default = 4
}

variable "elk_memory" {
  default = 8
}

variable "elk_disk_size" {
  default = 50
}
