# Быстрый старт

Краткое руководство для быстрого развертывания инфраструктуры.

## За 5 минут

### 1. Подготовка (однократно)

```bash
# Установить Terraform
brew install terraform  # macOS
# или wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip

# Установить Ansible
pip3 install ansible

# Установить Yandex Cloud CLI
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
```

### 2. Настройка Yandex Cloud (однократно)

```bash
# Аутентификация
yc init

# Получить credentials
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)

# Сохранить в ~/.bashrc или ~/.zshrc для постоянного использования
echo "export YC_TOKEN=\$(yc iam create-token)" >> ~/.bashrc
echo "export YC_CLOUD_ID=$(yc config get cloud-id)" >> ~/.bashrc
echo "export YC_FOLDER_ID=$(yc config get folder-id)" >> ~/.bashrc
```

### 3. Клонирование и настройка

```bash
# Клонировать репозиторий
git clone <repository-url>
cd homework4

# Настроить Terraform переменные
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Указать ваши значения:
# yc_cloud_id  = "ваш-cloud-id"
# yc_folder_id = "ваш-folder-id"
```

### 4. Развертывание

```bash
# Вернуться в корень проекта
cd ..

# ВАРИАНТ A: Автоматическое развертывание (рекомендуется)
./deploy.sh

# ВАРИАНТ B: Ручное развертывание
cd terraform
terraform init
terraform apply
terraform output -raw ansible_inventory > ../ansible/inventory.ini

cd ../ansible
ansible-playbook -i inventory.ini site.yml
```

### 5. Проверка

```bash
# Получить IP Load Balancer
cd terraform
LB_IP=$(terraform output -raw load_balancer_ip | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

# Проверить доступность
curl http://$LB_IP/health
# Ожидается: OK

# Открыть в браузере
echo "http://$LB_IP"
```

### 6. Тестирование отказоустойчивости

```bash
# Вернуться в корень проекта
cd ..

# Запустить тесты
./test-failover.sh
```

### 7. Удаление инфраструктуры

```bash
# Когда закончите работу
./destroy.sh
```

## Типичные команды

```bash
# Показать outputs Terraform
cd terraform && terraform output

# Пересобрать inventory
cd terraform && terraform output -raw ansible_inventory > ../ansible/inventory.ini

# Переприменить Ansible (без пересоздания VM)
cd ansible && ansible-playbook -i inventory.ini site.yml

# SSH на серверы
make ssh-nginx    # Подключиться к Nginx
make ssh-backend  # Подключиться к Backend
make ssh-db       # Подключиться к Database

# Посмотреть статус
make status

# Посмотреть все команды
make help
```

## Структура для понимания

```
homework4/
├── deploy.sh              # Автоматическое развертывание
├── destroy.sh             # Удаление инфраструктуры
├── test-failover.sh       # Тесты отказоустойчивости
├── Makefile               # Удобные команды
│
├── terraform/             # Инфраструктура
│   ├── *.tf              # Terraform конфигурация
│   └── terraform.tfvars   # Ваши переменные (создать из .example)
│
└── ansible/               # Конфигурация серверов
    ├── site.yml          # Главный playbook
    └── roles/            # Роли для каждого компонента
```

## Что развертывается

```
Internet
   │
   └─> Load Balancer (Yandex Cloud)
          │
          ├─> Nginx-1 (reverse proxy)
          └─> Nginx-2 (reverse proxy)
                 │
                 ├─> Backend-1 (Django + uWSGI) [NFS Server]
                 └─> Backend-2 (Django + uWSGI) [NFS Client]
                        │
                        └─> Database (PostgreSQL)

+ NFS для общей статики между Backend серверами
```

## Компоненты

- **5 виртуальных машин** в Yandex Cloud (AlmaLinux 9)
- **Network Load Balancer** для распределения нагрузки
- **Nginx** (2 инстанса) - reverse proxy
- **Django + uWSGI** (2 инстанса) - приложение
- **PostgreSQL 14** (1 инстанс) - база данных
- **NFS** - общее хранилище статики (Backend-1 = сервер, Backend-2 = клиент)

