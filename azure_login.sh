#!/bin/bash

# Azure Login and Initial Setup Script
# This script logs into Azure and sets up the initial configuration

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================"
echo "Azure Login and Setup"
echo -e "======================================${NC}"

# Load environment variables
if [ -f .env ]; then
    echo -e "${GREEN}[✓]${NC} Loading environment variables from .env"
    export $(grep -v '^#' .env | xargs)
else
    echo -e "${RED}[✗]${NC} .env file not found!"
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}[✗]${NC} Azure CLI is not installed"
    echo "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi
echo -e "${GREEN}[✓]${NC} Azure CLI is installed ($(az --version | head -n 1))"

# Login to Azure
echo ""
echo -e "${YELLOW}[i]${NC} Logging into Azure..."
echo "Username: $AZURE_USERNAME"

# Try to login (will prompt for password interactively)
if az login --username "$AZURE_USERNAME" --allow-no-subscriptions; then
    echo -e "${GREEN}[✓]${NC} Successfully logged into Azure"
else
    echo -e "${YELLOW}[i]${NC} Interactive login required. Opening browser..."
    az login
fi

# Get and display subscription information
echo ""
echo -e "${YELLOW}[i]${NC} Fetching subscription information..."
SUBSCRIPTIONS=$(az account list --output table)
echo "$SUBSCRIPTIONS"

# Get the default subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo ""
echo -e "${GREEN}[✓]${NC} Current subscription: $SUBSCRIPTION_ID"

# Update .env file with subscription ID if not already set
if [ -z "$AZURE_SUBSCRIPTION_ID" ] || [ "$AZURE_SUBSCRIPTION_ID" == "" ]; then
    echo ""
    echo -e "${YELLOW}[i]${NC} Updating .env with subscription ID..."
    
    # Check if the line exists
    if grep -q "^AZURE_SUBSCRIPTION_ID=" .env; then
        # Update existing line
        sed -i "s|^AZURE_SUBSCRIPTION_ID=.*|AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID|" .env
    else
        # Append if not exists
        echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID" >> .env
    fi
    echo -e "${GREEN}[✓]${NC} Updated .env with subscription ID"
fi

# Display Azure account info
echo ""
echo -e "${BLUE}======================================"
echo "Azure Account Information"
echo -e "======================================${NC}"
az account show --output table

# Check for existing resource groups
echo ""
echo -e "${YELLOW}[i]${NC} Checking for existing resource groups..."
EXISTING_RGS=$(az group list --query "[].name" -o tsv)
if [ -z "$EXISTING_RGS" ]; then
    echo "No existing resource groups found."
else
    echo "Existing resource groups:"
    echo "$EXISTING_RGS"
fi

# Ask if user wants to create resources now
echo ""
echo -e "${BLUE}======================================"
echo "Next Steps"
echo -e "======================================${NC}"
echo ""
echo "You are now logged into Azure!"
echo ""
echo "To deploy the TechConf application, you can:"
echo "1. Run './deploy_to_azure.sh' to automatically create all resources"
echo "2. Follow the manual steps in DEPLOYMENT_GUIDE.md"
echo ""
echo -e "${GREEN}TIP:${NC} Run 'az group list' to see your resource groups"
echo -e "${GREEN}TIP:${NC} Run 'az resource list --resource-group <name>' to see resources in a group"
echo ""
