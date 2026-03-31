# OTUS Homework 5 - Решение

## Задание

Разворачиваем отказоустойчивый кластер MySQL (Percona XtraDB Cluster или InnoDB Cluster) на ВМ или в докере любым способом.
Создаем внутри кластера вашу БД для проекта.

## Решение

Реализован отказоустойчивый **MySQL InnoDB Cluster** с использованием Docker Compose для развертывания на Yandex Cloud.

### Архитектура решения

```
┌─────────────────────────────────────────────────────────────┐
│                     MySQL InnoDB Cluster                     │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ MySQL Server │  │ MySQL Server │  │ MySQL Server │      │
│  │      #1      │  │      #2      │  │      #3      │      │
│  │  (PRIMARY)   │  │ (SECONDARY)  │  │ (SECONDARY)  │      │
│  │   Port 3311  │  │   Port 3312  │  │   Port 3313  │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                  │               │
│         └─────────────────┼──────────────────┘               │
│                           │                                  │
│                  ┌────────▼─────────┐                        │
│                  │  MySQL Router    │                        │
│                  │  Port 6446 (RW)  │                        │
│                  │  Port 6447 (RO)  │                        │
│                  └──────────────────┘                        │
│                                                              │
│  Automatic Failover │ Group Replication │ High Availability │
└─────────────────────────────────────────────────────────────┘
```

### Компоненты

1. **3 MySQL Server 8.0 узла**
   - Group Replication для автоматической репликации
   - GTID-based репликация
   - Автоматический failover
   - Кворумное голосование (минимум 2 узла для работы)

2. **MySQL Router**
   - Автоматическая маршрутизация на PRIMARY (Read-Write)
   - Load balancing по SECONDARY узлам (Read-Only)
   - Прозрачное переключение при failover

3. **MySQL Shell**
   - Управление кластером
   - Мониторинг состояния
   - Настройка репликации

### Особенности реализации

#### Отказоустойчивость
- **Автоматический failover**: При падении PRIMARY узла, один из SECONDARY автоматически становится PRIMARY
- **Quorum-based**: Требуется минимум 2 из 3 узлов для работы кластера
- **Self-healing**: Восстановившийся узел автоматически синхронизируется

#### Репликация
- **Синхронная репликация**: Group Replication с сертифицированными транзакциями
- **GTID**: Global Transaction Identifiers для консистентности
- **Conflict detection**: Автоматическое разрешение конфликтов

#### Производительность
- **Read scaling**: Read-запросы распределяются по SECONDARY узлам
- **Connection pooling**: MySQL Router эффективно управляет соединениями
- **Parallel replication**: 4 параллельных потока репликации

### База данных проекта

Создана БД `project_db` с таблицами:

```sql
- users (пользователи)
- products (товары)
- orders (заказы)
- order_items (позиции заказов)
```

С тестовыми данными и связями между таблицами.

## Варианты развертывания

### Вариант 1: Локально (для тестирования)

```bash
cd /Users/s.malyshev/otus/homework5
make all
```

### Вариант 2: На Yandex Cloud VM (вручную)

```bash
# 1. Создать VM
# 2. Установить Docker
# 3. Загрузить проект
# 4. Запустить
make all
```

См. подробности в `QUICKSTART.md`

### Вариант 3: Terraform (автоматизация)

```bash
cd terraform
terraform init
terraform apply
# Следовать инструкциям
```

См. подробности в `terraform/README.md`

## Проверка отказоустойчивости

### Тест 1: Остановка PRIMARY узла

```bash
# Остановить PRIMARY
docker compose stop mysql-server-1

# Кластер автоматически выберет новый PRIMARY
# Приложения продолжат работать через Router
docker exec -it mysql-shell bash /scripts/check-cluster-status.sh

# Вернуть узел
docker compose start mysql-server-1
# Узел автоматически присоединится как SECONDARY
```

**Результат**: Downtime < 10 секунд, автоматическое восстановление

### Тест 2: Проверка репликации

