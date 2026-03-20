<#
.SYNOPSIS
    Executes subinacl.exe, giving full permissions on the listed
    services to the specified account .
.DESCRIPTION
    Given a list of services, provides full permissions to the
    specified account to manage those services.

    e.g.
    ExecuteSubInAcl `
        -Services "service1,service2,service3"
        -Account 'REDMOND\mssprxyi'

    This will run the commands:
        subinacl.exe /service service1 /grant=REDMOND\mssprxyi=F
        subinacl.exe /service service2 /grant=REDMOND\mssprxyi=F
        subinacl.exe /service service3 /grant=REDMOND\mssprxyi=F
#>

[CmdletBinding()]
param (
    # Comma-separated list of services you want to grant full (F)
    # permissions to the specified account.
    [Parameter(Mandatory = $true)]
    [string] $SubInAclServices,

    # e.g. 'domain\user'
    [Parameter(Mandatory = $true)]
    [string] $ProxyAccount,

    # Executable path. Can override in case the path changes.
    [Parameter(Mandatory = $true)]
    [string] $SubInAclExePath
)


function main {
    Write-Host "Executing subinacl.exe on services $SubInAclServices"
    foreach ($service in $SubInAclServices.Split(',')) {
        if (!(Get-Service $service)) {
            Write-Host "[INFO] Service $service does not exist on this server. Skipping..."
            continue
        }

        try {
            Write-Host "[INFO] Executing command: $SubInAclExePath /service $service /grant=$ProxyAccount=F"
            & $SubInAclExePath /service $service /grant=$ProxyAccount=F
        }
        catch {
            Format-List -InputObject $PSItem.InvocationInfo
            Format-List -InputObject $_.Exception -Force
            throw
            Write-Host "[WARNING]: Could not grant $ProxyAccount permissions to service $service; possibly because it does not exist."
        }
    }
    Write-Host "[INFO] Finished granting permissions to $ProxyAccount"
}

main
