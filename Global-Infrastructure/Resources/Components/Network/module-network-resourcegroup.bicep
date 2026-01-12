

/*******************************************************************************
This module is used for the deployment of an Organization regional resource group.
Framework-Name: Global-Infrastructure
Module-Name: NetworkResourceGroup
Module-Version: 1.0.0
Module-Description: This module deploys a network resource group using the Global-Infrastructure Framework.
Module-Creator: Edward Rush
********************************************************************************/ 


/////////////////////////////////////////////////////
// The default for this module will be a Subscription Level Scope since it is a Resource Group
/////////////////////////////////////////////////////
targetScope = 'subscription'

@description('The Secure Object that contains the settings to be passed to the Network Resource Group')
@secure()
param settings object


/////////////////////////////////////////////////////
// Extract the Deploy or Update Setting to determine if the Resource should be created or Updated.
/////////////////////////////////////////////////////
var deployOrUpdate = settings.Network.ResourceGroup.deployOrUpdate

//if the resource group should be deployed or updated
resource NetworkResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = if (deployOrUpdate) {
  location: settings.location
  managedBy: settings.managedBy
  name: '${settings.organizationTag}-${settings.environment}-${settings.Network.ResourceGroup.name}'
  properties: {}
  tags: settings.standardTags
}


