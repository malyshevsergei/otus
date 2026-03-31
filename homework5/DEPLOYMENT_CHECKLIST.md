# Deployment Checklist - MySQL InnoDB Cluster

## Pre-Deployment

### Локальное тестирование

- [ ] Docker установлен и запущен (`docker --version`)
- [ ] Docker Compose установлен (`docker compose version`)
- [ ] Достаточно ресурсов (минимум 2GB RAM, 10GB диска)
- [ ] Порты 3311, 3312, 3313, 6446, 6447 свободны

### Yandex Cloud (если разворачиваете в облаке)

- [ ] Аккаунт в Yandex Cloud создан
- [ ] Yandex Cloud CLI установлен (`yc --version`)
- [ ] Выполнена аутентификация (`yc init`)
- [ ] SSH ключ сгенерирован (`~/.ssh/id_rsa.pub`)
- [ ] Terraform установлен (если используете, `terraform --version`)

## Deployment - Локально

### Шаг 1: Подготовка
```bash
cd /Users/s.malyshev/otus/homework5
```

- [ ] Файлы проекта на месте
- [ ] Скрипты имеют права на выполнение (`chmod +x scripts/*.sh`)

### Шаг 2: Запуск контейнеров
```bash
make start
# или: docker compose up -d
```

- [ ] Все 5 контейнеров запущены
- [ ] Проверка статуса: `docker compose ps`
- [ ] Все серверы в статусе "healthy"

Ожидаемый вывод:
```
NAME            STATUS          PORTS
mysql-server-1  Up (healthy)    3311, 33061
mysql-server-2  Up (healthy)    3312, 33062
mysql-server-3  Up (healthy)    3313, 33063
mysql-router    Up              6446-6447
mysql-shell     Up              -
```

### Шаг 3: Настройка кластера
```bash
make setup-cluster
# или: docker exec -it mysql-shell bash /scripts/setup-cluster.sh
```

- [ ] Скрипт выполнен без ошибок
- [ ] Создан пользователь clusteradmin
- [ ] Кластер 'myCluster' создан
- [ ] Все 3 узла добавлены в кластер
- [ ] Статус кластера показывает "OK"

Ожидаемый вывод в конце:
```json
{
    "clusterName": "myCluster",
    "defaultReplicaSet": {
        "status": "OK",
        "topology": {
            "mysql-server-1:3306": {"status": "ONLINE", "role": "PRIMARY"},
            "mysql-server-2:3306": {"status": "ONLINE", "role": "SECONDARY"},
            "mysql-server-3:3306": {"status": "ONLINE", "role": "SECONDARY"}
        }
    }
}
```

### Шаг 4: Создание БД проекта
```bash
make create-db
# или: docker exec -i mysql-shell mysql -h mysql-server-1 -uroot -prootpass < scripts/create-database.sql
```

- [ ] База данных `project_db` создана
- [ ] Пользователь `appuser` создан
- [ ] Таблицы созданы (users, products, orders, order_items)
- [ ] Тестовые данные загружены

Проверка:
```bash
docker exec -it mysql-shell mysql -h mysql-router -P 6446 -uappuser -papppass project_db -e "SHOW TABLES;"
```

### Шаг 5: Проверка статуса
```bash
make check
# или: docker exec -it mysql-shell bash /scripts/check-cluster-status.sh
```

- [ ] Все 3 узла в статусе ONLINE
- [ ] Один узел PRIMARY, два SECONDARY
- [ ] Нет ошибок или предупреждений
- [ ] Репликация работает на всех узлах

## Deployment - Yandex Cloud (Terraform)

### Шаг 1: Подготовка Terraform

```bash
cd terraform
```

- [ ] Переменные окружения установлены:
  ```bash
  export YC_TOKEN=$(yc iam create-token)
  export YC_CLOUD_ID=$(yc config get cloud-id)
  export YC_FOLDER_ID=$(yc config get folder-id)
  ```
- [ ] SSH ключ существует (`ls ~/.ssh/id_rsa.pub`)

### Шаг 2: Инициализация

```bash
terraform init
```

- [ ] Провайдеры загружены
- [ ] Нет ошибок инициализации

### Шаг 3: Проверка плана

```bash
terraform plan
```

- [ ] План создания корректен
- [ ] Будут созданы: сеть, подсеть, security group, VM
- [ ] Параметры VM соответствуют требованиям (CPU, RAM, диск)

### Шаг 4: Применение

```bash
terraform apply
```

- [ ] Подтверждено создание (`yes`)
- [ ] VM создана успешно
- [ ] Получен внешний IP адрес

### Шаг 5: Подключение к VM

```bash
EXTERNAL_IP=$(terraform output -raw external_ip)
ssh ubuntu@$EXTERNAL_IP
```

- [ ] SSH соединение установлено
- [ ] Docker установлен на VM (`docker --version`)

### Шаг 6: Загрузка проекта на VM

```bash
# На локальной машине
cd ..
scp -r docker-compose.yml config scripts Makefile README.md ubuntu@$EXTERNAL_IP:/home/ubuntu/mysql-cluster/
```

- [ ] Все файлы скопированы
- [ ] Права на файлы корректны

### Шаг 7: Запуск на VM

```bash
# На VM
cd /home/ubuntu/mysql-cluster
make all
```

- [ ] Контейнеры запущены
- [ ] Кластер настроен
- [ ] БД создана
- [ ] Статус OK

## Post-Deployment Testing

### Тест 1: Подключение к кластеру

