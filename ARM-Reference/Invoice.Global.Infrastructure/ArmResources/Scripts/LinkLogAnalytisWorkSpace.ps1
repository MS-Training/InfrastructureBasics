<#
.SYNOPSIS
    This post scripts links workspace to VMs.
.DESCRIPTION
   Post failover of Vms, this script will link the provided workspace.
.OUTPUTS
    None.
#>
param (
    [Parameter(Mandatory = $true)]
    [string] $WorkspaceId,
    [Parameter(Mandatory = $true)]
    [string] $WorkspaceKey
)
try {
    $ErrorActionPreference = "SilentlyContinue"
    
    new-EventLog -LogName Application -source 'AzureArmTemplates' -ErrorAction SilentlyContinue
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "LinkLogAnalyticsWorkSpace Start linking workspace"

    $mma = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
    $mma.AddCloudWorkspace($WorkspaceId, $WorkspaceKey)
    $mma.ReloadConfiguration()

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "LinkLogAnalyticsWorkSpace Complete linking workspace"
}
catch [System.Exception] {
    Write-Verbose "Error trying to link workspace with Virtual Machine" -Verbose
    Write-Verbose $_.Exception -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -message "LinkLogAnalyticsWorkSpace Error linking workspace"
    throw
} 