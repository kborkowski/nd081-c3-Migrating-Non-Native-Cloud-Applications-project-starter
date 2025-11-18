#!/bin/bash

# TechConf Local Testing Script
# This script sets up a complete local testing environment

set -e  # Exit on error

echo "======================================"
echo "TechConf Local Testing Setup"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
POSTGRES_CONTAINER="techconf-postgres"
POSTGRES_PASSWORD="postgres123"
POSTGRES_USER="postgres"
POSTGRES_DB="techconfdb"
POSTGRES_PORT="5432"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

# Check prerequisites
echo ""
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi
print_status "Docker is installed"

if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install Python 3 first."
    exit 1
fi
print_status "Python 3 is installed ($(python3 --version))"

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${POSTGRES_CONTAINER}$"; then
    print_info "PostgreSQL container already exists. Stopping and removing..."
    docker stop $POSTGRES_CONTAINER 2>/dev/null || true
    docker rm $POSTGRES_CONTAINER 2>/dev/null || true
fi

# Start PostgreSQL
echo ""
echo "Starting PostgreSQL database..."
docker run --name $POSTGRES_CONTAINER \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    -e POSTGRES_USER=$POSTGRES_USER \
    -e POSTGRES_DB=$POSTGRES_DB \
    -p $POSTGRES_PORT:5432 \
    -d postgres:12

print_status "PostgreSQL container started"

# Wait for PostgreSQL to be ready
echo ""
echo "Waiting for PostgreSQL to be ready..."
sleep 10

# Test connection
if docker exec $POSTGRES_CONTAINER pg_isready -U $POSTGRES_USER > /dev/null 2>&1; then
    print_status "PostgreSQL is ready"
else
    print_error "PostgreSQL failed to start properly"
    exit 1
fi

# Restore database
echo ""
echo "Restoring database backup..."
docker cp data/techconfdb_backup.sql $POSTGRES_CONTAINER:/tmp/
docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -f /tmp/techconfdb_backup.sql > /dev/null 2>&1
print_status "Database restored successfully"

# Verify tables
echo ""
echo "Verifying database tables..."
TABLES=$(docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';")
print_status "Found $TABLES tables in database"

# Check for sample data
CONFERENCE_COUNT=$(docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM conference;" | tr -d ' ')
ATTENDEE_COUNT=$(docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT COUNT(*) FROM attendee;" | tr -d ' ')
print_status "Database contains: $CONFERENCE_COUNT conferences, $ATTENDEE_COUNT attendees"

# Create .env file for web app
echo ""
echo "Creating environment configuration..."
cat > web/.env << EOF
# Database Configuration
POSTGRES_URL=localhost
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PW=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB

# Service Bus (empty for local testing)
SERVICE_BUS_CONNECTION_STRING=

# SendGrid (optional)
SENDGRID_API_KEY=
EOF
print_status "Created web/.env file"

# Check if virtual environment exists
if [ ! -d "web/venv" ]; then
    echo ""
    echo "Creating Python virtual environment..."
    cd web
    python3 -m venv venv
    print_status "Virtual environment created"
    cd ..
fi

# Install dependencies
echo ""
echo "Installing Python dependencies..."
cd web
source venv/bin/activate
pip install -q -r requirements.txt
print_status "Dependencies installed"
cd ..

# Print connection info
echo ""
echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
print_info "Database Connection:"
echo "    Host: localhost"
echo "    Port: $POSTGRES_PORT"
echo "    Database: $POSTGRES_DB"
echo "    User: $POSTGRES_USER"
echo "    Password: $POSTGRES_PASSWORD"
echo ""
print_info "To start the web application:"
echo "    cd web"
echo "    source venv/bin/activate"
echo "    python application.py"
echo ""
print_info "To stop and cleanup:"
echo "    docker stop $POSTGRES_CONTAINER"
echo "    docker rm $POSTGRES_CONTAINER"
echo ""
print_info "Database management commands:"
echo "    # Connect to database"
echo "    docker exec -it $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB"
echo ""
echo "    # View tables"
echo "    docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -c '\dt'"
echo ""
echo "    # View attendees"
echo "    docker exec $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $POSTGRES_DB -c 'SELECT * FROM attendee;'"
echo ""
echo "======================================"
