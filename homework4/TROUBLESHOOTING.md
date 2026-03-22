# Руководство по устранению неполадок

## Общие проблемы

### Terraform

#### Проблема: "Error: quota exceeded"

**Симптомы:**
```
Error: Error while requesting API to create instance: server-request-id = ... rpc error: code = ResourceExhausted desc = Quota limit vpc.networks.count exceeded
```

**Решение:**
1. Проверить квоты:
   ```bash
   yc compute quota list
   ```

2. Удалить неиспользуемые ресурсы или запросить увеличение квот в консоли Yandex Cloud

#### Проблема: "Error: Invalid provider credentials"

**Симптомы:**
```
Error: Error while requesting API to create network: server-request-id = ... rpc error: code = Unauthenticated desc = missing credentials
```

**Решение:**
```bash
# Проверить переменные окружения
echo $YC_TOKEN
echo $YC_CLOUD_ID
echo $YC_FOLDER_ID

# Или аутентифицироваться заново
yc init
export YC_TOKEN=$(yc iam create-token)
```

#### Проблема: "Error: Image not found"

**Симптомы:**
```
Error: Error while requesting API to create instance: server-request-id = ... rpc error: code = NotFound desc = Image not found
```

**Решение:**
1. Получить актуальный ID образа Ubuntu 22.04:
   ```bash
   yc compute image list --folder-id standard-images | grep ubuntu-22-04
   ```

2. Обновить переменную в `terraform/variables.tf` или `terraform.tfvars`

#### Проблема: Terraform state locked

**Симптомы:**
```
Error: Error acquiring the state lock
```

**Решение:**
```bash
# ВНИМАНИЕ: Используйте только если уверены, что нет других запущенных terraform процессов
cd terraform
terraform force-unlock <LOCK_ID>
```

### Ansible

#### Проблема: "Failed to connect to the host via ssh"

**Симптомы:**
```
fatal: [nginx-1]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh: ..."}
```

**Решение:**
1. Проверить доступность хоста:
   ```bash
   ping <HOST_IP>
   ssh -v ubuntu@<HOST_IP>
   ```

2. Проверить SSH ключи:
   ```bash
   ssh-add -l  # Список загруженных ключей
   ssh-add ~/.ssh/id_rsa  # Добавить ключ если нужно
   ```

3. Проверить security groups в Yandex Cloud (порт 22 должен быть открыт)

#### Проблема: "Permission denied (publickey)"

**Симптомы:**
```
Permission denied (publickey).
```

**Решение:**
1. Проверить, что публичный ключ соответствует приватному:
   ```bash
   ssh-keygen -y -f ~/.ssh/id_rsa > /tmp/public.pub
   diff /tmp/public.pub ~/.ssh/id_rsa.pub
   ```

2. Пересоздать инфраструктуру с правильным ключом:
   ```bash
   cd terraform
   terraform destroy
   # Исправить ssh_public_key_path в terraform.tfvars
   terraform apply
   ```

#### Проблема: "sudo: a password is required"

**Симптомы:**
```
"msg": "Missing sudo password"
```

**Решение:**
1. Убедиться, что в `ansible.cfg` установлено:
   ```ini
   [privilege_escalation]
   become = True
   become_method = sudo
   ```

2. Или добавить пароль:
   ```bash
   ansible-playbook -i inventory.ini site.yml --ask-become-pass
   ```

#### Проблема: Ansible роль не найдена

**Симптомы:**
```
ERROR! the role 'nginx' was not found
```

**Решение:**
1. Проверить структуру директорий:
   ```bash
   tree ansible/roles/
   ```

2. Проверить `ansible.cfg`:
   ```ini
   [defaults]
   roles_path = roles
   ```

3. Запускать playbook из директории `ansible/`:
   ```bash
   cd ansible
   ansible-playbook -i inventory.ini site.yml
   ```

### Nginx

#### Проблема: 502 Bad Gateway

**Симптомы:**
```
curl http://<LB_IP>/
<html>
<head><title>502 Bad Gateway</title></head>
```

