
@description('The virtual network object containing the subnet details.')
param virtualNetwork object

@description('The standard tags to be applied to all resources in this deployment')
param standardTags object

@description('The Location for the Resource Group.')
param location string

@description('Numeric value for the time. This is used to append to Deployment Names for Deployment Records')
param epochTime int = dateTimeToEpoch(dateTimeAdd(utcNow(), 'P1Y'))

//Network Security Group creation so that an embedded array can be used. There is an array being used in the 
//module, as this item itself is being referenced from inside an array.
module NetworkSecurityGroup './networkSecurityGroupModule.bicep' = [for sn in virtualNetwork.Properties.subNets: {
  name: '${sn.name}NetworkSecurityGroup${epochTime}'
  params: {
    networkSecurityGroup: sn.networkSecurityGroup
    location: location
    standardTags: standardTags
  }
}]

////////////////////////////
//Virtual Network Creation
//As the Subnets are created from the loop, the index of the current subnet will be used to access the index of the nsg from the passed in array.
//There is a one to one mapping of the collection of NSGs to the collection of Subnets created.
//https://docs.microsoft.com/en-us/azure/templates/microsoft.network/virtualnetworks?tabs=bicep
////////////////////////////
resource VirtualNetwork 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: virtualNetwork.Properties.name
  location: location
  extendedLocation: (empty(virtualNetwork.Properties.extendedLocation) ? json('null') : virtualNetwork.Properties.extendedLocation)
  tags: standardTags
  properties: {
    addressSpace: {
      addressPrefixes: virtualNetwork.Properties.addressSpaces
    }
    subnets: [for (sn, idx) in virtualNetwork.Properties.subNets: {
      name: sn.name
      properties: {
        addressPrefix: sn.addressRange
        serviceEndpoints: virtualNetwork.Properties.defaultServiceEndpoints
        networkSecurityGroup: {
          id: NetworkSecurityGroup[idx].outputs.networkSecurityGroup
        }
      }
      
    }]
    enableDdosProtection: virtualNetwork.Properties.ddosProtectionPlanEnabled
  }
}
