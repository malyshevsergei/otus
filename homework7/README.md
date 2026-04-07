# Homework 7: ELK Stack — Centralized Logging

Развёртывание кластера Elasticsearch + Logstash + Kibana + Filebeat для сбора логов с инфраструктуры homework6 (Patroni PostgreSQL).

## Архитектура

```
  homework6 nodes (Filebeat)              homework7 nodes
  ┌──────────────┐                    ┌─────────────────────┐
  │ patroni-1    │──┐                 │  logstash-1         │
  │ patroni-2    │──┼── Beats:5044 ──▶│  Logstash + Kibana  │
  │ patroni-3    │──┤                 │  10.131.0.20        │
  │ haproxy-1    │──┘                 └─────────┬───────────┘
  └──────────────┘                              │
                                                ▼ HTTP:9200
                              ┌─────────────────┼─────────────────┐
                              │                 │                 │
                        ┌─────┴─────┐     ┌─────┴─────┐    ┌─────┴─────┐
                        │ elastic-1 │     │ elastic-2 │    │ elastic-3 │
                        │ .0.11     │     │ .0.12     │    │ .0.13     │
                        └───────────┘     └───────────┘    └───────────┘
```

- **3 ноды** Elasticsearch 8.13 (кластер `otus-logging`)
- **1 нода** Logstash + Kibana
- **Filebeat** на 4 нодах homework6 (patroni-1/2/3, haproxy-1)

## Собираемые логи

| Источник | Тип | Файлы/сервисы |
|----------|-----|---------------|
| System | syslog | /var/log/syslog, /var/log/auth.log |
| PostgreSQL | postgresql | pg_log/*.log |
| Patroni | patroni | journald (patroni.service) |
| HAProxy | haproxy | /var/log/haproxy.log |
| etcd | etcd | journald (etcd.service) |

## Быстрый старт

### 1. Создать инфраструктуру

```bash
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=<your-cloud-id>
export YC_FOLDER_ID=<your-folder-id>

make infra-init
make infra-apply
```

### 2. Обновить inventory

Скопировать IP-адреса из `terraform output` в `ansible/inventory/hosts.yml`.
Также добавить IP-адреса нод из homework6 в секцию `filebeat_targets`.

### 3. Развернуть стек

```bash
make deploy
```

### 4. Проверить

```bash
# Кластер Elasticsearch
make check-cluster
make check-nodes

# Индексы с логами
make check-indices

# Kibana UI
open http://<LOGSTASH_PUBLIC_IP>:5601
```

## Порты

| Порт | Назначение |
|------|-----------|
| 9200 | Elasticsearch HTTP API |
| 9300 | Elasticsearch transport (inter-node) |
| 5044 | Logstash Beats input |
| 5601 | Kibana Web UI |

## Обработка логов (Logstash pipeline)

1. **Input**: Beats (port 5044) — принимает от Filebeat
2. **Filter**: Grok-парсинг по тегам:
   - `syslog` — стандартный syslog-формат
   - `postgresql` — timestamp, pid, user, database, level, message
   - `patroni` — timestamp, level, message
   - `haproxy` — HAPROXYHTTP pattern
3. **Output**: Elasticsearch кластер, индекс `filebeat-YYYY.MM.dd`
4. **Index template**: 1 shard, 1 replica, маппинги для keyword-полей
