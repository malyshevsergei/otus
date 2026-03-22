.PHONY: help init plan apply deploy ansible destroy clean test-failover ssh-nginx ssh-backend ssh-db

# Default target
help:
	@echo "Available targets:"
	@echo "  init         - Initialize Terraform"
	@echo "  plan         - Show Terraform plan"
	@echo "  apply        - Apply Terraform configuration"
	@echo "  deploy       - Full deployment (Terraform + Ansible)"
	@echo "  ansible      - Run Ansible playbook"
	@echo "  destroy      - Destroy infrastructure"
	@echo "  clean        - Clean generated files"
	@echo "  test-failover - Run failover tests"
	@echo "  ssh-nginx    - SSH to first nginx server"
	@echo "  ssh-backend  - SSH to first backend server"
	@echo "  ssh-db       - SSH to database server"
	@echo "  outputs      - Show Terraform outputs"
	@echo "  status       - Show infrastructure status"

# Terraform operations
init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply

outputs:
	cd terraform && terraform output

# Full deployment
deploy:
	./deploy.sh

# Ansible operations
ansible: generate-inventory
	cd ansible && ansible-playbook -i inventory.ini site.yml

generate-inventory:
	cd terraform && terraform output -raw ansible_inventory > ../ansible/inventory.ini

# Testing
test-failover:
	./test-failover.sh

# SSH shortcuts
ssh-nginx:
	@cd terraform && ssh ubuntu@$$(terraform output -json nginx_instances | jq -r '.[0].external_ip')

ssh-backend:
	@cd terraform && ssh ubuntu@$$(terraform output -json backend_instances | jq -r '.[0].external_ip')

ssh-db:
	@cd terraform && ssh ubuntu@$$(terraform output -json database_instance | jq -r '.external_ip')

# Status check
status:
	@echo "=== Infrastructure Status ==="
	@cd terraform && terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="yandex_compute_instance") | "\(.values.name): \(.values.status)"'

# Cleanup
destroy:
	./destroy.sh

clean:
	rm -rf terraform/.terraform
	rm -f terraform/.terraform.lock.hcl
	rm -f terraform/terraform.tfstate*
	rm -f ansible/inventory.ini
	rm -f ansible/*.retry
