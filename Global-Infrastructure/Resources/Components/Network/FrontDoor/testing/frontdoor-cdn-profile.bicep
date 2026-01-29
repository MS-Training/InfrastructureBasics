// ============================================================================
// Azure Front Door with CDN Profile
// Complete deployment including Profile, Endpoint, Origin Group, Origin & Route
// ============================================================================

// ============================================================================
// User-Defined Types
// ============================================================================

@description('Front Door SKU configuration')
type skuType = 'Standard_AzureFrontDoor' | 'Premium_AzureFrontDoor'

@description('Origin configuration type')
type originConfigType = {
  @description('Hostname of the origin (e.g., myapp.azurewebsites.net)')
  hostName: string
  @description('HTTP port for the origin')
  httpPort: int?
  @description('HTTPS port for the origin')
  httpsPort: int?
  @description('Priority of the origin (1-5, lower is higher priority)')
  priority: int?
  @description('Weight of the origin for load balancing (1-1000)')
  weight: int?
  @description('Whether the origin is enabled')
  enabled: bool?
}

@description('Health probe configuration type')
type healthProbeConfigType = {
  @description('Path to probe for health checks')
  probePath: string?
  @description('Protocol for health probe')
  probeProtocol: ('Http' | 'Https')?
  @description('HTTP method for health probe')
  probeRequestType: ('GET' | 'HEAD')?
  @description('Interval between probes in seconds')
  probeIntervalInSeconds: int?
}

@description('Route configuration type')
type routeConfigType = {
  @description('Patterns to match for this route')
  patternsToMatch: string[]
  @description('Supported protocols')
  supportedProtocols: ('Http' | 'Https')[]
  @description('Protocol to use when forwarding to origin')
  forwardingProtocol: ('HttpOnly' | 'HttpsOnly' | 'MatchRequest')
  @description('Whether to redirect HTTP to HTTPS')
  httpsRedirect: ('Enabled' | 'Disabled')
}

// ============================================================================
// Parameters
// ============================================================================

@description('Name of the Front Door CDN profile')
param profileName string

@description('Name of the Front Door endpoint')
param endpointName string

@description('Name of the origin group')
param originGroupName string = 'default-origin-group'

@description('Name of the origin')
param originName string = 'primary-origin'

@description('Name of the route')
param routeName string = 'default-route'

@description('Front Door SKU - Standard or Premium (Premium required for WAF)')
param sku skuType = 'Premium_AzureFrontDoor'

@description('Origin configuration')
param originConfig originConfigType

@description('Health probe configuration')
param healthProbeConfig healthProbeConfigType = {
  probePath: '/'
  probeProtocol: 'Https'
  probeRequestType: 'HEAD'
  probeIntervalInSeconds: 30
}

@description('Route configuration')
param routeConfig routeConfigType = {
  patternsToMatch: ['/*']
  supportedProtocols: ['Http', 'Https']
  forwardingProtocol: 'HttpsOnly'
  httpsRedirect: 'Enabled'
}

@description('Response timeout in seconds')
@minValue(16)
@maxValue(240)
param originResponseTimeoutSeconds int = 60

@description('Tags for all resources')
param tags object = {}

// ============================================================================
// Variables
// ============================================================================

var defaultHttpPort = 80
var defaultHttpsPort = 443
var defaultPriority = 1
var defaultWeight = 1000

// ============================================================================
// Front Door CDN Profile
// ============================================================================
resource cdnProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: profileName
  location: 'Global'
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    originResponseTimeoutSeconds: originResponseTimeoutSeconds
  }
}

// ============================================================================
// Front Door Endpoint
// ============================================================================
resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  parent: cdnProfile
  name: endpointName
  location: 'Global'
  tags: tags
  properties: {
    enabledState: 'Enabled'
  }
}

// ============================================================================
// Origin Group (Backend Pool)
// ============================================================================
resource originGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: cdnProfile
  name: originGroupName
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: healthProbeConfig.?probePath ?? '/'
      probeProtocol: healthProbeConfig.?probeProtocol ?? 'Https'
      probeRequestType: healthProbeConfig.?probeRequestType ?? 'HEAD'
      probeIntervalInSeconds: healthProbeConfig.?probeIntervalInSeconds ?? 30
    }
    sessionAffinityState: 'Disabled'
  }
}

// ============================================================================
// Origin (Backend)
// ============================================================================
resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: originGroup
  name: originName
  properties: {
    hostName: originConfig.hostName
    httpPort: originConfig.?httpPort ?? defaultHttpPort
    httpsPort: originConfig.?httpsPort ?? defaultHttpsPort
    priority: originConfig.?priority ?? defaultPriority
    weight: originConfig.?weight ?? defaultWeight
    originHostHeader: originConfig.hostName
    enabledState: (originConfig.?enabled ?? true) ? 'Enabled' : 'Disabled'
  }
}

// ============================================================================
// Route (connects endpoint to origin group)
// ============================================================================
resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  parent: endpoint
  name: routeName
  properties: {
    originGroup: {
      id: originGroup.id
    }
    originPath: '/'
    ruleSets: []
    supportedProtocols: routeConfig.supportedProtocols
    patternsToMatch: routeConfig.patternsToMatch
    forwardingProtocol: routeConfig.forwardingProtocol
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: routeConfig.httpsRedirect
    enabledState: 'Enabled'
  }
  dependsOn: [
    origin // Route requires at least one origin to exist
  ]
}

// ============================================================================
// Outputs
// ============================================================================

@description('Front Door CDN profile resource ID')
output profileId string = cdnProfile.id

@description('Front Door unique identifier (use for backend access restrictions)')
output frontDoorId string = cdnProfile.properties.frontDoorId

@description('Front Door endpoint hostname')
output endpointHostName string = endpoint.properties.hostName

@description('Front Door endpoint resource ID')
output endpointId string = endpoint.id

@description('Origin group resource ID')
output originGroupId string = originGroup.id

@description('Full Front Door URL')
output frontDoorUrl string = 'https://${endpoint.properties.hostName}'
