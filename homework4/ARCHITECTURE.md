# Архитектура системы

## Общая схема

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ HTTP/HTTPS
                         │
              ┌──────────▼──────────┐
              │  Yandex Cloud       │
              │  Network Load       │
              │  Balancer           │
              │  (Health Checks)    │
              └──────────┬──────────┘
                         │
          ┌──────────────┴──────────────┐
          │                             │
    ┌─────▼─────┐                 ┌─────▼─────┐
    │  Nginx-1  │                 │  Nginx-2  │
    │  (Reverse │                 │  (Reverse │
    │   Proxy)  │                 │   Proxy)  │
    └─────┬─────┘                 └─────┬─────┘
          │                             │
          │        uWSGI Protocol       │
          │                             │
          └──────────────┬──────────────┘
                         │
          ┌──────────────┴──────────────┐
          │                             │
    ┌─────▼─────┐                 ┌─────▼─────┐
    │ Backend-1 │◄───────────────►│ Backend-2 │
    │  Django + │   NFS Storage  │  Django + │
    │   uWSGI   │  NFS Client/Server  │   uWSGI   │
    └─────┬─────┘                 └─────┬─────┘
          │                             │
          │      PostgreSQL Protocol    │
          │                             │
          └──────────────┬──────────────┘
                         │
                   ┌─────▼─────┐
                   │PostgreSQL │
                   │ Database  │
                   └───────────┘
```

## Компоненты

### 1. Network Load Balancer (Yandex Cloud)

**Функции:**
- Распределение трафика между Nginx серверами
- Health checks каждые 2 секунды
- Автоматическое исключение неработающих серверов
- Публичный IP адрес для доступа к приложению

**Конфигурация:**
- Listener: порт 80 (HTTP)
- Health check endpoint: `/health`
- Алгоритм: Round Robin

### 2. Nginx Серверы (2 инстанса)

**Функции:**
- Reverse proxy для backend приложения
- Балансировка нагрузки между backend серверами
- Обслуживание статических файлов
- Rate limiting (10 req/s с burst 20)
- SSL termination (опционально)

**Конфигурация:**
- Upstream: least_conn алгоритм
- Max fails: 3
- Fail timeout: 30s
- Worker processes: auto
- Worker connections: 1024

**Ресурсы VM:**
- CPU: 2 cores
- RAM: 2 GB
- Disk: 20 GB

### 3. Backend Серверы (2 инстанса)

**Функции:**
- Выполнение бизнес-логики приложения
- Обработка HTTP запросов через uWSGI
- Хранение статических файлов на NFS
- Подключение к базе данных

**Стек:**
- OS: Ubuntu 22.04
- Python: 3.10
- Django: 4.2
- uWSGI: latest

**uWSGI конфигурация:**
- Processes: 4
- Threads: 2 per process
- Socket: 127.0.0.1:8000
- Protocol: uwsgi
- Max requests: 5000
- Harakiri timeout: 60s

**Ресурсы VM:**
- CPU: 2 cores
- RAM: 4 GB
- Disk: 30 GB (boot) + 10 GB (NFS)

### 4. NFS Storage

**Функции:**
- Общее хранилище для статических файлов
- Синхронизация между backend серверами
- Высокая доступность данных

**Компоненты:**
- NFS Server: Backend-1 экспортирует /var/www/static
- NFS Client: Backend-2+ монтируют удаленную файловую систему

**Конфигурация:**
- Server: Backend-1 с XFS на /dev/vdb
- Clients: Backend-2+ монтируют через NFS протокол
- Export: /var/www/static доступна для 10.0.1.0/24
- Mount point: /var/www/static
- Mount options: noatime,nodiratime

### 5. Database Сервер (1 инстанс)

**Функции:**
- Хранение данных приложения
- Обработка SQL запросов от backend серверов
- Управление транзакциями

**Конфигурация:**
- СУБД: PostgreSQL 14
- Listen addresses: * (все интерфейсы)
- Max connections: 100
- Authentication: scram-sha-256
- Доступ: только с backend серверов (10.0.1.0/24)

**Ресурсы VM:**
- CPU: 2 cores
- RAM: 4 GB
- Disk: 40 GB

## Сетевая архитектура

### VPC и подсети

```
VPC: otus-network (10.0.0.0/16)
│
└── Subnet: otus-subnet (10.0.1.0/24)
    ├── Nginx-1:    10.0.1.10
    ├── Nginx-2:    10.0.1.11
    ├── Backend-1:  10.0.1.20
    ├── Backend-2:  10.0.1.21
    └── Database:   10.0.1.30
