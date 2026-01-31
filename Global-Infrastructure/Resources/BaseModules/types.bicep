/*******************************************************************************
This module is used for the deployment of an Organization regional resource group.
Framework-Name: Global-Infrastructure
Module-Name: types
Module-Version: 1.0
Module-Description: The exportable types used when module outputs are used
Module-Creator: Edward Rush
Module-Creation-Date: 2026-01-31
********************************************************************************/


@description('The output type for a Resource Group Module')
@export()
type resourceGroupOutputType = {
  @description('The name of the Resource Group')
  name: string
  @description('The resource ID of the Resource Group')
  id: string
  @description('The Azure region where the Resource Group is deployed')
  location: string
  @description('The full name of the Resource Group including prefixes')
  resourceGroupFullName: string
}


@description('The output type for a Minimal Front Door Module')
@export()
type frontDoorMinimalOutputType = {
  @description('The full URL to access the Front Door Endpoint')
  url: string
  @description('Front Door CDN profile resource ID')
  profileId: string
  @description('Front Door profile name')
  profileName: string
  @description('Front Door unique identifier (use for backend access restrictions)')
  frontDoorId: string
  @description('Front Door endpoint hostname')
  endpointHostName: string
  @description('Front Door endpoint resource ID')
  endpointId: string
}

