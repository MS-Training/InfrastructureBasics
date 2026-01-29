using './frontdoor-waf.bicep'

// ============================================================================
// Front Door with WAF - Parameters
// ============================================================================

param frontDoorName = 'fd-myapp-prod'
param wafPolicyName = 'waf-myapp-prod'
param endpointName = 'myapp-endpoint'

// WAF Configuration
param wafMode = 'Prevention'
param enableRequestBodyCheck = true
param maxRequestBodySizeInKb = 128

// Tags
param tags = {
  environment: 'production'
  application: 'myapp'
  costCenter: 'IT'
}
