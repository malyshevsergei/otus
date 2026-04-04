# Homework 6: Patroni PostgreSQL HA Cluster

Развёртывание отказоустойчивого кластера PostgreSQL на базе Patroni с etcd и HAProxy в Yandex Cloud.

## Архитектура

```
                    ┌──────────────┐
                    │   HAProxy    │  :5000 (RW) / :5001 (RO) / :7000 (stats)
                    │ 10.130.0.20  │
                    └──────┬───────┘
                           │
            ┌──────────────┼──────────────┐
            │              │              │
     ┌──────┴──────┐ ┌────┴────────┐ ┌───┴───────┐
     │ patroni-1   │ │ patroni-2   │ │ patroni-3 │
     │ etcd + PG   │ │ etcd + PG   │ │ etcd + PG │
     │ 10.130.0.11 │ │ 10.130.0.12 │ │ 10.130.0.13│
     └─────────────┘ └─────────────┘ └───────────┘
```

- **3 ноды**: etcd + Patroni + PostgreSQL 15
- **1 нода**: HAProxy (балансировщик)
- **Service discovery**: etcd 3.5
- **Failover**: автоматический через Patroni

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

Скопировать IP-адреса из terraform output в `ansible/inventory/hosts.yml`.

### 3. Развернуть кластер

```bash
make deploy
```

### 4. Проверить

```bash
# Статус кластера
make cluster-status

# HAProxy stats
open http://<HAPROXY_IP>:7000/stats  # admin / HaproxyAdmin123

# Подключение к БД через HAProxy
psql -h <HAPROXY_IP> -p 5000 -U appuser -d project_db
```

### 5. Тест отказоустойчивости

```bash
make failover-test
```

Плейбук останавливает Patroni на текущем лидере, проверяет автоматическое переключение на новый лидер, затем возвращает остановленную ноду в кластер.

## Порты

| Порт | Назначение |
|------|-----------|
| 5000 | HAProxy → PostgreSQL RW (leader) |
| 5001 | HAProxy → PostgreSQL RO (replicas) |
| 5432 | PostgreSQL (прямой) |
| 7000 | HAProxy Stats UI |
| 2379 | etcd client |
| 2380 | etcd peer |
| 8008 | Patroni REST API |

## База данных

Схема `project_db` перенесена из homework5 (MySQL → PostgreSQL): users, products, orders, order_items с тестовыми данными.

## Учётные записи

| Пользователь | Пароль | Назначение |
|-------------|--------|-----------|
| postgres | SuperSecret123 | Суперпользователь PG |
| replicator | ReplicaPass123 | Репликация |
| appuser | AppPass123 | Приложение (project_db) |
| admin | HaproxyAdmin123 | HAProxy Stats |