## Проверка работоспособности

### Health Check

```bash
curl http://$LB_IP/health
# Ожидается: OK
```

### Django Admin

```bash
# Создать суперпользователя
ssh ubuntu@<BACKEND_IP>
cd /opt/webapp
source venv/bin/activate
python manage.py createsuperuser

# Открыть в браузере
echo "http://$LB_IP/admin/"
```

### Тест отказа сервера

```bash
# В одном терминале - мониторинг
while true; do curl -s http://$LB_IP/health; sleep 1; done

# В другом терминале - остановить Nginx
ssh ubuntu@<NGINX_1_IP>
sudo systemctl stop nginx

# В первом терминале запросы продолжают работать!
```

## Масштабирование

### Добавить больше серверов

```bash
# Отредактировать terraform/terraform.tfvars
nano terraform/terraform.tfvars

# Увеличить количество
nginx_count   = 3  # Было 2
backend_count = 3  # Было 2

# Применить изменения
cd terraform
terraform apply

# Обновить конфигурацию
terraform output -raw ansible_inventory > ../ansible/inventory.ini
cd ../ansible
ansible-playbook -i inventory.ini site.yml
```

## Мониторинг

### Логи в реальном времени

```bash
# Nginx
ssh ubuntu@<NGINX_IP>
sudo tail -f /var/log/nginx/webapp_access.log

# Backend
ssh ubuntu@<BACKEND_IP>
sudo tail -f /var/log/uwsgi/webapp.log

# Database
ssh ubuntu@<DB_IP>
sudo tail -f /var/log/postgresql/postgresql-14-main.log
```

### Статус сервисов

```bash
# Nginx
ssh ubuntu@<NGINX_IP>
sudo systemctl status nginx

# Backend
ssh ubuntu@<BACKEND_IP>
sudo systemctl status uwsgi

# Database
ssh ubuntu@<DB_IP>
sudo systemctl status postgresql

# NFS статус
ssh ubuntu@<BACKEND_1_IP>
sudo systemctl status nfs-server
sudo exportfs -v
```

Для экономии:
```bash
# Останавливать на ночь
cd terraform
terraform destroy  # Вечером
terraform apply    # Утром
```

## Частые проблемы

### Не могу подключиться по SSH

```bash
# Проверить SSH ключ
cat ~/.ssh/id_rsa.pub

# Должен совпадать с тем, что в terraform.tfvars
grep ssh_public_key_path terraform/terraform.tfvars
```

### Terraform apply падает с ошибкой quota

```bash
# Проверить квоты
yc compute quota list

# Удалить старые ресурсы или запросить увеличение квот
```

### Ansible не может подключиться

```bash
# Проверить inventory
cat ansible/inventory.ini

# Проверить доступность
ansible all -i ansible/inventory.ini -m ping

# Подождать 30 секунд после terraform apply
# VM нужно время для инициализации
```

### 502 Bad Gateway

```bash
# Проверить uWSGI на backend серверах
ssh ubuntu@<BACKEND_IP>
sudo systemctl status uwsgi
sudo systemctl restart uwsgi
```

## Полезные ссылки

- [Полная документация](README.md)
- [Архитектура системы](ARCHITECTURE.md)
- [Руководство по тестированию](TESTING.md)
- [Устранение неполадок](TROUBLESHOOTING.md)

## Следующие шаги

После успешного развертывания:

1. ✅ Проверить базовую доступность
2. ✅ Запустить тесты отказоустойчивости
3. ✅ Провести нагрузочное тестирование
4. ✅ Настроить мониторинг (опционально)
5. ✅ Настроить backup БД (опционально)
6. ✅ Добавить SSL сертификаты (опционально)

## Помощь

- **Документация**: См. README.md
- **Проблемы**: См. TROUBLESHOOTING.md
- **Issues**: GitHub issues
