#!/bin/bash

echo "========================================="
echo "Testing High Availability and Failover"
echo "========================================="
echo ""

# Get load balancer IP
cd terraform
LB_IP=$(terraform output -raw load_balancer_ip | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

if [ -z "$LB_IP" ]; then
    echo "Error: Could not get load balancer IP"
    exit 1
fi

echo "Load Balancer IP: $LB_IP"
echo ""

# Test 1: Check load balancer health
echo "Test 1: Checking load balancer health endpoint..."
if curl -s "http://$LB_IP/health" | grep -q "OK"; then
    echo "✓ Load balancer is healthy"
else
    echo "✗ Load balancer health check failed"
fi
echo ""

# Test 2: Continuous requests
echo "Test 2: Sending continuous requests (10 requests)..."
for i in {1..10}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://$LB_IP/")
    echo "Request $i: HTTP $response"
    sleep 1
done
echo ""

# Test 3: Backend failover test
echo "Test 3: Backend server failover test"
echo "Instructions:"
echo "1. In another terminal, stop one of the backend servers:"
echo "   cd terraform"
echo "   terraform console"
echo "   > yandex_compute_instance.backend[0].name"
echo "   Then SSH to that server and run: sudo systemctl stop uwsgi"
echo ""
echo "2. Monitor requests (they should continue working):"
echo ""
echo "Press Enter when you've stopped a backend server..."
read

echo "Sending requests to verify failover..."
for i in {1..10}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://$LB_IP/")
    if [ "$response" == "200" ] || [ "$response" == "502" ]; then
        echo "Request $i: HTTP $response"
    else
        echo "Request $i: HTTP $response (Unexpected)"
    fi
    sleep 1
done
echo ""

# Test 4: Nginx failover test
echo "Test 4: Nginx server failover test"
echo "Instructions:"
echo "1. Stop one of the nginx servers:"
echo "   SSH to nginx server and run: sudo systemctl stop nginx"
echo ""
echo "2. Requests should still work via the other nginx server"
echo ""
echo "Press Enter when you've stopped an nginx server..."
read

echo "Sending requests to verify nginx failover..."
for i in {1..10}; do
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://$LB_IP/health")
    echo "Request $i: HTTP $response"
    sleep 1
done
echo ""

echo "========================================="
echo "Failover tests completed"
echo "========================================="
echo ""
echo "Remember to restart stopped services:"
echo "  sudo systemctl start uwsgi"
echo "  sudo systemctl start nginx"
