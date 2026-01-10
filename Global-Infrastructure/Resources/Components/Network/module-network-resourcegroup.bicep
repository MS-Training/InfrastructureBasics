
//set the target scope to be the subscription so the scope property is not needed in the resource declaration
targetScope = 'subscription'

@description('The Secure Object that contains the settings to be passed to the Network Resource Group')
@secure()
param settings object

@description('The standard tags to be applied to all resources in this deployment')
param standardTags object

resource NetworkResourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  location: settings.location
  managedBy: 'string'
  name: settings.Network.name
  properties: {}
  tags: standardTags
}