**Диагностика:**
```bash
# SSH на Nginx сервер
ssh ubuntu@<NGINX_IP>

# Проверить логи
sudo tail -f /var/log/nginx/webapp_error.log

# Проверить upstream
curl -I http://<BACKEND_IP>:8000/
```

**Возможные причины:**
1. Backend серверы не запущены
2. Неправильный upstream в конфигурации
3. Файрвол блокирует соединение

**Решение:**
```bash
# На Backend сервере проверить uWSGI
sudo systemctl status uwsgi
sudo systemctl restart uwsgi

# Проверить логи uWSGI
sudo tail -f /var/log/uwsgi/webapp.log
```

#### Проблема: 404 Not Found для статики

**Симптомы:**
```
curl http://<LB_IP>/static/admin/css/base.css
404 Not Found
```

**Решение:**
```bash
# SSH на Backend сервер
ssh ubuntu@<BACKEND_IP>

# Собрать статику заново
cd /opt/webapp
source venv/bin/activate
python manage.py collectstatic --noinput

# Проверить права
ls -la /var/www/static/
sudo chown -R www-data:www-data /var/www/static/
```

#### Проблема: Nginx не запускается

**Симптомы:**
```
sudo systemctl status nginx
● nginx.service - A high performance web server
   Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
   Active: failed
```

**Диагностика:**
```bash
# Проверить конфигурацию
sudo nginx -t

# Посмотреть подробные логи
sudo journalctl -u nginx -n 50
```

**Решение:**
```bash
# Исправить ошибки в конфигурации
sudo nano /etc/nginx/sites-available/webapp.conf

# Проверить и перезапустить
sudo nginx -t && sudo systemctl restart nginx
```

### Backend (Django + uWSGI)

#### Проблема: uWSGI не запускается

**Симптомы:**
```
sudo systemctl status uwsgi
● uwsgi.service - uWSGI instance to serve webapp
   Active: failed
```

**Диагностика:**
```bash
# Логи systemd
sudo journalctl -u uwsgi -n 50

# Логи uWSGI
sudo tail -f /var/log/uwsgi/webapp.log

# Попробовать запустить вручную
cd /opt/webapp
venv/bin/uwsgi --ini uwsgi.ini
```

**Возможные проблемы:**
1. Ошибка в uwsgi.ini
2. Python зависимости не установлены
3. Django проект не найден
4. База данных недоступна

**Решение:**
```bash
# Проверить зависимости
cd /opt/webapp
source venv/bin/activate
pip list

# Переустановить зависимости
pip install Django uwsgi psycopg2-binary python-decouple

# Проверить Django
python manage.py check

# Запустить миграции
python manage.py migrate
```

#### Проблема: Django не подключается к БД

**Симптомы:**
```
django.db.utils.OperationalError: could not connect to server: Connection refused
```

**Диагностика:**
```bash
# Проверить доступность БД
telnet <DB_IP> 5432

# Или
nc -zv <DB_IP> 5432
```

**Решение:**
1. Проверить, что PostgreSQL запущен на DB сервере:
   ```bash
   ssh ubuntu@<DB_IP>
   sudo systemctl status postgresql
   ```

2. Проверить настройки в .env файле:
   ```bash
   cat /opt/webapp/.env
   # DB_HOST должен быть правильным
   ```

3. Проверить pg_hba.conf на DB сервере:
   ```bash
   sudo cat /etc/postgresql/14/main/pg_hba.conf | grep webapp
   ```

#### Проблема: 500 Internal Server Error

**Симптомы:**
```
curl http://<LB_IP>/
500 Internal Server Error
```

**Диагностика:**
```bash
# Логи Django/uWSGI
sudo tail -f /var/log/uwsgi/webapp.log

# Проверить Django
cd /opt/webapp
source venv/bin/activate
python manage.py check
python manage.py runserver 0.0.0.0:8001  # Тестовый запуск
```

**Решение:**
Исправить ошибки показанные в логах или при `python manage.py check`

### Database (PostgreSQL)

#### Проблема: PostgreSQL не принимает соединения

