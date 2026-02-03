


/////////////////////////////////////////////////////
// Type imports
/////////////////////////////////////////////////////
import { VirtualNetworkLinkType } from '../types.bicep'


@description('The Secure Object that contains the settings to be passed to the module')
@secure()
param settings object

@description('The name of the Private DNS Zone (e.g., privatelink.vaultcore.azure.net)')
param zoneName string

@description('VNet to link to this Private DNS Zone')
param virtualNetworkLink VirtualNetworkLinkType



////////////////////////////
// Private DNS Zone
// Creates a private DNS zone for Azure Private Link services
// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/privatednszones
////////////////////////////
resource PrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: zoneName
  location: 'global'  // Private DNS Zones are always global
  tags: settings.standardTags
}

////////////////////////////
// Virtual Network Link
// Links a Virtual Network to the Private DNS Zone for name resolution
// https://learn.microsoft.com/en-us/azure/templates/microsoft.network/privatednszones/virtualnetworklinks
////////////////////////////
resource VNetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: PrivateDnsZone
  name: virtualNetworkLink.name
  location: 'global'
  tags: settings.standardTags
  properties: {
    virtualNetwork: {
      id: virtualNetworkLink.virtualNetworkId
    }
    registrationEnabled: virtualNetworkLink.?registrationEnabled ?? false
  }
}

////////////////////////////
// Outputs
////////////////////////////
@description('The Private DNS Zone resource')
output privateDnsZone object = PrivateDnsZone

@description('The Private DNS Zone resource ID')
output privateDnsZoneId string = PrivateDnsZone.id

@description('The Private DNS Zone name')
output privateDnsZoneName string = PrivateDnsZone.name

@description('Virtual Network Link ID')
output virtualNetworkLinkId string = VNetLink.id
