import { storageAccountOutputType } from '../types.bicep'

@description('The Secure Object that contains the settings to be passed to the module')
@secure()
param settings object

@description('The Storage Account settings object')
param storageAccount object


var storageAccountName = '${settings.resourceTag.storageAccount}${settings.organizationTag}${storageAccount.name}${settings.environment}'

// ============================================================================
// Storage Account
// ============================================================================
resource createdStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: storageAccount.location
  tags: settings.standardTags
  sku: storageAccount.sku
  kind: storageAccount.kind
  properties: storageAccount.properties
}

// ============================================================================
// Blob Services (optional configuration)
// ============================================================================
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: createdStorageAccount
  name: 'default'
  properties: storageAccount.BlobStorage.properties
}

// ============================================================================
// Outputs - NO SECRETS! Only resource IDs and endpoints
// ============================================================================
@description('Storage account outputs')
output storageAccountCreated storageAccountOutputType = {
  id: createdStorageAccount.id
  name: createdStorageAccount.name
  endpoints: {
    blob: createdStorageAccount.properties.primaryEndpoints.blob
    file: createdStorageAccount.properties.primaryEndpoints.file
    table: createdStorageAccount.properties.primaryEndpoints.table
    queue: createdStorageAccount.properties.primaryEndpoints.queue
  }
}
