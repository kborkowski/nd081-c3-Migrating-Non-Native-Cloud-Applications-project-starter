#!/bin/bash

# Deploy Web Application to Azure App Service

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Deploying Web Application to Azure"
echo "=========================================="
echo ""

RESOURCE_GROUP="techconf-rg"
WEB_APP_NAME="techconf-web-xizeh6mypik36"
WEB_DIR="/workspaces/nd081-c3-Migrating-Non-Native-Cloud-Applications-project-starter/web"

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
cd "$WEB_DIR"

# Create a temporary directory for deployment
DEPLOY_DIR=$(mktemp -d)
echo "Temporary deployment directory: $DEPLOY_DIR"

# Copy application files
cp -r app application.py config.py requirements.txt "$DEPLOY_DIR/"

# Note: Startup command is configured separately via az webapp config set
# Azure App Service will automatically install requirements.txt
# We use gunicorn directly as the startup command

# Create .deployment file
cat > "$DEPLOY_DIR/.deployment" << 'EOF'
[config]
SCM_DO_BUILD_DURING_DEPLOYMENT=true
EOF

# Create zip package
cd "$DEPLOY_DIR"
zip -r web-deploy.zip . -x "*.pyc" -x "*__pycache__*" -x "venv/*"

echo -e "${GREEN}✓ Deployment package created${NC}"

# Deploy to Azure
echo -e "${YELLOW}Deploying to Azure Web App...${NC}"
az webapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP" \
    --name "$WEB_APP_NAME" \
    --src web-deploy.zip

echo -e "${GREEN}✓ Web application deployed${NC}"

# Configure startup command (use gunicorn directly)
echo -e "${YELLOW}Configuring startup command...${NC}"
az webapp config set \
    --resource-group "$RESOURCE_GROUP" \
    --name "$WEB_APP_NAME" \
    --startup-file "gunicorn --bind=0.0.0.0 --timeout 600 application:app"

echo -e "${GREEN}✓ Startup command configured${NC}"

# Clean up
rm -rf "$DEPLOY_DIR"

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Web App URL: https://${WEB_APP_NAME}.azurewebsites.net"
echo ""
echo "Check logs with:"
echo "az webapp log tail --resource-group $RESOURCE_GROUP --name $WEB_APP_NAME"
