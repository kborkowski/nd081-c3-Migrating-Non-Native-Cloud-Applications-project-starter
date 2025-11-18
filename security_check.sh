#!/bin/bash

# Security Check Script
# Verifies that no sensitive information is being committed to git

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "Security Check"
echo "======================================"
echo ""

# Check if .env file exists
if [ -f .env ]; then
    echo -e "${GREEN}[✓]${NC} .env file exists"
else
    echo -e "${YELLOW}[!]${NC} .env file not found"
fi

# Check if .env is in .gitignore
if grep -q "^\.env$" .gitignore 2>/dev/null || grep -q "^\.env$" web/.gitignore 2>/dev/null; then
    echo -e "${GREEN}[✓]${NC} .env is in .gitignore"
else
    echo -e "${RED}[✗]${NC} .env is NOT in .gitignore - SECURITY RISK!"
    exit 1
fi

# Check if .env is tracked by git
if git ls-files --error-unmatch .env >/dev/null 2>&1; then
    echo -e "${RED}[✗]${NC} .env is tracked by git - REMOVE IT IMMEDIATELY!"
    echo "Run: git rm --cached .env"
    exit 1
else
    echo -e "${GREEN}[✓]${NC} .env is not tracked by git"
fi

# Check for passwords in code files
echo ""
echo "Checking for potential hardcoded secrets..."

SUSPICIOUS_FILES=$(git diff --cached --name-only | grep -E '\.(py|js|json|yaml|yml)$' || true)

if [ -n "$SUSPICIOUS_FILES" ]; then
    for file in $SUSPICIOUS_FILES; do
        if [ -f "$file" ]; then
            # Check for potential passwords
            if grep -iE '(password|secret|key|token).*=.*["\'].[^"\']+["\']' "$file" | grep -vE '(getenv|environ|ENV)' | grep -v '#' > /dev/null; then
                echo -e "${YELLOW}[!]${NC} Potential hardcoded secret in: $file"
                echo "    Please verify this is not sensitive information"
            fi
        fi
    done
fi

# Check for Azure credentials
if git diff --cached | grep -iE '(odl_user|@udacityhol|=R3=MN=Y)' > /dev/null; then
    echo -e "${RED}[✗]${NC} Azure credentials detected in staged changes!"
    echo "Do NOT commit these credentials!"
    exit 1
else
    echo -e "${GREEN}[✓]${NC} No Azure credentials detected in staged changes"
fi

# Check for connection strings
if git diff --cached | grep -iE 'Endpoint=sb://|Server=.*\.postgres' > /dev/null; then
    echo -e "${YELLOW}[!]${NC} Connection string detected in staged changes"
    echo "Please verify these are not production credentials"
fi

echo ""
echo -e "${GREEN}======================================"
echo "Security check complete!"
echo -e "======================================${NC}"
echo ""
echo "Safe to commit if all checks passed."
echo ""
