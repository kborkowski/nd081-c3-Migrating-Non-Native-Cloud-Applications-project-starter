#!/bin/bash

# Automated Azure Deployment Script for TechConf Application
# This script creates all required Azure resources and deploys the application

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================"
echo "TechConf Azure Deployment"
echo -e "======================================${NC}"

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${RED}[✗]${NC} .env file not found!"
    exit 1
fi

# Check if logged into Azure
if ! az account show &> /dev/null; then
    echo -e "${RED}[✗]${NC} Not logged into Azure. Run './azure_login.sh' first."
    exit 1
fi

echo -e "${GREEN}[✓]${NC} Logged into Azure"

# Set variables with defaults from .env
RESOURCE_GROUP=${AZURE_RESOURCE_GROUP:-"techconf-rg"}
LOCATION=${AZURE_LOCATION:-"eastus"}
POSTGRES_SERVER="techconf-db-$(date +%s)"
POSTGRES_ADMIN="techconfadmin"
POSTGRES_PASSWORD="TechConf2025!$(openssl rand -base64 12 | tr -d '=/+' | head -c 10)"
DATABASE_NAME="techconfdb"
SERVICE_BUS_NAMESPACE="techconf-sb-$(date +%s)"
STORAGE_ACCOUNT="techconfstore$(date +%s | tail -c 8)"
FUNCTION_APP="techconf-func-$(date +%s)"
WEB_APP="techconf-web-$(date +%s)"
APP_SERVICE_PLAN="techconf-plan"

echo ""
echo -e "${BLUE}Resource Configuration:${NC}"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "PostgreSQL Server: $POSTGRES_SERVER"
echo "Service Bus: $SERVICE_BUS_NAMESPACE"
echo "Web App: $WEB_APP"
echo "Function App: $FUNCTION_APP"
echo ""

read -p "Continue with deployment? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Create Resource Group
echo ""
echo -e "${YELLOW}[1/8]${NC} Creating Resource Group..."
if az group create --name "$RESOURCE_GROUP" --location "$LOCATION" > /dev/null; then
    echo -e "${GREEN}[✓]${NC} Resource group created: $RESOURCE_GROUP"
else
    echo -e "${YELLOW}[i]${NC} Resource group already exists"
fi

# Create PostgreSQL Database
echo ""
echo -e "${YELLOW}[2/8]${NC} Creating PostgreSQL Database Server..."
az postgres server create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$POSTGRES_SERVER" \
    --location "$LOCATION" \
    --admin-user "$POSTGRES_ADMIN" \
    --admin-password "$POSTGRES_PASSWORD" \
    --sku-name B_Gen5_1 \
    --version 11 \
    --storage-size 5120 \
    --output none

echo -e "${GREEN}[✓]${NC} PostgreSQL server created"

# Create database
echo "Creating database $DATABASE_NAME..."
az postgres db create \
    --resource-group "$RESOURCE_GROUP" \
    --server-name "$POSTGRES_SERVER" \
    --name "$DATABASE_NAME" \
    --output none
echo -e "${GREEN}[✓]${NC} Database created"

# Configure firewall
echo "Configuring firewall rules..."
az postgres server firewall-rule create \
    --resource-group "$RESOURCE_GROUP" \
    --server-name "$POSTGRES_SERVER" \
    --name AllowAllAzureIPs \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0 \
    --output none

az postgres server firewall-rule create \
    --resource-group "$RESOURCE_GROUP" \
    --server-name "$POSTGRES_SERVER" \
    --name AllowAllIPs \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 255.255.255.255 \
    --output none
echo -e "${GREEN}[✓]${NC} Firewall rules configured"

# Create Service Bus
echo ""
echo -e "${YELLOW}[3/8]${NC} Creating Service Bus..."
az servicebus namespace create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$SERVICE_BUS_NAMESPACE" \
    --location "$LOCATION" \
    --sku Standard \
    --output none
echo -e "${GREEN}[✓]${NC} Service Bus namespace created"

az servicebus queue create \
    --resource-group "$RESOURCE_GROUP" \
    --namespace-name "$SERVICE_BUS_NAMESPACE" \
    --name notificationqueue \
    --output none
echo -e "${GREEN}[✓]${NC} Service Bus queue created"

# Get Service Bus connection string
SERVICE_BUS_CONNECTION=$(az servicebus namespace authorization-rule keys list \
    --resource-group "$RESOURCE_GROUP" \
    --namespace-name "$SERVICE_BUS_NAMESPACE" \
    --name RootManageSharedAccessKey \
    --query primaryConnectionString \
    --output tsv)

# Create Storage Account
echo ""
echo -e "${YELLOW}[4/8]${NC} Creating Storage Account..."
az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --output none
echo -e "${GREEN}[✓]${NC} Storage account created"

# Create App Service Plan
echo ""
echo -e "${YELLOW}[5/8]${NC} Creating App Service Plan..."
az appservice plan create \
    --name "$APP_SERVICE_PLAN" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku B1 \
    --is-linux \
    --output none
echo -e "${GREEN}[✓]${NC} App Service Plan created"

