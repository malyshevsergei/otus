# Ansible Quick Start Guide

## Подготовка за 5 минут

### 1. Установите Ansible

```bash
# MacOS
brew install ansible

# Ubuntu/Debian
sudo apt update && sudo apt install -y ansible

# Проверка
ansible --version
```

### 2. Установите зависимости

```bash
cd ansible

# Установить коллекции Ansible
ansible-galaxy collection install -r requirements.yml

# Установить Python библиотеки
pip3 install docker docker-compose
```

### 3. Создайте VM в Yandex Cloud

```bash
# С помощью Yandex Cloud CLI
yc compute instance create \
  --name mysql-cluster-node-1 \
  --zone ru-central1-a \
  --cores 4 \
  --memory 8 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=50 \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --ssh-key ~/.ssh/id_rsa.pub

# Получите IP адрес
EXTERNAL_IP=$(yc compute instance get mysql-cluster-node-1 --format json | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')
echo "VM IP: $EXTERNAL_IP"
```

### 4. Настройте inventory

```bash
# Отредактируйте inventory/hosts.yml
vim inventory/hosts.yml

# Замените ansible_host на ваш EXTERNAL_IP:
all:
  children:
    mysql_cluster:
      hosts:
        mysql-node-1:
          ansible_host: YOUR_EXTERNAL_IP  # ← Вставьте сюда ваш IP
```

### 5. Проверьте подключение

```bash
ansible all -m ping
```

Должны увидеть:
```
mysql-node-1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

### 6. Разверните кластер одной командой! 🚀

#### Автоматический способ (рекомендуется):

```bash
./deploy.sh
```

#### Или вручную:

```bash
ansible-playbook playbooks/deploy-all.yml
```

Эта команда автоматически:
- ✅ Установит все необходимые пакеты
- ✅ Установит и настроит Docker
- ✅ Скопирует конфигурации MySQL
- ✅ Запустит 3 MySQL сервера + Router
- ✅ Настроит InnoDB Cluster
- ✅ Создаст базу данных проекта
- ✅ Проверит статус кластера

**Время выполнения: ~5-10 минут**

### 7. Проверьте результат

```bash
# Простой способ
./check-status.sh

# Полное тестирование
./test-cluster.sh

# Или вручную
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && make check"
```

## Подключение к кластеру

### С вашей локальной машины

```bash
# Получите IP вашей VM
EXTERNAL_IP="YOUR_VM_IP"

# Read-Write подключение (PRIMARY)
mysql -h $EXTERNAL_IP -P 6446 -uappuser -papppass project_db

# Read-Only подключение (SECONDARY)
mysql -h $EXTERNAL_IP -P 6447 -uappuser -papppass project_db
```

### Через SSH туннель (рекомендуется)

```bash
# Создать туннель
ssh -L 6446:localhost:6446 -L 6447:localhost:6447 ubuntu@$EXTERNAL_IP

# В другом терминале подключиться
mysql -h 127.0.0.1 -P 6446 -uappuser -papppass project_db
```

## Управление кластером

### Интерактивное управление

```bash
ansible-playbook playbooks/manage-cluster.yml
```

Меню опций:
1. Check cluster status - Проверить статус
2. Restart cluster - Перезапустить
3. Stop cluster - Остановить
4. Start cluster - Запустить
5. View logs - Посмотреть логи
6. Backup database - Сделать бэкап

### Ad-hoc команды

```bash
# Статус кластера
ansible mysql_cluster -a "docker compose ps" -a "chdir=/opt/mysql-cluster"

# Логи
ansible mysql_cluster -a "docker compose logs --tail=50" -a "chdir=/opt/mysql-cluster"

# Перезапуск
ansible mysql_cluster -a "docker compose restart" -a "chdir=/opt/mysql-cluster"
```

## Тестирование

### Тест отказоустойчивости

```bash
# 1. Остановить PRIMARY узел
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker compose stop mysql-server-1"

# 2. Проверить статус (новый PRIMARY должен быть выбран автоматически)
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && make check"

# 3. Кластер продолжает работать!
mysql -h $EXTERNAL_IP -P 6446 -uappuser -papppass project_db -e "SELECT COUNT(*) FROM users;"

# 4. Вернуть узел обратно
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker compose start mysql-server-1"
```

### Тест репликации

```bash
# Вставить данные на PRIMARY
mysql -h $EXTERNAL_IP -P 6446 -uappuser -papppass project_db \
  -e "INSERT INTO users (username, email, password_hash) VALUES ('testuser', 'test@example.com', 'hash123');"

