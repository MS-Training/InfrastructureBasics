// ============================================================================
// Main Orchestration - Subscription Scope
// Creates Resource Group, then chains deployments into it
// ============================================================================
targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('An object containing deployment flags to control module behavior.')
param deploymentFlags object

@description('The Secure Object that contains the settings to be passed to the Network Resource Group')
@secure()
param settings object

@description('Numeric value for the time. This is used to append to Deployment Names for Deployment Records')
param epochTime int = dateTimeToEpoch(dateTimeAdd(utcNow(), 'P1Y'))


// ============================================================================
// Variables
// ============================================================================



// ============================================================================
// Step 1: Create Resource Group
// ============================================================================
module rgmodule '../Resources/Components/Network/module-network-resourcegroup.bicep' = {
  params: {
    deploymentFlags: deploymentFlags
    settings: settings
  }
}

var currentResourceGroupName = '${settings.organizationTag}-${settings.environment}-${settings.Network.ResourceGroup.name}'



/////////////////////////////////////////////////////
// Get a reference to the Resource Group for later deployments
/////////////////////////////////////////////////////
resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: currentResourceGroupName
  dependsOn: [rgmodule]
}

var createdResourceGroupObject = rgmodule.outputs.createdNetworkResourceGroup


// ============================================================================
// Step 2: Deploy Front Door (into the Resource Group)
// Uses output from network module - creates implicit dependency
// ============================================================================
module frontDoor '../Resources/Components/Network/FrontDoor/module-network-frontdoor-cdn.bicep' = {
  scope: networkResourceGroup
  name: '${settings.Network.FrontDoorCDN.profileName}-${epochTime}'
  params: {
    deploymentFlags: deploymentFlags
    settings: settings
  }
   dependsOn: [rgmodule]  
}

// ============================================================================
// Outputs
// ============================================================================

output resourceGroupName string = createdResourceGroupObject.name
output resourceGroupId string = createdResourceGroupObject.id
output frontDoorEndpoint string = frontDoor.outputs.endpointHostName
