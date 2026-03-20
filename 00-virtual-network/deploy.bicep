//Notes and references
//https://www.mangrovedata.co.uk/blog/2021/6/12/passing-azure-bicep-output-parameters-between-modules
//https://ochzhen.com/blog/nested-loops-in-azure-bicep#option-1-easier-avoid-nested-loop-by-passing-complete-array-property

targetScope = 'subscription'

@description('The Location for the Resource Group.')
param location string 

@description('The Resource Group Name.')
param resourceGroupName string
@description('The standard tags to be applied to all resources in this deployment')
param standardTags object

@description('Parameter used with the creation of the resource group')
param managedBy string 

@description('The virtual network objects containing the subnet and network security group details.')
param virtualNetwork object

@description('Numeric value for the time. This is used to append to Deployment Names for Deployment Records')
param epochTime int = dateTimeToEpoch(dateTimeAdd(utcNow(), 'P1Y'))

//https://docs.microsoft.com/en-us/azure/templates/microsoft.resources/resourcegroups?tabs=bicep
//Add the resource group here just in case it does not exist, it will be created and the objects will be deploy in that scope
resource ResourceGroupDeployment 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: standardTags
  managedBy: managedBy
  properties: {
  }
}


//////////////////////////////////////
//To create the virtual network and all of its subnets
//////////////////////////////////////
module VirtualNetworkWithSubNets 'virtualNetworkModule.bicep' = {
  scope: ResourceGroupDeployment
  name: 'FullCoceVirtualNetwork${epochTime}'
  params: {
    virtualNetwork: virtualNetwork
    location: location
    standardTags: standardTags
  }
}


