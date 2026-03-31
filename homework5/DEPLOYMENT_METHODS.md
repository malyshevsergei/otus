# Методы развертывания MySQL InnoDB Cluster

Проект поддерживает 4 способа развертывания. Выберите подходящий для ваших нужд.

## Сравнение методов

| Метод | Сложность | Время | Гибкость | Автоматизация | Подходит для |
|-------|-----------|-------|----------|---------------|--------------|
| **Docker Compose** | ⭐ Простой | 5 мин | ⭐⭐ | ⭐⭐ | Локальная разработка, тестирование |
| **Makefile** | ⭐ Простой | 5 мин | ⭐⭐ | ⭐⭐⭐ | Быстрое локальное развертывание |
| **Terraform** | ⭐⭐ Средний | 10 мин | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Инфраструктура как код, CI/CD |
| **Ansible** | ⭐⭐⭐ Продвинутый | 10 мин | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Production, масштабирование, управление конфигурацией |

## 1. Docker Compose (Локальное тестирование)

### Когда использовать
- ✅ Быстрое тестирование локально
- ✅ Разработка и отладка
- ✅ Демонстрация возможностей
- ❌ Не для production
- ❌ Только один хост

### Установка

```bash
cd /Users/s.malyshev/otus/homework5

# Запустить
docker compose up -d

# Подождать 30 секунд
sleep 30

# Настроить кластер
docker exec -it mysql-shell bash /scripts/setup-cluster.sh

# Создать БД
docker exec -i mysql-shell mysql -h mysql-server-1 -uroot -prootpass < scripts/create-database.sql
```

### Плюсы
- ✅ Самый простой способ
- ✅ Не требует облачных ресурсов
- ✅ Быстрый старт
- ✅ Изоляция в контейнерах

### Минусы
- ❌ Только локально
- ❌ Ручная настройка
- ❌ Не масштабируется
- ❌ Нет управления инфраструктурой

---

## 2. Makefile (Автоматизация команд)

### Когда использовать
- ✅ Нужны готовые команды
- ✅ Частое использование одних и тех же операций
- ✅ Удобство для разработчиков
- ❌ Только локально или на одном хосте

### Установка

```bash
cd /Users/s.malyshev/otus/homework5

# Все в одной команде!
make all

# Или по шагам
make start
make setup-cluster
make create-db
make check
```

### Доступные команды

```bash
make start          # Запустить контейнеры
make stop           # Остановить
make restart        # Перезапустить
make status         # Статус
make setup-cluster  # Настроить кластер
make create-db      # Создать БД
make check          # Проверить статус
make logs           # Логи
make clean          # Удалить все
make test-failover  # Тест отказоустойчивости
make mysql-app      # Подключиться к БД
```

### Плюсы
- ✅ Простые команды
- ✅ Автоматизация рутины
- ✅ Документирует процессы
- ✅ Не требует изучения новых инструментов

### Минусы
- ❌ Только локально или SSH на сервер
- ❌ Нет управления инфраструктурой
- ❌ Сложно масштабировать

---

## 3. Terraform (Infrastructure as Code)

### Когда использовать
- ✅ Нужно создать VM в Yandex Cloud
- ✅ Инфраструктура как код
- ✅ Версионирование инфраструктуры
- ✅ CI/CD пайплайны
- ✅ Несколько окружений (dev, staging, prod)

### Установка

```bash
cd terraform

# Инициализация
terraform init

# Проверка плана
terraform plan

# Применение
terraform apply

# Получить IP
EXTERNAL_IP=$(terraform output -raw external_ip)

# Загрузить проект на VM
cd ..
scp -r docker-compose.yml config scripts Makefile ubuntu@$EXTERNAL_IP:/opt/mysql-cluster/

# SSH на VM и запустить
ssh ubuntu@$EXTERNAL_IP
cd /opt/mysql-cluster
make all
```

### Что делает Terraform
1. ✅ Создает VPC сеть
2. ✅ Создает подсеть
3. ✅ Настраивает Security Group (firewall)
4. ✅ Создает VM с Ubuntu
5. ✅ Устанавливает Docker через cloud-init
6. ✅ Настраивает SSH доступ

### Плюсы
- ✅ Полное управление инфраструктурой
- ✅ Версионирование в Git
- ✅ Легко создать/удалить окружение
- ✅ Поддержка множества провайдеров
- ✅ State management

### Минусы
- ❌ Требует изучения HCL
- ❌ Не управляет приложениями
- ❌ Нужен доступ к Yandex Cloud
- ❌ Дополнительная сложность для простых задач

---

## 4. Ansible (Configuration Management) ⭐ РЕКОМЕНДУЕТСЯ

### Когда использовать
- ✅ Production развертывание
- ✅ Множество серверов
- ✅ Управление конфигурацией
- ✅ Идемпотентные операции
- ✅ Сложная автоматизация
- ✅ Обновления и патчи

### Установка

```bash
cd ansible

# Установить зависимости
ansible-galaxy collection install -r requirements.yml
pip3 install docker docker-compose

# Обновить inventory с IP вашей VM
vim inventory/hosts.yml

# Проверить подключение
ansible all -m ping

# Развернуть все одной командой!
ansible-playbook playbooks/deploy-all.yml
```

### Что делает Ansible
1. ✅ Настраивает систему (пакеты, firewall, sysctl)
2. ✅ Устанавливает и настраивает Docker
3. ✅ Копирует конфигурации из templates
4. ✅ Запускает контейнеры
5. ✅ Настраивает InnoDB Cluster
6. ✅ Создает базу данных
7. ✅ Проверяет статус

### Управление

