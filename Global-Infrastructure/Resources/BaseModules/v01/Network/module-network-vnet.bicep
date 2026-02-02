@description('The Secure Object that contains the settings to be passed to the module')
@secure()
param settings object

@description('A unique identifier for the deployment. Defaults to a new GUID.')
param deploymentGuid string = newGuid()

//Network Security Group creation so that an embedded array can be used. There is an array being used in the 
//module, as this item itself is being referenced from inside an array.
module NetworkSecurityGroup 'module-network-securitygroup.bicep' = [
  for sn in settings.Network.VirtualNetwork.Properties.subNets: {
    name: '${sn.name}nsg${deploymentGuid}'
    params: {
      settings: settings
      networkSecurityGroup: sn.networkSecurityGroup
    }
  }
]

////////////////////////////
//Virtual Network Creation
//As the Subnets are created from the loop, the index of the current subnet will be used to access the index of the nsg from the passed in array.
//There is a one to one mapping of the collection of NSGs to the collection of Subnets created.
//https://docs.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks?tabs=bicep
////////////////////////////
resource VirtualNetwork 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: settings.Network.VirtualNetwork.Properties.name
  location: settings.location
  extendedLocation: (empty(settings.Network.VirtualNetwork.Properties.extendedLocation)? json('null'): settings.Network.VirtualNetwork.Properties.extendedLocation)
  tags: settings.standardTags
  properties: {
    addressSpace: {
      addressPrefixes: settings.Network.VirtualNetwork.Properties.addressSpaces
    }
    subnets: [
      for (sn, idx) in settings.Network.VirtualNetwork.Properties.subNets: {
        name: '${settings.resourceTag.subnet}${sn.name}'
        properties: {
          addressPrefix: sn.addressRange
          serviceEndpoints: settings.Network.VirtualNetwork.Properties.defaultServiceEndpoints
          networkSecurityGroup: {
            id: NetworkSecurityGroup[idx].outputs.networkSecurityGroup
          }
        }
      }
    ]
    enableDdosProtection: settings.Network.VirtualNetwork.Properties.ddosProtectionPlanEnabled
  }
}
