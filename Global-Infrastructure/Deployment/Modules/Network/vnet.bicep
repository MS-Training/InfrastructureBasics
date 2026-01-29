// ============================================================================
// VNet Module - Resource Group Scope
// ============================================================================

@description('Name of the virtual network')
param vnetName string

@description('Azure region')
param location string

@description('Address prefix for the VNet')
param addressPrefix string = '10.0.0.0/16'

@description('Tags')
param tags object = {}

// ============================================================================
// Virtual Network
// ============================================================================
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [
      {
        name: 'snet-app'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 0)  // 10.0.0.0/24
        }
      }
      {
        name: 'snet-data'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 1)  // 10.0.1.0/24
        }
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

output vnetId string = vnet.id
output vnetName string = vnet.name
output appSubnetId string = vnet.properties.subnets[0].id
output dataSubnetId string = vnet.properties.subnets[1].id
