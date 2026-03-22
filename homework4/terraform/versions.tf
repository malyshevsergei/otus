terraform {
  required_version = ">= 1.0.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.193.0"
    }
  }
}

provider "yandex" {
  zone = var.yc_zone
}