# Прочитать с SECONDARY
mysql -h $EXTERNAL_IP -P 6447 -uappuser -papppass project_db \
  -e "SELECT * FROM users WHERE username='testuser';"

# Данные должны быть реплицированы!
```

## Использование с несколькими VM

Если вы хотите развернуть каждый MySQL сервер на отдельной VM:

### 1. Создайте 3 VM

```bash
for i in 1 2 3; do
  yc compute instance create \
    --name mysql-cluster-node-$i \
    --zone ru-central1-a \
    --cores 2 \
    --memory 4 \
    --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=30 \
    --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
    --ssh-key ~/.ssh/id_rsa.pub
done
```

### 2. Обновите inventory

```yaml
all:
  children:
    mysql_cluster:
      hosts:
        mysql-node-1:
          ansible_host: <IP_NODE_1>
        mysql-node-2:
          ansible_host: <IP_NODE_2>
        mysql-node-3:
          ansible_host: <IP_NODE_3>
```

### 3. Разверните на всех узлах

```bash
ansible-playbook playbooks/deploy-all.yml
```

## Полезные команды

```bash
# Dry-run (проверка без изменений)
ansible-playbook playbooks/deploy-all.yml --check

# Verbose режим
ansible-playbook playbooks/deploy-all.yml -vvv

# Только определенные таги
ansible-playbook playbooks/deploy-all.yml --tags docker

# Пропустить теги
ansible-playbook playbooks/deploy-all.yml --skip-tags mysql

# Только на определенном хосте
ansible-playbook playbooks/deploy-all.yml --limit mysql-node-1
```

## Безопасность

### Использование Ansible Vault для паролей

```bash
# Создать vault файл
ansible-vault create inventory/group_vars/vault.yml

# Добавьте в файл:
---
vault_mysql_root_password: "your_super_secure_password"
vault_mysql_cluster_password: "another_secure_password"
vault_mysql_app_password: "app_secure_password"

# Обновите inventory/group_vars/all.yml:
mysql_root_password: "{{ vault_mysql_root_password }}"
mysql_cluster_password: "{{ vault_mysql_cluster_password }}"
mysql_app_password: "{{ vault_mysql_app_password }}"

# Запустите playbook с vault
ansible-playbook playbooks/deploy-all.yml --ask-vault-pass
```

## Обновление кластера

```bash
# Обновить конфигурации
ansible-playbook playbooks/deploy-all.yml --tags mysql-cluster

# Только обновить Docker образы
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker compose pull && docker compose up -d"
```

## Резервное копирование

```bash
# Создать бэкап через Ansible
ansible mysql_cluster -m shell -a "docker exec mysql-server-1 mysqldump -uroot -prootpass --all-databases > /tmp/backup_$(date +%Y%m%d).sql"

# Скачать бэкап на локальную машину
ansible mysql_cluster -m fetch -a "src=/tmp/backup_*.sql dest=./backups/ flat=yes"
```

## Troubleshooting

### Ansible не может подключиться

```bash
# Проверьте SSH напрямую
ssh ubuntu@$EXTERNAL_IP

# Проверьте с verbose
ansible all -m ping -vvv

# Укажите SSH ключ явно
ansible all -m ping --private-key ~/.ssh/id_rsa
```

### Docker не установлен

```bash
# Установите только Docker
ansible-playbook playbooks/deploy-all.yml --tags docker
```

### Кластер не запускается

```bash
# Проверьте логи
ansible mysql_cluster -a "docker compose logs" -a "chdir=/opt/mysql-cluster"

# Пересоздайте контейнеры
ansible mysql_cluster -a "docker compose down -v && docker compose up -d" -a "chdir=/opt/mysql-cluster"

# Запустите setup повторно
ansible mysql_cluster -a "docker exec mysql-shell bash /scripts/setup-cluster.sh"
```

## Что дальше?

1. 📖 Прочитайте полную документацию: `ansible/README.md`
2. 🔒 Настройте Ansible Vault для безопасности
3. 📊 Добавьте мониторинг (Prometheus, Grafana)
4. 🔄 Настройте автоматические бэкапы
5. 🚀 Интегрируйте с CI/CD

## Преимущества Ansible подхода

✅ **Идемпотентность** - можно запускать многократно
✅ **Декларативный стиль** - описываете желаемое состояние
✅ **Агентless** - не требует установки агентов на серверах
✅ **Масштабируемость** - легко добавлять новые узлы
✅ **Переиспользование** - роли можно использовать в других проектах
✅ **Версионирование** - вся инфраструктура в Git

---

**Готово!** Ваш MySQL InnoDB Cluster развернут и работает! 🎉
