<#
.SYNOPSIS
	Geneva startup configuration
.DESCRIPTION
    Configures geneva startup script.
.OUTPUTS
    None
#>

param(
    [Parameter(Mandatory = $true)]
    $MonitoringTenant,
    [Parameter(Mandatory = $true)]
    $MonitoringRole,
    [Parameter(Mandatory = $true)]
    $MonitoringRoleInstance,
    [Parameter(Mandatory = $true)]
    $MonitoringGcsAccount,
    [Parameter(Mandatory = $true)]
    $MonitoringGcsNamespace,
    [Parameter(Mandatory = $true)]
    $MonitoringGcsEnvironment,
    [Parameter(Mandatory = $true)]
    $MonitoringGcsRegion,
    [Parameter(Mandatory = $true)]
    $MonitoringConfigVersion,
    [Parameter(Mandatory = $true)]
    $MonitoringGcsCertStore,
    [Parameter(Mandatory = $true)]
    $MonitoringGcsThumprint)

$Path = "C:\"
$GenevaAgentDir = "GenevaAgent\"
$GenevaAgent = "MonAgentClient.ps1"

[Environment]::SetEnvironmentVariable("MONITORING_TENANT", $MonitoringTenant, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("MONITORING_ROLE", $MonitoringRole, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("MONITORING_ROLE_INSTANCE", $MonitoringRoleInstance, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("MONITORING_DATA_DIRECTORY", "${env:LOCALAPPDATA}\Monitoring", [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("MONITORING_GCS_ACCOUNT", $MonitoringGcsAccount, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("MONITORING_GCS_NAMESPACE", $MonitoringGcsNamespace, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("MONITORING_GCS_ENVIRONMENT", $MonitoringGcsEnvironment, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("MONITORING_GCS_REGION", $MonitoringGcsRegion, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("MONITORING_CONFIG_VERSION", $MonitoringConfigVersion, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("MONITORING_GCS_CERTSTORE", $MonitoringGcsCertStore, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable("MONITORING_GCS_THUMBPRINT", $MonitoringGcsThumprint, [EnvironmentVariableTarget]::Machine)

$clientLocation = [Environment]::GetEnvironmentVariable("MonAgentClientLocation", [EnvironmentVariableTarget]::Machine)

$script = "${clientLocation}\MonAgentClient.exe -useenv"

try {
    New-Item -Path $Path -Name $GenevaAgentDir -ItemType "directory" -Force
    New-Item -Path ($Path + $GenevaAgentDir) -Name $GenevaAgent -ItemType "file" -Value $script -Force

    $psFile = ($Path + $GenevaAgentDir + $GenevaAgent)
    $taskName = "GenevaAgentMonitor"
    $genevaAgentMonitor = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    if ($genevaAgentMonitor) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }

    $trigger = New-ScheduledTaskTrigger -AtLogon -RandomDelay 00:00:30
    $action = New-ScheduledTaskAction -Execute "powershell.exe -ExecutionPolicy Unrestricted -File ${psFile} -NoNewWindow -Wait"
    Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -User "System"
}
catch {
    Write-Verbose "Error trying to to create Geneva Agent Monitor" -Verbose
    Write-Verbose $_.Exception -Verbose
    throw
}





