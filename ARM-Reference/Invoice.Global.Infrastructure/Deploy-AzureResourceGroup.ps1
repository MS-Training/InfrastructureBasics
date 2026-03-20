#Requires -Version 3.0

Param(
    [switch] $UploadArtifacts = $true,
    [switch] $ValidateOnly,
    [string] $ArtifactStagingDirectory = '.\ArmResources\',
    [string] $TemplateFile = '.\ArmDeployers\Invoice\ServiceGroupRoot\Templates\azuredeploy.json',
    [string] $TemplateParametersFile = '.\ArmDeployers\Invoice\ServiceGroupRoot\Parameters\azuredeploy.parameters.local.json'
)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ', '_'), '3.0.0')
}
catch { }

$ErrorMessages = ''
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | Where-Object { $_ -ne $null } | ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))

#Region "Load Parameters from Parameter File"

#Load and parse Parameter File
$JsonParameters = Get-Content $TemplateParametersFile -Raw | ConvertFrom-Json
if ($null -ne ($JsonParameters | Get-Member -Type NoteProperty 'parameters')) {
    $JsonParameters = $JsonParameters.parameters
}

#Set main Deployment Parameter Drivers
$ArtifactsSaBaseUri = $JsonParameters | Select-Object -Expand 'artifactsSaBaseUri' -ErrorAction Ignore | Select-Object -Expand 'value' -ErrorAction Ignore
$BaseName = $JsonParameters | Select-Object -Expand 'baseName'-ErrorAction Ignore | Select-Object -Expand 'value' -ErrorAction Ignore
$Environment = $JsonParameters | Select-Object -Expand 'environment'-ErrorAction Ignore | Select-Object -Expand 'value' -ErrorAction Ignore
$ServiceLayer = $JsonParameters | Select-Object -Expand 'settings'-ErrorAction Ignore | Select-Object -Expand 'value' | Select-Object -Expand 'common' | Select-Object -Expand 'serviceLayer' -ErrorAction Ignore
$ApplicationId = $JsonParameters | Select-Object -Expand 'settings'-ErrorAction Ignore | Select-Object -Expand 'value' | Select-Object -Expand 'common' | Select-Object -Expand 'applicationId' -ErrorAction Ignore
Write-Verbose "baseName: $BaseName" -Verbose
Write-Verbose "environment: $Environment" -Verbose

$splitUri = $ArtifactsSaBaseUri.Split('/')

if ($ArtifactsSaBaseUri -eq '$(artifactsSaBaseUri)') {

    $StorageAccountName = ($BaseName + $Environment + 'sa' + $ServiceLayer.ToLower() + 'global' )
    $StorageContainerName = 'armresources'
    Write-Verbose "StorageAccountName: $StorageAccountName" -Verbose
    Write-Verbose "ContainerName: $StorageContainerName" -Verbose

}
elseif (($ArtifactsSaBaseUri.Substring($ArtifactsSaBaseUri.Length - 1)) -eq '/') {

    throw 'Please Remove the last "/" from artifactsSaBaseUri parameter in the parameter File'
}
else {

    $StorageContainerName = $splitUri[$splitUri.Length - 1].ToString()
    $splitStorageAccountName = $splitUri[$splitUri.Length - ($splitUri.Length - 2)]
    $splitStorageAccountName = $splitStorageAccountName.Split('.')
    $StorageAccountName = $splitStorageAccountName[0]
    Write-Verbose "StorageAccountName: $StorageAccountName"  -Verbose
    Write-Verbose "ContainerName: $StorageContainerName"  -Verbose

}

$ArtifactsSaSasToken = $JsonParameters | Select-Object -Expand 'artifactsSaSasToken' -ErrorAction Ignore | Select-Object -Expand 'value' -ErrorAction Ignore

