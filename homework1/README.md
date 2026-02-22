# Yandex Cloud Compute Instance Terraform Module

This Terraform module creates and manages compute instances (VMs) in Yandex Cloud.

## Features

- Create compute instances with customizable resources (CPU, memory)
- Support for different platform IDs and availability zones
- Flexible boot disk configuration (size, type, image)
- Network interface configuration with optional NAT
- SSH key injection for secure access

## Usage

```hcl
module "vm" {
  source = "./path-to-this-module"

  folder_id     = "b1g1234567890abcdefg"
  instance_name = "my-instance"
  subnet_id     = "e9b1234567890abcdefg"

  cores  = 2
  memory = 4

  labels = {
    environment = "production"
    managed_by  = "terraform"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| yandex | >= 0.100 |

## Providers

| Name | Version |
|------|---------|
| yandex | >= 0.100 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| folder_id | Yandex Cloud folder ID where resources will be created | `string` | n/a | yes |
| subnet_id | ID of the subnet to attach the instance to | `string` | n/a | yes |
| instance_name | Name of the compute instance | `string` | n/a | yes |
| zone | Yandex Cloud availability zone | `string` | `"ru-central1-a"` | no |
| hostname | Hostname of the instance | `string` | `null` | no |
| platform_id | Platform ID | `string` | `"standard-v3"` | no |
| cores | Number of CPU cores | `number` | `2` | no |
| memory | Amount of memory in GB | `number` | `2` | no |
| core_fraction | Core fraction (percentage of CPU performance) | `number` | `100` | no |
| boot_disk_image_id | ID of the boot disk image | `string` | `null` | no |
| boot_disk_image_family | Family of the boot disk image | `string` | `"ubuntu-2204-lts"` | no |
| boot_disk_size | Size of the boot disk in GB | `number` | `20` | no |
| boot_disk_type | Type of the boot disk | `string` | `"network-hdd"` | no |
| nat | Enable NAT for the instance | `bool` | `true` | no |
| ssh_keys | List of SSH public keys for the default user | `list(string)` | `[]` | no |
| labels | Labels to assign to the instance | `map(string)` | `{}` | no |
| preemptible | Create preemptible (spot) instance | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | ID of the created compute instance |
| instance_name | Name of the compute instance |
| internal_ip_address | Internal IP address of the instance |
| external_ip_address | External IP address of the instance (if NAT is enabled) |
| fqdn | Fully qualified domain name of the instance |
| status | Status of the instance |

## Examples

### Basic Instance

```hcl
module "basic_vm" {
  source = "./path-to-this-module"

  folder_id     = "b1g1234567890abcdefg"
  instance_name = "basic-vm"
  subnet_id     = "e9b1234567890abcdefg"
}
```

### Custom Configuration

```hcl
module "custom_vm" {
  source = "./path-to-this-module"

  folder_id     = "b1g1234567890abcdefg"
  instance_name = "custom-vm"
  subnet_id     = "e9b1234567890abcdefg"

  platform_id   = "standard-v3"
  cores         = 4
  memory        = 8
  core_fraction = 100

  boot_disk_image_family = "ubuntu-2204-lts"
  boot_disk_size         = 50
  boot_disk_type         = "network-ssd"

  ssh_keys = [
    file("~/.ssh/id_rsa.pub")
  ]

  labels = {
    environment = "dev"
    project     = "myproject"
  }
}
```

### Preemptible Instance

```hcl
module "spot_vm" {
  source = "./path-to-this-module"

  folder_id     = "b1g1234567890abcdefg"
  instance_name = "spot-vm"
  subnet_id     = "e9b1234567890abcdefg"

  preemptible = true
  cores       = 2
  memory      = 2
}
```