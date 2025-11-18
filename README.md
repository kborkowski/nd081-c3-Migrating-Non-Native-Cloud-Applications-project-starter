# TechConf Registration Website

## Project Overview
The TechConf website allows attendees to register for an upcoming conference. Administrators can also view the list of attendees and notify all attendees via a personalized email message.

The application is currently working but the following pain points have triggered the need for migration to Azure:
 - The web application is not scalable to handle user load at peak
 - When the admin sends out notifications, it's currently taking a long time because it's looping through all attendees, resulting in some HTTP timeout exceptions
 - The current architecture is not cost-effective 

In this project, you are tasked to do the following:
- Migrate and deploy the pre-existing web app to an Azure App Service
- Migrate a PostgreSQL database backup to an Azure Postgres database instance
- Refactor the notification logic to an Azure Function via a service bus queue message

## Dependencies

You will need to install the following locally:
- [Postgres](https://www.postgresql.org/download/)
- [Visual Studio Code](https://code.visualstudio.com/download)
- [Azure Function tools V3](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=windows%2Ccsharp%2Cbash#install-the-azure-functions-core-tools)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- [Azure Tools for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode.vscode-node-azure-pack)

## Project Instructions

### Part 1: Create Azure Resources and Deploy Web App
1. Create a Resource group
2. Create an Azure Postgres Database single server
   - Add a new database `techconfdb`
   - Allow all IPs to connect to database server
   - Restore the database with the backup located in the data folder
3. Create a Service Bus resource with a `notificationqueue` that will be used to communicate between the web and the function
   - Open the web folder and update the following in the `config.py` file
      - `POSTGRES_URL`
      - `POSTGRES_USER`
      - `POSTGRES_PW`
      - `POSTGRES_DB`
      - `SERVICE_BUS_CONNECTION_STRING`
4. Create App Service plan
5. Create a storage account
6. Deploy the web app

### Part 2: Create and Publish Azure Function
1. Create an Azure Function in the `function` folder that is triggered by the service bus queue created in Part 1.

      **Note**: Skeleton code has been provided in the **README** file located in the `function` folder. You will need to copy/paste this code into the `__init.py__` file in the `function` folder.
      - The Azure Function should do the following:
         - Process the message which is the `notification_id`
         - Query the database using `psycopg2` library for the given notification to retrieve the subject and message
         - Query the database to retrieve a list of attendees (**email** and **first name**)
         - Loop through each attendee and send a personalized subject message
         - After the notification, update the notification status with the total number of attendees notified
2. Publish the Azure Function

### Part 3: Refactor `routes.py`
1. Refactor the post logic in `web/app/routes.py -> notification()` using servicebus `queue_client`:
   - The notification method on POST should save the notification object and queue the notification id for the function to pick it up
2. Re-deploy the web app to publish changes

## Monthly Cost Analysis
Complete a month cost analysis of each Azure resource to give an estimate total cost using the table below:

| Azure Resource | Service Tier | Monthly Cost |
| ------------ | ------------ | ------------ |
| Azure App Service (Web App) | Basic B1 (1 Core, 1.75 GB RAM) | ~$13.14/month |
| Azure PostgreSQL Database | Basic Gen5 (1 vCore, 5GB storage) | ~$25.00/month |
| Azure Service Bus | Standard | ~$10.00/month (base) + $0.05 per million operations |
| Azure Function App | Consumption Plan | First 1M executions free, then $0.20 per million |
| Azure Storage Account | Standard LRS | ~$0.02/GB/month + transaction costs |
| Application Insights | Basic (5GB free) | Free tier sufficient for small apps |
| **Estimated Total** | | **~$50-60/month** |

**Cost Optimization Notes:**
- **Development/Testing**: Use shared App Service Plan (~$9.49/month) and disable resources when not in use
- **Production**: Consider reserved instances for 30-40% savings on predictable workloads
- **Scaling**: Consumption-based Function App scales automatically and only charges for actual usage
- **Database**: Basic tier sufficient for small-medium workloads; consider burstable SKUs for cost savings
- **Monitoring**: Application Insights free tier (5GB/month) adequate for initial deployment

## Architecture Explanation

### Architecture Overview
This solution migrates a monolithic Flask web application to a modern, scalable microservices architecture on Azure, addressing the key pain points: scalability, performance, and cost-effectiveness.

### Architecture Components

#### 1. **Azure App Service (Web Application)**
**Decision Rationale:**
- **Platform-as-a-Service (PaaS)**: Eliminates infrastructure management overhead
- **Auto-scaling**: Handles variable user load automatically during peak registration periods
- **Built-in CI/CD**: Simplifies deployment pipeline
- **Cost-effective**: Pay only for compute resources used, with scaling options from Basic to Premium tiers
- **Python Support**: Native support for Flask applications with minimal code changes

**Why not Azure VMs?**
- VMs require manual patching, scaling configuration, and higher operational overhead
- Higher cost for similar workload capacity
- App Service provides better developer productivity

#### 2. **Azure PostgreSQL Database**
**Decision Rationale:**
- **Managed Service**: Automated backups, patching, and high availability
- **Compatibility**: Direct migration from existing PostgreSQL without schema changes
- **Scalability**: Vertical and horizontal scaling options available
- **Security**: Built-in SSL/TLS, firewall rules, and Azure AD integration
- **Performance**: Connection pooling and query optimization tools

**Why not Azure SQL?**
- Existing PostgreSQL schema requires no refactoring
- Team familiarity with PostgreSQL reduces learning curve
- Cost-effective for this workload size

#### 3. **Azure Service Bus (Message Queue)**
**Decision Rationale:**
- **Decoupling**: Separates web app from notification processing, preventing HTTP timeouts
- **Reliability**: Guaranteed message delivery with dead-letter queue support
- **Scalability**: Handles high message throughput during peak notification periods
- **Asynchronous Processing**: Web app responds immediately while notifications process in background
- **Enterprise Features**: Message sessions, duplicate detection, and scheduled delivery

**Why not Azure Storage Queue?**
- Service Bus provides advanced messaging features (sessions, dead-letter queues)
- Better integration with Azure Functions for enterprise scenarios
- Support for larger message sizes (256KB vs 64KB)

#### 4. **Azure Functions (Notification Processing)**
**Decision Rationale:**
- **Serverless**: Zero infrastructure management, automatic scaling
- **Event-driven**: Triggered automatically by Service Bus messages
- **Cost-efficient**: Consumption plan charges only for execution time (first 1M executions free)
- **Parallel Processing**: Multiple function instances handle notifications concurrently
- **Independent Scaling**: Scales independently from web application based on queue depth

**Why not App Service Background Job?**
- Functions provide better isolation and independent scaling
- More cost-effective for intermittent workloads
- Automatic retry logic and error handling built-in

#### 5. **Azure Storage Account**
**Decision Rationale:**
- **Function Requirement**: Required by Azure Functions for state management
- **Static Assets**: Can serve static content for web app (CSS, JS, images)
- **Backup Storage**: Can store database backups and logs
- **Cost-effective**: Pay per GB stored with multiple redundancy options

### Architecture Flow

```
1. User Registration:
   Browser → Azure App Service → PostgreSQL Database → Response

2. Notification Flow (Refactored):
   Admin creates notification → 
   Web App saves notification to DB → 
   Web App sends notification ID to Service Bus Queue → 
   Immediate response to admin →
   Azure Function triggered by queue message →
   Function queries DB for notification details →
   Function queries DB for attendee list →
   Function sends emails asynchronously →
   Function updates notification status in DB
```

### Key Improvements

#### **Scalability**
- **Web App**: Auto-scales based on CPU/memory metrics to handle user load spikes
- **Function App**: Automatically scales based on queue depth (up to 200 instances)
- **Database**: Can scale vertically (vCores) or horizontally (read replicas)

#### **Performance**
- **Async Processing**: Notifications no longer block HTTP requests
- **Parallel Execution**: Multiple function instances process notifications simultaneously
- **Queue Buffering**: Service Bus queues messages during high load

#### **Cost-Effectiveness**
- **Consumption Model**: Pay only for actual function executions
- **Right-sized Resources**: Start with Basic tier, scale as needed
- **Managed Services**: Reduce operational costs (no server management)

#### **Reliability**
- **Message Durability**: Service Bus ensures no notification is lost
- **Retry Logic**: Automatic retries for failed operations
- **Dead Letter Queue**: Failed messages moved for investigation
- **Database Backups**: Automated daily backups with point-in-time restore

### Deployment Strategy
1. **Blue-Green Deployment**: Zero-downtime deployments using deployment slots
2. **Infrastructure as Code**: Use ARM templates or Terraform for reproducible deployments
3. **CI/CD Pipeline**: Azure DevOps or GitHub Actions for automated deployments
4. **Monitoring**: Application Insights for end-to-end visibility

### Security Considerations
- **Managed Identity**: Use for service-to-service authentication
- **Key Vault**: Store secrets and connection strings
- **Network Isolation**: VNet integration for production environments
- **SSL/TLS**: All connections encrypted in transit
- **Firewall Rules**: Restrict database access to Azure services only

### Future Enhancements
- **CDN**: Add Azure CDN for static asset delivery
- **Redis Cache**: Implement caching layer for frequently accessed data
- **API Management**: Add API gateway for rate limiting and monitoring
- **Container Option**: Consider Azure Container Apps for more control
