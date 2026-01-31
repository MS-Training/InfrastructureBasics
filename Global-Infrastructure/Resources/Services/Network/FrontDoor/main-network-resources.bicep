
targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('An object containing deployment flags to control module behavior.')
param deploymentFlags object

@description('The Secure Object that contains the settings to be passed to the Network Resource Group')
@secure()
param settings object

@@description('A unique identifier for the deployment. Defaults to a new GUID.')
param deploymentGuid string = newGuid()


// ============================================================================
// Variables
// ============================================================================
var currentResourceGroupName = 'rg-${settings.organizationTag}-${settings.environment}-${settings.Network.ResourceGroup.name}'

// ============================================================================
// Step 1: Create Resource Group (idempotent - safe to run if exists)
// ============================================================================
module rgmodule '../../../BaseModules/module-resourcegroup.bicep' = {
  name: 'rg-deployment-${deploymentGuid}'
  params: {
    resourceGroupName: settings.Network.ResourceGroup.name
    settings: settings
  }
}

/////////////////////////////////////////////////////
// Get a reference to the Resource Group for scoping other modules
// Use calculated name (known at compile time) not module output
/////////////////////////////////////////////////////
resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: currentResourceGroupName
  dependsOn: [rgmodule]
}


// ============================================================================
// Step 2: Deploy Front Door (into the Resource Group)
// Uses output from network module - creates implicit dependency
// ============================================================================
module frontDoor '../../../BaseModules/module-network-frontdoor.bicep' = {
  scope: networkResourceGroup
  name: '${settings.Network.FrontDoor.profileName}-${deploymentGuid}'
  params: {
    settings: settings
  }
  dependsOn: [rgmodule]
}


// ============================================================================
// Outputs
// ============================================================================

output resourceGroupName string = currentResourceGroupName
output resourceGroupId string = networkResourceGroup.id


output frontDoorEndpoint string = frontDoor.outputs.endpointHostName
