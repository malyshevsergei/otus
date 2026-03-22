#!/bin/bash
set -e

echo "========================================="
echo "Destroying Infrastructure"
echo "========================================="
echo ""

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}WARNING: This will destroy all infrastructure!${NC}"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destruction cancelled"
    exit 1
fi

cd terraform
echo -e "${YELLOW}Destroying infrastructure...${NC}"
terraform destroy -auto-approve

echo -e "${YELLOW}Cleaning up generated files...${NC}"
rm -f ../ansible/inventory.ini

echo "Infrastructure destroyed successfully"
