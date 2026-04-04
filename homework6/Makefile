.PHONY: infra-init infra-plan infra-apply infra-destroy deploy failover-test

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

failover-test:
	cd ansible && ansible-playbook playbooks/test-failover.yml

cluster-status:
	cd ansible && ansible patroni_cluster -m shell -a "patronictl -c /etc/patroni/patroni.yml list" --limit patroni-1

etcd-status:
	cd ansible && ansible patroni_cluster -m shell -a "etcdctl endpoint health --endpoints=http://localhost:2379" --limit patroni-1
