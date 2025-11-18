# Pre-Deployment Checklist

## Overview
This checklist ensures the application is fully functional and ready for Azure deployment.

## Local Testing Checklist

### Environment Setup
- [ ] Docker installed and running
- [ ] Python 3.8+ installed
- [ ] PostgreSQL container running
- [ ] Database backup restored successfully
- [ ] Virtual environment created
- [ ] All Python dependencies installed

### Database Verification
- [ ] All tables created (attendee, conference, notification)
- [ ] Sample data loaded
- [ ] Database connections working
- [ ] Queries executing successfully

### Web Application Testing
- [ ] Application starts without errors
- [ ] Homepage loads correctly (/)
- [ ] Registration page accessible (/Registration)
- [ ] Can submit new attendee registration
- [ ] Attendees list displays (/Attendees)
- [ ] Notification creation page works (/Notification)
- [ ] Notifications list displays (/Notifications)

### Code Quality Checks
- [ ] No syntax errors in Python files
- [ ] All imports resolve correctly
- [ ] Configuration file properly formatted
- [ ] No hardcoded credentials
- [ ] Logging configured properly

### Azure Function Verification
- [ ] function.json created and configured
- [ ] __init__.py implements all required logic
- [ ] requirements.txt includes all dependencies
- [ ] host.json properly configured
- [ ] Function can connect to database
- [ ] Email sending logic implemented

### Security Review
- [ ] Passwords not committed to git
- [ ] Connection strings use environment variables
- [ ] .env file in .gitignore
- [ ] Secrets management plan documented
- [ ] Database firewall rules planned

## Azure Prerequisites Checklist

### Azure Account Setup
- [ ] Azure subscription active
- [ ] Sufficient credits/budget allocated
- [ ] Azure CLI installed locally
- [ ] Logged in to Azure CLI (`az login`)
- [ ] Correct subscription selected

### Azure Resources Planning
- [ ] Resource group name decided
- [ ] Azure region selected
- [ ] Resource naming convention defined
- [ ] Tags strategy documented

### Service Configuration
- [ ] PostgreSQL server name available
- [ ] Web app name available (globally unique)
- [ ] Function app name available (globally unique)
- [ ] Storage account name available (globally unique)
- [ ] Service Bus namespace name available

### Credentials & Secrets
- [ ] PostgreSQL admin password generated
- [ ] SendGrid API key obtained (optional)
- [ ] Connection strings documented securely
- [ ] Secrets storage plan (Key Vault)

## Deployment Readiness Checklist

### Documentation
- [ ] README.md reviewed and complete
- [ ] Architecture documented
- [ ] Cost analysis completed
- [ ] Deployment guide reviewed
- [ ] Local setup guide tested

### Code Preparation
- [ ] All TODOs in code addressed
- [ ] Config.py updated with placeholders
- [ ] requirements.txt verified
- [ ] .gitignore includes sensitive files
- [ ] No debugging code in production files

### Testing Plan
- [ ] Test scenarios documented
- [ ] Expected outcomes defined
- [ ] Rollback plan documented
- [ ] Monitoring plan established

### Notification Refactoring
- [ ] Service Bus queue client configured
- [ ] routes.py refactored to use queue
- [ ] Azure Function tested locally
- [ ] End-to-end flow documented

## Post-Deployment Verification

### Infrastructure
- [ ] All Azure resources created
- [ ] Resource group contains all services
- [ ] Network connectivity verified
- [ ] Firewall rules configured

### Web Application
- [ ] Web app deployed successfully
- [ ] Application settings configured
- [ ] Database connection successful
- [ ] Service Bus connection successful
- [ ] Homepage accessible via Azure URL

### Azure Function
- [ ] Function app deployed
- [ ] Function visible in portal
- [ ] Environment variables set
- [ ] Service Bus trigger configured
- [ ] Function logs accessible

### Integration Testing
- [ ] Submit test attendee registration
- [ ] Verify data in database
- [ ] Create test notification
- [ ] Verify message in Service Bus queue
- [ ] Verify function processes message
- [ ] Verify notification status updated
- [ ] Check email logs (if SendGrid configured)

### Monitoring
- [ ] Application Insights enabled
- [ ] Logs streaming successfully
- [ ] Alerts configured
- [ ] Metrics visible in portal

## Known Issues & Limitations

### Current Implementation
1. **Azure Service Bus Library Version**
   - Using deprecated `azure-servicebus==0.50.2`
   - Consider upgrading to `azure-servicebus>=7.0.0` for production
   - API changes required for upgrade

2. **SendGrid Configuration**
   - Optional for testing
   - Required for actual email delivery
   - Needs API key from SendGrid account

3. **Database Performance**
   - Basic tier suitable for development
   - May need scaling for production load
   - Connection pooling not implemented

4. **Error Handling**
   - Basic error handling in place
   - Enhanced retry logic recommended
   - Dead letter queue handling needed

### Security Considerations
1. **Database Access**
   - "Allow all IPs" rule for testing only
   - Must restrict in production
   - Consider VNet integration

2. **Secrets Management**
   - Environment variables in app settings
   - Migrate to Key Vault for production
   - Rotate credentials regularly

3. **Authentication**
   - No authentication on web app
   - Consider adding Azure AD
   - Implement RBAC for admin functions

## Testing Scenarios

### Scenario 1: User Registration
1. Navigate to /Registration
2. Fill in all required fields
3. Submit form
4. Verify success message
5. Check /Attendees page for new entry
6. Verify database entry

### Scenario 2: Notification Flow (Local - without Azure)
1. Navigate to /Notification
2. Enter subject and message
3. Submit form
4. Observe synchronous email sending (slow)
5. Check notification status
6. Verify database updated

### Scenario 3: Notification Flow (Azure - with Service Bus)
1. Navigate to /Notification
2. Enter subject and message
3. Submit form
4. Should return immediately
5. Check Service Bus queue for message
6. Wait for function execution
7. Verify notification status updated
8. Check function logs

### Scenario 4: Load Testing
1. Register multiple attendees (10+)
2. Create notification
3. Verify all attendees receive emails
4. Check function execution time
5. Monitor resource utilization

## Troubleshooting Guide

### Web App Won't Start
- Check Python version compatibility
- Verify all dependencies installed
- Review application logs
- Check database connection string

### Database Connection Failed
- Verify firewall rules
- Check connection string format
- Ensure SSL enabled
- Test with psql client

### Function Not Triggering
- Verify Service Bus connection
- Check function.json binding
- Review function logs
- Test queue manually

### Service Bus Issues
- Verify connection string
- Check queue exists
- Verify permissions
- Test with Service Bus Explorer

## Sign-off

### Development Team
- [ ] Local testing completed
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Ready for deployment

### Operations Team
- [ ] Azure resources planned
- [ ] Monitoring configured
- [ ] Backup strategy defined
- [ ] Support procedures documented

### Security Team
- [ ] Security review completed
- [ ] Credentials secured
- [ ] Access controls defined
- [ ] Compliance verified

---

**Deployment Date**: _______________
**Deployed By**: _______________
**Approved By**: _______________
