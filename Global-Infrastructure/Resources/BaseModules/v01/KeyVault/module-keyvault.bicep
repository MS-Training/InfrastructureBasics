@description('The Secure Object that contains the settings to be passed to the module')
@secure()
param settings object

@description('Flag to indicate if network isolation is enabled for the Key Vault')
var isNetworkIsolated = settings.KeyVault.privateEndpoint.?enabled ?? false

////////////////////////////
// Key Vault Settings Type Definition
////////////////////////////
@description('Key Vault configuration settings')
type KeyVaultSettingsType = {
  @description('Name of the Key Vault (3-24 alphanumeric characters and hyphens)')
  name: string
  
  @description('SKU name - standard or premium')
  skuName: 'standard' | 'premium'
  
  @description('Enable soft delete (recommended: true)')
  enableSoftDelete: bool?
  
  @description('Soft delete retention in days (7-90)')
  softDeleteRetentionInDays: int?
  
  @description('Enable purge protection (recommended: true for production)')
  enablePurgeProtection: bool?
  
  @description('Enable RBAC authorization instead of access policies')
  enableRbacAuthorization: bool?
  
  @description('Enable for Azure Disk Encryption')
  enabledForDiskEncryption: bool?
  
  @description('Enable for ARM template deployment')
  enabledForTemplateDeployment: bool?
  
  @description('Enable for Azure VM deployment')
  enabledForDeployment: bool?
  
  @description('Private endpoint settings')
  privateEndpoint: {
    @description('Enable private endpoint')
    enabled: bool
    @description('Subnet ID for the private endpoint')
    subnetId: string?
    @description('Private DNS Zone ID for Key Vault')
    privateDnsZoneId: string?
  }?
}

////////////////////////////
// Key Vault Creation
// Security best practices:
// - Soft delete enabled
// - Purge protection enabled  
// - RBAC authorization (preferred over access policies)
// - Public network access disabled
// - Private endpoint for secure access
// https://learn.microsoft.com/en-us/azure/templates/microsoft.keyvault/vaults
////////////////////////////
resource KeyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: settings.KeyVault.name
  location: settings.location
  tags: settings.standardTags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: settings.KeyVault.skuName ?? 'standard'
    }
    // Security: Enable RBAC authorization (preferred over access policies)
    enableRbacAuthorization: settings.KeyVault.enableRbacAuthorization ?? true
    
    // Security: Enable soft delete to protect against accidental deletion
    enableSoftDelete: settings.KeyVault.enableSoftDelete ?? true
    softDeleteRetentionInDays: settings.KeyVault.softDeleteRetentionInDays ?? 90
    
    // Security: Enable purge protection to prevent permanent deletion
    enablePurgeProtection: settings.KeyVault.enablePurgeProtection ?? true
    
    // Optional: Enable for various Azure services
    enabledForDeployment: settings.KeyVault.enabledForDeployment ?? false
    enabledForDiskEncryption: settings.KeyVault.enabledForDiskEncryption ?? false
    enabledForTemplateDeployment: settings.KeyVault.enabledForTemplateDeployment ?? false
    
    // Security: Disable public network access when using private endpoint
    publicNetworkAccess: isNetworkIsolated ? 'Disabled' : 'Enabled'
    
    // Security: Network ACLs - deny by default, allow trusted Azure services
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: isNetworkIsolated ? 'Deny' : 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

////////////////////////////
// Private Endpoint for Key Vault
// Enables secure access to Key Vault over a private network connection
// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/privateendpoints
////////////////////////////
resource PrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (isNetworkIsolated) {
  name: '${settings.KeyVault.name}-pe'
  location: settings.location
  tags: settings.standardTags
  properties: {
    subnet: {
      id: settings.KeyVault.privateEndpoint.subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${settings.KeyVault.name}-plsc'
        properties: {
          privateLinkServiceId: KeyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

////////////////////////////
// Private DNS Zone Group
// Automatically registers the private endpoint in the Private DNS Zone
// Required for name resolution of the Key Vault over the private network
////////////////////////////
resource PrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (isNetworkIsolated && settings.KeyVault.privateEndpoint.?privateDnsZoneId != null) {
  parent: PrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: settings.KeyVault.privateEndpoint.privateDnsZoneId
        }
      }
    ]
  }
}

////////////////////////////
// Outputs
////////////////////////////
@description('The Key Vault resource')
output keyVault object = KeyVault

@description('The Key Vault resource ID')
output keyVaultId string = KeyVault.id

@description('The Key Vault name')
output keyVaultName string = KeyVault.name

@description('The Key Vault URI')
output keyVaultUri string = KeyVault.properties.vaultUri

@description('The Private Endpoint resource (if enabled)')
output privateEndpointOutput object = isNetworkIsolated ? PrivateEndpoint : {}

@description('The Private Endpoint ID (if enabled)')
output privateEndpointResourceId string = isNetworkIsolated ? PrivateEndpoint.id : ''
