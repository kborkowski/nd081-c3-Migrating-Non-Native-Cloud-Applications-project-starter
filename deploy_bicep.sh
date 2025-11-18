#!/bin/bash

# TechConf Azure Deployment Script using Bicep
# This script deploys all Azure resources using the Bicep template

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=========================================="
echo "TechConf Azure Deployment"
echo "=========================================="
echo ""

# Configuration
RESOURCE_GROUP="techconf-rg"
LOCATION="westeurope"
DEPLOYMENT_NAME="techconf-deployment-$(date +%s)"

# Check if logged in to Azure
echo -e "${YELLOW}Checking Azure login...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED}Not logged in to Azure. Please run 'az login' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Logged in to Azure${NC}"
az account show --output table
echo ""

# Create Resource Group
echo -e "${YELLOW}Creating resource group: ${RESOURCE_GROUP}...${NC}"
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --output table

echo -e "${GREEN}✓ Resource group created${NC}"
echo ""

# Validate Bicep template
echo -e "${YELLOW}Validating Bicep template...${NC}"
az deployment group validate \
  --resource-group $RESOURCE_GROUP \
  --template-file main.bicep \
  --parameters main.parameters.json \
  --output table

echo -e "${GREEN}✓ Template validated${NC}"
echo ""

# Deploy resources
echo -e "${YELLOW}Deploying Azure resources (this may take 10-15 minutes)...${NC}"
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --template-file main.bicep \
  --parameters main.parameters.json \
  --output table

echo -e "${GREEN}✓ Resources deployed${NC}"
echo ""

# Get deployment outputs
echo -e "${YELLOW}Retrieving deployment outputs...${NC}"
WEB_APP_URL=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.webAppUrl.value \
  --output tsv)

FUNCTION_APP_URL=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.functionAppUrl.value \
  --output tsv)

POSTGRES_SERVER=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $DEPLOYMENT_NAME \
  --query properties.outputs.postgresServerFqdn.value \
  --output tsv)

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo -e "${GREEN}Web App URL:${NC} $WEB_APP_URL"
echo -e "${GREEN}Function App URL:${NC} $FUNCTION_APP_URL"
echo -e "${GREEN}PostgreSQL Server:${NC} $POSTGRES_SERVER"
echo ""

# Save outputs to file
cat > deployment-outputs.txt << EOF
TechConf Deployment Outputs
Generated: $(date)

Resource Group: $RESOURCE_GROUP
Location: $LOCATION

Web App URL: $WEB_APP_URL
Function App URL: $FUNCTION_APP_URL
PostgreSQL Server: $POSTGRES_SERVER

Next Steps:
1. Restore database: PGPASSWORD='SecurePass123!' psql "host=$POSTGRES_SERVER port=5432 dbname=techconfdb user=techconfadmin@$(echo $POSTGRES_SERVER | cut -d'.' -f1) sslmode=require" < data/techconfdb_backup.sql
2. Deploy web app: cd web && zip -r ../web-deploy.zip . -x "venv/*" -x "__pycache__/*" -x "*.pyc" && cd .. && az webapp deployment source config-zip --resource-group $RESOURCE_GROUP --name $(echo $WEB_APP_URL | sed 's|https://||' | cut -d'.' -f1) --src web-deploy.zip
3. Deploy function: cd function && func azure functionapp publish $(echo $FUNCTION_APP_URL | sed 's|https://||' | cut -d'.' -f1)
EOF

echo -e "${GREEN}✓ Deployment outputs saved to deployment-outputs.txt${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Restore the database backup"
echo "2. Deploy the web application code"
echo "3. Deploy the Azure Function code"
echo ""
echo "Run the following commands:"
echo ""
echo "# 1. Restore database"
echo "PGPASSWORD='SecurePass123!' psql \"host=$POSTGRES_SERVER port=5432 dbname=techconfdb user=techconfadmin@\$(echo $POSTGRES_SERVER | cut -d'.' -f1) sslmode=require\" < data/techconfdb_backup.sql"
echo ""
echo "# 2. Deploy web app"
echo "./deploy_webapp.sh"
echo ""
echo "# 3. Deploy function"
echo "./deploy_function.sh"
echo ""
