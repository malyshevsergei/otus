# Руководство по тестированию

Этот документ содержит подробные инструкции по тестированию отказоустойчивости и производительности развёрнутой инфраструктуры.

## Предварительные требования

Убедитесь, что инфраструктура полностью развёрнута:

```bash
# Проверить статус
make status

# Получить IP Load Balancer
cd terraform
LB_IP=$(terraform output -raw load_balancer_ip | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
echo $LB_IP
```

## Тест 1: Базовая доступность

### Проверка health endpoint

```bash
curl http://$LB_IP/health
# Ожидается: OK
```

### Проверка главной страницы

```bash
curl -I http://$LB_IP/
# Ожидается: HTTP/1.1 200 OK или 301/302 (redirect)
```

### Проверка Django admin

```bash
curl -I http://$LB_IP/admin/
# Ожидается: HTTP/1.1 302 Found (redirect to login)
```

## Тест 2: Отказоустойчивость Nginx

### Подготовка

```bash
# Открыть 3 терминала:
# Terminal 1: Мониторинг запросов
# Terminal 2: Остановка Nginx
# Terminal 3: Логи Load Balancer (опционально)
```

### Terminal 1: Непрерывные запросы

```bash
# Бесконечный цикл запросов
while true; do
  response=$(curl -s -o /dev/null -w "%{http_code}" http://$LB_IP/health)
  echo "$(date '+%H:%M:%S') - HTTP $response"
  sleep 1
done
```

### Terminal 2: Остановка Nginx-1

```bash
# Получить IP первого nginx сервера
cd terraform
NGINX_1_IP=$(terraform output -json nginx_instances | jq -r '.[0].external_ip')

# SSH на сервер
ssh ubuntu@$NGINX_1_IP

# Остановить Nginx
sudo systemctl stop nginx

# Проверить статус
sudo systemctl status nginx
```

### Ожидаемый результат

1. В Terminal 1 продолжаются успешные ответы (200 OK)
2. Через 30-60 секунд Load Balancer исключает Nginx-1
3. Все запросы идут на Nginx-2
4. Нет потерянных запросов

### Восстановление

```bash
# На Nginx-1 сервере
sudo systemctl start nginx
sudo systemctl status nginx

# Проверить, что Load Balancer снова включил сервер в пул
# (через 30-60 секунд)
```

## Тест 3: Отказоустойчивость Backend

### Terminal 1: Непрерывные запросы

```bash
while true; do
  response=$(curl -s -o /dev/null -w "%{http_code}" http://$LB_IP/)
  echo "$(date '+%H:%M:%S') - HTTP $response"
  sleep 1
done
```

### Terminal 2: Остановка Backend-1

```bash
# Получить IP первого backend сервера
cd terraform
BACKEND_1_IP=$(terraform output -json backend_instances | jq -r '.[0].external_ip')

# SSH на сервер
ssh ubuntu@$BACKEND_1_IP

# Остановить uWSGI
sudo systemctl stop uwsgi

# Проверить статус
sudo systemctl status uwsgi

# Посмотреть логи
sudo tail -f /var/log/uwsgi/webapp.log
```

### Terminal 3: Мониторинг Nginx upstream

```bash
# SSH на Nginx сервер
NGINX_1_IP=$(terraform output -json nginx_instances | jq -r '.[0].external_ip')
ssh ubuntu@$NGINX_1_IP

# Смотреть логи в реальном времени
sudo tail -f /var/log/nginx/webapp_error.log
```

### Ожидаемый результат

1. Первые 3 запроса к Backend-1 могут вернуть ошибку 502
2. После fail_timeout (30s) Nginx исключает Backend-1
3. Все последующие запросы идут на Backend-2
4. Запросы успешны (200 OK)

### Восстановление

```bash
# На Backend-1
sudo systemctl start uwsgi
sudo systemctl status uwsgi
```

## Тест 4: GFS2 Синхронизация

### Создание файла на Backend-1

```bash
# SSH на Backend-1
BACKEND_1_IP=$(terraform output -json backend_instances | jq -r '.[0].external_ip')
ssh ubuntu@$BACKEND_1_IP

# Создать тестовый файл
echo "Test from Backend-1 at $(date)" | sudo tee /var/www/static/test-gfs2.txt

# Проверить создание
cat /var/www/static/test-gfs2.txt
```

### Проверка на Backend-2

```bash
# SSH на Backend-2
BACKEND_2_IP=$(terraform output -json backend_instances | jq -r '.[1].external_ip')
ssh ubuntu@$BACKEND_2_IP

# Файл должен быть виден немедленно (GFS2)
cat /var/www/static/test-gfs2.txt
# Ожидается: Test from Backend-1 at ...
```

