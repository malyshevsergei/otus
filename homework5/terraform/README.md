# Terraform конфигурация для Yandex Cloud

Автоматическое развертывание VM для MySQL InnoDB Cluster в Yandex Cloud.

## Предварительные требования

1. Установленный Terraform (>= 1.0)
2. Аккаунт в Yandex Cloud
3. Настроенный Yandex Cloud CLI (`yc`)

## Подготовка

### 1. Установка Terraform

```bash
# MacOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### 2. Установка и настройка Yandex Cloud CLI

```bash
# Установка
curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash

# Инициализация
yc init

# Получение OAuth токена
yc config list
```

### 3. Настройка переменных окружения

```bash
# Экспортировать переменные
export YC_TOKEN=$(yc iam create-token)
export YC_CLOUD_ID=$(yc config get cloud-id)
export YC_FOLDER_ID=$(yc config get folder-id)

# Или создать файл terraform.tfvars
cat > terraform.tfvars <<EOF
# yc_token  = "your-token"
# cloud_id  = "your-cloud-id"
# folder_id = "your-folder-id"
zone        = "ru-central1-a"
vm_name     = "mysql-cluster"
vm_cores    = 4
vm_memory   = 8
disk_size   = 50
EOF
```

## Развертывание

### Шаг 1: Инициализация Terraform

```bash
cd terraform
terraform init
```

### Шаг 2: Проверка плана

```bash
terraform plan
```

### Шаг 3: Применение конфигурации

```bash
terraform apply
```

Подтвердите создание ресурсов, введя `yes`.

### Шаг 4: Получение информации о созданной VM

```bash
terraform output
```

Вы получите:
- `external_ip`: Внешний IP адрес VM
- `ssh_connection`: Команда для SSH подключения
- `mysql_rw_connection`: Команда для подключения к MySQL (Read-Write)
- `mysql_ro_connection`: Команда для подключения к MySQL (Read-Only)

## Загрузка проекта на VM

```bash
# Получить IP адрес
EXTERNAL_IP=$(terraform output -raw external_ip)

# Загрузить файлы проекта
cd ..
scp -r docker-compose.yml config scripts Makefile README.md ubuntu@$EXTERNAL_IP:/home/ubuntu/mysql-cluster/

# Подключиться к VM
ssh ubuntu@$EXTERNAL_IP
```

## Запуск кластера на VM

```bash
# На VM
cd /home/ubuntu/mysql-cluster

# Запустить кластер
make all

# Или вручную:
docker compose up -d
sleep 30
docker exec -it mysql-shell bash /scripts/setup-cluster.sh
docker exec -i mysql-shell mysql -h mysql-server-1 -uroot -prootpass < scripts/create-database.sql
docker exec -it mysql-shell bash /scripts/check-cluster-status.sh
```

## Подключение к кластеру

### С локальной машины

```bash
# Получить команду подключения
terraform output mysql_rw_connection

# Или вручную
EXTERNAL_IP=$(terraform output -raw external_ip)
mysql -h $EXTERNAL_IP -P 6446 -uappuser -papppass project_db
```

### SSH туннель (рекомендуется для production)

```bash
EXTERNAL_IP=$(terraform output -raw external_ip)
ssh -L 6446:localhost:6446 -L 6447:localhost:6447 ubuntu@$EXTERNAL_IP

# В другом терминале
mysql -h 127.0.0.1 -P 6446 -uappuser -papppass project_db
```

## Управление инфраструктурой

### Просмотр текущего состояния

```bash
terraform show
```

### Обновление конфигурации

После изменения `main.tf`:

```bash
terraform plan
terraform apply
```

### Удаление инфраструктуры

```bash
terraform destroy
```

## Создание нескольких окружений

### Production конфигурация

Создайте `terraform/environments/production.tfvars`:

```hcl
zone      = "ru-central1-a"
vm_name   = "mysql-cluster-prod"
vm_cores  = 8
vm_memory = 16
disk_size = 100
```

Применить:

```bash
terraform apply -var-file=environments/production.tfvars
```

### Development конфигурация

Создайте `terraform/environments/development.tfvars`:

```hcl
zone      = "ru-central1-a"
vm_name   = "mysql-cluster-dev"
vm_cores  = 2
vm_memory = 4
disk_size = 30
```

## Параметры конфигурации

| Параметр       | Описание                    | По умолчанию      |
|----------------|-----------------------------|-------------------|
| zone           | Зона Yandex Cloud           | ru-central1-a     |
| vm_name        | Имя виртуальной машины      | mysql-cluster     |
| vm_cores       | Количество CPU              | 4                 |
| vm_memory      | Объем RAM (GB)              | 8                 |
| disk_size      | Размер диска (GB)           | 50                |
| ssh_key_path   | Путь к SSH ключу            | ~/.ssh/id_rsa.pub |

## Стоимость

Примерная стоимость при конфигурации по умолчанию (4 CPU, 8GB RAM, 50GB SSD):
- ~3500-4000 рублей/месяц при 24/7 работе
- Используйте preemptible VM для экономии (~1000 рублей/месяц)

Для preemptible VM добавьте в `main.tf`:

```hcl
scheduling_policy {
  preemptible = true
}
```

## Мониторинг ресурсов в Yandex Cloud

```bash
# Просмотр информации о VM
yc compute instance get mysql-cluster

# Мониторинг использования
yc compute instance list
```

## Резервное копирование

Настройте снимки дисков:

```hcl
resource "yandex_compute_snapshot_schedule" "mysql_snapshots" {
  name = "mysql-daily-snapshots"

  schedule_policy {
    expression = "0 3 * * *"  # Каждый день в 3:00
  }

  snapshot_count = 7  # Хранить 7 последних снимков

  snapshot_spec {
    description = "Daily MySQL cluster snapshot"
  }

  disk_ids = [yandex_compute_instance.mysql_cluster_vm.boot_disk[0].disk_id]
}
```

## Troubleshooting

### Ошибка аутентификации

```bash
# Обновить токен
export YC_TOKEN=$(yc iam create-token)
terraform plan
```

### Ошибка квот

Проверьте квоты в консоли Yandex Cloud или:

```bash
yc quota list
```

### SSH ключ не работает

```bash
# Проверьте путь к ключу
ls -la ~/.ssh/id_rsa.pub

# Или укажите другой ключ
terraform apply -var="ssh_key_path=/path/to/your/key.pub"
```

## Полезные команды

```bash
# Форматирование кода
terraform fmt

# Валидация конфигурации
terraform validate

# Просмотр состояния
terraform state list

# Импорт существующей VM
terraform import yandex_compute_instance.mysql_cluster_vm <instance-id>

# Обновление провайдеров
terraform init -upgrade
```

## Дополнительные материалы

- [Terraform Yandex Provider](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs)
- [Yandex Cloud Documentation](https://cloud.yandex.ru/docs)
- [Yandex Cloud Pricing](https://cloud.yandex.ru/prices)
