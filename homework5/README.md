# MySQL InnoDB Cluster - OTUS Homework 5

Отказоустойчивый кластер MySQL InnoDB Cluster в Docker для Yandex Cloud.

## Описание решения

Данный проект разворачивает MySQL InnoDB Cluster, состоящий из:
- 3 узла MySQL Server 8.0 (для обеспечения отказоустойчивости)
- MySQL Router (для автоматической маршрутизации запросов)
- MySQL Shell (для управления кластером)

## Компоненты

### MySQL Servers
- **mysql-server-1**: Первичный узел (порты 3311, 33061)
- **mysql-server-2**: Вторичный узел (порты 3312, 33062)
- **mysql-server-3**: Вторичный узел (порты 3313, 33063)

### MySQL Router
- Порт 6446: Read-Write соединения (PRIMARY)
- Порт 6447: Read-Only соединения (SECONDARY)

### Сеть
- Subnet: 172.20.0.0/16
- mysql-server-1: 172.20.0.11
- mysql-server-2: 172.20.0.12
- mysql-server-3: 172.20.0.13
- mysql-shell: 172.20.0.10
- mysql-router: 172.20.0.20

## Быстрый старт

### 1. Запуск кластера

```bash
# Запустить все контейнеры
docker-compose up -d

# Проверить статус контейнеров
docker-compose ps
```

### 2. Настройка InnoDB Cluster

```bash
# Выполнить скрипт настройки кластера
docker exec -it mysql-shell bash /scripts/setup-cluster.sh
```

Скрипт выполнит:
- Создание пользователя администратора кластера
- Конфигурацию всех инстансов для работы в кластере
- Создание InnoDB Cluster с именем 'myCluster'
- Добавление всех узлов в кластер

### 3. Создание базы данных проекта

```bash
# Создать базу данных и тестовые таблицы
docker exec -it mysql-shell mysql -h mysql-server-1 -uroot -prootpass < /scripts/create-database.sql
```

### 4. Проверка статуса кластера

```bash
# Проверить состояние кластера
docker exec -it mysql-shell bash /scripts/check-cluster-status.sh
```

## Подключение к кластеру

### Через MySQL Router (рекомендуется)

```bash
# Read-Write подключение (PRIMARY)
mysql -h 127.0.0.1 -P 6446 -uappuser -papppass project_db

# Read-Only подключение (SECONDARY)
mysql -h 127.0.0.1 -P 6447 -uappuser -papppass project_db
```

### Напрямую к узлам

```bash
# К первому узлу
mysql -h 127.0.0.1 -P 3311 -uroot -prootpass

# Ко второму узлу
mysql -h 127.0.0.1 -P 3312 -uroot -prootpass

# К третьему узлу
mysql -h 127.0.0.1 -P 3313 -uroot -prootpass
```

## Учетные данные

### Root пользователь
- Username: `root`
- Password: `rootpass`

### Cluster Admin
- Username: `clusteradmin`
- Password: `clusterpass`

### Application User
- Username: `appuser`
- Password: `apppass`
- Database: `project_db`

## Тестирование отказоустойчивости

### Остановка PRIMARY узла

```bash
# Остановить первый узел
docker-compose stop mysql-server-1

# Проверить статус - один из оставшихся узлов станет PRIMARY
docker exec -it mysql-shell bash /scripts/check-cluster-status.sh

# Запустить узел обратно
docker-compose start mysql-server-1
```

### Проверка автоматической репликации

```bash
# Подключиться к PRIMARY и создать тестовую таблицу
mysql -h 127.0.0.1 -P 6446 -uappuser -papppass project_db -e "CREATE TABLE test (id INT PRIMARY KEY AUTO_INCREMENT, data VARCHAR(100)); INSERT INTO test (data) VALUES ('test data');"

# Проверить на SECONDARY узле
mysql -h 127.0.0.1 -P 6447 -uappuser -papppass project_db -e "SELECT * FROM test;"
```

## Управление кластером

### Вход в MySQL Shell

```bash
docker exec -it mysql-shell mysqlsh -uclusteradmin -pclusterpass -h mysql-server-1
```

### Полезные команды в MySQL Shell

```javascript
// Получить кластер
var cluster = dba.getCluster('myCluster');

// Статус кластера
cluster.status();

// Описание кластера
cluster.describe();

// Проверка инстанса
cluster.checkInstanceState('clusteradmin@mysql-server-2:3306');

// Ребаланс кластера
cluster.rebalanceInstances();
```

## Структура проекта

```
homework5/
├── docker-compose.yml          # Основная конфигурация Docker Compose
├── config/
│   └── my.cnf                  # Конфигурация MySQL для InnoDB Cluster
├── scripts/
│   ├── setup-cluster.sh        # Скрипт настройки кластера
│   ├── create-database.sql     # Создание БД проекта
│   └── check-cluster-status.sh # Проверка статуса кластера
└── README.md                   # Документация
```

## База данных проекта

База данных `project_db` содержит следующие таблицы:
- **users**: Пользователи системы
- **products**: Каталог товаров
- **orders**: Заказы
- **order_items**: Элементы заказов

## Мониторинг

### Просмотр логов

```bash
# Логи всех контейнеров
docker-compose logs -f

# Логи конкретного контейнера
docker-compose logs -f mysql-server-1
```

### Performance Schema

```bash
# Просмотр состояния репликации
mysql -h 127.0.0.1 -P 3311 -uroot -prootpass -e "SELECT * FROM performance_schema.replication_group_members;"

# Просмотр статистики группы
mysql -h 127.0.0.1 -P 3311 -uroot -prootpass -e "SELECT * FROM performance_schema.replication_group_member_stats\G"
```

## Очистка

```bash
# Остановить и удалить контейнеры
docker-compose down

# Удалить вместе с volumes (ВНИМАНИЕ: удалит все данные)
docker-compose down -v
```

## Требования

- Docker 20.10+
- Docker Compose 1.29+
- Минимум 2GB RAM
- Минимум 10GB дискового пространства

## Troubleshooting

### Кластер не инициализируется

1. Проверьте статус всех контейнеров: `docker-compose ps`
2. Проверьте логи: `docker-compose logs`
3. Убедитесь, что все порты свободны
4. Перезапустите с чистыми volumes: `docker-compose down -v && docker-compose up -d`

### Ошибки подключения

1. Проверьте что все узлы запущены
2. Проверьте статус кластера: `docker exec -it mysql-shell bash /scripts/check-cluster-status.sh`
3. Убедитесь в правильности учетных данных

## Производительность

Конфигурация оптимизирована для работы в Docker:
- InnoDB buffer pool: 256MB
- Max connections: 200
- 4 параллельных потока репликации

Для production рекомендуется увеличить параметры в `config/my.cnf`.

## Безопасность

⚠️ **ВАЖНО**: Данная конфигурация предназначена для разработки и тестирования!

Для production необходимо:
- Изменить все пароли
- Настроить SSL/TLS
- Ограничить сетевой доступ
- Настроить файрволл
- Включить audit логирование

## Полезные ссылки

- [MySQL InnoDB Cluster Documentation](https://dev.mysql.com/doc/refman/8.0/en/mysql-innodb-cluster-introduction.html)
- [MySQL Sample Databases](https://dev.mysql.com/doc/index-other.html)
- [MySQL Shell Documentation](https://dev.mysql.com/doc/mysql-shell/8.0/en/)
