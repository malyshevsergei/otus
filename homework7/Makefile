.PHONY: infra-init infra-plan infra-apply infra-destroy deploy check-cluster check-indices

# --- Terraform ---
infra-init:
	cd terraform && terraform init

infra-plan:
	cd terraform && terraform plan

infra-apply:
	cd terraform && terraform apply -auto-approve
	@echo "\n>>> Update ansible/inventory/hosts.yml with IPs from terraform output <<<"
	cd terraform && terraform output

infra-destroy:
	cd terraform && terraform destroy -auto-approve

# --- Ansible ---
deploy:
	cd ansible && ansible-playbook playbooks/deploy-all.yml

deploy-filebeat:
	cd ansible && ansible-playbook playbooks/deploy-all.yml --limit filebeat_targets --tags filebeat

check-cluster:
	@echo "=== Elasticsearch Cluster Health ==="
	cd ansible && ansible elasticsearch -m shell -a "curl -s http://localhost:9200/_cluster/health?pretty" --limit elastic-1

check-indices:
	@echo "=== Elasticsearch Indices ==="
	cd ansible && ansible elasticsearch -m shell -a "curl -s http://localhost:9200/_cat/indices?v" --limit elastic-1

check-nodes:
	@echo "=== Elasticsearch Nodes ==="
	cd ansible && ansible elasticsearch -m shell -a "curl -s http://localhost:9200/_cat/nodes?v" --limit elastic-1
