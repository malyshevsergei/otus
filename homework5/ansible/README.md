# Ansible Automation для MySQL InnoDB Cluster

Автоматизация развертывания и управления MySQL InnoDB Cluster на Yandex Cloud с помощью Ansible.

## Структура

```
ansible/
├── ansible.cfg                          # Конфигурация Ansible
├── inventory/
│   ├── hosts.yml                        # Инвентарь хостов
│   └── group_vars/
│       └── all.yml                      # Глобальные переменные
├── playbooks/
│   ├── deploy-all.yml                   # Полное развертывание
│   ├── setup-vm.yml                     # Настройка VM
│   └── manage-cluster.yml               # Управление кластером
├── roles/
│   ├── common/                          # Общие задачи
│   │   └── tasks/main.yml
│   ├── docker/                          # Установка Docker
│   │   └── tasks/main.yml
│   └── mysql-cluster/                   # MySQL Cluster
│       ├── tasks/main.yml
│       └── templates/
│           ├── docker-compose.yml.j2
│           ├── my.cnf.j2
│           ├── setup-cluster.sh.j2
│           ├── check-cluster-status.sh.j2
│           ├── create-database.sql.j2
│           └── Makefile.j2
└── README.md                            # Эта документация
```

## Предварительные требования

### 1. Установка Ansible

```bash
# MacOS
brew install ansible

# Ubuntu/Debian
sudo apt update
sudo apt install ansible python3-pip

# Проверка
ansible --version
```

### 2. Установка необходимых коллекций

```bash
ansible-galaxy collection install community.docker
ansible-galaxy collection install community.general
```

### 3. Установка Python зависимостей

```bash
pip3 install docker docker-compose
```

### 4. Создание VM в Yandex Cloud

```bash
# С помощью yc CLI
yc compute instance create \
  --name mysql-cluster-node-1 \
  --zone ru-central1-a \
  --cores 4 \
  --memory 8 \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2204-lts,size=50 \
  --network-interface subnet-name=default-ru-central1-a,nat-ip-version=ipv4 \
  --ssh-key ~/.ssh/id_rsa.pub

# Получить IP адрес
yc compute instance get mysql-cluster-node-1 --format json | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address'
```

## Настройка инвентаря

### Шаг 1: Обновить inventory/hosts.yml

```yaml
all:
  children:
    mysql_cluster:
      hosts:
        mysql-node-1:
          ansible_host: <EXTERNAL_IP>  # Замените на реальный IP
```

### Шаг 2: Проверить подключение

```bash
cd ansible
ansible all -m ping
```

Ожидаемый результат:
```
mysql-node-1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

## Развертывание

### Вариант 1: Полное автоматическое развертывание (рекомендуется)

```bash
cd ansible

# Развернуть все: подготовить VM, установить Docker, развернуть кластер
ansible-playbook playbooks/deploy-all.yml
```

Этот playbook выполнит:
1. ✅ Установку базовых пакетов
2. ✅ Установку и настройку Docker
3. ✅ Копирование конфигураций
4. ✅ Запуск контейнеров MySQL
5. ✅ Настройку InnoDB Cluster
6. ✅ Создание БД проекта

### Вариант 2: Пошаговое развертывание

```bash
# Шаг 1: Подготовить VM
ansible-playbook playbooks/setup-vm.yml

# Шаг 2: Развернуть кластер
ansible-playbook playbooks/deploy-all.yml --tags mysql,cluster
```

### Вариант 3: Выборочное развертывание с тегами

```bash
# Только установка Docker
ansible-playbook playbooks/deploy-all.yml --tags docker

# Только настройка MySQL кластера
ansible-playbook playbooks/deploy-all.yml --tags mysql

# Установить базовые пакеты и Docker
ansible-playbook playbooks/deploy-all.yml --tags common,docker
```

## Управление кластером

### Проверка статуса кластера

```bash
ansible-playbook playbooks/manage-cluster.yml
# Выберите опцию 1 для проверки статуса
```

Или напрямую:

```bash
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && make check"
```

### Перезапуск кластера

```bash
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && make restart"
```

### Просмотр логов

```bash
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker compose logs --tail=50"
```

### Создание резервной копии

```bash
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker exec mysql-server-1 mysqldump -uroot -prootpass --all-databases > /tmp/backup.sql"
```

## Переменные и настройки

### Основные переменные (inventory/group_vars/all.yml)

```yaml
# Проект
project_name: "mysql-innodb-cluster"
project_dir: "/opt/mysql-cluster"

# MySQL
mysql_root_password: "rootpass"
mysql_cluster_admin: "clusteradmin"
mysql_cluster_password: "clusterpass"
mysql_app_user: "appuser"
mysql_app_password: "apppass"

# База данных
project_db_name: "project_db"
project_db_charset: "utf8mb4"
```

### Использование Ansible Vault для паролей

```bash
# Создать vault файл
ansible-vault create inventory/group_vars/vault.yml

# Добавить в vault.yml:
---
vault_mysql_root_password: "your_secure_password"
vault_mysql_cluster_password: "your_cluster_password"
vault_mysql_app_password: "your_app_password"

