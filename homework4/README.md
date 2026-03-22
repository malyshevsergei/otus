# Высоконагруженное отказоустойчивое веб-приложение

Проект демонстрирует развертывание высоконагруженной и отказоустойчивой инфраструктуры веб-приложения в Yandex Cloud с использованием Terraform и Ansible.

## Архитектура

```
                                Internet
                                   |
                        [Network Load Balancer]
                          /              \
                    [Nginx-1]        [Nginx-2]
                          \              /
                           \            /
                        [Backend-1]  [Backend-2]
                             \          /
                              \        /
                           [GFS2 Cluster]
                                  |
                            [PostgreSQL DB]
```

### Компоненты инфраструктуры:

1. **Network Load Balancer** (Yandex Cloud)
   - Распределение нагрузки между Nginx серверами
   - Health checks для автоматического исключения неработающих серверов

2. **Nginx серверы (2 инстанса)**
   - Reverse proxy для backend приложения
   - Балансировка нагрузки между backend серверами (least_conn)
   - Кэширование статических файлов
   - Rate limiting

3. **Backend серверы (2 инстанса)**
   - Django веб-приложение
   - uWSGI application server
   - GFS2 кластерная файловая система для общей статики

4. **Database сервер (1 инстанс)**
   - PostgreSQL некластеризованная СУБД
   - Доступ только с backend серверов

## Используемые технологии

- **IaC**: Terraform 1.0+
- **Провайдер**: Yandex Cloud
- **Configuration Management**: Ansible
- **Балансировщик**: Yandex Network Load Balancer
- **Web Server**: Nginx
- **Application Server**: uWSGI
- **Framework**: Django 4.2
- **Database**: PostgreSQL 14
- **Shared Storage**: GFS2 (Global File System 2) с Pacemaker/Corosync
- **OS**: Ubuntu 22.04 LTS

## Предварительные требования

### 1. Установленное ПО

```bash
# Terraform
brew install terraform  # macOS
# или скачать с https://www.terraform.io/downloads

# Ansible
pip3 install ansible

# Yandex Cloud CLI (опционально, для управления)
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
```

### 2. Yandex Cloud

Создайте аккаунт в Yandex Cloud и получите:
- Cloud ID
- Folder ID
- OAuth токен или Service Account ключ

```bash
# Аутентификация в Yandex Cloud
yc init

# Получить Cloud ID
yc config list

# Создать service account (рекомендуется)
yc iam service-account create --name terraform-sa

# Назначить роли
yc resource-manager folder add-access-binding <FOLDER_ID> \
  --role admin \
  --subject serviceAccount:<SA_ID>

# Создать ключ для service account
yc iam key create --service-account-name terraform-sa --output key.json

# Экспортировать переменные
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)
```

### 3. SSH ключи

```bash
# Создать SSH ключ, если его нет
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

## Развертывание инфраструктуры

### Быстрый старт (автоматический)

```bash
# 1. Клонировать репозиторий
git clone <repository-url>
cd homework4

# 2. Настроить переменные Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Отредактировать terraform.tfvars, указать ваши Cloud ID и Folder ID

# 3. Запустить автоматическое развертывание
cd ..
./deploy.sh
```

### Ручное развертывание (пошагово)

#### Шаг 1: Подготовка Terraform

```bash
cd terraform

# Скопировать и настроить переменные
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars

# Указать:
# - yc_cloud_id
# - yc_folder_id
# - yc_zone (опционально)
# - ssh_public_key_path (путь к публичному SSH ключу)
```

#### Шаг 2: Создание инфраструктуры

```bash
# Инициализация Terraform
terraform init

# Проверка плана
terraform plan

# Применение конфигурации
terraform apply

# Дождаться завершения (обычно 5-10 минут)
```

#### Шаг 3: Подготовка Ansible

```bash
# Сгенерировать inventory из Terraform output
terraform output -raw ansible_inventory > ../ansible/inventory.ini

# Проверить доступность хостов
cd ../ansible
ansible all -i inventory.ini -m ping
```

#### Шаг 4: Настройка серверов с Ansible

```bash
# Запустить playbook
ansible-playbook -i inventory.ini site.yml

# Процесс занимает 10-15 минут
```

#### Шаг 5: Проверка развертывания

```bash
# Получить IP адрес Load Balancer
cd ../terraform
terraform output load_balancer_ip