**Симптомы:**
```
psql: could not connect to server: Connection refused
```

**Диагностика:**
```bash
# Проверить, что слушает на всех интерфейсах
sudo netstat -tlnp | grep 5432

# Должно быть:
# 0.0.0.0:5432 или *:5432
```

**Решение:**
```bash
# Проверить postgresql.conf
sudo grep listen_addresses /etc/postgresql/14/main/postgresql.conf
# Должно быть: listen_addresses = '*'

# Перезапустить PostgreSQL
sudo systemctl restart postgresql
```

#### Проблема: Authentication failed

**Симптомы:**
```
psql: FATAL: password authentication failed for user "webapp_user"
```

**Решение:**
```bash
# SSH на DB сервер
ssh ubuntu@<DB_IP>

# Пересоздать пользователя
sudo -u postgres psql

DROP USER IF EXISTS webapp_user;
CREATE USER webapp_user WITH PASSWORD 'changeme_secure_password';
GRANT ALL PRIVILEGES ON DATABASE webapp_db TO webapp_user;
\q

# Обновить .env на Backend серверах с правильным паролем
```

#### Проблема: Database does not exist

**Симптомы:**
```
psql: FATAL: database "webapp_db" does not exist
```

**Решение:**
```bash
# SSH на DB сервер
sudo -u postgres psql

CREATE DATABASE webapp_db;
GRANT ALL PRIVILEGES ON DATABASE webapp_db TO webapp_user;
\q
```

### NFS Storage

#### Проблема: NFS диск не монтируется

**Симптомы:**
```
mount: wrong fs type, bad option, bad superblock on /dev/vdb
```

**Диагностика:**
```bash
# Проверить, что диск существует
lsblk | grep vdb

# Проверить, что диск отформатирован
sudo blkid /dev/vdb

# Проверить статус NFS сервера
sudo systemctl status nfs-server
```

**Решение:**
```bash
# Если NFS сервер не запущен (на Backend-1)
sudo systemctl start nfs-server

# Если диск не отформатирован
sudo mkfs.xfs /dev/vdb

# Примонтировать на NFS сервере (Backend-1)
sudo mount /dev/vdb /var/www/static

# Примонтировать на NFS клиенте (Backend-2)
sudo mount -t nfs <BACKEND_1_IP>:/var/www/static /var/www/static
```

#### Проблема: NFS сервер не запускается

**Симптомы:**
```
sudo systemctl status nfs-server
Failed to start NFS server
```

**Диагностика:**
```bash
# Проверить статус NFS сервера (на Backend-1)
sudo systemctl status nfs-server

# Проверить exports
sudo exportfs -v

# Логи
sudo journalctl -u nfs-server -n 50
```

**Решение:**
```bash
# Перезапустить NFS сервер
sudo systemctl restart nfs-server

# Проверить и переэкспортировать
sudo exportfs -ra

# Проверить firewall
sudo firewall-cmd --list-services
```

#### Проблема: NFS клиент не может подключиться

**Симптомы:**
```
mount.nfs: Connection timed out
```

**Решение:**
```bash
# На Backend-1 (сервер) проверить:
sudo systemctl status nfs-server
sudo exportfs -v
sudo firewall-cmd --list-services | grep nfs

# На Backend-2 (клиент):
# Проверить доступность NFS сервера
showmount -e <BACKEND_1_IP>

# Перемонтировать
sudo umount /var/www/static
sudo mount -t nfs <BACKEND_1_IP>:/var/www/static /var/www/static
```

### Load Balancer

#### Проблема: Все target unhealthy

**Симптомы:**
В консоли Yandex Cloud все targets показаны как "Unhealthy"

**Диагностика:**
```bash
# На каждом Nginx сервере проверить health endpoint
curl http://localhost/health
# Должен вернуть "OK"
```

**Решение:**
```bash
# Создать health файл если его нет
echo "OK" | sudo tee /var/www/html/health

# Проверить конфигурацию Nginx
sudo cat /etc/nginx/sites-available/webapp.conf | grep -A 5 "/health"

# Перезапустить Nginx
sudo systemctl restart nginx
```

