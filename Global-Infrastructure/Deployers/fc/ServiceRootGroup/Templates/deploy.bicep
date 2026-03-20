/////////////////////////////////////////////////////
// Type Imports
/////////////////////////////////////////////////////

import {
  resourceGroupOutputType
  frontDoorMinimalOutputType
  storageAccountOutputType
  deployBicepCompleteOutputType
  virtualNetworkOutputType
} from '../../../../Resources/BaseModules/v01/types.bicep'

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

var networkResourceGroupName = '${settings.resourceTag.resourceGroup}${settings.organizationTag}${settings.environment}${settings.Network.ResourceGroup.name}'
//var templateSpecsResourceGroupName = '${settings.resourceTag.resourceGroup}${settings.organizationTag}${settings.environment}${settings.TemplateSpec.ResourceGroup.name}'

module newtworkResourceGroupModule '../../../../Resources/BaseModules/v01/module-resourcegroup.bicep' = {
  name: 'networkrg${settings.Network.ResourceGroup.name}-${deploymentGuid}'
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

module frontDoor '../../../../Resources/BaseModules/v01/Network/module-network-minimal-frontdoor.bicep' = if (deploymentFlags.deployFrontDoor) {
  scope: networkResourceGroup
  name: '${settings.resourceTag.frontDoor}${settings.Network.FrontDoor.profileName}-${deploymentGuid}'
  params: {
    settings: settings
  }
  dependsOn: [newtworkResourceGroupModule]
}

/////////////////////////////////////////////////////
// If front door was not created in this operation, then just default the values
/////////////////////////////////////////////////////
var frontDoorOutputs frontDoorMinimalOutputType = deploymentFlags.deployFrontDoor ? frontDoor.outputs.frontDoorCreated : {
    url: ''
    profileId: ''
    profileName: ''
    frontDoorId: ''
    endpointHostName: ''
    endpointId: ''
  }



module virtualNetwork '../../../../Resources/BaseModules/v01/Network/module-network-vnet.bicep' = {
  scope: networkResourceGroup
  name: 'vnet-${settings.Network.VirtualNetwork.Properties.name}-${deploymentGuid}'
  params: {
    settings: settings
  }
  dependsOn: [newtworkResourceGroupModule]
}

var virtualNetworkOuts virtualNetworkOutputType = virtualNetwork.outputs.virtualNetworkCreated


// ============================================================================
// Create Resource Group for the Template Specs deployments :  currently we are not using Template Specs. Put this on hold for now.
// ============================================================================
/*
  module templateSpecsResourceGroupModule '../../../../Resources/BaseModules/v01/module-resourcegroup.bicep' = {
    name: 'temprg${settings.TemplateSpec.ResourceGroup.name}-${deploymentGuid}'
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
*/



@description('Storage account module for the network resource group default storage account')
module defaultStorageAccountModule '../../../../Resources/BaseModules/v01/Storage/module-storage-account.bicep' = {
  scope: networkResourceGroup
  name: 'st-${settings.StorageAccounts.NetworkStorageAccount.name}-${deploymentGuid}'
  params: {
    settings: settings
    storageAccount: settings.StorageAccounts.NetworkStorageAccount
  }
  dependsOn: [newtworkResourceGroupModule]
}

var defaultStorageAccountOuts storageAccountOutputType = defaultStorageAccountModule.outputs.storageAccountCreated




// ============================================================================
// Outputs
// ============================================================================

output deploymentComplete deployBicepCompleteOutputType = {
  frontDoorCreated: frontDoorOutputs
  networkResourceGroupCreated: networkResourceGroupOuts
  defaultStorageAccountCreated: defaultStorageAccountOuts
  virtualNetworkCreated: virtualNetworkOuts
}


