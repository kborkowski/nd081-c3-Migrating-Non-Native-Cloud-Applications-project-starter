# TechConf Quick Reference Guide

## 🔐 Security - IMPORTANT

### Your Azure Credentials (NEVER commit these!)
- **Username**: `odl_user_290152@udacityhol.onmicrosoft.com`
- **Password**: `=R3=MN=Y`
- **Stored in**: `.env` (automatically excluded from git)

### Security Checklist
- [x] `.env` file contains all secrets
- [x] `.env` is in `.gitignore`
- [x] `.env` is NOT tracked by git
- [x] Run `./security_check.sh` before committing

## 🚀 Quick Start Commands

### 1. Login to Azure
```bash
./azure_login.sh
```

### 2. Setup Local Environment
```bash
./setup_local_env.sh
```

### 3. Test Locally
```bash
cd web
source venv/bin/activate
python application.py
# Visit: http://localhost:5000
```

### 4. Deploy to Azure
```bash
./deploy_to_azure.sh
```

## 📁 File Structure

```
.
├── .env                    # 🔒 SECRETS (never commit!)
├── .env.template           # Template for .env
├── .gitignore              # Protects sensitive files
├── azure_login.sh          # Login to Azure
├── deploy_to_azure.sh      # Automated deployment
├── setup_local_env.sh      # Local environment setup
├── security_check.sh       # Check for leaked secrets
│
├── web/                    # Flask web application
│   ├── config.py           # Uses environment variables
│   ├── requirements.txt    # Updated dependencies
│   └── app/
│       ├── __init__.py     # Updated for new Azure SDK
│       ├── routes.py       # Needs refactoring
│       └── models.py
│
├── function/               # Azure Function
│   ├── __init__.py         # Service Bus trigger
│   ├── function.json       # Function binding
│   ├── host.json           # Function configuration
│   └── requirements.txt    # Function dependencies
│
└── data/
    └── techconfdb_backup.sql  # Database backup
```

## 🔧 Configuration

### Environment Variables (.env)
```bash
# Azure Credentials
AZURE_USERNAME=odl_user_290152@udacityhol.onmicrosoft.com
AZURE_TEMP_PASSWORD==R3=MN=Y

# Local Database
POSTGRES_URL=localhost
POSTGRES_USER=postgres
POSTGRES_PW=postgres123
POSTGRES_DB=techconfdb

# Azure Resources (filled after deployment)
SERVICE_BUS_CONNECTION_STRING=<after-deployment>
AZURE_POSTGRES_URL=<after-deployment>
```

## 📋 Deployment Checklist

### Before Deployment
- [ ] Logged into Azure (`./azure_login.sh`)
- [ ] Tested locally (`./setup_local_env.sh`)
- [ ] Updated dependencies installed
- [ ] All secrets in `.env`
- [ ] Security check passed (`./security_check.sh`)

### Deployment Steps
1. **Login**: `./azure_login.sh`
2. **Deploy**: `./deploy_to_azure.sh`
3. **Wait**: 10-15 minutes for resource creation
4. **Deploy Code**:
   ```bash
   # Web App
   cd web
   zip -r ../web.zip .
   az webapp deployment source config-zip \
     --resource-group techconf-rg \
     --name <web-app-name> \
     --src ../web.zip
   
   # Function App
   cd ../function
   func azure functionapp publish <function-app-name>
   ```

### After Deployment
- [ ] Web app accessible at Azure URL
- [ ] Database restored successfully
- [ ] Service Bus queue created
- [ ] Function app deployed
- [ ] Test notification flow

## 🛠️ Common Commands

### Azure CLI
```bash
# List subscriptions
az account list --output table

# List resource groups
az group list --output table

# List resources in a group
az resource list --resource-group techconf-rg --output table

# Stream logs
az webapp log tail --resource-group techconf-rg --name <web-app-name>
```

### Database
```bash
# Connect to local PostgreSQL
docker exec -it techconf-postgres psql -U postgres -d techconfdb

# View tables
\dt

# View attendees
SELECT * FROM attendee;

# View notifications
SELECT * FROM notification;
```

### Git Safety
```bash
# Before committing, run security check
./security_check.sh

# Check what will be committed
git status

# Verify .env is ignored
git check-ignore .env
```

## 🔍 Troubleshooting

### "Cannot login to Azure"
- Check username and password in `.env`
- Try interactive login: `az login`
- Check internet connection

### "Dependencies fail to install"
- Using Python 3.12, updated dependencies should work
- Check: `python3 --version`
- Activate venv: `source web/venv/bin/activate`

### "Database connection failed"
- Local: Ensure Docker container is running
- Azure: Check firewall rules
- Verify connection string in `.env`

### ".env file is tracked by git"
- Remove it: `git rm --cached .env`
- Verify: `git status`
- Never commit it again!

## 📞 Resources

- **Documentation**: See `DEPLOYMENT_GUIDE.md` for detailed steps
- **Architecture**: See `README.md` for architecture explanation
- **Status**: See `PROJECT_STATUS.md` for current status
- **Local Setup**: See `LOCAL_SETUP.md` for local testing

## ⚠️ Important Reminders

1. **NEVER commit `.env` file**
2. **Always run `./security_check.sh` before committing**
3. **Change default passwords in production**
4. **Restrict database firewall in production**
5. **Use Azure Key Vault for production secrets**

## 🎯 Current Status

✅ **Completed**:
- Architecture designed
- Azure Function implemented
- Dependencies updated to latest versions
- Security configured (.gitignore, .env)
- Automation scripts created

⚠️ **Pending**:
- Refactor `web/app/routes.py` notification function
- Login to Azure
- Deploy to Azure
- Test end-to-end flow

---

**Need Help?** Review the full documentation in `DEPLOYMENT_GUIDE.md` and `PROJECT_STATUS.md`