#### Локально:
```bash
mysql -h 127.0.0.1 -P 6446 -uappuser -papppass project_db -e "SELECT COUNT(*) FROM users;"
```

#### Yandex Cloud:
```bash
mysql -h $EXTERNAL_IP -P 6446 -uappuser -papppass project_db -e "SELECT COUNT(*) FROM users;"
```

- [ ] Подключение успешно
- [ ] Запросы выполняются
- [ ] Данные отображаются

### Тест 2: Read-Write операции

```bash
# Write
mysql -h 127.0.0.1 -P 6446 -uappuser -papppass project_db \
  -e "INSERT INTO users (username, email, password_hash) VALUES ('testuser', 'test@example.com', 'hash123');"

# Read
mysql -h 127.0.0.1 -P 6447 -uappuser -papppass project_db \
  -e "SELECT * FROM users WHERE username='testuser';"
```

- [ ] Запись успешна
- [ ] Чтение с SECONDARY успешно
- [ ] Данные реплицированы

### Тест 3: Failover

```bash
# Остановить PRIMARY
docker compose stop mysql-server-1

# Подождать 10 секунд
sleep 10

# Проверить статус
make check
```

- [ ] Кластер автоматически выбрал новый PRIMARY
- [ ] Статус кластера "OK"
- [ ] Приложения продолжают работать через Router

```bash
# Вернуть узел
docker compose start mysql-server-1

# Проверить через 10 секунд
sleep 10
make check
```

- [ ] Узел автоматически присоединился
- [ ] Статус узла "ONLINE" (SECONDARY)
- [ ] Репликация восстановлена

### Тест 4: Производительность

```bash
# Простой нагрузочный тест
for i in {1..100}; do
  mysql -h 127.0.0.1 -P 6446 -uappuser -papppass project_db \
    -e "INSERT INTO products (name, description, price, stock_quantity, category) VALUES ('Product$i', 'Description$i', 99.99, 10, 'Test');" &
done
wait

# Проверить
mysql -h 127.0.0.1 -P 6446 -uappuser -papppass project_db \
  -e "SELECT COUNT(*) FROM products WHERE category='Test';"
```

- [ ] 100 записей вставлено
- [ ] Нет ошибок
- [ ] Данные корректны на всех узлах

## Monitoring Setup

### Логи

```bash
# Просмотр логов
docker compose logs -f
```

- [ ] Логи доступны
- [ ] Нет критических ошибок
- [ ] Репликация работает

### Performance Schema

```bash
mysql -h 127.0.0.1 -P 3311 -uroot -prootpass \
  -e "SELECT * FROM performance_schema.replication_group_members;"
```

- [ ] Все члены группы видны
- [ ] Статусы ONLINE
- [ ] Role корректны (PRIMARY/SECONDARY)

### Метрики кластера

```bash
docker exec -it mysql-shell mysqlsh -uclusteradmin -pclusterpass -h mysql-server-1 --js \
  -e "var cluster = dba.getCluster('myCluster'); cluster.status();"
```

- [ ] Кластер в статусе "OK"
- [ ] Все узлы ONLINE
- [ ] Нет отставаний репликации

## Security Checklist

⚠️ **Для Production окружения:**

- [ ] Изменены все пароли по умолчанию
  - [ ] root password
  - [ ] clusteradmin password
  - [ ] appuser password
- [ ] Настроен SSL/TLS для соединений
- [ ] Ограничен сетевой доступ (firewall)
- [ ] Настроено логирование audit
- [ ] Регулярные бэкапы настроены
- [ ] Мониторинг настроен (Prometheus, Grafana)
- [ ] Alerting настроен

## Backup & Recovery

### Создание бэкапа

```bash
# Логический бэкап через mysqldump
docker exec mysql-server-1 mysqldump -uroot -prootpass --all-databases \
  --single-transaction --triggers --routines --events > backup_$(date +%Y%m%d).sql
```

- [ ] Бэкап создан
- [ ] Размер бэкапа адекватен
- [ ] Файл бэкапа читаем

### Тест восстановления

```bash
# Создать тестовую БД и восстановить в нее
docker exec -i mysql-server-1 mysql -uroot -prootpass < backup_*.sql
```

- [ ] Восстановление прошло успешно
- [ ] Данные корректны

## Documentation

- [ ] README.md прочитан
- [ ] QUICKSTART.md прочитан
- [ ] HOMEWORK_SOLUTION.md прочитан
- [ ] Все пароли и IP адреса задокументированы в безопасном месте

## Final Checks

- [ ] Все компоненты работают
- [ ] Кластер в статусе "OK"
- [ ] БД проекта доступна
- [ ] Тесты failover пройдены
- [ ] Производительность приемлема
- [ ] Документация актуальна
- [ ] Backup настроен (для production)
- [ ] Мониторинг настроен (для production)

## Rollback Plan

В случае проблем:

### Локально
```bash
docker compose down -v
docker compose up -d
# Повторить настройку
```

### Yandex Cloud
```bash
terraform destroy
# Исправить проблемы
terraform apply
```

## Support Contacts

- OTUS Support: support@otus.ru
- MySQL Documentation: https://dev.mysql.com/doc/
- Project Issues: (ваш репозиторий)

---

**Дата развертывания**: _________________

**Выполнил**: _________________

**Статус**: ⬜ Success  ⬜ Failed  ⬜ Partial

**Заметки**:
_____________________________________________________________
_____________________________________________________________
_____________________________________________________________
