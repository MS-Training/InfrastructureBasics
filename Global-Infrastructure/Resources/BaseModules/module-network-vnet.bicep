@description('Virtual network name')
param virtualNetworkName string

@description('The IP Address Prefix of the Network')
param virtualNetworkAddressPrefix string = '172.20.0.0/16'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('enable if you have a DDoS protection plan created')
param enableDDoSProtection bool = false

@description('The Resource id of the DDoS Protection Plan if enableDDoSProtection is true')
param dDoSProtectionPlanResourceId string = ''

var dDoSProperties = {
  addressSpace: {
    addressPrefixes: [
      virtualNetworkAddressPrefix
    ]
  }
  subnets: []
  enableDdosProtection: enableDDoSProtection
  ddosProtectionPlan: {
    id: dDoSProtectionPlanResourceId
  }
}
var properties = {
  addressSpace: {
    addressPrefixes: [
      virtualNetworkAddressPrefix
    ]
  }
  subnets: []
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-09-01' = {
  name: virtualNetworkName
  location: location
  properties: (enableDDoSProtection ? dDoSProperties : properties)
}
