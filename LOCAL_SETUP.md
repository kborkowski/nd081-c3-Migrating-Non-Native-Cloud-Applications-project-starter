# Local Development Setup

## Prerequisites
- Python 3.8+
- Docker (for local PostgreSQL)
- Azure CLI (for deployment)
- Azure Functions Core Tools V3+

## Local Testing Steps

### 1. Start PostgreSQL Database
```bash
# Start PostgreSQL in Docker
docker run --name techconf-postgres \
  -e POSTGRES_PASSWORD=postgres123 \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=techconfdb \
  -p 5432:5432 \
  -d postgres:12

# Wait for PostgreSQL to start (about 10 seconds)
sleep 10

# Restore the database backup
docker cp data/techconfdb_backup.sql techconf-postgres:/tmp/
docker exec techconf-postgres psql -U postgres -d techconfdb -f /tmp/techconfdb_backup.sql
```

### 2. Configure Environment Variables

Create a `.env` file in the `web` directory:
```bash
# Database Configuration
POSTGRES_URL=localhost
POSTGRES_USER=postgres
POSTGRES_PW=postgres123
POSTGRES_DB=techconfdb

# Service Bus (leave empty for local testing without Azure)
SERVICE_BUS_CONNECTION_STRING=

# SendGrid (optional for local testing)
SENDGRID_API_KEY=
```

### 3. Install Python Dependencies
```bash
cd web
pip install -r requirements.txt
```

### 4. Run the Web Application
```bash
cd web
python application.py
```

The application should be available at http://localhost:5000

### 5. Test Database Connection
```bash
# Verify tables exist
docker exec -it techconf-postgres psql -U postgres -d techconfdb -c "\dt"

# Check sample data
docker exec -it techconf-postgres psql -U postgres -d techconfdb -c "SELECT * FROM conference;"
```

### 6. Cleanup
```bash
# Stop and remove the container
docker stop techconf-postgres
docker rm techconf-postgres
```

## Testing the Azure Function Locally

### 1. Install Azure Functions Core Tools
Follow instructions at: https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local

### 2. Install Function Dependencies
```bash
cd function
pip install -r requirements.txt
```

### 3. Configure local.settings.json
Create `function/local.settings.json`:
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "SERVICE_BUS_CONNECTION_STRING": "<your-servicebus-connection-string>",
    "POSTGRES_URL": "localhost",
    "POSTGRES_USER": "postgres",
    "POSTGRES_PW": "postgres123",
    "POSTGRES_DB": "techconfdb",
    "ADMIN_EMAIL_ADDRESS": "info@techconf.com",
    "SENDGRID_API_KEY": "YOUR_SENDGRID_API_KEY"
  }
}
```

### 4. Run the Function Locally
```bash
cd function
func start
```

## Known Issues
- The app currently uses `azure-servicebus==0.50.2` which is deprecated. For production, consider upgrading to `azure-servicebus>=7.0.0`
- `psycopg2==2.8.5` may have compatibility issues; use `psycopg2-binary` for Azure Functions
