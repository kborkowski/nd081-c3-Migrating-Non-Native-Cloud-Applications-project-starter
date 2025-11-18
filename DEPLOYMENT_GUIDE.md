# TechConf Azure Deployment Guide

## Overview
This guide provides comprehensive step-by-step instructions for deploying the TechConf application to Azure using Infrastructure as Code (Bicep templates). The deployment includes migrating the web application, database, and background notification processing to Azure.

## Architecture Summary

### Azure Resources Used
1. **Azure App Service (Web App)** - B1 (Basic) tier, Linux, Python 3.11
2. **Azure Functions** - Consumption plan, Python 3.11, Service Bus trigger
3. **Azure Database for PostgreSQL** - Flexible Server, Standard_B1ms (Burstable tier), PostgreSQL 13
4. **Azure Service Bus** - Standard tier with notification queue
5. **Azure Storage Account** - Standard_LRS for Function App backend

### Why This Architecture?
- **Cost-Effective**: Basic tier App Service (~$13/month) and Burstable PostgreSQL (~$25/month) minimize costs while providing adequate performance for the application
- **Scalable**: Service Bus decouples notification processing, allowing the system to handle high volumes asynchronously
- **Reliable**: Azure Functions automatically scale based on queue depth, ensuring notifications are processed efficiently
- **Maintainable**: Separation of concerns between web app (user interface) and function (background processing)

### Monthly Cost Analysis
| Azure Resource | Pricing Tier | Estimated Monthly Cost | Justification |
|----------------|--------------|------------------------|---------------|
| App Service Plan (B1) | Basic (1 Core, 1.75 GB RAM) | ~$13 | Cost-effective for low-to-medium traffic web apps. Provides "Always On" capability and custom domains |
| PostgreSQL Flexible Server | Standard_B1ms (Burstable, 1 vCore, 2 GB RAM, 32 GB storage) | ~$25 | Burstable tier ideal for applications with intermittent usage patterns. Automatically scales compute |
| Service Bus Namespace | Standard tier | ~$10 | Enables advanced messaging features like topics/subscriptions and larger message sizes (256 KB) |
| Azure Functions | Consumption Plan | ~$0-5 | Pay-per-execution model. First 1 million executions free. Ideal for event-driven workloads |
| Storage Account | Standard_LRS (Locally Redundant) | ~$2 | Required for Function App runtime. LRS provides cost-effective redundancy |
| **Total Estimated Cost** | | **~$50-55/month** | |

> **Note**: Costs may vary based on actual usage, data transfer, and regional pricing. West Europe pricing applied.

## Prerequisites
1. **Azure subscription** with sufficient credits (at least $100 recommended)
2. **Azure CLI** version 2.80.0 or higher installed and configured
3. **PostgreSQL client tools** (psql) for database restoration
4. **Python 3.11+** installed locally for testing
5. **SendGrid account** with API key for email notifications
6. **Git** for version control
7. **Basic knowledge** of Azure services and command-line operations

## Step-by-Step Deployment

### Phase 1: Prepare Environment and Credentials

#### 1.1 Verify Prerequisites
```bash
# Check Azure CLI version (must be 2.80.0+)
az --version

# Login to Azure
az login

# Verify your subscription
az account show --query "{Name:name, SubscriptionId:id, TenantId:tenantId}" --output table

# Set your subscription (if you have multiple)
az account set --subscription "<your-subscription-id>"
```

