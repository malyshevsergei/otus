#!/bin/bash

echo "=== Checking InnoDB Cluster Status ==="
mysqlsh --log-level=ERROR -uclusteradmin -pclusterpass -h mysql-server-1 --js <<EOF
var cluster = dba.getCluster('myCluster');
print('\n=== Cluster Status ===');
cluster.status();
print('\n=== Cluster Description ===');
cluster.describe();
EOF

echo ""
echo "=== Checking Replication Status on all nodes ==="
for server in mysql-server-1 mysql-server-2 mysql-server-3; do
  echo ""
  echo "--- $server ---"
  mysql -h $server -uroot -prootpass -e "SHOW VARIABLES LIKE 'server_id'; SELECT MEMBER_HOST, MEMBER_PORT, MEMBER_STATE, MEMBER_ROLE FROM performance_schema.replication_group_members;"
done
