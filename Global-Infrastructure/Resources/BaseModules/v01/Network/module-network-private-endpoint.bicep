@description('The Secure Object that contains the settings to be passed to the module')
@secure()
param settings object

@description('Name of the private endpoint')
param name string

@description('Resource ID of the target resource (e.g., Key Vault, Storage Account)')
param targetResourceId string

@description('Group ID for the private link connection (e.g., vault, blob, file)')
param groupId string

@description('Resource ID of the subnet where the private endpoint will be created')
param subnetId string

@description('Resource ID of the Private DNS Zone for automatic DNS registration (optional)')
param dnsZoneId string = ''

@description('Custom network interface name (optional)')
param customNetworkInterfaceName string = ''

////////////////////////////
// Type Definitions
////////////////////////////
@description('Common group IDs for Azure services')
type GroupIdType =
  | 'vault'           // Key Vault
  | 'blob'            // Storage Blob
  | 'blob_secondary'  // Storage Blob Secondary
  | 'file'            // Storage File
  | 'file_secondary'  // Storage File Secondary
  | 'queue'           // Storage Queue
  | 'queue_secondary' // Storage Queue Secondary
  | 'table'           // Storage Table
  | 'table_secondary' // Storage Table Secondary
  | 'web'             // Storage Static Website
  | 'web_secondary'   // Storage Static Website Secondary
  | 'dfs'             // Storage Data Lake Gen2
  | 'dfs_secondary'   // Storage Data Lake Gen2 Secondary
  | 'sqlServer'       // SQL Database
  | 'Sql'             // Synapse SQL
  | 'SqlOnDemand'     // Synapse SQL On-Demand
  | 'Dev'             // Synapse Dev
  | 'namespace'       // Service Bus / Event Hubs
  | 'topic'           // Event Grid Topic
  | 'domain'          // Event Grid Domain
  | 'registry'        // Container Registry
  | 'sites'           // App Service / Functions
  | 'redisCache'      // Redis Cache
  | 'account'         // Cognitive Services / Azure OpenAI
  | 'searchService'   // Azure Search

////////////////////////////
// Private Endpoint
// Creates a private endpoint for secure access to Azure PaaS services
// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/privateendpoints
////////////////////////////
resource PrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: name
  location: settings.location
  tags: settings.standardTags
  properties: {
    subnet: {
      id: subnetId
    }
    customNetworkInterfaceName: !empty(customNetworkInterfaceName) ? customNetworkInterfaceName : null
    privateLinkServiceConnections: [
      {
        name: '${name}-plsc'
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: [
            groupId
          ]
        }
      }
    ]
  }
}

////////////////////////////
// Private DNS Zone Group
// Automatically registers the private endpoint IP in the Private DNS Zone
// This creates an A record pointing to the private endpoint's IP address
////////////////////////////
resource DnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!empty(dnsZoneId)) {
  parent: PrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: replace(replace(groupId, '_', '-'), 'secondary', 'sec')
        properties: {
          privateDnsZoneId: dnsZoneId
        }
      }
    ]
  }
}

////////////////////////////
// Outputs
////////////////////////////
@description('The Private Endpoint resource')
output endpoint object = PrivateEndpoint

@description('The Private Endpoint resource ID')
output endpointId string = PrivateEndpoint.id

@description('The Private Endpoint name')
output endpointName string = PrivateEndpoint.name

@description('The custom network interface name (if provided)')
output customNicName string = customNetworkInterfaceName