#### 1.2 Obtain SendGrid API Key
1. Sign up for a free SendGrid account at https://signup.sendgrid.com/
2. Navigate to **Settings > API Keys**
3. Click **Create API Key**
4. Name it "TechConf" and select **Full Access**
5. Copy the API key immediately (you won't be able to see it again)
6. Save it securely - you'll need it for the deployment

#### 1.3 Configure Deployment Parameters
Edit `main.parameters.json` with your values:
```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "resourcePrefix": {
      "value": "techconf"
    },
    "postgresAdminUser": {
      "value": "techconfadmin"
    },
    "postgresAdminPassword": {
      "value": "YourSecurePassword123!"
    },
    "databaseName": {
      "value": "techconfdb"
    },
    "sendGridApiKey": {
      "value": "SG.your-sendgrid-api-key-here"
    },
    "adminEmailAddress": {
      "value": "your-email@example.com"
    }
  }
}
```

> **Security Note**: Never commit `main.parameters.json` with real credentials to Git. This file is already in `.gitignore`.

### Phase 2: Deploy Azure Resources (Infrastructure as Code)

#### 2.1 Deploy Using Bicep Template
The project includes a comprehensive Bicep template (`main.bicep`) that deploys all required Azure resources in one command.

```bash
# Make the deployment script executable
chmod +x deploy_bicep.sh

# Run the automated deployment
./deploy_bicep.sh
```

The deployment script will:
1. ✅ Verify Azure login
2. ✅ Create resource group in West Europe
3. ✅ Validate Bicep template syntax
4. ✅ Deploy all Azure resources:
   - PostgreSQL Flexible Server (Standard_B1ms, PostgreSQL 13)
   - Service Bus namespace with notification queue
   - Storage Account for Function App
   - App Service Plan (B1 Basic tier, Linux)
   - Web App with Python 3.11 runtime
   - Function App with Python 3.11 runtime
5. ✅ Configure all environment variables and connection strings
6. ✅ Save deployment outputs to `deployment-outputs.txt`

**Deployment time**: Approximately 10-15 minutes

#### 2.2 Verify Resource Deployment
```bash
# List all deployed resources
az resource list --resource-group techconf-rg --output table

# Expected resources:
# - techconf-db-* (PostgreSQL Flexible Server)
# - techconf-sb-* (Service Bus Namespace)
# - tcstore* (Storage Account)
# - techconf-plan-* (App Service Plan)
# - techconf-web-* (Web App)
# - techconf-func-* (Function App)
```

#### 2.3 Retrieve Deployment Information
```bash
# View deployment outputs
cat deployment-outputs.txt

# Or query specific values
az deployment group show \
  --resource-group techconf-rg \
  --name techconf-deployment-* \
  --query properties.outputs
```

**Save these values** - you'll need them for the next steps:
- Web App URL: `https://techconf-web-*.azurewebsites.net`
- Function App URL: `https://techconf-func-*.azurewebsites.net`
- PostgreSQL Server: `techconf-db-*.postgres.database.azure.com`

### Phase 3: Migrate Database (Restore Backup)

#### 3.1 Install PostgreSQL Client (if not already installed)
```bash
# For Ubuntu/Debian
sudo apt update && sudo apt install -y postgresql-client

# For macOS
brew install postgresql

# For Windows
# Download from https://www.postgresql.org/download/windows/
```

#### 3.2 Restore Database Backup to Azure
```bash
# Get your PostgreSQL server name from deployment outputs
POSTGRES_SERVER=$(cat deployment-outputs.txt | grep "PostgreSQL Server:" | cut -d' ' -f3)

# Or manually set it (replace with your actual server name)
POSTGRES_SERVER="techconf-db-xizeh6mypik36.postgres.database.azure.com"

# Restore the database backup
PGPASSWORD='SecurePass123!' psql \
  "host=${POSTGRES_SERVER} port=5432 dbname=techconfdb user=techconfadmin sslmode=require" \
  < data/techconfdb_backup.sql
```

**Expected output**:
```
SET
SET
SET
SET
SET
CREATE TABLE
ALTER TABLE
CREATE TABLE
ALTER TABLE
CREATE TABLE
ALTER TABLE
COPY 2
COPY 6
COPY 0
ALTER TABLE
ALTER TABLE
ALTER TABLE
```

#### 3.3 Verify Database Restoration
```bash
# Connect to the database and verify tables
PGPASSWORD='SecurePass123!' psql \
  "host=${POSTGRES_SERVER} port=5432 dbname=techconfdb user=techconfadmin sslmode=require" \
  -c "\dt" -c "SELECT COUNT(*) FROM attendee;" -c "SELECT COUNT(*) FROM conference;"
```

**Expected results**:
- 3 tables: `attendee`, `conference`, `notification`
- 6 attendees
- 2 conferences

### Phase 4: Deploy Web Application Code

#### 4.1 Deploy Web App Using Automated Script
```bash
# Make the deployment script executable
chmod +x deploy_webapp.sh

# Deploy the Flask application
./deploy_webapp.sh
```

The script will:
1. ✅ Create a deployment package with all application files
2. ✅ Configure startup script with gunicorn
3. ✅ Deploy to Azure Web App using zip deployment
4. ✅ Configure the startup command

**Deployment time**: Approximately 4-5 minutes

#### 4.2 Verify Web App Deployment
```bash
# Get the web app URL
WEB_APP_URL=$(cat deployment-outputs.txt | grep "Web App URL:" | cut -d' ' -f4)

# Test the web app
curl -I $WEB_APP_URL

# Expected: HTTP/1.1 200 OK
```

#### 4.3 Access the Web Application
Open your browser and navigate to the Web App URL shown in `deployment-outputs.txt`:
```
https://techconf-web-xizeh6mypik36.azurewebsites.net
```

**Verify the following pages load successfully**:
- ✅ Home page (/)
- ✅ Conference Registration (/Registration)
- ✅ Attendees list (/Attendees) - should show attendees from database
- ✅ Notifications (/Notifications) - should show notification history
- ✅ Send Notification (/Notification) - form to create new notifications

> **📸 Rubric Screenshot**: Take a **fullscreen screenshot** of the web app running with the URL visible in the browser (https://\*.azurewebsites.net)

### Phase 5: Deploy Azure Function (Background Notification Processing)

#### 5.1 Install Azure Functions Core Tools (if not installed)
```bash
# For Ubuntu/Debian
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'
sudo apt update
sudo apt install azure-functions-core-tools-4

# For macOS
brew tap azure/functions
brew install azure-functions-core-tools@4

# For Windows
# Download from https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local
```

#### 5.2 Deploy Function App
```bash
# Navigate to function directory
cd function

# Get Function App name from deployment outputs
FUNCTION_APP_NAME=$(az functionapp list --resource-group techconf-rg --query "[0].name" --output tsv)

# Deploy the function
func azure functionapp publish $FUNCTION_APP_NAME

# Expected output:
# Getting site publishing info...
# Uploading package...
# Upload completed successfully.
# Deployment completed successfully.
```

**Deployment time**: Approximately 2-3 minutes

#### 5.3 Verify Function Deployment
```bash
# List deployed functions
az functionapp function list \
  --resource-group techconf-rg \
  --name $FUNCTION_APP_NAME \
  --output table

# Check function app status
az functionapp show \
  --resource-group techconf-rg \
  --name $FUNCTION_APP_NAME \
  --query "{name:name, state:state, defaultHostName:defaultHostName}" \
  --output table
```

> **📸 Rubric Screenshot**: Take a screenshot of the Azure Function App in the Azure Portal showing the function name and consumption plan

### Phase 6: End-to-End Testing and Verification

#### 6.1 Test Complete Notification Flow

**Step 1: Submit a New Notification**
1. Navigate to your Web App URL: `https://techconf-web-*.azurewebsites.net`
2. Click on **"Notifications"** in the navigation menu
3. Click **"Submit New Notification"** button
4. Fill in the notification form:
   - **Subject**: "Welcome to TechConf 2025!"
   - **Message**: "Thank you for registering. We look forward to seeing you at the conference."
5. Click **"Submit"**

> **📸 Rubric Screenshot #1**: Take a screenshot showing the notification submission form with your filled-in details

**Step 2: Verify Notification Queued to Service Bus**
After submission, you should see:
- ✅ Success message: "Notification submitted successfully"
- ✅ Notification status: "Queued for processing"
- ✅ Submitted date populated

> **📸 Rubric Screenshot #2**: Take a screenshot of the Notifications list showing the new notification with "Queued for processing" status

**Step 3: Monitor Azure Function Processing**
```bash
# Stream function logs in real-time
FUNCTION_APP_NAME=$(az functionapp list --resource-group techconf-rg --query "[0].name" --output tsv)

# Watch function logs
az functionapp log tail --resource-group techconf-rg --name $FUNCTION_APP_NAME

# You should see logs showing:
# - Service Bus message received
# - Database query for attendees
# - Sending emails to each attendee
# - Notification status updated
```

**Step 4: Verify Notification Processed**
1. Refresh the Notifications page in your browser
2. Check the notification you just created

**Expected results**:
- ✅ **Status**: "Notified X attendees" (where X is the count from database)
- ✅ **Submitted date**: Populated with submission time
- ✅ **Completed date**: Populated with processing completion time
- ✅ **Total attendees notified**: Should match the count in the attendees table

> **📸 Rubric Screenshot #3**: Take a screenshot showing the completed notification with both submitted and completed dates, plus the attendee count

#### 6.2 Verify Database Integration

**Check Attendees List**:
1. Navigate to **"Attendees"** page
2. Verify attendees from the restored database are displayed

> **📸 Rubric Screenshot #4**: Take a fullscreen screenshot of the Attendees page showing the list of attendees loaded from Azure PostgreSQL

**Expected attendees** (from backup):
- First Name: John, Last Name: Smith
- First Name: Jane, Last Name: Doe
- First Name: Bob, Last Name: Johnson
- And others from the database backup

#### 6.3 Test Conference Registration (Optional)

1. Navigate to **"Conference Registration"**
2. Fill in the registration form with test data
3. Submit the form
4. Verify the new attendee appears in the **"Attendees"** list

This confirms:
- ✅ Web app can write to Azure PostgreSQL
- ✅ Database connection is working bidirectionally
- ✅ Form handling and data persistence are functional

### Phase 7: Azure Portal Screenshots for Rubric

#### 7.1 Required Screenshots for Project Submission

**Screenshot 1: App Service Plan**
- Navigate to Azure Portal → Resource Groups → techconf-rg
- Click on the App Service Plan (techconf-plan-*)
- Screenshot should show:
  - ✅ Resource name
  - ✅ Pricing tier (B1 - Basic)
  - ✅ Operating System (Linux)
  - ✅ Region (West Europe)

**Screenshot 2: PostgreSQL Database**
- Navigate to Azure Portal → Resource Groups → techconf-rg
- Click on the PostgreSQL server (techconf-db-*)
- Screenshot should show:
  - ✅ Server name (techconf-db-*.postgres.database.azure.com)
  - ✅ PostgreSQL version (13)
  - ✅ Compute + storage tier (Burstable, Standard_B1ms)
  - ✅ Database name (techconfdb)

**Screenshot 3: Azure Function App**
- Navigate to Azure Portal → Resource Groups → techconf-rg
- Click on the Function App (techconf-func-*)
- Screenshot should show:
  - ✅ Function App name
  - ✅ Status (Running)
  - ✅ App Service Plan (Consumption)
  - ✅ Runtime stack (Python 3.11)

**Screenshot 4: Web App Running**
- Open Web App URL in browser: https://techconf-web-*.azurewebsites.net
- Take **fullscreen screenshot** showing:
  - ✅ Full URL in address bar (https://\*.azurewebsites.net)
  - ✅ Application homepage loaded successfully
  - ✅ Navigation menu visible
  - ✅ No errors on the page

**Screenshot 5: Attendees Loaded from Database**
- Navigate to Attendees page
- Screenshot should show:
  - ✅ List of attendees displayed
  - ✅ URL visible showing it's from Azure Web App
  - ✅ Data from PostgreSQL database

**Screenshot 6: Notification Submission**
- Navigate to Send Notification page
- Fill in a test notification
- Screenshot the form before submission

**Screenshot 7: Notification Processing Complete**
- After submitting notification and waiting for Azure Function to process
- Screenshot the Notifications list showing:
  - ✅ Notification with "Notified X attendees" status
  - ✅ Both submitted and completed dates visible
  - ✅ Total attendee count shown

### Phase 8: Cost Analysis and Documentation

#### 8.1 Verify Monthly Costs in Azure Portal

1. Navigate to **Cost Management + Billing** in Azure Portal
2. Select **Cost Analysis**
3. Filter by Resource Group: **techconf-rg**
4. View estimated monthly costs

**Expected cost breakdown**:
```
App Service (B1):                  ~$13/month
PostgreSQL Flexible (Standard_B1ms): ~$25/month
Service Bus (Standard):            ~$10/month
Function App (Consumption):        ~$0-5/month
Storage Account (Standard_LRS):    ~$2/month
──────────────────────────────────────────────
Total:                             ~$50-55/month
```

#### 8.2 Architecture Documentation Checklist

Ensure your README.md includes:
- ✅ Clear explanation of why Azure Web App was chosen (cost-effective for web hosting)
- ✅ Clear explanation of why Azure Functions was chosen (event-driven, pay-per-execution)
- ✅ Purpose of each Azure resource used
- ✅ Monthly cost estimate for each resource
- ✅ Justification for each pricing tier selected
- ✅ Total estimated monthly cost

### Phase 9: Cleanup (After Project Submission)

⚠️ **Warning**: Only perform cleanup after your project has been graded and you no longer need the resources.

```bash
# Delete all Azure resources
az group delete --name techconf-rg --yes --no-wait

# This will delete:
# - Web App
# - Function App
# - App Service Plan
# - PostgreSQL Database (including all data)
# - Service Bus Namespace and Queue
# - Storage Account

# Verify deletion (after a few minutes)
az group exists --name techconf-rg
# Should return: false
```

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: Bicep Deployment Fails

**Symptoms**:
- Deployment returns "Failed" status
- Error message: "LocationIsOfferRestricted" for PostgreSQL

**Solution**:
```bash
# The deployment script uses West Europe by default
# If West Europe has restrictions, try another region:

# Edit deploy_bicep.sh and change LOCATION
nano deploy_bicep.sh
# Change: LOCATION="westeurope"
# To: LOCATION="westus2"  # or "northeurope", "uksouth"

# Delete failed resource group and retry
az group delete --name techconf-rg --yes --no-wait
./deploy_bicep.sh
```

#### Issue 2: PostgreSQL Connection Failures

**Symptoms**:
- Web app shows 500 error
- Error in logs: "could not connect to server"
- Database restore fails with connection timeout

**Solutions**:

**Check 1: Verify firewall rules**
```bash
az postgres flexible-server firewall-rule list \
  --resource-group techconf-rg \
  --name <your-postgres-server-name> \
  --output table

# Should show: AllowAllAzureIPs and AllowAllIPs
```

**Check 2: Test connection manually**
```bash
# Replace with your actual values
PGPASSWORD='SecurePass123!' psql \
  "host=techconf-db-*.postgres.database.azure.com port=5432 dbname=techconfdb user=techconfadmin sslmode=require" \
  -c "SELECT version();"

# Should return PostgreSQL version
```

**Check 3: Verify connection string in app settings**
```bash
az webapp config appsettings list \
  --resource-group techconf-rg \
  --name <your-webapp-name> \
  --query "[?name=='POSTGRES_URL'].value" \
  --output tsv

# Should return: techconf-db-*.postgres.database.azure.com
```

#### Issue 3: Web App Shows 503 Error

**Symptoms**:
- Browser shows "Service Unavailable"
- `curl` returns HTTP 503

**Solutions**:

**Check 1: Verify app is running**
```bash
az webapp show \
  --resource-group techconf-rg \
  --name <your-webapp-name> \
  --query state

# Should return: "Running"
```

**Check 2: Check application logs**
```bash
# Enable logging
az webapp log config \
  --resource-group techconf-rg \
  --name <your-webapp-name> \
  --application-logging filesystem \
  --level information

# View logs
az webapp log tail --resource-group techconf-rg --name <your-webapp-name>
```

**Check 3: Restart the app**
```bash
az webapp restart --resource-group techconf-rg --name <your-webapp-name>

# Wait 2-3 minutes for startup
sleep 180

# Test again
curl -I https://<your-webapp-name>.azurewebsites.net
```

**Check 4: Missing dependencies**
```bash
# Verify requirements.txt was deployed
az webapp deploy --resource-group techconf-rg \
  --name <your-webapp-name> \
  --type static \
  --src-path web/requirements.txt \
  --target-path /home/site/wwwroot/requirements.txt
```

#### Issue 4: Azure Function Not Triggering

**Symptoms**:
- Notifications stay in "Queued for processing" status
- Completed date never gets populated
- No emails sent to attendees

**Solutions**:

**Check 1: Verify function deployment**
```bash
# List functions
az functionapp function list \
  --resource-group techconf-rg \
  --name <your-function-app-name> \
  --output table

# Should show: ServiceBusQueueTrigger function
```

**Check 2: Check Service Bus connection**
```bash
# Verify app setting
az functionapp config appsettings list \
  --resource-group techconf-rg \
  --name <your-function-app-name> \
  --query "[?name=='SERVICE_BUS_CONNECTION_STRING'].value"

# Should return a connection string starting with "Endpoint=sb://"
```

**Check 3: Check Service Bus queue for messages**
```bash
# Check queue message count
az servicebus queue show \
  --resource-group techconf-rg \
  --namespace-name <your-servicebus-namespace> \
  --name notificationqueue \
  --query "{ActiveMessages:countDetails.activeMessageCount, DeadLetter:countDetails.deadLetterMessageCount}"

# If ActiveMessages > 0 and function isn't processing, there's an issue
# If DeadLetter > 0, messages failed processing
```

**Check 4: View function logs**
```bash
# Stream function logs
func azure functionapp logstream <your-function-app-name>

# Or use Azure CLI
az webapp log tail --resource-group techconf-rg --name <your-function-app-name>
```

**Check 5: Manually trigger a test**
```bash
# Send a test notification through the web app
# Then immediately check function logs to see if it's picked up
```

#### Issue 5: SendGrid Emails Not Sending

**Symptoms**:
- Function completes successfully
- Notification status updates
- But no emails received

**Solutions**:

**Check 1: Verify SendGrid API key**
```bash
# Test SendGrid API key
curl -X POST https://api.sendgrid.com/v3/mail/send \
  -H "Authorization: Bearer YOUR_SENDGRID_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "personalizations": [{"to": [{"email": "test@example.com"}]}],
    "from": {"email": "noreply@techconf.com"},
    "subject": "Test",
    "content": [{"type": "text/plain", "value": "Test"}]
  }'

# Should return HTTP 202 (Accepted)
```

**Check 2: Verify API key in function settings**
```bash
az functionapp config appsettings list \
  --resource-group techconf-rg \
  --name <your-function-app-name> \
  --query "[?name=='SENDGRID_API_KEY'].value"

# Should return your SendGrid API key
```

**Check 3: Check SendGrid dashboard**
- Login to SendGrid dashboard
- Navigate to Activity Feed
- Check for bounced or failed emails
- Verify sender email is configured

#### Issue 6: Database Backup Restore Fails

**Symptoms**:
- `psql` command fails
- Error: "psql: command not found"
- Connection timeout

**Solutions**:

**Check 1: Install PostgreSQL client**
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y postgresql-client

# macOS
brew install postgresql

# Verify installation
psql --version
```

**Check 2: Use Docker container for restore** (Alternative)
```bash
# Run psql in Docker container
docker run --rm -i \
  -e PGPASSWORD='SecurePass123!' \
  postgres:13 \
  psql \
  "host=techconf-db-*.postgres.database.azure.com port=5432 dbname=techconfdb user=techconfadmin sslmode=require" \
  < data/techconfdb_backup.sql
```

**Check 3: Restore via Azure Cloud Shell**
```bash
# Open Azure Cloud Shell in browser
# Upload techconfdb_backup.sql
# Run restore command
```

## Security Best Practices

### Secrets Management
✅ **Implemented**:
- All sensitive credentials stored in Azure App Settings (encrypted at rest)
- `.gitignore` configured to exclude `.env` and `main.parameters.json`
- Environment variables loaded at runtime (not hardcoded)

🔐 **Recommendations for Production**:
- Migrate to **Azure Key Vault** for centralized secret management
- Enable **Managed Identity** for passwordless authentication to PostgreSQL
- Implement secret rotation policies (30-90 days)
- Use **Azure App Configuration** for non-secret settings

### Network Security
✅ **Current Configuration** (Development):
- PostgreSQL firewall allows Azure services and all IPs
- HTTPS enforced for all web traffic (TLS 1.2 minimum)
- App Service uses system-assigned identity

🔒 **Recommendations for Production**:
```bash
# Restrict PostgreSQL to specific IPs only
az postgres flexible-server firewall-rule delete \
  --resource-group techconf-rg \
  --name <server-name> \
  --rule-name AllowAllIPs

# Add specific IP ranges instead
az postgres flexible-server firewall-rule create \
  --resource-group techconf-rg \
  --name <server-name> \
  --rule-name AllowOfficeNetwork \
  --start-ip-address 203.0.113.0 \
  --end-ip-address 203.0.113.255

# Enable Virtual Network integration
az webapp vnet-integration add \
  --resource-group techconf-rg \
  --name <webapp-name> \
  --vnet <vnet-name> \
  --subnet <subnet-name>
```

### Access Control
✅ **Current Setup**:
- Resource-level access via Azure RBAC
- PostgreSQL uses username/password authentication
- Service Bus uses connection string authentication

🔑 **Recommendations for Production**:
- Enable **Azure AD authentication** for PostgreSQL
- Use **Managed Service Identity (MSI)** for app-to-service communication
- Implement **least privilege access** (separate read/write roles)
- Enable **Azure AD integration** for web app authentication

## Monitoring and Logging

### Application Insights Setup (Optional)
```bash
# Create Application Insights resource
az monitor app-insights component create \
  --app techconf-insights \
  --location westeurope \
  --resource-group techconf-rg \
  --application-type web

# Get instrumentation key
INSTRUMENTATION_KEY=$(az monitor app-insights component show \
  --app techconf-insights \
  --resource-group techconf-rg \
  --query instrumentationKey \
  --output tsv)

# Configure Web App
az webapp config appsettings set \
  --resource-group techconf-rg \
  --name <webapp-name> \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY=$INSTRUMENTATION_KEY

# Configure Function App
az functionapp config appsettings set \
  --resource-group techconf-rg \
  --name <function-app-name> \
  --settings APPINSIGHTS_INSTRUMENTATIONKEY=$INSTRUMENTATION_KEY
```

### Key Metrics to Monitor
1. **Web App**:
   - HTTP 5xx errors (server errors)
   - Response time (should be < 2 seconds)
   - Request rate (requests per minute)
   - CPU/Memory usage (should be < 80%)

2. **Function App**:
   - Execution count (total invocations)
   - Execution duration (processing time)
   - Failure rate (should be < 1%)
   - Service Bus queue depth (should drain to 0)

3. **PostgreSQL**:
   - Connection count (should be < max connections)
   - CPU percentage (should be < 80%)
   - Storage percentage (should be < 80%)
   - Failed connection rate

4. **Service Bus**:
   - Active message count (should drain quickly)
   - Dead-letter message count (should be 0)
   - Incoming/Outgoing messages per second

### Setting Up Alerts
```bash
# Example: Alert on high error rate
az monitor metrics alert create \
  --name HighErrorRate \
  --resource-group techconf-rg \
  --scopes /subscriptions/<sub-id>/resourceGroups/techconf-rg/providers/Microsoft.Web/sites/<webapp-name> \
  --condition "count requests/failed > 10" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action <action-group-id>
```

## Cost Optimization Strategies

### Current Cost Breakdown (Monthly)
```
Resource                          Tier                  Cost      Optimization Potential
─────────────────────────────────────────────────────────────────────────────────────────
App Service Plan (B1)             Basic (1 Core)        $13       ✓ Switch to Free tier for dev
PostgreSQL Flexible (B1ms)        Burstable (1 vCore)   $25       ✓ Stop when not in use
Service Bus (Standard)            Standard tier         $10       ✗ Required for features
Azure Functions (Consumption)     Pay-per-execution     $0-5      ✓ Already optimized
Storage Account (Standard_LRS)    Locally Redundant     $2        ✓ Already optimized
─────────────────────────────────────────────────────────────────────────────────────────
Total                                                   $50-55/mo
```

### Optimization Strategies

**1. Development/Testing Environment**
```bash
# Stop PostgreSQL when not in use (saves ~$25/month)
az postgres flexible-server stop \
  --resource-group techconf-rg \
  --name <server-name>

# Start when needed
az postgres flexible-server start \
  --resource-group techconf-rg \
  --name <server-name>

# Downgrade to Free tier App Service for dev (saves ~$13/month)
az appservice plan update \
  --resource-group techconf-rg \
  --name <plan-name> \
  --sku FREE
```

**2. Auto-Scaling for Production**
```bash
# Enable auto-scaling (scale out during high traffic)
az monitor autoscale create \
  --resource-group techconf-rg \
  --resource <app-service-plan-id> \
  --min-count 1 \
  --max-count 3 \
  --count 1

# Add scale-out rule (CPU > 70%)
az monitor autoscale rule create \
  --resource-group techconf-rg \
  --autoscale-name <autoscale-name> \
  --condition "Percentage CPU > 70 avg 5m" \
  --scale out 1
```

**3. Reserved Instances (Production)**
- Save up to 40% on App Service by purchasing 1-year reserved capacity
- Save up to 55% on PostgreSQL with 1-year commitment
- Only recommended for production workloads with predictable usage

**4. Resource Tagging for Cost Tracking**
```bash
# Tag resources by environment
az resource tag \
  --resource-group techconf-rg \
  --ids <resource-id> \
  --tags Environment=Development Project=TechConf Owner=YourName

# View costs by tag in Cost Management
```

## Production Deployment Checklist

Before deploying to production, ensure:

### Security
- [ ] Secrets moved to Azure Key Vault
- [ ] Managed Identity enabled for app services
- [ ] PostgreSQL firewall restricted to specific IPs/VNets
- [ ] Azure AD authentication configured
- [ ] TLS 1.2+ enforced on all services
- [ ] Diagnostic logging enabled

### Performance
- [ ] Application Insights configured
- [ ] Auto-scaling rules defined
- [ ] Database indexes optimized
- [ ] CDN configured for static assets
- [ ] Connection pooling enabled

### Reliability
- [ ] Health check endpoints implemented
- [ ] Dead-letter queue monitoring configured
- [ ] Backup policy configured for PostgreSQL
- [ ] Disaster recovery plan documented
- [ ] Deployment slots configured for zero-downtime updates

### Compliance
- [ ] Data retention policies defined
- [ ] GDPR compliance verified (if applicable)
- [ ] Access audit logs enabled
- [ ] Cost alerts configured
- [ ] Resource locks applied to prevent accidental deletion

## Additional Resources

- **Azure App Service Documentation**: https://docs.microsoft.com/azure/app-service/
- **Azure Functions Documentation**: https://docs.microsoft.com/azure/azure-functions/
- **Azure PostgreSQL Documentation**: https://docs.microsoft.com/azure/postgresql/
- **Azure Service Bus Documentation**: https://docs.microsoft.com/azure/service-bus-messaging/
- **Bicep Documentation**: https://docs.microsoft.com/azure/azure-resource-manager/bicep/
- **Azure Cost Management**: https://docs.microsoft.com/azure/cost-management-billing/
- **Azure Security Best Practices**: https://docs.microsoft.com/azure/security/fundamentals/best-practices-and-patterns

## Support

If you encounter issues not covered in this guide:
1. Check Azure Service Health for outages
2. Review Azure Monitor logs for your resources
3. Consult Azure documentation for specific services
4. Contact Azure Support if needed

---

**Deployment Guide Version**: 2.0  
**Last Updated**: November 18, 2025  
**Python Version**: 3.11  
**Azure CLI Version**: 2.80.0+  
**Region**: West Europe (westeurope)
