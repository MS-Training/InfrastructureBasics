using './frontdoor-cdn-profile.bicep'

// ============================================================================
// Front Door CDN Profile - Parameters
// ============================================================================

// Profile Configuration
param profileName = 'fd-myapp-prod'
param endpointName = 'myapp'
param sku = 'Premium_AzureFrontDoor'

// Origin Group & Origin Configuration
param originGroupName = 'webapp-origin-group'
param originName = 'webapp-origin'

param originConfig = {
  hostName: 'myapp.azurewebsites.net'
  httpPort: 80
  httpsPort: 443
  priority: 1
  weight: 1000
  enabled: true
}

// Health Probe Configuration
param healthProbeConfig = {
  probePath: '/health'
  probeProtocol: 'Https'
  probeRequestType: 'GET'
  probeIntervalInSeconds: 30
}

// Route Configuration
param routeName = 'default-route'
param routeConfig = {
  patternsToMatch: ['/*']
  supportedProtocols: ['Http', 'Https']
  forwardingProtocol: 'HttpsOnly'
  httpsRedirect: 'Enabled'
}

// General Settings
param originResponseTimeoutSeconds = 60

// Tags
param tags = {
  environment: 'Development'
  application: 'myapp'
  managedBy: 'bicep'
}
