


/////////////////////////////////////////////////////
// The default for this module will be a Subscription Level Scope since it is a Resource Group
/////////////////////////////////////////////////////
targetScope = 'subscription'

@description('Name of the Resource Group to be created')
param resourceGroupName string 

@description('The Secure Object that contains the settings to be passed to the Network Resource Group')
@secure()
param settings object

@description('Should this resource group be deployed?')
param shouldDeploy bool = true

@description('Prefix for the resource to be created')
param resourcePrefix string = 'rg'

/////////////////////////////////////////////////////
// Extract the Deploy or Update Setting to determine if the Resource should be created or Updated.
/////////////////////////////////////////////////////


//if the resource group should be deployed or updated
resource CreatedResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = if (shouldDeploy) {
  location: settings.location
  managedBy: settings.managedBy
  name: '${resourcePrefix}-${settings.organizationTag}-${settings.environment}-${resourceGroupName}'
  properties: {}
  tags: settings.standardTags
}


// Return individual properties
output createdCreatedResourceGroup object = {
  name: CreatedResourceGroup.?name ?? ''
  id: CreatedResourceGroup.?id ?? ''
  location: CreatedResourceGroup.?location ?? ''
}

