#!/bin/bash
# Quick diagnostic script for backend servers

echo "Checking backend servers..."
echo ""

# Get backend IPs
cd terraform
BACKEND_1_IP=$(terraform output -json backend_instances | jq -r '.[0].external_ip')
BACKEND_2_IP=$(terraform output -json backend_instances | jq -r '.[1].external_ip')

echo "Backend 1: $BACKEND_1_IP"
echo "Backend 2: $BACKEND_2_IP"
echo ""

echo "==================== Backend 1 Diagnostics ===================="
ssh -o StrictHostKeyChecking=no almalinux@$BACKEND_1_IP << 'EOF'
echo "--- uWSGI Service Status ---"
sudo systemctl status uwsgi --no-pager | head -20

echo ""
echo "--- Last 30 lines of uWSGI log ---"
sudo tail -30 /var/log/uwsgi/webapp.log

echo ""
echo "--- Check if uWSGI is listening on port 8000 ---"
sudo ss -tlnp | grep 8000
EOF

echo ""
echo "==================== Backend 2 Diagnostics ===================="
ssh -o StrictHostKeyChecking=no almalinux@$BACKEND_2_IP << 'EOF'
echo "--- uWSGI Service Status ---"
sudo systemctl status uwsgi --no-pager | head -20

echo ""
echo "--- Last 30 lines of uWSGI log ---"
sudo tail -30 /var/log/uwsgi/webapp.log

echo ""
echo "--- Check if uWSGI is listening on port 8000 ---"
sudo ss -tlnp | grep 8000
EOF