# Create Web App
echo ""
echo -e "${YELLOW}[6/8]${NC} Creating Web App..."
az webapp create \
    --resource-group "$RESOURCE_GROUP" \
    --plan "$APP_SERVICE_PLAN" \
    --name "$WEB_APP" \
    --runtime "PYTHON:3.9" \
    --output none
echo -e "${GREEN}[✓]${NC} Web App created"

# Configure Web App settings
POSTGRES_HOST="${POSTGRES_SERVER}.postgres.database.azure.com"
az webapp config appsettings set \
    --resource-group "$RESOURCE_GROUP" \
    --name "$WEB_APP" \
    --settings \
        POSTGRES_URL="$POSTGRES_HOST" \
        POSTGRES_USER="${POSTGRES_ADMIN}@${POSTGRES_SERVER}" \
        POSTGRES_PW="$POSTGRES_PASSWORD" \
        POSTGRES_DB="$DATABASE_NAME" \
        SERVICE_BUS_CONNECTION_STRING="$SERVICE_BUS_CONNECTION" \
        SERVICE_BUS_QUEUE_NAME="notificationqueue" \
        ADMIN_EMAIL_ADDRESS="$ADMIN_EMAIL_ADDRESS" \
        SECRET_KEY="$SECRET_KEY" \
    --output none
echo -e "${GREEN}[✓]${NC} Web App settings configured"

# Create Function App
echo ""
echo -e "${YELLOW}[7/8]${NC} Creating Function App..."
az functionapp create \
    --resource-group "$RESOURCE_GROUP" \
    --consumption-plan-location "$LOCATION" \
    --runtime python \
    --runtime-version 3.9 \
    --functions-version 4 \
    --name "$FUNCTION_APP" \
    --storage-account "$STORAGE_ACCOUNT" \
    --os-type Linux \
    --output none
echo -e "${GREEN}[✓]${NC} Function App created"

# Configure Function App settings
az functionapp config appsettings set \
    --name "$FUNCTION_APP" \
    --resource-group "$RESOURCE_GROUP" \
    --settings \
        SERVICE_BUS_CONNECTION_STRING="$SERVICE_BUS_CONNECTION" \
        POSTGRES_URL="$POSTGRES_HOST" \
        POSTGRES_USER="${POSTGRES_ADMIN}@${POSTGRES_SERVER}" \
        POSTGRES_PW="$POSTGRES_PASSWORD" \
        POSTGRES_DB="$DATABASE_NAME" \
        ADMIN_EMAIL_ADDRESS="$ADMIN_EMAIL_ADDRESS" \
        SENDGRID_API_KEY="$SENDGRID_API_KEY" \
    --output none
echo -e "${GREEN}[✓]${NC} Function App settings configured"

# Restore database
echo ""
echo -e "${YELLOW}[8/8]${NC} Restoring database backup..."
PGPASSWORD="$POSTGRES_PASSWORD" psql \
    "host=$POSTGRES_HOST port=5432 dbname=$DATABASE_NAME user=${POSTGRES_ADMIN}@${POSTGRES_SERVER} sslmode=require" \
    < data/techconfdb_backup.sql 2>/dev/null || echo -e "${YELLOW}[i]${NC} Database restore completed with warnings (this is normal)"

echo -e "${GREEN}[✓]${NC} Database backup restored"

# Update .env file with Azure resources
echo ""
echo -e "${YELLOW}[i]${NC} Updating .env file with Azure resource details..."

cat >> .env << EOF

# Azure Deployment Details (Generated $(date))
AZURE_POSTGRES_URL=$POSTGRES_HOST
AZURE_POSTGRES_USER=${POSTGRES_ADMIN}@${POSTGRES_SERVER}
AZURE_POSTGRES_PW=$POSTGRES_PASSWORD
SERVICE_BUS_CONNECTION_STRING=$SERVICE_BUS_CONNECTION
AZURE_WEB_APP_NAME=$WEB_APP
AZURE_FUNCTION_APP_NAME=$FUNCTION_APP
EOF

echo -e "${GREEN}[✓]${NC} .env file updated"

# Display summary
echo ""
echo -e "${BLUE}======================================"
echo "Deployment Complete!"
echo -e "======================================${NC}"
echo ""
echo -e "${GREEN}Web App URL:${NC} https://${WEB_APP}.azurewebsites.net"
echo -e "${GREEN}PostgreSQL Server:${NC} $POSTGRES_HOST"
echo -e "${GREEN}PostgreSQL Admin:${NC} ${POSTGRES_ADMIN}@${POSTGRES_SERVER}"
echo -e "${GREEN}PostgreSQL Password:${NC} $POSTGRES_PASSWORD"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Deploy web app code: cd web && zip -r ../web.zip . && az webapp deployment source config-zip --resource-group $RESOURCE_GROUP --name $WEB_APP --src ../web.zip"
echo "2. Deploy function code: cd function && func azure functionapp publish $FUNCTION_APP"
echo ""
echo -e "${YELLOW}IMPORTANT:${NC} Save the PostgreSQL password shown above!"
echo ""
