// ============================================================================
// Azure Front Door - Minimal Deployment (Profile + Endpoint Only)
// Origin groups, origins, and routes can be added later
// ============================================================================

@description('Name of the Front Door CDN profile')
param profileName string

@description('Name of the Front Door endpoint')
param endpointName string

@description('Front Door SKU')
@allowed(['Standard_AzureFrontDoor', 'Premium_AzureFrontDoor'])
param sku string = 'Premium_AzureFrontDoor'

@description('Tags for all resources')
param tags object = {}

// ============================================================================
// Front Door CDN Profile
// ============================================================================
resource cdnProfile 'Microsoft.Cdn/profiles@2025-06-01' = {
  name: profileName
  location: 'Global'
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

// ============================================================================
// Front Door Endpoint
// ============================================================================
resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-06-01' = {
  parent: cdnProfile
  name: endpointName
  location: 'Global'
  tags: tags
  properties: {
    enabledState: 'Enabled'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Front Door CDN profile resource ID')
output profileId string = cdnProfile.id

@description('Front Door profile name')
output profileName string = cdnProfile.name

@description('Front Door unique identifier (use for backend access restrictions)')
output frontDoorId string = cdnProfile.properties.frontDoorId

@description('Front Door endpoint hostname')
output endpointHostName string = endpoint.properties.hostName

@description('Front Door endpoint resource ID')
output endpointId string = endpoint.id
