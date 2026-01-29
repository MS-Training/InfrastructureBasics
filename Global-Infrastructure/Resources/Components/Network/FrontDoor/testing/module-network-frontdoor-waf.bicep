


/*******************************************************************************
This module is used for the deployment of an Organization regional resource group.
Framework-Name: Global-Infrastructure
Module-Name: module-network-frontdoor-waf
Module-Version: 1.0
Module-Description: Creating a basic FrontDoor Instance, with a Web Application Firewall (WAF)
Module-Creator: Edward Rush
********************************************************************************/


/////////////////////////////////////////////////////
// The default for this module will be a Resource Group Level Scope
// FrontDoorWithWAF parameter object
// Properties:
//   - frontDoorName (string, required): Name of the Front Door profile
//   - wafPolicyName (string, required): Name of the WAF policy
//   - endpointName  (string, required): Name of the Front Door endpoint
//   - wafMode (string, optional)      : WAF mode - Detection (monitor only) or Prevention (block). Allowed values: 'Detection', 'Prevention'. Default: 'Prevention'
//   - enableRequestBodyCheck (bool, optional) : Enable request body inspection. Default: true
//   - maxRequestBodySizeInKb (int, optional)  : Maximum request body size in KB (8-128). Default: 128
//   - tags (object, optional)                 : Tags for all resources. Default: {}


@description('The Secure Object that contains the settings to be passed to the module')
@secure()
param settings object

@description('Front Door and WAF configuration object')
param config object = {
  frontDoorName: ''
  wafPolicyName: ''
  endpointName: ''
  wafMode: 'Prevention'
  enableRequestBodyCheck: true
  maxRequestBodySizeInKb: 128
  tags: {}
}

// ============================================================================
// WAF Policy
// ============================================================================
resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2025-10-01' = {
  name: settings.Network.FrontDoorWithWAF.wafPolicyName
  location: 'Global'
  tags: settings.Network.FrontDoorWithWAF.tags
  sku: settings.Network.FrontDoorWithWAF.sku
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: settings.Network.FrontDoorWithWAF.wafMode
      requestBodyCheck: settings.Network.FrontDoorWithWAF.enableRequestBodyCheck ? 'Enabled' : 'Disabled'

      customBlockResponseStatusCode: 403
      customBlockResponseBody: base64('{"error":"Request blocked by WAF policy"}')
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleSetAction: 'Block'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
    customRules: {
      rules: [
        {
          name: 'RateLimitRule'
          priority: 100
          ruleType: 'RateLimitRule'
          action: 'Block'
          rateLimitThreshold: 1000
          rateLimitDurationInMinutes: 1
          matchConditions: [
            {
              matchVariable: 'RequestUri'
              operator: 'RegEx'
              matchValue: ['.*']
              transforms: []
            }
          ]
        }
      ]
    }
  }
}

// ============================================================================
// Front Door Profile (Premium SKU for WAF support)
// ============================================================================
resource frontDoorProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: frontDoorName
  location: 'Global'
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

// ============================================================================
// Front Door Endpoint
// ============================================================================
resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  parent: frontDoorProfile
  name: endpointName
  location: 'Global'
  tags: tags
  properties: {
    enabledState: 'Enabled'
  }
}

// ============================================================================
// Security Policy (links WAF to Endpoint)
// ============================================================================
resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2023-05-01' = {
  parent: frontDoorProfile
  name: 'waf-security-policy'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================
@description('Front Door profile resource ID')
output frontDoorId string = frontDoorProfile.id

@description('Front Door unique identifier (use for access restrictions)')
output frontDoorUniqueId string = frontDoorProfile.properties.frontDoorId

@description('Front Door endpoint hostname')
output frontDoorEndpointHostname string = frontDoorEndpoint.properties.hostName

@description('WAF policy resource ID')
output wafPolicyId string = wafPolicy.id

@description('Front Door profile name')
output frontDoorProfileName string = frontDoorProfile.name
