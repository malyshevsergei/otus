.PHONY: help start stop restart status setup-cluster create-db check clean logs

help:
	@echo "MySQL InnoDB Cluster Management"
	@echo ""
	@echo "Available commands:"
	@echo "  make start          - Start all containers"
	@echo "  make stop           - Stop all containers"
	@echo "  make restart        - Restart all containers"
	@echo "  make status         - Show container status"
	@echo "  make setup-cluster  - Configure InnoDB Cluster"
	@echo "  make create-db      - Create project database"
	@echo "  make check          - Check cluster status"
	@echo "  make logs           - Show logs from all containers"
	@echo "  make clean          - Stop and remove all containers and volumes"
	@echo "  make shell          - Connect to MySQL Shell"
	@echo "  make mysql-primary  - Connect to primary MySQL node"
	@echo "  make test-failover  - Test cluster failover"

start:
	docker-compose up -d
	@echo "Waiting for MySQL servers to start..."
	@sleep 30
	@echo "Containers started successfully!"

stop:
	docker-compose stop

restart:
	docker-compose restart

status:
	docker-compose ps

setup-cluster:
	@echo "Setting up InnoDB Cluster..."
	docker exec -it mysql-shell bash /scripts/setup-cluster.sh

create-db:
	@echo "Creating project database..."
	docker exec -i mysql-shell mysql -h mysql-server-1 -uroot -prootpass < scripts/create-database.sql

check:
	docker exec -it mysql-shell bash /scripts/check-cluster-status.sh

logs:
	docker-compose logs -f

clean:
	docker-compose down -v
	@echo "All containers and volumes removed!"

shell:
	docker exec -it mysql-shell mysqlsh -uclusteradmin -pclusterpass -h mysql-server-1

mysql-primary:
	docker exec -it mysql-shell mysql -h mysql-server-1 -uroot -prootpass

mysql-app:
	docker exec -it mysql-shell mysql -h mysql-router -P 6446 -uappuser -papppass project_db

test-failover:
	@echo "Testing failover by stopping mysql-server-1..."
	docker-compose stop mysql-server-1
	@echo "Waiting for failover..."
	@sleep 10
	@echo "Checking cluster status..."
	@make check
	@echo ""
	@echo "Starting mysql-server-1 back..."
	docker-compose start mysql-server-1
	@echo "Cluster should recover automatically"

all: start setup-cluster create-db check