```

### Security Groups

#### Nginx Security Group
- **Ingress:**
  - TCP 80 (HTTP) from 0.0.0.0/0
  - TCP 443 (HTTPS) from 0.0.0.0/0
  - TCP 22 (SSH) from 0.0.0.0/0
  - ANY from 10.0.1.0/24 (internal)
- **Egress:**
  - ANY to 0.0.0.0/0

#### Backend Security Group
- **Ingress:**
  - TCP 8000 (uWSGI) from 10.0.1.0/24
  - TCP 22 (SSH) from 0.0.0.0/0
  - ANY from 10.0.1.0/24 (internal, для NFS)
- **Egress:**
  - ANY to 0.0.0.0/0

#### Database Security Group
- **Ingress:**
  - TCP 5432 (PostgreSQL) from 10.0.1.0/24
  - TCP 22 (SSH) from 0.0.0.0/0
  - ANY from 10.0.1.0/24 (internal)
- **Egress:**
  - ANY to 0.0.0.0/0

## Потоки данных

### 1. Запрос пользователя

```
User → Load Balancer → Nginx (80) → Backend (8000/uwsgi) → Database (5432)
                                  ↓
                          Static files (NFS)
```

### 2. Статические файлы

```
User → Load Balancer → Nginx → /var/www/static (NFS)
```

Django collectstatic → Backend → /var/www/static (NFS) → Sync → Other Backends

### 3. Данные приложения

```
Backend-1 → PostgreSQL ← Backend-2
```

## Отказоустойчивость

### Сценарий 1: Отказ Nginx сервера

```
1. Nginx-1 падает
2. Load Balancer обнаруживает отказ через health check
3. Load Balancer исключает Nginx-1 из пула
4. Весь трафик идёт на Nginx-2
5. Приложение остаётся доступным
```

**RTO (Recovery Time Objective):** ~30-60 секунд (время health check)

### Сценарий 2: Отказ Backend сервера

```
1. Backend-1 падает (uWSGI останавливается)
2. Nginx обнаруживает отказ (max_fails=3, fail_timeout=30s)
3. Nginx исключает Backend-1 из upstream
4. Весь трафик идёт на Backend-2
5. Приложение остаётся доступным
```

**RTO:** ~30-90 секунд (3 failed requests × 30s timeout)

### Сценарий 3: NFS проблемы

```
1. Один из backend серверов (клиент) теряет доступ к NFS
2. NFS автоматически восстанавливает соединение
3. Другой backend продолжает работать
4. Статические файлы доступны через NFS сервер
```

**RTO:** ~0 секунд (автоматическая синхронизация)

### Сценарий 4: Отказ Database

```
1. PostgreSQL падает
2. Backend серверы теряют соединение
3. Приложение возвращает ошибки 500
4. Требуется ручное восстановление или failover
```

**RTO:** Зависит от процедуры восстановления

**Примечание:** Для полной отказоустойчивости БД рекомендуется:
- PostgreSQL Streaming Replication
- Patroni для автоматического failover
- pgBouncer для connection pooling

## Масштабируемость

### Горизонтальное масштабирование

#### Nginx слой
- Легко масштабируется до N серверов
- Load Balancer автоматически добавляет в пул
- Без состояния (stateless)

#### Backend слой
- Масштабируется до N серверов
- NFS поддерживает до 16 узлов
- Требует настройки количества журналов NFS

#### Database слой
- Масштабирование через Read Replicas
- Партиционирование (sharding) для очень больших данных

### Вертикальное масштабирование

Все компоненты поддерживают увеличение ресурсов:
- CPU cores
- RAM
- Disk space
- Network bandwidth

## Мониторинг и метрики

### Ключевые метрики

#### Load Balancer
- Requests per second
- Active connections
- Target health status
- Response time

#### Nginx
- Requests per second
- Active connections
- 2xx/4xx/5xx responses
- Upstream response time
- Cache hit ratio

#### Backend (uWSGI)
- Active workers
- Queue length
- Request time
- Memory usage
- CPU usage

#### Database
- Active connections
- Query time
- Cache hit ratio
- Disk I/O
- Replication lag (если есть)

#### NFS
- Cluster status
- Lock contention
- I/O throughput
- Available space

### Инструменты мониторинга (для внедрения)

- **Prometheus** + **Grafana**: метрики и визуализация
- **ELK Stack**: логи и анализ
- **Zabbix**: системный мониторинг
- **Yandex Monitoring**: встроенный мониторинг облака

## Производительность

### Оптимизации

1. **Nginx:**
   - Кэширование статических файлов
   - Gzip компрессия
   - HTTP/2 поддержка (опционально)
   - Connection pooling к upstream

2. **uWSGI:**
   - Process и thread pool
   - Lazy apps loading
   - Harakiri timeout
   - Max requests recycling

3. **Django:**
   - Database query optimization
   - ORM select_related и prefetch_related
   - Кэширование (Redis/Memcached - опционально)
   - Static files на CDN (опционально)

4. **PostgreSQL:**
   - Индексы на часто запрашиваемые поля
   - Connection pooling (pgBouncer)
   - Query optimization
   - Vacuum и analyze

### Ожидаемая производительность

При текущей конфигурации (2+2+1 схема):
- **RPS (Requests Per Second):** ~500-1000 rps
- **Concurrent Users:** ~100-200
- **Response Time:** <100ms для статики, <500ms для динамики
- **Availability:** 99.5% (с учётом single point of failure в БД)

## Безопасность

### Уровни защиты

1. **Network Level:**
   - Security Groups (файрвол)
   - Private Network для внутренних коммуникаций
   - NAT для исходящих соединений

2. **Application Level:**
   - Rate limiting в Nginx
   - Django CSRF protection
   - SQL injection protection (ORM)
   - XSS protection

3. **Data Level:**
   - PostgreSQL authentication (scram-sha-256)
   - SSL/TLS для БД соединений (опционально)
   - Encrypted storage (опционально)

4. **Access Level:**
   - SSH key-based authentication
   - Sudo без пароля только для deploy user
   - Минимальные права для app user

## Backup и Disaster Recovery

### Резервное копирование (рекомендуется)

1. **Database:**
   ```bash
   # Ежедневный backup
   pg_dump webapp_db > backup_$(date +%Y%m%d).sql

   # Point-in-time recovery (PITR)
   # Настроить WAL archiving
   ```

2. **Статические файлы (NFS):**
   ```bash
   # Snapshot дисков в Yandex Cloud
   yc compute disk create-snapshot
   ```

3. **Конфигурация:**
   - Всё в Git
   - Infrastructure as Code (Terraform)

### RPO и RTO цели

- **RPO (Recovery Point Objective):** 24 часа (ежедневные backup)
- **RTO (Recovery Time Objective):** 1-2 часа (время на восстановление из backup)

## Стоимость (примерная в Yandex Cloud)

- 2× Nginx (2 core, 2GB): ~₽2000/мес
- 2× Backend (2 core, 4GB): ~₽3000/мес
- 1× Database (2 core, 4GB): ~₽1500/мес
- Network Load Balancer: ~₽500/мес
- Диски (120GB total): ~₽1000/мес
- Трафик (100GB/мес): ~₽500/мес

**Итого:** ~₽11 500 руб/мес (~$125/мес)

## Дальнейшие улучшения

1. **Database HA:**
   - PostgreSQL Streaming Replication
   - Patroni + etcd для автоматического failover
   - PgBouncer для connection pooling

2. **Monitoring:**
   - Prometheus + Grafana
   - Alertmanager для уведомлений
   - ELK для централизованных логов

3. **CI/CD:**
   - GitLab CI/Ansible AWX
   - Автоматическое тестирование
   - Blue-Green или Canary deployments

4. **Security:**
   - SSL/TLS сертификаты (Let's Encrypt)
   - WAF (Web Application Firewall)
   - IDS/IPS системы
   - Vault для secrets management

5. **Performance:**
   - Redis для кэширования
   - CDN для статических файлов
   - Database read replicas
   - Auto-scaling groups

6. **Backup:**
   - Автоматические snapshots
   - Offsite backup storage
   - Disaster recovery plan
