/*
https://docs.microsoft.com/en-us/azure/templates/microsoft.network/networksecuritygroups?tabs=bicep

Creates a Network Security Group and its respective rules.

*/
@description('The Location for the Resource Group.')
param location string

@description('The network security group objects to create')
param networkSecurityGroup object

@description('The standard tags to add to the resource')
param standardTags object

///////////////////////////////////////
// Network Security Group deployment operation contains a Loop to create each of the rules assigned to the Security Group.
///////////////////////////////////////
resource NetworkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2021-08-01' = {
  name: networkSecurityGroup.name
  location: location
  tags: standardTags
  properties: {
    securityRules: [for sr in networkSecurityGroup.RuleList: {
      type: 'Microsoft.Network/networkSecurityGroups'
      id: 'Rule${networkSecurityGroup.name}${sr.name}'
      name: sr.name
      properties: {
        description: sr.description
        priority: sr.priority
        protocol: sr.protocol
        sourcePortRange: sr.sourcePortRange
        destinationPortRange: sr.destinationPortRange
        sourceAddressPrefix: sr.sourceAddressPrefix
        destinationAddressPrefix: sr.destinationAddressPrefix
        access: sr.access
        direction: sr.direction
      }
    }]
  }

}
//the return security group object
output networkSecurityGroup string = NetworkSecurityGroup.id