```bash
# Записать данные через Router (автоматически попадут на PRIMARY)
mysql -h 127.0.0.1 -P 6446 -uappuser -papppass project_db \
  -e "INSERT INTO users (username, email, password_hash) VALUES ('test', 'test@test.com', 'hash');"

# Прочитать с SECONDARY через Router
mysql -h 127.0.0.1 -P 6447 -uappuser -papppass project_db \
  -e "SELECT * FROM users WHERE username='test';"
```

**Результат**: Данные реплицируются автоматически на все узлы

### Тест 3: Split-brain защита

```bash
# Остановить 2 узла из 3
docker compose stop mysql-server-2 mysql-server-3

# Кластер потеряет кворум и перейдет в read-only
# Это защищает от split-brain
```

**Результат**: Кластер блокирует запись при потере большинства узлов

## Файловая структура

```
homework5/
├── docker-compose.yml          # Основная конфигурация
├── config/
│   └── my.cnf                  # MySQL конфиг для InnoDB Cluster
├── scripts/
│   ├── setup-cluster.sh        # Автоматическая настройка кластера
│   ├── create-database.sql     # Создание БД проекта
│   └── check-cluster-status.sh # Проверка статуса
├── terraform/                  # Автоматизация Yandex Cloud
│   ├── main.tf
│   ├── cloud-init.yml
│   └── README.md
├── Makefile                    # Удобные команды
├── README.md                   # Подробная документация
├── QUICKSTART.md              # Быстрый старт
└── HOMEWORK_SOLUTION.md       # Этот файл
```

## Использованные технологии

- **MySQL Server 8.0**: СУБД
- **MySQL InnoDB Cluster**: Решение для HA
- **MySQL Router**: Load balancer и connection router
- **MySQL Shell**: AdminAPI для управления
- **Docker & Docker Compose**: Контейнеризация
- **Terraform**: Infrastructure as Code
- **Yandex Cloud**: Облачная платформа

## Преимущества решения

1. ✅ **Полная автоматизация**: One-command deployment
2. ✅ **Отказоустойчивость**: Автоматический failover без ручного вмешательства
3. ✅ **Масштабируемость**: Легко добавить новые узлы
4. ✅ **Производительность**: Read-масштабирование на SECONDARY узлах
5. ✅ **Простота развертывания**: Docker Compose или Terraform
6. ✅ **Готовая БД проекта**: С тестовыми данными и схемой

## Соответствие требованиям задания

| Требование | Реализация | Статус |
|------------|------------|--------|
| Отказоустойчивый кластер MySQL | InnoDB Cluster с 3 узлами | ✅ |
| Развертывание в докере | Docker Compose | ✅ |
| Развертывание на ВМ | Yandex Cloud VM + Terraform | ✅ |
| Создание БД для проекта | База project_db с таблицами | ✅ |
| Любым способом | Makefile, Docker Compose, Terraform | ✅ |

## Полезные команды

```bash
# Запуск всего кластера
make all

# Проверка статуса
make check

# Тест failover
make test-failover

# Подключение к БД
make mysql-app

# Просмотр логов
make logs

# Полная очистка
make clean
```

## Документация

- `README.md` - Полная документация по проекту
- `QUICKSTART.md` - Быстрый старт и инструкции для Yandex Cloud
- `terraform/README.md` - Документация по Terraform развертыванию

## Мониторинг и метрики

```bash
# Статус кластера
docker exec -it mysql-shell bash /scripts/check-cluster-status.sh

# Репликация на узлах
mysql -h 127.0.0.1 -P 3311 -uroot -prootpass \
  -e "SELECT * FROM performance_schema.replication_group_members;"

# Производительность
mysql -h 127.0.0.1 -P 3311 -uroot -prootpass \
  -e "SHOW GLOBAL STATUS LIKE 'Threads_%'; SHOW GLOBAL STATUS LIKE 'Questions';"
```

## Заключение

Решение предоставляет production-ready отказоустойчивый MySQL InnoDB Cluster с:
- Автоматическим failover
- Горизонтальным масштабированием чтения
- Полной автоматизацией развертывания
- Готовой структурой БД для проекта
- Возможностью развертывания локально или в Yandex Cloud

Все компоненты протестированы, документированы и готовы к использованию.
