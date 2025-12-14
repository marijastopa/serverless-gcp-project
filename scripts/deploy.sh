#!/bin/bash

# Deployment Script for Serverless GCP Pipeline

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}GCP Serverless Pipeline Deployment${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if terraform.tfvars exists
if [ ! -f "infrastructure/terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found${NC}"
    echo -e "${YELLOW}Please copy terraform.tfvars.example to terraform.tfvars and fill in your values:${NC}"
    echo -e "  cd infrastructure"
    echo -e "  cp terraform.tfvars.example terraform.tfvars"
    echo -e "  # Edit terraform.tfvars with your GCP project ID"
    exit 1
fi

# Navigate to infrastructure directory
cd infrastructure

echo -e "${YELLOW}Step 1: Initializing Terraform...${NC}"
terraform init

echo ""
echo -e "${YELLOW}Step 2: Validating Terraform configuration...${NC}"
terraform validate

echo ""
echo -e "${YELLOW}Step 3: Planning deployment...${NC}"
terraform plan -out=tfplan

echo ""
echo -e "${YELLOW}Step 4: Reviewing plan...${NC}"
echo -e "${GREEN}Review the plan above. Do you want to apply? (yes/no)${NC}"
read -r response

if [ "$response" != "yes" ]; then
    echo -e "${RED}Deployment cancelled${NC}"
    rm -f tfplan
    exit 0
fi

echo ""
echo -e "${YELLOW}Step 5: Applying Terraform configuration...${NC}"
terraform apply tfplan

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Display outputs
echo -e "${YELLOW}Deployment Details:${NC}"
terraform output

echo ""
echo -e "${GREEN}Next steps:${NC}"
echo -e "  1. Test the function:"
terraform output -raw test_command
echo ""
echo -e "  2. View logs in GCP Console"
echo -e "  3. Check Firestore for stored data"

# Cleanup
rm -f tfplan

cd ..