/*******************************************************************************
This module is used for the deployment of an Organization regional resource group.
Framework-Name: Global-Infrastructure
Module-Name: types
Module-Version: 1.0
Module-Description: The exportable types used when module outputs are used
Module-Creator: Edward Rush
Module-Creation-Date: 2026-01-31
********************************************************************************/

@description('The complete output type for the deploy.bicep file')
@export()
type deployBicepCompleteOutputType = {
  @description('Resource Group deployment output')
  networkResourceGroupCreated: resourceGroupOutputType?
  @description('Front Door deployment output')
  frontDoorCreated: frontDoorMinimalOutputType?
  @description('Default Storage Account Output')
  defaultStorageAccountCreated: storageAccountOutputType?
  @description('Virtual Network Output')
  virtualNetworkCreated: virtualNetworkOutputType?
}



@description('The output type for a Resource Group Module')
@export()
type resourceGroupOutputType = {
  @description('The name of the Resource Group')
  name: string
  @description('The resource ID of the Resource Group')
  id: string
  @description('The Azure region where the Resource Group is deployed')
  location: string
  @description('The full name of the Resource Group including prefixes')
  resourceGroupFullName: string
}


@description('The output type for a Minimal Front Door Module')
@export()
type frontDoorMinimalOutputType = {
  @description('The full URL to access the Front Door Endpoint')
  url: string
  @description('Front Door CDN profile resource ID')
  profileId: string
  @description('Front Door profile name')
  profileName: string
  @description('Front Door unique identifier (use for backend access restrictions)')
  frontDoorId: string
  @description('Front Door endpoint hostname')
  endpointHostName: string
  @description('Front Door endpoint resource ID')
  endpointId: string
}


@description('The output type for a Storage Account Module')
@export()
type storageAccountOutputType = {
  @description('Storage Account resource ID')
  id: string
  @description('Storage Account name')  
  name: string
  @description('Storage Account blob service endpoints')
  endpoints: {
  @description('Blob service endpoint URL')
    blob: string
  @description('File service endpoint URL')
    file: string
  @description('Table service endpoint URL')
    table: string
  @description('Queue service endpoint URL')
    queue: string
  }
}


/////////////////////////////////////////////////////
// Virtual Network and Private Endpoint Types
/////////////////////////////////////////////////////

@description('Well-known Private DNS Zone names for Azure services')
@export()
type PrivateDnsZoneNameType = 
  | 'privatelink.vaultcore.azure.net'           // Key Vault
  | 'privatelink.blob.core.windows.net'         // Storage Blob
  | 'privatelink.file.core.windows.net'         // Storage File
  | 'privatelink.queue.core.windows.net'        // Storage Queue
  | 'privatelink.table.core.windows.net'        // Storage Table
  | 'privatelink.web.core.windows.net'          // Storage Static Website
  | 'privatelink.dfs.core.windows.net'          // Storage Data Lake Gen2
  | 'privatelink.database.windows.net'          // SQL Database
  | 'privatelink.sql.azuresynapse.net'          // Synapse SQL
  | 'privatelink.dev.azuresynapse.net'          // Synapse Dev
  | 'privatelink.azuresynapse.net'              // Synapse
  | 'privatelink.documents.azure.com'           // Cosmos DB
  | 'privatelink.mongo.cosmos.azure.com'        // Cosmos DB MongoDB
  | 'privatelink.cassandra.cosmos.azure.com'    // Cosmos DB Cassandra
  | 'privatelink.gremlin.cosmos.azure.com'      // Cosmos DB Gremlin
  | 'privatelink.table.cosmos.azure.com'        // Cosmos DB Table
  | 'privatelink.postgres.database.azure.com'   // PostgreSQL
  | 'privatelink.mysql.database.azure.com'      // MySQL
  | 'privatelink.mariadb.database.azure.com'    // MariaDB
  | 'privatelink.redis.cache.windows.net'       // Redis Cache
  | 'privatelink.servicebus.windows.net'        // Service Bus
  | 'privatelink.eventgrid.azure.net'           // Event Grid
  | 'privatelink.azure-automation.net'          // Azure Automation
  | 'privatelink.cognitiveservices.azure.com'   // Cognitive Services
  | 'privatelink.openai.azure.com'              // Azure OpenAI
  | 'privatelink.azurecr.io'                    // Container Registry
  | 'privatelink.azurewebsites.net'             // App Service / Functions
  | 'privatelink.api.azureml.ms'                // Azure ML API
  | 'privatelink.notebooks.azure.net'           // Azure ML Notebooks
  | 'privatelink.afs.azure.net'                 // Azure File Sync
  | 'privatelink.monitor.azure.com'             // Azure Monitor
  | 'privatelink.oms.opinsights.azure.com'      // Log Analytics
  | 'privatelink.ods.opinsights.azure.com'      // Log Analytics Data
  | 'privatelink.agentsvc.azure-automation.net' // Automation Agent
  | 'privatelink.search.windows.net'            // Azure Search
  | 'privatelink.purview.azure.com'             // Microsoft Purview
  | 'privatelink.purviewstudio.azure.com'       // Purview Studio




@description('The output type for a Virtual Network Module')
@export()
type virtualNetworkOutputType = {
  @description('The resource ID of the Virtual Network')
  vnetId: string
  @description('The name of the Virtual Network')
  vnetName: string
  @description('The resource ID of the Application Subnet')
  applicationSubnetId: string
  @description('The resource ID of the Data Subnet')
  dataSubnetId: string
  @description('The address prefixes configured for the Virtual Network')
  addressPrefixes: array
  @description('The provisioning state of the Virtual Network')
  provisioningState: string
  @description('The unique GUID for the Virtual Network resource')
  resourceGuid: string
}
