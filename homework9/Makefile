.PHONY: infra-init infra-plan infra-apply infra-destroy deploy verify consul-status dns-test check

# --- Terraform ---

infra-init:
	cd terraform && terraform init

infra-plan:
	cd terraform && terraform plan

infra-apply:
	cd terraform && terraform apply -auto-approve
	@echo ""
	@echo ">>> Fill in bastion_public_ip in ansible/inventory/group_vars/all.yml <<<"
	@echo ">>> Fill in consul-server-1 ansible_host in ansible/inventory/hosts.yml <<<"
	cd terraform && terraform output

infra-destroy:
	cd terraform && terraform destroy -auto-approve

# --- Ansible ---

deploy:
	cd ansible && ansible-playbook playbooks/deploy-all.yml

verify:
	cd ansible && ansible-playbook playbooks/verify-consul.yml

consul-status:
	cd ansible && ansible consul_servers -m command \
		-a "consul members" --limit consul-server-1

dns-test:
	cd ansible && ansible consul_servers -m command \
		-a "dig @127.0.0.1 -p 8600 webapp.service.consul +short" \
		--limit consul-server-1

# --- Health check script (повышенная сложность) ---
# Usage: make check CONSUL_IP=<consul-server-public-ip>

CONSUL_IP ?= 127.0.0.1

check:
	./scripts/check-consul.sh $(CONSUL_IP)
