<#
.SYNOPSIS
    BCDR deployment for secondary region (before failover/DR)
.DESCRIPTION
    Deploy pre-req infrastructure changes for secondary region
#>
param (
    [string] $ResourceGroupName,
    [string] $StorageName
)

try {

    Install-Module PowerShellGet -Repository PSGallery -Force
    Install-Module Az -Repository PSGallery -AllowClobber
    Install-Module Az.Storage -Repository PSGallery -RequiredVersion 1.1.1-preview -AllowPrerelease -AllowClobber -Force -SkipPublisherCheck
   
    #failover
    Invoke-AzStorageAccountFailover -ResourceGroupName $resourceGroupName -Name $StorageName -Force -confirm:$false
    Set-AzStorageAccount -ResourceGroupName $resourceGroupName -AccountName $StorageName -SkuName Standard_GRS
	
   
}
catch {
    Write-Host -ForegroundColor Red -BackgroundColor Black "Error in AppInsightStorage failover"
    Write-Host -ForegroundColor Red -BackgroundColor Black $_
    throw
}