.PHONY: infra-init infra-plan infra-apply infra-destroy deploy deploy-web deploy-kafka deploy-elk deploy-filebeat check-kafka check-indices help

ANSIBLE_DIR := ansible
TERRAFORM_DIR := terraform
PLAYBOOK := $(ANSIBLE_DIR)/playbooks/deploy-all.yml
INVENTORY := $(ANSIBLE_DIR)/inventory/hosts.yml

help:
	@echo "Available targets:"
	@echo "  infra-init       - Initialize Terraform"
	@echo "  infra-plan       - Plan infrastructure changes"
	@echo "  infra-apply      - Apply infrastructure (creates VMs)"
	@echo "  infra-destroy    - Destroy infrastructure"
	@echo "  deploy           - Full Ansible deployment"
	@echo "  deploy-web       - Deploy web portal only"
	@echo "  deploy-kafka     - Deploy Kafka only"
	@echo "  deploy-elk       - Deploy ELK stack only"
	@echo "  deploy-filebeat  - Deploy Filebeat only"
	@echo "  check-kafka      - List Kafka topics"
	@echo "  check-indices    - List Elasticsearch indices"

infra-init:
	cd $(TERRAFORM_DIR) && terraform init

infra-plan:
	cd $(TERRAFORM_DIR) && terraform plan

infra-apply:
	cd $(TERRAFORM_DIR) && terraform apply -auto-approve
	@echo "Update ansible/inventory/hosts.yml with IPs from terraform output"
	cd $(TERRAFORM_DIR) && terraform output

infra-destroy:
	cd $(TERRAFORM_DIR) && terraform destroy -auto-approve

deploy:
	cd $(ANSIBLE_DIR) && ansible-playbook $(PLAYBOOK)

deploy-web:
	cd $(ANSIBLE_DIR) && ansible-playbook $(PLAYBOOK) --tags web

deploy-kafka:
	cd $(ANSIBLE_DIR) && ansible-playbook $(PLAYBOOK) --tags kafka

deploy-elk:
	cd $(ANSIBLE_DIR) && ansible-playbook $(PLAYBOOK) --tags elk

deploy-filebeat:
	cd $(ANSIBLE_DIR) && ansible-playbook $(PLAYBOOK) --tags filebeat

check-kafka:
	@WEB_IP=$$(grep -A2 'web-1:' $(INVENTORY) | grep 'ansible_host' | awk '{print $$2}'); \
	KAFKA_IP=$$(grep -A2 'kafka-1:' $(INVENTORY) | grep 'ansible_host' | awk '{print $$2}'); \
	ssh ubuntu@$$KAFKA_IP "/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092"

check-indices:
	@ELK_IP=$$(grep -A2 'elk-1:' $(INVENTORY) | grep 'ansible_host' | awk '{print $$2}'); \
	curl -s http://$$ELK_IP:9200/_cat/indices?v | grep -E 'nginx|wordpress'
