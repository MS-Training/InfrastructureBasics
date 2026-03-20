<#
.SYNOPSIS
    Set SQL Mode authentication to either mixed mode or windows auth only
.DESCRIPTION
    Gets the sql instance of the server, changes the registry and restart sql if needed
.PARAMETER SQLJobPath
    Flag to set the sql auth
#>
param (
    $EnableMixedMode = $true
)

function Get-SQLInstance {

    $InstanceName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances | Select-Object -ExpandProperty InstalledInstances | Where-Object { $_ -eq 'MSSQLSERVER' }
    $InstanceFullName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -Name $InstanceName | Select-Object -ExpandProperty $InstanceName;

    return $InstanceFullName
}

function SetMode {
    param(
        [String] $Name,
        [Int] $Value,
        [String] $PropertyType,
        [String] $RegistryPath
    )

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Setting mode for $Name"
    $regValue = Get-ItemProperty -Path $RegistryPath -Name $Name
    if ($regValue.LoginMode -ne $Value) {
        
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Starting to Set Authentication Mode to $Value"

        if ((Get-Service -Name 'ClusSvc' -ErrorAction SilentlyContinue)) {

            $ActiveNode = (Get-ClusterGroup | Where-Object { $_.Name -like "*SQL*" }).OwnerNode
            $vmName = $env:ComputerName

            if ($Activenode -eq $vmName) {

                New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType $PropertyType -Force | Out-Null
                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Finished setting mode for $Name in the SQL Cluster"

            }
        }
        else {

            New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType $PropertyType -Force | Out-Null
            Restart-Service -Force MSSQLSERVER
            Start-Service -Name "SQLSERVERAGENT" 
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Finished setting mode for $Name"

        }
    }
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Finished SetMode function"
}

function Main {

    $InstanceFullName = Get-SQLInstance

    #Set SQLAuthentication mode to Mixed
    if ($EnableMixedMode) {      
        $Value = 2
    }
    else {
        $Value = 1
    }
    SetMode -Name 'LoginMode' -Value $Value -PropertyType 'DWORD' -RegistryPath "HKLM:\Software\Microsoft\Microsoft SQL Server\$InstanceFullName\MSSQLServer"
        
}

Main