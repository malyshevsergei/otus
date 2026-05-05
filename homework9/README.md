# Homework 9: Consul Cluster — Service Discovery и DNS-балансировка

Развёртывание кластера Consul для динамического управления DNS-записями веб-портала в Yandex Cloud. Плавающий IP заменяется DNS-балансировкой через Consul: при падении веб-сервера его IP автоматически исчезает из DNS-ответа.

## Архитектура

```
  Интернет
     │ SSH / :8500 / :80
     ▼
┌─────────────────────────────┐
│  consul-server-1  (bastion) │  ← единственный публичный IP
│  10.132.0.11  [NAT=true]    │  Consul UI :8500
└──────┬──────────────────────┘
       │ ProxyJump (SSH)         NAT gateway (outbound)
       │◄────────────────────────────────────────────┐
       │                                             │
  ┌────┴──────────────────────────────────────┐      │
  │           10.132.0.0/24 (private)         │      │
  │                                           │      │
  │  consul-server-2   consul-server-3        │──────┘
  │  10.132.0.12       10.132.0.13            │
  │                                           │
  │  web-1             web-2                  │
  │  nginx+consul      nginx+consul           │
  │  10.132.0.21       10.132.0.22            │
  └───────────────────────────────────────────┘
          │ LAN gossip / RPC (8300-8302)
          ▼
  Consul DNS :8600 → webapp.service.consul
  (только живые инстансы)
```

- **1 публичный IP** — consul-server-1 (бастион + Consul UI)
- **NAT gateway** — все остальные ноды выходят в интернет через него (установка пакетов)
- **ProxyJump** — Ansible достигает приватных нод через бастион
- **3 Consul-сервера** — raft-кворум (допустима потеря 1 ноды)
- **2 веб-сервера** — nginx + Consul-клиент, сервис `webapp` с HTTP health check
- **systemd-resolved** форвардит `*.consul` → `127.0.0.1:8600` на всех нодах

## Быстрый старт

### 1. Создать инфраструктуру

```bash
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=<your-cloud-id>
export YC_FOLDER_ID=<your-folder-id>

make infra-init
make infra-apply
```

### 2. Обновить inventory и сгенерировать ключ шифрования

```bash
# Взять публичный IP бастиона из вывода terraform
terraform -chdir=terraform output bastion_public_ip

# Вставить его в двух местах:
#   ansible/inventory/hosts.yml         → consul-server-1.ansible_host
#   ansible/inventory/group_vars/all.yml → bastion_public_ip

# Сгенерировать ключ gossip-шифрования
consul keygen
# Вставить результат в ansible/inventory/group_vars/all.yml → consul_encrypt_key
```

### 3. Развернуть кластер

```bash
make deploy
```

Playbook выполняется в три фазы:
1. **common** — установка базовых пакетов на все ноды
2. **consul servers** — установка Consul в режиме server, формирование raft-кластера
3. **web servers** — Consul-клиент + nginx + регистрация сервиса `webapp`

### 4. Проверить

```bash
# Статус членов кластера
make consul-status

# DNS-ответ для webapp.service.consul
make dns-test

# Полная проверка через Ansible
make verify

# Скрипт-проверка (повышенная сложность)
make check CONSUL_IP=<consul-server-public-ip>
```

### 5. Тест отказоустойчивости

```bash
# Остановить nginx на одном из веб-серверов (через бастион)
ssh -J ubuntu@<BASTION_PUBLIC_IP> ubuntu@10.132.0.21 'sudo systemctl stop nginx'

# Подождать ~30 секунд (consul deregister_critical_service_after)
# Убедиться, что его IP больше не возвращается в DNS
make dns-test

# Вернуть сервер
ssh -J ubuntu@<BASTION_PUBLIC_IP> ubuntu@10.132.0.21 'sudo systemctl start nginx'
```

## Порты

| Порт | Протокол | Назначение |
|------|----------|-----------|
| 80   | TCP | nginx — веб-портал |
| 8300 | TCP | Consul server RPC (raft) |
| 8301 | TCP/UDP | Consul LAN serf (gossip) |
| 8302 | TCP/UDP | Consul WAN serf |
| 8500 | TCP | Consul HTTP API + UI |
| 8600 | TCP/UDP | Consul DNS |

## DNS

Consul отвечает на запросы вида `<service>.service.<datacenter>.<domain>`.  
В данной конфигурации:

```
webapp.service.consul   →  [10.132.0.21, 10.132.0.22]  (если оба живы)
webapp.service.consul   →  [10.132.0.22]               (если web-1 упал)
```

Проверка вручную:

```bash
# Прямой запрос к Consul DNS
dig @<CONSUL_SERVER_IP> -p 8600 webapp.service.consul

# Через systemd-resolved (с любой ноды кластера)
host webapp.service.consul
curl http://webapp.service.consul/health
```

## Consul UI

После деплоя Consul Web UI доступен на любом сервере:

```
http://<CONSUL_SERVER_PUBLIC_IP>:8500
```

## Структура файлов

```
homework9/
├── Makefile
├── terraform/
│   ├── main.tf                  # VMs, VPC, security group
│   ├── variables.tf
│   ├── outputs.tf               # публичные IP + пример DNS-запроса
│   ├── cloud-init.yml
│   └── terraform.tfvars.example
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   ├── hosts.yml            # заполнить IP после terraform apply
│   │   └── group_vars/
│   │       └── all.yml          # consul_version, encrypt_key, server IPs
│   ├── playbooks/
│   │   ├── deploy-all.yml       # полный деплой
│   │   └── verify-consul.yml    # проверка кластера и DNS
│   └── roles/
│       ├── common/              # базовые пакеты
│       ├── consul/              # установка бинаря, конфиг, DNS-форвардинг
│       ├── nginx/               # веб-сервер с /health endpoint
│       └── consul-service/      # регистрация сервиса webapp в Consul
└── scripts/
    └── check-consul.sh          # bash health-check (повышенная сложность)
```

## Повышенная сложность: скрипт проверки цепочки

`scripts/check-consul.sh` проверяет всю цепочку:

1. Consul HTTP API доступен и лидер избран
2. Кластер имеет ≥ 3 живых членов (кворум)
3. Сервис `webapp` имеет живые инстансы по данным health check
4. DNS `webapp.service.consul` возвращает A-записи
5. HTTP GET `/health` на каждый живой инстанс возвращает 200

```bash
./scripts/check-consul.sh <consul-server-ip>
# или
make check CONSUL_IP=<consul-server-ip>
```