```bash
# Интерактивное управление
ansible-playbook playbooks/manage-cluster.yml

# Ad-hoc команды
ansible mysql_cluster -m shell -a "docker ps"
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && make check"

# Только определенные задачи
ansible-playbook playbooks/deploy-all.yml --tags docker
ansible-playbook playbooks/deploy-all.yml --tags mysql

# Dry-run
ansible-playbook playbooks/deploy-all.yml --check
```

### Плюсы
- ✅ **Идемпотентность** - можно запускать многократно безопасно
- ✅ **Декларативный** - описываете желаемое состояние
- ✅ **Agentless** - работает через SSH, не требует агентов
- ✅ **Масштабируемость** - легко на 10+ серверов
- ✅ **Переиспользование** - роли можно использовать в других проектах
- ✅ **Версионирование** - вся конфигурация в Git
- ✅ **Безопасность** - Ansible Vault для паролей
- ✅ **Теги** - выборочное выполнение задач
- ✅ **Мощный** - может все: от настройки ОС до деплоя приложений

### Минусы
- ❌ Требует изучения YAML и Ansible концепций
- ❌ Более сложная структура проекта
- ❌ Дольше настройка первый раз

---

## Комбинированные подходы

### Terraform + Ansible (BEST PRACTICE для Production)

```bash
# 1. Создать инфраструктуру с Terraform
cd terraform
terraform apply
EXTERNAL_IP=$(terraform output -raw external_ip)

# 2. Развернуть приложения с Ansible
cd ../ansible
# Обновить inventory с IP из Terraform
echo "mysql-node-1 ansible_host=$EXTERNAL_IP" > inventory/hosts.yml
ansible-playbook playbooks/deploy-all.yml
```

**Преимущества:**
- Terraform управляет инфраструктурой (VM, сети, диски)
- Ansible управляет конфигурацией и приложениями
- Четкое разделение ответственности
- Полная автоматизация от железа до приложения

### Docker Compose + Makefile (для разработки)

```bash
make all
```

**Преимущества:**
- Максимально простой способ для локальной разработки
- Быстрое тестирование изменений
- Минимум зависимостей

---

## Рекомендации по выбору

### Для локальной разработки
```
Docker Compose + Makefile
```

### Для тестового окружения
```
Terraform (инфраструктура) + Docker Compose (вручную на VM)
```

### Для production
```
Terraform (инфраструктура) + Ansible (конфигурация и деплой)
```

### Для CI/CD
```
Ansible playbooks в GitLab CI / GitHub Actions
```

---

## Быстрый старт по методам

| Метод | Документация | Quick Start |
|-------|--------------|-------------|
| Docker Compose | `README.md` | `make all` |
| Makefile | `README.md` | `make all` |
| Terraform | `terraform/README.md` | `cd terraform && terraform apply` |
| Ansible | `ansible/README.md` | `cd ansible && ansible-playbook playbooks/deploy-all.yml` |
| Ansible Quick | `ansible/QUICKSTART_ANSIBLE.md` | Пошаговая инструкция для начинающих |

---

## Примеры использования

### Сценарий 1: Быстрое локальное тестирование

```bash
# Самый быстрый способ
make all

# Или
docker compose up -d && sleep 30
docker exec -it mysql-shell bash /scripts/setup-cluster.sh
docker exec -i mysql-shell mysql -h mysql-server-1 -uroot -prootpass < scripts/create-database.sql
```

**Время: 5 минут**

### Сценарий 2: Развертывание в Yandex Cloud (простой способ)

```bash
# 1. Создать VM через Yandex Cloud Console или CLI
# 2. SSH на VM
ssh ubuntu@<IP>

# 3. Установить Docker
curl -fsSL https://get.docker.com | sh

# 4. Загрузить проект
git clone <repo> && cd homework5

# 5. Запустить
make all
```

**Время: 15 минут**

### Сценарий 3: Production deployment (recommended)

```bash
# 1. Создать инфраструктуру
cd terraform
terraform init && terraform apply

# 2. Развернуть приложение
cd ../ansible
vim inventory/hosts.yml  # Добавить IP из Terraform
ansible-playbook playbooks/deploy-all.yml

# 3. Проверить
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && make check"
```

**Время: 20 минут**

---

## Матрица возможностей

| Возможность | Docker Compose | Makefile | Terraform | Ansible |
|-------------|----------------|----------|-----------|---------|
| Создание VM | ❌ | ❌ | ✅ | ❌ |
| Настройка ОС | ❌ | ❌ | Частично | ✅ |
| Установка Docker | Вручную | Вручную | ✅ (cloud-init) | ✅ |
| Деплой приложения | ✅ | ✅ | ❌ | ✅ |
| Управление конфигурацией | ❌ | ❌ | ❌ | ✅ |
| Обновления | Вручную | Вручную | ❌ | ✅ |
| Масштабирование | ❌ | ❌ | ✅ | ✅ |
| Идемпотентность | Нет | Нет | ✅ | ✅ |
| Rollback | ❌ | ❌ | ✅ | Частично |
| Секреты | Plain text | Plain text | Variables | Vault |
| CI/CD интеграция | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## Заключение

Все 4 метода имеют свое место:

- **Docker Compose**: Идеален для начала и локальной разработки
- **Makefile**: Добавляет удобство к Docker Compose
- **Terraform**: Лучший выбор для управления облачной инфраструктурой
- **Ansible**: Самый мощный и гибкий для production и автоматизации

Для OTUS homework любой из методов подойдет, но **Ansible** демонстрирует наиболее продвинутый подход и лучшие практики DevOps.

---

**Рекомендация для homework**: Используйте **Ansible**, чтобы показать навыки автоматизации и best practices! 🚀
