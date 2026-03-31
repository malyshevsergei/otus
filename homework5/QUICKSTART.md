# Быстрый старт - MySQL InnoDB Cluster

## Для развертывания на Yandex Cloud VM

### Шаг 1: Подготовка VM в Yandex Cloud

1. Создайте VM в Yandex Cloud через консоль или CLI:
```bash
yc compute instance create \
  --name mysql-cluster \
  --zone ru-central1-a \
  --cores 4 \
  --memory 8 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=50 \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --ssh-key ~/.ssh/id_rsa.pub
```

2. Подключитесь к VM:
```bash
ssh ubuntu@<EXTERNAL_IP>
```

### Шаг 2: Установка Docker на VM

```bash
# Обновить пакеты
sudo apt-get update

# Установить необходимые пакеты
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Добавить GPG ключ Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Добавить репозиторий Docker
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установить Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Добавить пользователя в группу docker
sudo usermod -aG docker $USER
newgrp docker

# Проверить установку
docker --version
docker compose version
```

### Шаг 3: Загрузка проекта на VM

Вариант А - если используете Git:
```bash
# Склонировать репозиторий
git clone <your-repo-url>
cd homework5
```

Вариант Б - загрузка файлов через SCP:
```bash
# На локальной машине
cd /Users/s.malyshev/otus
scp -r homework5 ubuntu@<EXTERNAL_IP>:~/

# На VM
cd ~/homework5
```

### Шаг 4: Запуск кластера

```bash
# Запустить контейнеры
docker compose up -d

# Подождать ~30 секунд пока MySQL серверы запустятся
sleep 30

# Настроить InnoDB Cluster
docker exec -it mysql-shell bash /scripts/setup-cluster.sh

# Создать базу данных проекта
docker exec -i mysql-shell mysql -h mysql-server-1 -uroot -prootpass < scripts/create-database.sql

# Проверить статус кластера
docker exec -it mysql-shell bash /scripts/check-cluster-status.sh
```

## Альтернативно - используя Makefile

```bash
# Запустить все сразу
make all

# Или по шагам:
make start          # Запустить контейнеры
make setup-cluster  # Настроить кластер
make create-db      # Создать БД
make check          # Проверить статус
```

## Проверка работы

### 1. Проверить статус контейнеров
```bash
docker compose ps
```

Должны быть запущены:
- mysql-server-1 (healthy)
- mysql-server-2 (healthy)
- mysql-server-3 (healthy)
- mysql-shell
- mysql-router

### 2. Подключиться к кластеру через Router
```bash
# Read-Write соединение
docker exec -it mysql-shell mysql -h mysql-router -P 6446 -uappuser -papppass project_db

# В MySQL выполнить:
SHOW TABLES;
SELECT * FROM users;
```

### 3. Проверить репликацию
```bash
# На PRIMARY создать тестовые данные
docker exec -it mysql-shell mysql -h mysql-router -P 6446 -uappuser -papppass project_db -e "INSERT INTO users (username, email, password_hash) VALUES ('test_user', 'test@example.com', 'hash123');"

# Проверить на SECONDARY
docker exec -it mysql-shell mysql -h mysql-router -P 6447 -uappuser -papppass project_db -e "SELECT * FROM users WHERE username='test_user';"
```

### 4. Тест отказоустойчивости
```bash
# Остановить PRIMARY узел
docker compose stop mysql-server-1

# Подождать автоматического переключения (~10 сек)
sleep 10

# Проверить статус - должен быть новый PRIMARY
docker exec -it mysql-shell bash /scripts/check-cluster-status.sh

# Кластер должен продолжать работать
docker exec -it mysql-shell mysql -h mysql-router -P 6446 -uappuser -papppass project_db -e "SELECT COUNT(*) FROM users;"

# Вернуть узел обратно
docker compose start mysql-server-1
```

## Доступ извне VM

Для доступа к кластеру с вашей локальной машины, настройте проброс портов в Yandex Cloud:

```bash
# На локальной машине создать SSH туннель
ssh -L 6446:<VM_INTERNAL_IP>:6446 -L 6447:<VM_INTERNAL_IP>:6447 ubuntu@<EXTERNAL_IP>

# Теперь можно подключаться локально
mysql -h 127.0.0.1 -P 6446 -uappuser -papppass project_db
```

## Загрузка тестовых данных MySQL

Если нужна большая тестовая БД:

```bash
# Скачать например world database
wget https://downloads.mysql.com/docs/world-db.tar.gz
tar -xzf world-db.tar.gz

# Загрузить в кластер
docker exec -i mysql-shell mysql -h mysql-router -P 6446 -uroot -prootpass < world-db/world.sql

# Проверить
docker exec -it mysql-shell mysql -h mysql-router -P 6446 -uroot -prootpass world -e "SHOW TABLES; SELECT COUNT(*) FROM city;"
```

## Мониторинг

```bash
# Логи кластера
docker compose logs -f

# Статус репликации на всех узлах
for i in 1 2 3; do
  echo "=== mysql-server-$i ==="
  docker exec mysql-server-$i mysql -uroot -prootpass -e "SELECT * FROM performance_schema.replication_group_members;"
done

# Производительность
docker exec mysql-server-1 mysql -uroot -prootpass -e "SHOW GLOBAL STATUS LIKE 'Threads_connected'; SHOW GLOBAL STATUS LIKE 'Queries';"
```

## Остановка и очистка

```bash
# Остановить кластер
docker compose stop

# Удалить контейнеры (данные сохранятся)
docker compose down

# Удалить всё включая данные
docker compose down -v
```

## Troubleshooting

### Ошибка "Can't connect to MySQL server"
- Проверьте что контейнеры запущены: `docker compose ps`
- Проверьте логи: `docker compose logs mysql-server-1`
- Подождите ~30 секунд после запуска

### Ошибка при setup-cluster.sh
- Убедитесь что все серверы healthy: `docker compose ps`
- Перезапустите: `docker compose restart`
- Попробуйте заново: `docker exec -it mysql-shell bash /scripts/setup-cluster.sh`

### Кластер не синхронизируется
```bash
# Пересоздать кластер с чистого листа
docker compose down -v
docker compose up -d
sleep 30
docker exec -it mysql-shell bash /scripts/setup-cluster.sh
```

## Полезные команды

```bash
# Войти в MySQL Shell для управления кластером
docker exec -it mysql-shell mysqlsh -uclusteradmin -pclusterpass -h mysql-server-1

# В MySQL Shell:
\js
var cluster = dba.getCluster('myCluster');
cluster.status();
cluster.describe();

# Добавить узел обратно в кластер (если выпал)
cluster.rejoinInstance('clusteradmin@mysql-server-2:3306');

# Перебалансировка
cluster.rebalanceInstances();
```

## Что дальше?

1. Изучите `README.md` для подробной документации
2. Настройте под свои нужды `config/my.cnf`
3. Добавьте свои таблицы в `scripts/create-database.sql`
4. Настройте резервное копирование
5. Настройте мониторинг (Prometheus + Grafana)

## Полезные материалы

- [MySQL InnoDB Cluster User Guide](https://dev.mysql.com/doc/refman/8.0/en/mysql-innodb-cluster-userguide.html)
- [MySQL Router Documentation](https://dev.mysql.com/doc/mysql-router/8.0/en/)
- [Sample Databases](https://dev.mysql.com/doc/index-other.html)
