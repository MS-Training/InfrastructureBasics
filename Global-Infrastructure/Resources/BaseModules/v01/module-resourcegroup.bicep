/*******************************************************************************
This module is used for the deployment of an Organization regional resource groups.
Framework-Name: Global-Infrastructure
Module-Name: module-resourcegroup
Module-Version: v01
Module-Description: The basic Module for any resource group. API Version 2025-04-01
Module-Creator: Edward Rush
Module-Creation-Date: 2026-01-31
********************************************************************************/

/////////////////////////////////////////////////////
// Type imports
/////////////////////////////////////////////////////
import { resourceGroupOutputType } from './types.bicep'

/////////////////////////////////////////////////////
// The default for this module will be a Subscription Level Scope since it is a Resource Group
/////////////////////////////////////////////////////
targetScope = 'subscription'

@description('Name of the Resource Group to be created')
param resourceGroupName string

@description('The Secure Object that contains the settings to be passed to the Network Resource Group')
@secure()
param settings object

  /////////////////////////////////////////////////////
// Variables
/////////////////////////////////////////////////////
var resourceGroupFullName = '${settings.resourceTag.resourceGroup}${settings.organizationTag}${settings.environment}${resourceGroupName}'

/////////////////////////////////////////////////////
// Create the Resource Group
/////////////////////////////////////////////////////
resource CreatedResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  location: settings.location
  managedBy: settings.managedBy
  name: resourceGroupFullName
  properties: {}
  tags: settings.standardTags
}



/////////////////////////////////////////////////////
// The Output of the Resource Group. Currently can't return Resource Group object.
/////////////////////////////////////////////////////
output resourceGroupCreated resourceGroupOutputType = {
  name: CreatedResourceGroup.?name ?? ''
  id: CreatedResourceGroup.?id ?? ''
  location: CreatedResourceGroup.?location ?? ''
  resourceGroupFullName: resourceGroupFullName
}


