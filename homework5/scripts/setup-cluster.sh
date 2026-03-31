#!/bin/bash

echo "=== Waiting for MySQL servers to be ready ==="
sleep 20

echo "=== Creating InnoDB Cluster Administrator User on all nodes ==="
for server in mysql-server-1 mysql-server-2 mysql-server-3; do
  echo "Configuring $server..."
  mysql -h $server -uroot -prootpass <<EOF
CREATE USER IF NOT EXISTS 'clusteradmin'@'%' IDENTIFIED BY 'clusterpass';
GRANT ALL PRIVILEGES ON *.* TO 'clusteradmin'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
done

echo "=== Configuring instances for InnoDB Cluster ==="
mysqlsh --log-level=DEBUG3 -uroot -prootpass -h mysql-server-1 --js <<EOF
dba.configureInstance('root@mysql-server-1:3306', {password: 'rootpass', clusterAdmin: 'clusteradmin', clusterAdminPassword: 'clusterpass', restart: false});
dba.configureInstance('root@mysql-server-2:3306', {password: 'rootpass', clusterAdmin: 'clusteradmin', clusterAdminPassword: 'clusterpass', restart: false});
dba.configureInstance('root@mysql-server-3:3306', {password: 'rootpass', clusterAdmin: 'clusteradmin', clusterAdminPassword: 'clusterpass', restart: false});
EOF

echo "=== Creating InnoDB Cluster ==="
mysqlsh --log-level=DEBUG3 -uclusteradmin -pclusterpass -h mysql-server-1 --js <<EOF
var cluster = dba.createCluster('myCluster', {ipWhitelist: '172.20.0.0/16'});
cluster.addInstance('clusteradmin@mysql-server-2:3306', {password: 'clusterpass', recoveryMethod: 'clone'});
cluster.addInstance('clusteradmin@mysql-server-3:3306', {password: 'clusterpass', recoveryMethod: 'clone'});
cluster.status();
EOF

echo "=== InnoDB Cluster Setup Complete ==="
echo "=== Cluster Status ==="
mysqlsh --log-level=DEBUG3 -uclusteradmin -pclusterpass -h mysql-server-1 --js <<EOF
var cluster = dba.getCluster('myCluster');
cluster.status();
EOF
