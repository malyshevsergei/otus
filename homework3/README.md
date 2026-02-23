# Homework 3 — Nginx Load Balancing on Yandex Cloud

Deploy 3 VMs in Yandex Cloud: 1 Nginx load balancer + 2 Nginx backend servers.

## Architecture

```
Internet
   │
   ▼
[lb] 10.0.0.10  (public IP)
 Nginx upstream (round-robin or ip_hash)
   ├──▶ [backend-1] 10.0.0.11
   └──▶ [backend-2] 10.0.0.12
```

All VMs: Ubuntu 22.04, standard-v3, 2 vCPU / 2 GB RAM, preemptible.

## Prerequisites

- Yandex Cloud account with `YC_TOKEN`, `YC_CLOUD_ID`, `YC_FOLDER_ID` set
- Terraform ≥ 1.3
- Ansible ≥ 2.14
- SSH key at `~/.ssh/id_rsa.pub`

## Quickstart

### 1. Terraform

```bash
cd homework3/terraform

terraform init
terraform apply \
  -var="token=$YC_TOKEN" \
  -var="cloud_id=$YC_CLOUD_ID" \
  -var="folder_id=$YC_FOLDER_ID"
```

After apply, note the outputs:

```
lb_public_ip       = "<lb-public-ip>"
backend_public_ips = ["<backend-1-public-ip>", "<backend-2-public-ip>"]
```

### 2. Update inventory

Edit [ansible/inventory/hosts.yml](ansible/inventory/hosts.yml) and replace the
`ansible_host` values with the actual public IPs from Terraform output:

```yaml
lb:
  hosts:
    lb:
      ansible_host: <lb_public_ip>

backends:
  hosts:
    backend-1:
      ansible_host: <backend-1-public-ip>
    backend-2:
      ansible_host: <backend-2-public-ip>
```

### 3. Ansible

```bash
cd homework3/ansible

# Round-robin (default)
ansible-playbook -i inventory/hosts.yml site.yml

# ip_hash (sticky sessions)
ansible-playbook -i inventory/hosts.yml site.yml \
  -e lb_method=hash
```

### 4. Test

```bash
LB=<lb_public_ip>

# Round-robin: each request hits a different backend
for i in $(seq 1 6); do curl -s http://$LB | grep -o 'backend-[0-9]*'; done

# ip_hash: all requests from your IP go to the same backend
for i in $(seq 1 6); do curl -s http://$LB | grep -o 'backend-[0-9]*'; done
```

## Balancing Methods

| `lb_method` | Nginx directive | Behaviour |
|---|---|---|
| `roundrobin` | _(none — default)_ | Requests distributed evenly across backends |
| `hash` | `ip_hash` | Client IP hashed → same backend per client |

Switch methods without reprovisioning:

```bash
ansible-playbook -i inventory/hosts.yml site.yml -e lb_method=hash
ansible-playbook -i inventory/hosts.yml site.yml -e lb_method=roundrobin
```

## File Structure

```
homework3/
├── terraform/
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf          # VPC, subnet, LB VM, 2 backend VMs
│   └── outputs.tf
└── ansible/
    ├── site.yml
    ├── inventory/
    │   └── hosts.yml
    ├── group_vars/
    │   └── all.yml      # backend_servers, lb_method, lb_port
    └── roles/
        ├── nginx_lb/    # upstream.conf.j2, lb.conf.j2
        └── nginx_backend/  # backend.conf.j2, index.html.j2
```

## Cleanup

```bash
cd homework3/terraform
terraform destroy \
  -var="token=$YC_TOKEN" \
  -var="cloud_id=$YC_CLOUD_ID" \
  -var="folder_id=$YC_FOLDER_ID"
```
