# Basic Example

This example demonstrates how to use the Yandex Cloud compute instance module to create a basic VM.

## What This Example Creates

- VPC network
- Subnet in the specified zone
- Single compute instance with default Ubuntu 22.04 LTS image

## Usage

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your values:
   - Set your Yandex Cloud folder ID
   - Add your SSH public key
   - Adjust other parameters as needed

3. Set up authentication via environment variables:
   ```bash
   export YC_TOKEN="your-token"
   # or
   export YC_SERVICE_ACCOUNT_KEY_FILE="path/to/key.json"
   ```

4. Initialize Terraform:
   ```bash
   terraform init
   ```

5. Review the plan:
   ```bash
   terraform plan
   ```

6. Apply the configuration:
   ```bash
   terraform apply
   ```

## Connecting to the Instance

After the instance is created, you can connect via SSH:

```bash
ssh ubuntu@<external_ip>
```

The external IP address will be shown in the Terraform outputs.

## Cleanup

To destroy all resources:

```bash
terraform destroy
```
