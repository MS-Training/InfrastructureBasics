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

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-06-01' = if (contains(
  settings.Network.FrontDoorCDN,
  'endpoint'
)){
  parent: cdnProfile
  name: settings.Network.FrontDoorCDN.endpoint.name
  location: settings.Network.FrontDoorCDN.location
  tags: settings.standardTags
  properties: settings.Network.FrontDoorCDN.endpoint.properties
}

// ============================================================================
// Origin Group with Health Probe
// ============================================================================
resource originGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = if (contains(
  settings.Network.FrontDoorCDN,
  'originGroup'
)) {
  parent: cdnProfile
  name: settings.Network.FrontDoorCDN.originGroup.name
  properties: {
    loadBalancingSettings: settings.Network.FrontDoorCDN.originGroup.loadBalancingSettings
    healthProbeSettings: settings.Network.FrontDoorCDN.originGroup.healthProbeSettings
    sessionAffinityState: settings.Network.FrontDoorCDN.originGroup.?sessionAffinityState ?? 'Disabled'
  }
}

// ============================================================================
// Origin (Backend)
// ============================================================================
resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = if (contains(
  settings.Network.FrontDoorCDN,
  'origin'
)) {
  parent: originGroup
  name: settings.Network.FrontDoorCDN.origin.name
  properties: settings.Network.FrontDoorCDN.origin.properties
}

// ============================================================================
// Route (connects endpoint to origin group)
// ============================================================================
resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = if (contains(
  settings.Network.FrontDoorCDN,
  'route'
)) {
  parent: endpoint
  name: settings.Network.FrontDoorCDN.route.name
  properties: {
    originGroup: {
      id: originGroup.id
    }
    originPath: settings.Network.FrontDoorCDN.route.?originPath ?? '/'
    supportedProtocols: settings.Network.FrontDoorCDN.route.?supportedProtocols ?? ['Http', 'Https']
    patternsToMatch: settings.Network.FrontDoorCDN.route.?patternsToMatch ?? ['/*']
    forwardingProtocol: settings.Network.FrontDoorCDN.route.?forwardingProtocol ?? 'HttpsOnly'
    linkToDefaultDomain: settings.Network.FrontDoorCDN.route.?linkToDefaultDomain ?? 'Enabled'
    httpsRedirect: settings.Network.FrontDoorCDN.route.?httpsRedirect ?? 'Enabled'
    enabledState: 'Enabled'
  }
  dependsOn: [origin]
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
