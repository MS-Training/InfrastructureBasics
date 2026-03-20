param (
    [Parameter(Mandatory=$true)][string]$containerAccessOutputs,
    [string] $AppInsightsName,
    [string] $ResourceGroupName
    )


try {
#region Convert from json
$containerAccess = $containerAccessOutputs | convertfrom-json
#endregion

$DocumentType="Request", "Exception", "Custom Event", "Trace", "Metric", "Page Load", "Page View", "Dependency", "Availability", "Performance Counter"

#Linking appinsight with storage account 
New-AzApplicationInsightsContinuousExport -ResourceGroupName $ResourceGroupName -Name $AppInsightsName `
    -DocumentType $DocumentType -StorageAccountId $containerAccess.storageId.value -StorageLocation $containerAccess.storageLocation.value -StorageSASUri $containerAccess.blobContainerSASUri.value

Write-Host "AppInsight Continous Export complete"

} catch {
       Write-Host -ForegroundColor Red -BackgroundColor Black "Error in enabling continous export!"
       Write-Host -ForegroundColor Red -BackgroundColor Black $_
       throw
   }

