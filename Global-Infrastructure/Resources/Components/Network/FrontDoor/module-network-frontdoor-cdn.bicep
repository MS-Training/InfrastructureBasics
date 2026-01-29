@description('An object containing deployment flags to control module behavior.')
param deploymentFlags object

@description('The Secure Object that contains the settings to be passed to the module')
@secure()
param settings object

// ============================================================================
// Front Door CDN Profile
// ============================================================================
resource cdnProfile 'Microsoft.Cdn/profiles@2025-06-01' = {
  name: '${settings.organizationTag}-${settings.Network.FrontDoorCDN.profileName}-${settings.environment}'
  location: settings.Network.FrontDoorCDN.location
  tags: settings.standardTags
  sku: settings.Network.FrontDoorCDN.sku
  properties: settings.Network.FrontDoorCDN.properties
}

// ============================================================================
// Front Door Endpoint
// ============================================================================

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-06-01' = {
  parent: cdnProfile
  name: settings.Network.FrontDoorCDN.endpoint.name
  location: settings.Network.FrontDoorCDN.location
  tags: settings.standardTags
  properties: settings.Network.FrontDoorCDN.endpoint.properties
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
