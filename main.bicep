// TechConf Azure Infrastructure Deployment
// This Bicep template deploys all required Azure resources

@description('The name prefix for all resources')
param resourcePrefix string = 'techconf'

@description('The Azure region for all resources')
param location string = resourceGroup().location

@description('PostgreSQL administrator username')
param postgresAdminUser string = 'techconfadmin'

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('SendGrid API Key for email sending')
@secure()
param sendGridApiKey string

@description('Admin email address')
param adminEmailAddress string = 'info@techconf.com'

@description('Secret key for Flask application')
@secure()
param secretKey string = 'LWd2tzlprdGHCIPHTd4tp5SBFgDszm'

@description('Database name')
param databaseName string = 'techconfdb'

// Generate unique names using resource group ID
var uniqueSuffix = uniqueString(resourceGroup().id)
var postgresServerName = '${resourcePrefix}-db-${uniqueSuffix}'
var serviceBusNamespaceName = '${resourcePrefix}-sb-${uniqueSuffix}'
var storageAccountName = 'tcstore${take(uniqueString(resourceGroup().id), 17)}'
var appServicePlanName = '${resourcePrefix}-plan-${uniqueSuffix}'
var webAppName = '${resourcePrefix}-web-${uniqueSuffix}'
var functionAppName = '${resourcePrefix}-func-${uniqueSuffix}'
var queueName = 'notificationqueue'

// PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: postgresServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '13'
    administratorLogin: postgresAdminUser
    administratorLoginPassword: postgresAdminPassword
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// PostgreSQL Database
resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  parent: postgresServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// PostgreSQL Firewall Rule - Allow Azure Services
resource postgresFirewallAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
  parent: postgresServer
  name: 'AllowAllAzureIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// PostgreSQL Firewall Rule - Allow all IPs (for development only)
resource postgresFirewallAll 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
  parent: postgresServer
  name: 'AllowAllIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// Service Bus Namespace
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    minimumTlsVersion: '1.2'
  }
}

// Service Bus Queue
resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2021-11-01' = {
  parent: serviceBusNamespace
  name: queueName
  properties: {
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 10
    enablePartitioning: false
    enableExpress: false
  }
}

// Service Bus Authorization Rule
resource serviceBusAuthRule 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2021-11-01' = {
  parent: serviceBusNamespace
  name: 'RootManageSharedAccessKey'
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}

// Storage Account for Function App
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
    family: 'B'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// Web App
resource webApp 'Microsoft.Web/sites@2021-03-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'POSTGRES_URL'
          value: '${postgresServerName}.postgres.database.azure.com'
        }
        {
          name: 'POSTGRES_USER'
          value: postgresAdminUser
        }
        {
          name: 'POSTGRES_PW'
          value: postgresAdminPassword
        }
        {
          name: 'POSTGRES_DB'
          value: databaseName
        }
        {
          name: 'SERVICE_BUS_CONNECTION_STRING'
          value: listKeys(serviceBusAuthRule.id, serviceBusAuthRule.apiVersion).primaryConnectionString
        }
        {
          name: 'SERVICE_BUS_QUEUE_NAME'
          value: queueName
        }
        {
          name: 'SENDGRID_API_KEY'
          value: sendGridApiKey
        }
        {
          name: 'ADMIN_EMAIL_ADDRESS'
          value: adminEmailAddress
        }
        {
          name: 'SECRET_KEY'
          value: secretKey
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
    }
  }
}

// Function App
resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'SERVICE_BUS_CONNECTION_STRING'
          value: listKeys(serviceBusAuthRule.id, serviceBusAuthRule.apiVersion).primaryConnectionString
        }
        {
          name: 'POSTGRES_URL'
          value: '${postgresServerName}.postgres.database.azure.com'
        }
        {
          name: 'POSTGRES_USER'
          value: postgresAdminUser
        }
        {
          name: 'POSTGRES_PW'
          value: postgresAdminPassword
        }
        {
          name: 'POSTGRES_DB'
          value: databaseName
        }
        {
          name: 'ADMIN_EMAIL_ADDRESS'
          value: adminEmailAddress
        }
        {
          name: 'SENDGRID_API_KEY'
          value: sendGridApiKey
        }
      ]
    }
  }
}

// Outputs
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName
output serviceBusNamespace string = serviceBusNamespace.name
output resourceGroupName string = resourceGroup().name