# Использовать с playbook
ansible-playbook playbooks/deploy-all.yml --ask-vault-pass
```

## Полезные команды

### Ad-hoc команды

```bash
# Проверить версию Docker на всех хостах
ansible mysql_cluster -m shell -a "docker --version"

# Проверить статус контейнеров
ansible mysql_cluster -m shell -a "docker compose ps" -a "chdir=/opt/mysql-cluster"

# Проверить использование ресурсов
ansible mysql_cluster -m shell -a "docker stats --no-stream"

# Перезагрузить VM
ansible mysql_cluster -m reboot --become

# Обновить пакеты
ansible mysql_cluster -m apt -a "update_cache=yes upgrade=dist" --become
```

### Проверка конфигурации

```bash
# Проверить синтаксис playbook
ansible-playbook playbooks/deploy-all.yml --syntax-check

# Dry-run (проверка без применения изменений)
ansible-playbook playbooks/deploy-all.yml --check

# Показать, что будет изменено
ansible-playbook playbooks/deploy-all.yml --check --diff

# Список всех задач
ansible-playbook playbooks/deploy-all.yml --list-tasks

# Список всех тегов
ansible-playbook playbooks/deploy-all.yml --list-tags
```

## Масштабирование

### Добавление новых узлов

1. Обновить `inventory/hosts.yml`:

```yaml
mysql_cluster:
  hosts:
    mysql-node-1:
      ansible_host: 192.168.1.10
    mysql-node-2:
      ansible_host: 192.168.1.11
    mysql-node-3:
      ansible_host: 192.168.1.12
```

2. Развернуть на новых узлах:

```bash
ansible-playbook playbooks/deploy-all.yml --limit mysql-node-2,mysql-node-3
```

## Тестирование

### Тест подключения к кластеру

```bash
ansible mysql_cluster -m shell -a "docker exec -it mysql-shell mysql -h mysql-router -P 6446 -uappuser -papppass project_db -e 'SELECT COUNT(*) FROM users;'"
```

### Тест failover

```bash
# Остановить PRIMARY узел
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker compose stop mysql-server-1"

# Проверить статус (должен быть новый PRIMARY)
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && make check"

# Вернуть узел
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker compose start mysql-server-1"
```

### Тест репликации

```bash
# Вставить данные
ansible mysql_cluster -m shell -a "docker exec mysql-shell mysql -h mysql-router -P 6446 -uappuser -papppass project_db -e \"INSERT INTO users (username, email, password_hash) VALUES ('test', 'test@test.com', 'hash');\""

# Проверить репликацию
ansible mysql_cluster -m shell -a "docker exec mysql-shell mysql -h mysql-router -P 6447 -uappuser -papppass project_db -e \"SELECT * FROM users WHERE username='test';\""
```

## Мониторинг

### Создание playbook для мониторинга

```bash
ansible mysql_cluster -m shell -a "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'"
```

### Проверка здоровья контейнеров

```bash
ansible mysql_cluster -m shell -a "docker inspect --format='{{.Name}}: {{.State.Health.Status}}' \$(docker ps -q)"
```

## Troubleshooting

### Проблема: Ansible не может подключиться к хосту

```bash
# Проверить SSH соединение
ssh ubuntu@<EXTERNAL_IP>

# Проверить SSH ключ
ansible mysql_cluster -m ping -vvv

# Использовать явный SSH ключ
ansible mysql_cluster -m ping --private-key ~/.ssh/id_rsa
```

### Проблема: Docker контейнеры не запускаются

```bash
# Проверить логи
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker compose logs"

# Пересоздать контейнеры
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker compose down -v && docker compose up -d"
```

### Проблема: Кластер не инициализируется

```bash
# Проверить healthcheck контейнеров
ansible mysql_cluster -m shell -a "docker ps -a"

# Запустить setup вручную
ansible mysql_cluster -m shell -a "docker exec mysql-shell bash /scripts/setup-cluster.sh"
```

## Лучшие практики

1. **Используйте Ansible Vault для паролей**
2. **Тегируйте playbook задачи для гибкости**
3. **Используйте `--check` перед применением изменений**
4. **Делайте резервные копии перед обновлениями**
5. **Документируйте изменения в переменных**
6. **Используйте роли для переиспользования кода**

## Интеграция с CI/CD

### GitHub Actions пример

```yaml
name: Deploy MySQL Cluster

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Ansible
        run: |
          pip install ansible
          ansible-galaxy collection install community.docker

      - name: Deploy cluster
        run: |
          cd ansible
          ansible-playbook playbooks/deploy-all.yml
        env:
          ANSIBLE_HOST_KEY_CHECKING: False
```

## Дополнительные ресурсы

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [MySQL InnoDB Cluster](https://dev.mysql.com/doc/refman/8.0/en/mysql-innodb-cluster-introduction.html)
- [Docker Ansible Module](https://docs.ansible.com/ansible/latest/collections/community/docker/)

## Поддержка

При возникновении проблем:
1. Проверьте логи: `ansible-playbook playbooks/deploy-all.yml -vvv`
2. Проверьте документацию в корневом README.md
3. Создайте issue в репозитории проекта
