# Homework 8 — Централизованный сбор логов через Kafka

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                         web-1                                │
│               Nginx + WordPress + MariaDB                    │
│                    10.132.0.11                               │
│                                                              │
│  /var/log/nginx/access.log ──┐                               │
│  /var/log/nginx/error.log  ──┤  Filebeat                     │
│  wordpress/wp-content/       │  (output.kafka)               │
│    debug.log               ──┘                               │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                       kafka-1                                 │
│             Apache Kafka 3.7.0 (KRaft mode)                  │
│                    10.132.0.20:9092                           │
│                                                              │
│   topic: nginx      (2 partitions, RF=1)                     │
│   topic: wordpress  (2 partitions, RF=1)                     │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│                        elk-1                                  │
│         Elasticsearch + Logstash + Kibana 8.13.4             │
│                    10.132.0.30                               │
│                                                              │
│  Logstash:  kafka → nginx-YYYY.MM.dd                         │
│             kafka → wordpress-YYYY.MM.dd                     │
│  Kibana:    http://ELK_PUBLIC_IP:5601                        │
└──────────────────────────────────────────────────────────────┘
```

## Компоненты

| Нода     | IP            | Роль                              | CPU | RAM | Диск |
|----------|---------------|-----------------------------------|-----|-----|------|
| web-1    | 10.132.0.11   | Nginx + WordPress + Filebeat      | 2   | 2G  | 20G  |
| kafka-1  | 10.132.0.20   | Apache Kafka (KRaft)              | 2   | 4G  | 30G  |
| elk-1    | 10.132.0.30   | Elasticsearch + Logstash + Kibana | 4   | 8G  | 50G  |

## Быстрый старт

### 1. Развернуть инфраструктуру

```bash
# Скопировать и настроить переменные
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Отредактировать terraform/terraform.tfvars — указать ssh_key_path

# Добавить свой SSH ключ в terraform/cloud-init.yml
# (заменить <YOUR_SSH_PUBLIC_KEY> на содержимое ~/.ssh/id_rsa.pub)

make infra-init
make infra-apply
```

### 2. Обновить inventory

После `infra-apply` Terraform выведет публичные IP-адреса.
Обновить `ansible/inventory/hosts.yml`:

```yaml
web-1:
  ansible_host: <WEB_PUBLIC_IP>

kafka-1:
  ansible_host: <KAFKA_PUBLIC_IP>

elk-1:
  ansible_host: <ELK_PUBLIC_IP>
```

### 3. Развернуть сервисы

```bash
make deploy
```

### 4. Проверить результат

```bash
# Проверить топики Kafka
make check-kafka

# Проверить индексы Elasticsearch
make check-indices

# Открыть Kibana
open http://<ELK_PUBLIC_IP>:5601
```

## Поток данных

### Filebeat → Kafka

Filebeat на web-1 собирает логи и отправляет в Kafka:

- **nginx** тег → топик `nginx`
  - `/var/log/nginx/access.log` (JSON формат)
  - `/var/log/nginx/error.log` (plain text)
- **wordpress** тег → топик `wordpress`
  - `/var/www/html/wordpress/wp-content/debug.log`
  - `/var/log/php8.1-fpm.log`

### Logstash → Elasticsearch

Logstash читает из обоих топиков Kafka и записывает в отдельные индексы:

| Kafka топик | Elasticsearch индекс  | Парсинг                   |
|-------------|----------------------|---------------------------|
| nginx       | `nginx-YYYY.MM.dd`   | JSON + grok error logs    |
| wordpress   | `wordpress-YYYY.MM.dd` | grok PHP error format   |

### Kibana index patterns

После деплоя автоматически создаются два index pattern:
- `nginx-*` с timeField `@timestamp`
- `wordpress-*` с timeField `@timestamp`

## Kafka топики

```
Topic: nginx
  Partitions: 2
  Replication-factor: 1 (одна нода — больше нельзя)

Topic: wordpress
  Partitions: 2
  Replication-factor: 1
```

> **Примечание**: задание требует RF=2, но для этого нужны минимум 2 брокера Kafka.
> В бонусном варианте (кластерный режим) можно развернуть 3 брокера и установить RF=2.

## Nginx: JSON формат логов

Nginx настроен писать access-логи в JSON формате:

```json
{
  "time_local": "18/Apr/2026:10:30:00 +0300",
  "remote_addr": "1.2.3.4",
  "request": "GET / HTTP/1.1",
  "status": "200",
  "body_bytes_sent": "12345",
  "request_time": "0.123",
  "http_referer": "",
  "http_user_agent": "Mozilla/5.0 ...",
  "upstream_addr": ""
}
```

## Диагностика

```bash
# Статус Kafka на kafka-1
ssh ubuntu@<KAFKA_IP> "sudo systemctl status kafka"

# Список топиков
ssh ubuntu@<KAFKA_IP> "/opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092"

# Просмотр сообщений из топика nginx
ssh ubuntu@<KAFKA_IP> "/opt/kafka/bin/kafka-console-consumer.sh \
  --topic nginx \
  --from-beginning \
  --max-messages 10 \
  --bootstrap-server localhost:9092"

# Статус Logstash
ssh ubuntu@<ELK_IP> "sudo systemctl status logstash"

# Логи Logstash
ssh ubuntu@<ELK_IP> "sudo tail -f /var/log/logstash/logstash-plain.log"

# Индексы Elasticsearch
curl http://<ELK_IP>:9200/_cat/indices?v

# Logstash pipeline stats
curl http://localhost:9600/_node/stats/pipelines
```

## Задание повышенной сложности — кластерный режим

Для RF=2 на Kafka нужен кластер из 3 брокеров.

Изменения в `terraform/main.tf`:
- Добавить kafka-2 (10.132.0.21) и kafka-3 (10.132.0.22)

Изменения в `server.properties.j2`:
```ini
controller.quorum.voters=1@10.132.0.20:9093,2@10.132.0.21:9093,3@10.132.0.22:9093
```

Изменения в `group_vars/all.yml`:
```yaml
kafka_topics:
  - name: nginx
    partitions: 2
    replication_factor: 2
  - name: wordpress
    partitions: 2
    replication_factor: 2
```

Для ELK в кластерном режиме:
- 3 ноды Elasticsearch (как в homework7)
- Logstash вынести на отдельную ноду
- Kibana с подключением ко всем 3 ES-нодам

## Порты

| Порт | Сервис         | Нода    |
|------|----------------|---------|
| 22   | SSH            | все     |
| 80   | Nginx          | web-1   |
| 9092 | Kafka          | kafka-1 |
| 9200 | Elasticsearch  | elk-1   |
| 5601 | Kibana         | elk-1   |
