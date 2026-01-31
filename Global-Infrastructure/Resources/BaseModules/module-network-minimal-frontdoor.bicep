/*******************************************************************************
This module is used for the deployment of an Organization regional resource group.
Framework-Name: Global-Infrastructure
Module-Name: module-network-minimal-frontdoor
Module-Version: 1.0
Module-Description: Minimal Front Door Resource
Module-Creator: Edward Rush
Module-Creation-Date: 2026-01-31
********************************************************************************/

/////////////////////////////////////////////////////
// Type imports
/////////////////////////////////////////////////////
import { frontDoorMinimalOutputType } from './types.bicep'

@description('The Secure Object that contains the settings to be passed to the module')
@secure()
param settings object

// ============================================================================
// Front Door CDN Profile
// ============================================================================
resource cdnProfile 'Microsoft.Cdn/profiles@2025-06-01' = {
  name: '${settings.organizationTag}-${settings.Network.FrontDoor.profileName}-${settings.environment}'
  location: settings.Network.FrontDoor.location
  tags: settings.standardTags
  sku: settings.Network.FrontDoor.sku
  properties: settings.Network.FrontDoor.properties
}

// ============================================================================
// Front Door Endpoint
// ============================================================================
@description('Azure Front Door Endpoint that is the public URL. It is the entry point for all traffic.')
resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2025-06-01' = if (contains(
  settings.Network.FrontDoor,
  'endpoint'
)) {
  parent: cdnProfile
  name: settings.Network.FrontDoor.endpoint.name
  location: settings.Network.FrontDoor.location
  tags: settings.standardTags
  properties: settings.Network.FrontDoor.endpoint.properties
}

/////////////////////////////////////////////////////
// Outputs
/////////////////////////////////////////////////////

/*
  Front Door Module Outputs
  -------------------------
  This module returns the following outputs for Azure Front Door CDN:

  | Output Name       | Type   | Description                                                    |
  |-------------------|--------|----------------------------------------------------------------|
  | url               | string | The full URL to access the Front Door Endpoint                 |
  | profileId         | string | Front Door CDN profile resource ID                             |
  | profileName       | string | Front Door profile name                                        |
  | frontDoorId       | string | Front Door unique identifier (use for backend access restrictions) |
  | endpointHostName  | string | Front Door endpoint hostname                                   |
  | endpointId        | string | Front Door endpoint resource ID                                |

  Usage:
    Reference these outputs when configuring backend services or DNS records.
    The frontDoorId is particularly useful for restricting backend access to only
    traffic originating from this Front Door instance.
*/

@description('Front Door outputs containing profile and endpoint information')
output frontDoorCreated frontDoorMinimalOutputType = {
  url: 'https://${endpoint.properties.hostName}'
  profileId: cdnProfile.id
  profileName: cdnProfile.name
  frontDoorId: cdnProfile.properties.frontDoorId
  endpointHostName: endpoint.properties.hostName
  endpointId: endpoint.id
}
