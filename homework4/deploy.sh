#!/bin/bash
set -e

echo "========================================="
echo "Deploying High-Availability Web Application"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Initialize Terraform
echo -e "${YELLOW}Step 1: Initializing Terraform...${NC}"
cd terraform
terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Step 2: Plan infrastructure
echo -e "${YELLOW}Step 2: Planning infrastructure...${NC}"
terraform plan
echo ""

# Step 3: Apply infrastructure
echo -e "${YELLOW}Step 3: Applying infrastructure changes...${NC}"
read -p "Do you want to proceed with infrastructure creation? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 1
fi

terraform apply -auto-approve
echo -e "${GREEN}✓ Infrastructure created${NC}"
echo ""

# Step 4: Generate Ansible inventory
echo -e "${YELLOW}Step 4: Generating Ansible inventory...${NC}"
terraform output -raw ansible_inventory > ../ansible/inventory.ini
echo -e "${GREEN}✓ Inventory generated${NC}"
echo ""

# Step 5: Wait for instances to be ready
echo -e "${YELLOW}Step 5: Waiting for instances to be ready...${NC}"
sleep 30
echo -e "${GREEN}✓ Instances ready${NC}"
echo ""

# Step 6: Run Ansible playbook
echo -e "${YELLOW}Step 6: Configuring servers with Ansible...${NC}"
cd ../ansible
ansible-playbook -i inventory.ini site.yml
echo -e "${GREEN}✓ Configuration complete${NC}"
echo ""

# Step 7: Display access information
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
cd ../terraform
echo "Load Balancer IP:"
terraform output load_balancer_ip
echo ""
echo "Access your application at:"
echo "http://$(terraform output -raw load_balancer_ip | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')"
echo ""
echo "To test the deployment:"
echo "  curl http://$(terraform output -raw load_balancer_ip | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')/health"