#### Проблема: Load Balancer не создаётся

**Симптомы:**
```
Error: Error while requesting API to create network load balancer
```

**Решение:**
1. Проверить квоты для Load Balancer
2. Убедиться что target group создана
3. Проверить, что VMs в статусе "RUNNING"

## Команды для диагностики

### Проверка статуса всех сервисов

```bash
# На Nginx
ssh ubuntu@<NGINX_IP> '
  echo "=== Nginx Status ==="
  sudo systemctl status nginx --no-pager
  echo ""
  echo "=== Nginx Config Test ==="
  sudo nginx -t
'

# На Backend
ssh ubuntu@<BACKEND_IP> '
  echo "=== uWSGI Status ==="
  sudo systemctl status uwsgi --no-pager
  echo ""
  echo "=== Django Check ==="
  cd /opt/webapp && source venv/bin/activate && python manage.py check
  echo ""
  echo "=== NFS Mount ==="
  mount | grep nfs
  echo ""
  echo "=== Cluster Status ==="
  sudo pcs status
'

# На Database
ssh ubuntu@<DB_IP> '
  echo "=== PostgreSQL Status ==="
  sudo systemctl status postgresql --no-pager
  echo ""
  echo "=== Database Connections ==="
  sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
'
```

### Полная диагностика

Создайте скрипт `diagnose.sh`:

```bash
#!/bin/bash

cd terraform

echo "=== Infrastructure Overview ==="
terraform show -json | jq -r '.values.root_module.resources[] |
  select(.type=="yandex_compute_instance") |
  "\(.values.name): \(.values.status) - \(.values.network_interface[0].nat_ip_address)"'
echo ""

echo "=== Load Balancer ==="
LB_IP=$(terraform output -raw load_balancer_ip | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
echo "IP: $LB_IP"
curl -s -o /dev/null -w "Health Check: HTTP %{http_code}\n" http://$LB_IP/health
echo ""

echo "=== Nginx Servers ==="
terraform output -json nginx_instances | jq -r '.[] | "\(.name): \(.external_ip)"' | \
while read name ip; do
  echo "$name ($ip):"
  ssh -o ConnectTimeout=5 ubuntu@$ip 'sudo systemctl is-active nginx' 2>/dev/null || echo "  ERROR: Cannot connect"
done
echo ""

echo "=== Backend Servers ==="
terraform output -json backend_instances | jq -r '.[] | "\(.name): \(.external_ip)"' | \
while read name ip; do
  echo "$name ($ip):"
  ssh -o ConnectTimeout=5 ubuntu@$ip 'sudo systemctl is-active uwsgi' 2>/dev/null || echo "  ERROR: Cannot connect"
done
echo ""

echo "=== Database ==="
DB_IP=$(terraform output -json database_instance | jq -r '.external_ip')
echo "Database ($DB_IP):"
ssh -o ConnectTimeout=5 ubuntu@$DB_IP 'sudo systemctl is-active postgresql' 2>/dev/null || echo "  ERROR: Cannot connect"
```

## Получение помощи

1. **Логи** - всегда начинайте с проверки логов
2. **Документация** - см. README.md и ARCHITECTURE.md
3. **Yandex Cloud Support** - для проблем с облачной инфраструктурой
4. **Community** - форумы Ansible, Django, PostgreSQL

## Полезные команды

```bash
# Пересоздать только Ansible конфигурацию (без пересоздания VM)
cd ansible
ansible-playbook -i inventory.ini site.yml --tags "nginx,backend,database"

# Проверить доступность всех хостов
ansible all -i inventory.ini -m ping

# Выполнить команду на всех хостах
ansible all -i inventory.ini -a "uptime"

# Собрать факты о системе
ansible all -i inventory.ini -m setup

# Проверить синтаксис playbook
ansible-playbook site.yml --syntax-check

# Dry-run (без изменений)
ansible-playbook -i inventory.ini site.yml --check

# Запустить только определенную роль
ansible-playbook -i inventory.ini site.yml --tags "nginx"
```
