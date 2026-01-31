/////////////////////////////////////////////////////
// Type Imports
/////////////////////////////////////////////////////

import {
  resourceGroupOutputType
  frontDoorMinimalOutputType
} from '../../../../Resources/BaseModules/types.bicep'

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('An object containing deployment flags to control module behavior.')
param deploymentFlags object

@description('The Secure Object that contains the settings to be passed to the Network Resource Group')
@secure()
param settings object

@description('A unique identifier for the deployment. Defaults to a new GUID.')
param deploymentGuid string = newGuid()

// ============================================================================
// Variables
// ============================================================================
// Calculate the resource group name (must be known at compile time for 'existing' reference)
var networkResourceGroupName = 'rg-${settings.organizationTag}-${settings.environment}-${settings.Network.ResourceGroup.name}'
var templateSpecsResourceGroupName = 'rg-${settings.organizationTag}-${settings.environment}-${settings.TemplateSpec.ResourceGroup.name}'

// ============================================================================
// Step 1: Create Resource Group (idempotent - safe to run if exists)
// ============================================================================
module newtworkResourceGroupModule '../../../../Resources/BaseModules/module-resourcegroup.bicep' = {
  name: 'rg-${settings.Network.ResourceGroup.name}-${deploymentGuid}'
  params: {
    resourceGroupName: settings.Network.ResourceGroup.name
    settings: settings
  }
}

var networkResourceGroupOuts resourceGroupOutputType = newtworkResourceGroupModule.outputs.resourceGroupCreated


/////////////////////////////////////////////////////
// Get a reference to the Resource Group for scoping other modules
// Use calculated name (known at compile time) not module output
/////////////////////////////////////////////////////
resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: networkResourceGroupName
  dependsOn: [newtworkResourceGroupModule]
}

// ============================================================================
// Step 2: Deploy Front Door (into the Resource Group)
// Uses output from network module - creates implicit dependency
// ============================================================================
module frontDoor '../../../../Resources/BaseModules/module-network-minimal-frontdoor.bicep' = {
  scope: networkResourceGroup
  name: '${settings.Network.FrontDoor.profileName}-${deploymentGuid}'
  params: {
    settings: settings
  }
  dependsOn: [newtworkResourceGroupModule]
}

var frontDoorOutputs frontDoorMinimalOutputType = frontDoor.outputs.frontDoorCreated



// ============================================================================
// Step 3: Create Resource Group for the Template Specs deployments
// ============================================================================
module templateSpecsResourceGroupModule '../../../../Resources/BaseModules/module-resourcegroup.bicep' = {
  name: 'rg-${settings.TemplateSpec.ResourceGroup.name}-${deploymentGuid}'
  params: {
    resourceGroupName: settings.TemplateSpec.ResourceGroup.name
    settings: settings
  }
}

var templateSpecsResourceGroupOuts resourceGroupOutputType = templateSpecsResourceGroupModule.outputs.resourceGroupCreated

resource templateSpecsResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' existing = {
  name: templateSpecsResourceGroupName
  dependsOn: [templateSpecsResourceGroupModule]
}


// ============================================================================
// Outputs
// ============================================================================
output frontDoorCreated frontDoorMinimalOutputType = frontDoorOutputs
output networkResourceGroupCreated resourceGroupOutputType = networkResourceGroupOuts
output templateSpecsResourceGroupCreated resourceGroupOutputType = templateSpecsResourceGroupOuts