$ResourcesLocation = $JsonParameters | Select-Object -Expand 'settings'-ErrorAction Ignore `
| Select-Object -Expand 'value' -ErrorAction Ignore `
| Select-Object -Expand 'common' -ErrorAction Ignore `
| Select-Object -Expand 'region' -ErrorAction Ignore
Write-Verbose "ResourcesLocation: $ResourcesLocation" -Verbose

if (-Not($ServiceLayer)) {

    $CommonResourceGroupName = ('RG-' + $ApplicationId + '-' + $BaseName + '-' + $Environment + '-COMMON').ToUpper()
}
else {

    $CommonResourceGroupName = ('RG-' + $ApplicationId + '-' + $BaseName + '-' + $Environment + '-COMMON-' + $ServiceLayer).ToUpper()

}

Write-Verbose "CommonResourceGroupName: $CommonResourceGroupName" -Verbose
#endRegion

#Region "Setup Artifacs in Storage Account for Link Templates"
if ($UploadArtifacts) {
    # Convert relative paths to absolute paths if needed
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
    Write-Verbose "ArtifactsDirectory: $ArtifactStagingDirectory" -Verbose

    # Create the storage account if it doesn't already exist
    $StorageAccount = (Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName })
    if ($null -eq $StorageAccount) {
        $StorageResourceGroupName = $CommonResourceGroupName
        New-AzResourceGroup -Location "$ResourcesLocation" -Name $StorageResourceGroupName -Force
        Write-Verbose $StorageAccountName -Verbose
        Write-Verbose $StorageResourceGroupName -Verbose
        Write-Verbose $ResourcesLocation -Verbose
        $StorageAccount = New-AzStorageAccount -StorageAccountName $StorageAccountName -Type 'Standard_LRS' -ResourceGroupName $StorageResourceGroupName -Location "$ResourcesLocation"
    }

    #Check if container already exist)
    if (-Not(Get-AzStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context -ErrorAction SilentlyContinue) ) {
        New-AzStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context
    }

    # Copy files from the local storage staging location to the storage account container
    Get-ChildItem $ArtifactStagingDirectory -Recurse -File | Set-AzStorageBlobContent -Container $StorageContainerName -Context $StorageAccount.Context -Force


    if (('$(artifactsSaSasToken)' -eq $ArtifactsSaSasToken) -or ('$(artifactsSaBaseUri)' -eq $ArtifactsSaBaseUri) ) {
        
        # Generate a 4 hour SAS token for the artifacts location if one was not provided in the parameters file
        $ArtifactsSaSasToken = ConvertTo-SecureString -AsPlainText -Force `
        (New-AzStorageContainerSASToken -Container $StorageContainerName -Context $StorageAccount.Context -Permission r -ExpiryTime (Get-Date).AddHours(4))
             
        $ArtifactsSaBaseUri = $StorageAccount.Context.BlobEndPoint + $StorageContainerName
        Write-Verbose "ArtifactsSaBaseUri: $ArtifactsSaBaseUri" -Verbose
        Write-Verbose "Updating Parameter File" -Verbose
        $OptionalParameters['artifactsSaBaseUri'] = $ArtifactsSaBaseUri
        $OptionalParameters['artifactsSaSasToken'] = $ArtifactsSaSasToken
    }
}
#endRegion

#Region "Validation"
if ($ValidateOnly) {

    Write-Verbose "Starting ARM Template Deployment Validation..." -Verbose
    $ErrorMessages = Format-ValidationOutput (Test-AzDeployment -Location $ResourcesLocation `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $TemplateParametersFile `
            @OptionalParameters)
    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
    }
    else {
        Write-Output '', 'Template is valid.'
    }
}
#endRegion

#Region "Deployment"
else {

    Write-Verbose "Starting ARM Template Subscription Level Deployment..." -Verbose
    New-AzDeployment -Name ($BaseName + $Environment + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $TemplateParametersFile `
        @OptionalParameters `
        -Location $ResourcesLocation `
        -Verbose
    Write-Verbose "ARM Template Deployment Completed..." -Verbose   
    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    }
}
#endRegion