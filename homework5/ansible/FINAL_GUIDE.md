# MySQL InnoDB Cluster - Финальная инструкция

## ✅ Кластер развернут и работает!

### Информация о кластере

**IP адреса:**
- VM: `89.169.134.127` (или ваш актуальный IP)

**Порты:**
- `6446` - Read-Write (подключение к PRIMARY)
- `6447` - Read-Only (подключение к SECONDARY с балансировкой)
- `3311, 3312, 3313` - Прямые подключения к узлам MySQL

**Учетные данные:**
- Root: `root` / `rootpass`
- Cluster Admin: `clusteradmin` / `clusterpass`
- Application: `appuser` / `apppass`
- Database: `project_db`

---

## 🚀 Использование

### Подключение к кластеру

```bash
# Read-Write (PRIMARY)
mysql -h 89.169.134.127 -P 6446 -uappuser -papppass project_db

# Read-Only (SECONDARY)
mysql -h 89.169.134.127 -P 6447 -uappuser -papppass project_db

# Простой тест
mysql -h 89.169.134.127 -P 6446 -uappuser -papppass project_db -e "SELECT * FROM users;"
```

### Проверка статуса через Ansible

```bash
cd /Users/s.malyshev/otus/homework5/ansible

# Статус контейнеров
ansible mysql_cluster -m shell -a "docker ps"

# Статус кластера
ansible mysql_cluster -m shell -a "docker exec mysql-shell mysql -h mysql-server-1 -uroot -prootpass -e 'SELECT * FROM performance_schema.replication_group_members;'"

# Логи Router
ansible mysql_cluster -m shell -a "docker logs mysql-router --tail 20"
```

### SSH на VM

```bash
ssh ubuntu@89.169.134.127

# На VM:
cd /opt/mysql-cluster
docker ps
docker logs mysql-router
```

---

## 🔧 Управление кластером через Ansible

### Полное развертывание

```bash
cd /Users/s.malyshev/otus/homework5/ansible
ansible-playbook playbooks/deploy-all.yml
```

### Выборочное развертывание

```bash
# Только установка Docker
ansible-playbook playbooks/deploy-all.yml --tags docker

# Только настройка MySQL кластера
ansible-playbook playbooks/deploy-all.yml --tags mysql

# Настройка VM (пакеты, firewall, sysctl)
ansible-playbook playbooks/setup-vm.yml
```

### Управление кластером

```bash
# Интерактивное меню
ansible-playbook playbooks/manage-cluster.yml

# Перезапуск
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker compose restart"

# Остановка
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker compose stop"

# Запуск
ansible mysql_cluster -m shell -a "cd /opt/mysql-cluster && docker compose up -d"
```

---

## 🧪 Тестирование

### Тест failover

```bash
# 1. Остановить PRIMARY (mysql-server-1)
ansible mysql_cluster -m shell -a "docker compose stop mysql-server-1" -a "chdir=/opt/mysql-cluster"

# 2. Подождать 10 секунд
sleep 10

# 3. Проверить статус - должен быть новый PRIMARY
ansible mysql_cluster -m shell -a "docker exec mysql-shell mysql -h mysql-server-1 -uroot -prootpass -e 'SELECT MEMBER_HOST, MEMBER_STATE, MEMBER_ROLE FROM performance_schema.replication_group_members;'"

# 4. Кластер продолжает работать!
mysql -h 89.169.134.127 -P 6446 -uappuser -papppass project_db -e "SELECT COUNT(*) FROM users;"

# 5. Вернуть узел
ansible mysql_cluster -m shell -a "docker compose start mysql-server-1" -a "chdir=/opt/mysql-cluster"
```

### Тест репликации

```bash
# Вставить данные на PRIMARY
mysql -h 89.169.134.127 -P 6446 -uappuser -papppass project_db -e "INSERT INTO users (username, email, password_hash) VALUES ('testuser', 'test@example.com', 'hash');"

# Прочитать с SECONDARY
mysql -h 89.169.134.127 -P 6447 -uappuser -papppass project_db -e "SELECT * FROM users WHERE username='testuser';"
```

### Тест производительности

```bash
# Запустить несколько параллельных вставок
for i in {1..100}; do
  mysql -h 89.169.134.127 -P 6446 -uappuser -papppass project_db -e "INSERT INTO products (name, description, price, stock_quantity, category) VALUES ('Product$i', 'Test product', 99.99, 10, 'Test');" &
done
wait

# Проверить
mysql -h 89.169.134.127 -P 6446 -uappuser -papppass project_db -e "SELECT COUNT(*) FROM products WHERE category='Test';"
```

---

## 📊 Структура проекта

```
ansible/
├── ansible.cfg              # Конфигурация Ansible
├── requirements.yml         # Необходимые коллекции
├── README.md               # Полная документация
├── QUICKSTART_ANSIBLE.md   # Quick Start guide
├── FINAL_GUIDE.md          # Эта инструкция
│
├── inventory/
│   ├── hosts.yml           # Инвентарь серверов
│   └── group_vars/
│       └── all.yml         # Глобальные переменные
│
├── playbooks/
│   ├── deploy-all.yml      # Полное развертывание
│   ├── setup-vm.yml        # Настройка VM
│   └── manage-cluster.yml  # Управление кластером
│
└── roles/
    ├── common/             # Общие задачи
    ├── docker/             # Установка Docker
    └── mysql-cluster/      # MySQL InnoDB Cluster
        ├── tasks/
        └── templates/
```

---

## 📝 Что было сделано

1. ✅ **Ansible роли:**
   - `common` - базовая настройка системы
   - `docker` - установка Docker
   - `mysql-cluster` - развертывание InnoDB Cluster

2. ✅ **InnoDB Cluster:**
   - 3 MySQL Server 8.0 узла
   - MySQL Router для автоматической маршрутизации
   - Group Replication настроена
   - Автоматический failover

3. ✅ **База данных:**
   - Database: `project_db`
   - Таблицы: users, products, orders, order_items
   - Тестовые данные

4. ✅ **Автоматизация:**
   - Идемпотентные playbook'и
   - Теги для выборочного запуска
   - Шаблоны конфигураций (Jinja2)

---

## 🎓 Для OTUS Homework

Проект демонстрирует:
- ✅ Отказоустойчивый MySQL InnoDB Cluster
- ✅ Автоматизация через Ansible
- ✅ Infrastructure as Code подход
- ✅ Идемпотентность и переиспользование
- ✅ Best practices DevOps
- ✅ Полная документация

---

## 🔗 Дополнительная документация

- `README.md` - Полная документация по Ansible
- `QUICKSTART_ANSIBLE.md` - Быстрый старт для начинающих
- `../README.md` - Общая документация проекта
- `../DEPLOYMENT_METHODS.md` - Сравнение методов развертывания
- `../HOMEWORK_SOLUTION.md` - Описание решения для OTUS

---

## ✨ Итоги

**MySQL InnoDB Cluster успешно развернут через Ansible!**

- 3 узла MySQL в кластере
- Автоматический failover работает
- Router маршрутизирует запросы
- База данных создана и заполнена
- Всё автоматизировано и идемпотентно

🎉 **Готово к сдаче OTUS Homework!**