### Создание файла на Backend-2

```bash
# На Backend-2
echo "Test from Backend-2 at $(date)" | sudo tee /var/www/static/test-gfs2-2.txt

# На Backend-1 проверить
cat /var/www/static/test-gfs2-2.txt
# Ожидается: Test from Backend-2 at ...
```

### Проверка статуса кластера

```bash
# На любом backend сервере
sudo pcs status

# Ожидается:
# - Cluster name: webapp_cluster
# - 2 nodes online
# - dlm resource running
```

## Тест 5: Database Connectivity

### Проверка соединения с Backend

```bash
# SSH на Backend-1
ssh ubuntu@$BACKEND_1_IP

# Активировать virtualenv и проверить подключение
cd /opt/webapp
source venv/bin/python

# Запустить Django shell
venv/bin/python manage.py dbshell

# В psql выполнить:
\l           # Список баз данных
\dt          # Список таблиц
\q           # Выход
```

### Проверка на Database сервере

```bash
# SSH на Database
DB_IP=$(terraform output -json database_instance | jq -r '.external_ip')
ssh ubuntu@$DB_IP

# Проверить статус PostgreSQL
sudo systemctl status postgresql

# Подключиться к базе
sudo -u postgres psql

# Проверить соединения
SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;

# Проверить пользователя
\du webapp_user

\q
```

### Тест отказа БД

```bash
# На Database сервере
sudo systemctl stop postgresql

# На Backend - запросы к БД должны падать
curl http://$LB_IP/admin/
# Ожидается: 500 Internal Server Error

# Восстановить
sudo systemctl start postgresql

# Запросы снова работают
curl http://$LB_IP/admin/
# Ожидается: 302 Found
```

## Тест 6: Нагрузочное тестирование

### Установка инструментов

```bash
# На локальной машине
# Apache Bench
sudo apt-get install apache2-utils  # Ubuntu/Debian
brew install httpd                   # macOS

# Или wrk (более продвинутый)
brew install wrk                     # macOS
```

### Базовый тест с Apache Bench

```bash
# 1000 запросов, 10 одновременных
ab -n 1000 -c 10 http://$LB_IP/health

# Результаты:
# - Requests per second
# - Time per request
# - Failed requests (должно быть 0)
```

### Тест с нагрузкой

```bash
# 10000 запросов, 100 одновременных
ab -n 10000 -c 100 http://$LB_IP/

# Следить за:
# - RPS (requests per second)
# - Latency (ms)
# - Failed requests
```

### Продвинутый тест с wrk

```bash
# 30 секунд, 100 соединений, 4 потока
wrk -t4 -c100 -d30s http://$LB_IP/

# Результаты:
# - Latency distribution
# - Throughput
# - Non-2xx responses
```

### Тест с одновременным отказом

```bash
# Terminal 1: Запуск нагрузочного теста
wrk -t4 -c100 -d60s http://$LB_IP/

# Terminal 2: Через 10 секунд остановить Backend-1
ssh ubuntu@$BACKEND_1_IP 'sudo systemctl stop uwsgi'

# Terminal 3: Через 30 секунд остановить Nginx-1
ssh ubuntu@$NGINX_1_IP 'sudo systemctl stop nginx'

# Анализировать результаты wrk:
# - Сколько запросов упало
# - Изменение latency
```

## Тест 7: Мониторинг ресурсов

### CPU и Memory на Backend

```bash
# SSH на Backend
ssh ubuntu@$BACKEND_1_IP

# Установить htop
sudo apt-get install htop -y

# Мониторинг в реальном времени
htop

# Или проще
top
# Найти процессы uwsgi и посмотреть CPU/MEM usage
```

### Мониторинг Nginx

```bash
# SSH на Nginx
ssh ubuntu@$NGINX_1_IP

# Активные соединения
ss -tln | grep :80

# Количество worker процессов
ps aux | grep nginx

# Статистика из логов (за последнюю минуту)
sudo tail -n 1000 /var/log/nginx/webapp_access.log | \
  awk '{print $9}' | sort | uniq -c | sort -rn
# Покажет количество каждого HTTP кода ответа
```

### Мониторинг Database

```bash
# SSH на Database
ssh ubuntu@$DB_IP

# Активность PostgreSQL
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"

# Статистика по базе
sudo -u postgres psql -c "SELECT * FROM pg_stat_database WHERE datname='webapp_db';"

# Размер базы
sudo -u postgres psql -c "SELECT pg_size_pretty(pg_database_size('webapp_db'));"
```

### Диск GFS2

