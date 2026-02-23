# Homework 3 — Joomla CMS Load Balancing on Yandex Cloud

Deploy 4 VMs in Yandex Cloud with Terraform + Ansible:
- **lb** — Nginx reverse proxy / load balancer (public IP)
- **backend-1, backend-2** — Nginx + PHP-FPM + Joomla 5
- **db** — MariaDB (shared database for both backends)

## Architecture

```
Internet
   │
   ▼
[lb] 10.0.0.10  (public IP)
 Nginx upstream (round-robin or ip_hash)
   ├──▶ [backend-1] 10.0.0.11  Nginx + PHP-FPM + Joomla 5
   └──▶ [backend-2] 10.0.0.12  Nginx + PHP-FPM + Joomla 5
                │                         │
                └──────────┬──────────────┘
                           ▼
                    [db] 10.0.0.20
                     MariaDB 10.x
```

Sessions are stored in MariaDB (`$session_handler = 'database'`), so both backends
share session state — round-robin works without sticky sessions.

All VMs: Ubuntu 22.04, standard-v3, preemptible.

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

Note the outputs:

```
lb_public_ip       = "<lb-public-ip>"
backend_public_ips = ["<b1-ip>", "<b2-ip>"]
db_public_ip       = "<db-ip>"
```

### 2. Update inventory

Edit [ansible/inventory/hosts.yml](ansible/inventory/hosts.yml) — replace `ansible_host`
values with actual public IPs from Terraform output. The `db` host needs to be filled in.

### 3. Ansible

```bash
cd homework3/ansible

# Deploy everything (DB → backends → LB)
ansible-playbook -i inventory/hosts.yml site.yml
```

The playbook runs in order:
1. **db** — Installs MariaDB, creates `joomla` database and user, opens remote access
2. **backends** — Installs Nginx + PHP 8.1 FPM + Joomla 5; runs the Joomla CLI installer
   **once** (on backend-1) to initialise the DB schema; deploys identical `configuration.php`
   to both backends
3. **lb** — Configures Nginx upstream pointing to backend-1 and backend-2

### 4. Access

Open `http://<lb_public_ip>` — Joomla front-end.
Admin: `http://<lb_public_ip>/administrator`
Credentials: `admin` / `Admin1234!`

### 5. Test load balancing

```bash
LB=<lb_public_ip>

# Round-robin — responses come from alternating backends
for i in $(seq 1 6); do curl -sI http://$LB | head -1; done

# Switch to ip_hash (sticky per client IP)
ansible-playbook -i inventory/hosts.yml site.yml -e lb_method=hash
```

## Balancing Methods

| `lb_method` | Nginx directive | Sessions |
|---|---|---|
| `roundrobin` | _(none — default)_ | DB-based sessions work across both backends |
| `hash` | `ip_hash` | Client IP pinned to one backend |

Switch without re-deploying Joomla:

```bash
ansible-playbook -i inventory/hosts.yml site.yml -e lb_method=hash
ansible-playbook -i inventory/hosts.yml site.yml -e lb_method=roundrobin
```

## Key Variables (`group_vars/all.yml`)

| Variable | Default | Description |
|---|---|---|
| `lb_method` | `roundrobin` | `roundrobin` or `hash` |
| `joomla_version` | `5.2.3` | Joomla release to download from GitHub |
| `joomla_site_name` | `Joomla Cluster` | Site title |
| `joomla_admin_pass` | `Admin1234!` | Admin password |
| `db_host` | `10.0.0.20` | MariaDB private IP |
| `db_password` | `JoomlaDB123!` | DB user password |
| `joomla_secret` | *(set)* | Shared security key — must be identical on all backends |

## File Structure

```
homework3/
├── terraform/
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf          # VPC, lb VM, 2 backend VMs, db VM
│   └── outputs.tf
└── ansible/
    ├── site.yml         # db → backends → lb
    ├── inventory/hosts.yml
    ├── group_vars/all.yml
    └── roles/
        ├── mariadb/     # MariaDB + joomla DB/user
        ├── joomla/      # Nginx + PHP-FPM + Joomla 5 + configuration.php
        └── nginx_lb/    # Nginx upstream (round-robin / ip_hash)
```

## Cleanup

```bash
cd homework3/terraform
terraform destroy \
  -var="token=$YC_TOKEN" \
  -var="cloud_id=$YC_CLOUD_ID" \
  -var="folder_id=$YC_FOLDER_ID"
```
