<#
.SYNOPSIS
    BCDR deployment for secondary region (before failover/DR)
.DESCRIPTION
    Deploy pre-req infrastructure changes for secondary region
#>
param (
    [string] $primaryResourceGroupName,
    [string] $secResourceGroupName,
    [string] $secondaryLocation,
    [string] $primarySubId,
    [string] $secondarySubId
)

try{
    ############AppInsight rule configuration for secondary region###############
    # accessing primary region to get rules
    Get-AzSubscription -SubscriptionId $primarySubId | Set-AzContext

    # Fetching primary region montioring 
    $MonitoringRules = Get-AzScheduledQueryRule -ResourceGroupName $primaryResourceGroupName  -WarningAction Ignore
    
    # setting secondary region to set rules
    Get-AzSubscription -SubscriptionId $secondarySubId | Set-AzContext
    
    #Create same rules for secondary region
    foreach($MonitoringRule in $MonitoringRules)
    {
    $Name = $AppInsightRule.Name
     New-AzScheduledQueryRule -ResourceGroupName $SecResourceGroupName -Name $Name -Source $MonitoringRule.Source -Action $MonitoringRule.Action `
     -Schedule $MonitoringRule.Schedule -Location $secondaryLocation -Enabled true
    }
    
    } catch {
        Write-Host -ForegroundColor Red -BackgroundColor Black "Error trying to copy monitoring rule to new region!"
        Write-Host -ForegroundColor Red -BackgroundColor Black $_
        throw
}