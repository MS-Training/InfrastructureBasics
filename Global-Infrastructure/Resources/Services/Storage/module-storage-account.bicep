// ============================================================================
// Storage Account - No Secrets (Uses Entra ID Authentication)
// ============================================================================

@description('Storage account name (3-24 chars, lowercase, alphanumeric)')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Location for the storage account')
param location string = resourceGroup().location

@description('Storage account SKU')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS', 'Premium_LRS'])
param sku string = 'Standard_LRS'

@description('Allow public blob access')
param allowBlobPublicAccess bool = false

@description('Enable hierarchical namespace (Data Lake)')
param enableHierarchicalNamespace bool = false

@description('Tags')
param tags object = {}

// ============================================================================
// Storage Account
// ============================================================================
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: 'StorageV2'
  properties: {
    // Security: Disable shared key access (forces Entra ID auth)
    allowSharedKeyAccess: false
    
    // Security: Require HTTPS
    supportsHttpsTrafficOnly: true
    
    // Security: Minimum TLS version
    minimumTlsVersion: 'TLS1_2'
    
    // Security: Disable public blob access
    allowBlobPublicAccess: allowBlobPublicAccess
    
    // Network: Default deny (optional - uncomment for private access only)
    // networkAcls: {
    //   defaultAction: 'Deny'
    //   bypass: 'AzureServices'
    // }
    
    // Data Lake support
    isHnsEnabled: enableHierarchicalNamespace
    
    // Access tier
    accessTier: 'Hot'
  }
}

// ============================================================================
// Blob Services (optional configuration)
// ============================================================================
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// ============================================================================
// Outputs - NO SECRETS! Only resource IDs and endpoints
// ============================================================================

@description('Storage account resource ID')
output storageAccountId string = storageAccount.id

@description('Storage account name')
output storageAccountName string = storageAccount.name

@description('Blob endpoint')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob

@description('File endpoint')
output fileEndpoint string = storageAccount.properties.primaryEndpoints.file

@description('Table endpoint')
output tableEndpoint string = storageAccount.properties.primaryEndpoints.table

@description('Queue endpoint')
output queueEndpoint string = storageAccount.properties.primaryEndpoints.queue