# Проверить доступность
LB_IP=$(terraform output -raw load_balancer_ip | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
curl http://$LB_IP/health

# Должен вернуть: OK
```

## Проверка отказоустойчивости

### Автоматический тест

```bash
./test-failover.sh
```

### Ручное тестирование

#### 1. Тест отказа Backend сервера

```bash
# Получить информацию о backend серверах
cd terraform
terraform output backend_instances

# SSH на первый backend сервер
ssh ubuntu@<BACKEND_1_IP>

# Остановить uWSGI
sudo systemctl stop uwsgi

# В другом терминале - проверить доступность
curl http://$LB_IP/

# Приложение должно продолжать работать через второй backend
# Восстановить сервис
sudo systemctl start uwsgi
```

#### 2. Тест отказа Nginx сервера

```bash
# Получить информацию о nginx серверах
terraform output nginx_instances

# SSH на первый nginx сервер
ssh ubuntu@<NGINX_1_IP>

# Остановить Nginx
sudo systemctl stop nginx

# Проверить health check Load Balancer
# Через 30-60 секунд LB должен исключить неработающий сервер
curl http://$LB_IP/health

# Приложение доступно через второй Nginx
# Восстановить
sudo systemctl start nginx
```

#### 3. Тест GFS2 (общая файловая система)

```bash
# SSH на первый backend
ssh ubuntu@<BACKEND_1_IP>

# Создать тестовый файл в статике
echo "Test from backend-1" | sudo tee /var/www/static/test.txt

# SSH на второй backend
ssh ubuntu@<BACKEND_2_IP>

# Проверить наличие файла (GFS2 синхронизация)
cat /var/www/static/test.txt
# Должен вывести: Test from backend-1
```

#### 4. Нагрузочное тестирование

```bash
# Установить Apache Bench
sudo apt-get install apache2-utils

# Запустить нагрузочный тест
ab -n 1000 -c 10 http://$LB_IP/

# Параметры:
# -n 1000: всего 1000 запросов
# -c 10: 10 одновременных соединений

# Во время теста можно останавливать/запускать серверы
# и наблюдать за распределением нагрузки
```

## Мониторинг

### Логи Nginx

```bash
ssh ubuntu@<NGINX_IP>
sudo tail -f /var/log/nginx/webapp_access.log
sudo tail -f /var/log/nginx/webapp_error.log
```

### Логи uWSGI

```bash
ssh ubuntu@<BACKEND_IP>
sudo tail -f /var/log/uwsgi/webapp.log
```

### Статус кластера GFS2

```bash
ssh ubuntu@<BACKEND_IP>
sudo pcs status
sudo pcs cluster status
```

### Статус PostgreSQL

```bash
ssh ubuntu@<DATABASE_IP>
sudo systemctl status postgresql
sudo -u postgres psql -c "\l"  # список баз
sudo -u postgres psql -c "\du"  # список пользователей
```

## Структура проекта

```
homework4/
├── README.md                      # Этот файл
├── deploy.sh                      # Скрипт автоматического развертывания
├── destroy.sh                     # Скрипт удаления инфраструктуры
├── test-failover.sh              # Скрипт тестирования отказоустойчивости
│
├── terraform/                     # Terraform конфигурация
│   ├── versions.tf               # Версии провайдеров
│   ├── variables.tf              # Переменные
│   ├── network.tf                # VPC, подсети, security groups
│   ├── compute.tf                # Виртуальные машины
│   ├── load_balancer.tf          # Network Load Balancer
│   ├── outputs.tf                # Выходные значения
│   ├── terraform.tfvars.example  # Пример переменных
│   └── templates/
│       └── inventory.tpl         # Шаблон Ansible inventory
│
└── ansible/                       # Ansible конфигурация
    ├── ansible.cfg               # Конфигурация Ansible
    ├── site.yml                  # Главный playbook
    │
    └── roles/                    # Ansible роли
        ├── database/             # PostgreSQL
        │   ├── defaults/
        │   ├── tasks/
        │   ├── templates/
        │   └── handlers/
        │
        ├── gfs2/                 # GFS2 кластер
        │   ├── defaults/
        │   └── tasks/
        │
        ├── backend/              # Django + uWSGI
        │   ├── defaults/
        │   ├── tasks/
        │   ├── templates/
        │   └── handlers/
        │
        └── nginx/                # Nginx
            ├── defaults/
            ├── tasks/
            ├── templates/
            └── handlers/
```

## Безопасность

1. **Security Groups**: Настроены правила файрвола для ограничения доступа между компонентами
2. **Private Network**: Все внутренние коммуникации через приватную сеть
3. **Database**: Доступна только с backend серверов
4. **SSH**: Доступ по ключам, без паролей
5. **Secrets**: Используйте `ansible-vault` для хранения паролей в продакшене

```bash
# Зашифровать чувствительные данные
ansible-vault encrypt ansible/roles/database/defaults/main.yml

# Запустить с vault
ansible-playbook -i inventory.ini site.yml --ask-vault-pass
```

## Масштабирование

### Горизонтальное масштабирование

Увеличить количество серверов можно через переменные Terraform:

```hcl
# terraform.tfvars
nginx_count   = 3  # Увеличить до 3 nginx серверов
backend_count = 4  # Увеличить до 4 backend серверов
```

Затем:
```bash
cd terraform
terraform apply
cd ../ansible
terraform output -raw ansible_inventory > inventory.ini
ansible-playbook -i inventory.ini site.yml
```

### Вертикальное масштабирование

Изменить ресурсы VM в `terraform/compute.tf`:

```hcl
resources {
  cores  = 4  # Увеличить CPU
  memory = 8  # Увеличить RAM
}
```

## Удаление инфраструктуры

```bash
# Автоматически
./destroy.sh

# Или вручную
cd terraform
terraform destroy
```

## Возможные проблемы и решения

### 1. Ошибка "quota exceeded"

Проверьте квоты в Yandex Cloud:
```bash
yc compute quota list
```

### 2. Ansible не может подключиться к хостам

Проверьте:
- SSH ключи добавлены корректно
- Security groups разрешают SSH (порт 22)
- Хосты получили внешние IP адреса

```bash
ansible all -i inventory.ini -m ping -vvv
```

### 3. GFS2 кластер не запускается

```bash
# Проверить статус кластера
sudo pcs status

# Перезапустить кластер
sudo pcs cluster stop --all
sudo pcs cluster start --all
```

### 4. Load Balancer показывает unhealthy targets

Проверьте:
```bash
# На Nginx сервере
curl localhost/health

# Должен вернуть "OK"
```

## Дополнительная информация

- [Terraform Yandex Provider](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs)
- [Yandex Cloud Network Load Balancer](https://cloud.yandex.ru/docs/network-load-balancer/)
- [Ansible Documentation](https://docs.ansible.com/)
- [GFS2 Documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/global_file_system_2/)
- [Django Documentation](https://docs.djangoproject.com/)
- [uWSGI Documentation](https://uwsgi-docs.readthedocs.io/)

## Авторы

OTUS Homework Project

## Лицензия

MIT