```bash
# SSH на Backend
ssh ubuntu@$BACKEND_1_IP

# Использование диска
df -h /var/www/static

# I/O статистика
sudo iostat -x 1 5

# Статус GFS2
mount | grep gfs2
```

## Тест 8: Логирование

### Nginx Access Logs

```bash
# SSH на Nginx
ssh ubuntu@$NGINX_1_IP

# Последние 20 запросов
sudo tail -n 20 /var/log/nginx/webapp_access.log

# Запросы с ошибками
sudo grep " 5[0-9][0-9] " /var/log/nginx/webapp_access.log | tail -n 20

# Самые частые IP адреса
sudo awk '{print $1}' /var/log/nginx/webapp_access.log | \
  sort | uniq -c | sort -rn | head -n 10
```

### uWSGI Logs

```bash
# SSH на Backend
ssh ubuntu@$BACKEND_1_IP

# Последние логи
sudo tail -n 50 /var/log/uwsgi/webapp.log

# Ошибки
sudo grep -i error /var/log/uwsgi/webapp.log | tail -n 20

# Следить в реальном времени
sudo tail -f /var/log/uwsgi/webapp.log
```

### PostgreSQL Logs

```bash
# SSH на Database
ssh ubuntu@$DB_IP

# Логи PostgreSQL
sudo tail -f /var/log/postgresql/postgresql-14-main.log

# Медленные запросы (если настроено)
sudo grep "duration:" /var/log/postgresql/postgresql-14-main.log
```

## Контрольный список тестирования

### Функциональные тесты
- [ ] Load Balancer health check работает
- [ ] Главная страница приложения доступна
- [ ] Django admin доступен
- [ ] Статические файлы отдаются
- [ ] База данных доступна

### Тесты отказоустойчивости
- [ ] Отказ одного Nginx - приложение работает
- [ ] Отказ двух Nginx - приложение недоступно (ожидаемо)
- [ ] Отказ одного Backend - приложение работает
- [ ] Отказ двух Backend - приложение недоступно (ожидаемо)
- [ ] GFS2 синхронизация работает между Backend серверами
- [ ] Отказ БД - приложение падает (ожидаемо, single point)

### Производительность
- [ ] RPS >= 100 при 10 одновременных соединениях
- [ ] Latency < 100ms для health endpoint
- [ ] Latency < 500ms для динамических страниц
- [ ] CPU usage < 80% при нормальной нагрузке
- [ ] Memory usage стабильна (нет утечек)

### Мониторинг и логирование
- [ ] Nginx логи пишутся корректно
- [ ] uWSGI логи пишутся корректно
- [ ] PostgreSQL логи доступны
- [ ] GFS2 кластер в статусе "Online"
- [ ] Все сервисы в systemd enabled

## Автоматизированный тест-сюит

Для автоматизации можно создать скрипт:

```bash
#!/bin/bash
# test-suite.sh

LB_IP=$(cd terraform && terraform output -raw load_balancer_ip | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

echo "=== Running Test Suite ==="
echo "Load Balancer IP: $LB_IP"
echo ""

# Test 1: Health Check
echo "Test 1: Health Check"
if curl -s http://$LB_IP/health | grep -q "OK"; then
  echo "✓ PASS"
else
  echo "✗ FAIL"
fi
echo ""

# Test 2: Main Page
echo "Test 2: Main Page Availability"
status=$(curl -s -o /dev/null -w "%{http_code}" http://$LB_IP/)
if [ "$status" -eq 200 ] || [ "$status" -eq 301 ] || [ "$status" -eq 302 ]; then
  echo "✓ PASS (HTTP $status)"
else
  echo "✗ FAIL (HTTP $status)"
fi
echo ""

# Test 3: Performance
echo "Test 3: Performance (100 requests)"
ab_result=$(ab -n 100 -c 10 http://$LB_IP/health 2>&1)
rps=$(echo "$ab_result" | grep "Requests per second" | awk '{print $4}')
echo "RPS: $rps"
if (( $(echo "$rps > 50" | bc -l) )); then
  echo "✓ PASS"
else
  echo "✗ FAIL"
fi
echo ""

echo "=== Test Suite Completed ==="
```

## Отчёт о тестировании

После завершения тестов заполните отчёт:

```markdown
## Отчёт о тестировании

Дата: ________
Тестировщик: ________

### Результаты

1. Базовая доступность: PASS/FAIL
2. Nginx failover: PASS/FAIL
3. Backend failover: PASS/FAIL
4. GFS2 синхронизация: PASS/FAIL
5. Database connectivity: PASS/FAIL
6. Производительность: ___ RPS, ___ ms latency

### Проблемы

1. ...
2. ...

### Рекомендации

1. ...
2. ...
```
