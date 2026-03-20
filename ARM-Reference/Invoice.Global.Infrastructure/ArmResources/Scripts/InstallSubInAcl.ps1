<#
.SYNOPSIS
    Installs the subinacl.exe program from the specified .msi
    installer location.
.DESCRIPTION
    Downloads the .msi installer from $SubInAclInstallerLocation.
    Then it runs the installer at the dst location.

    The subinacl program lets you configure permissions on
    various objects such as folders, files, and services.

    It should not be heavily relied on, as it is no longer
    supported by Microsoft.
#>

[CmdletBinding()]
param (
    # Filepath where subinacl msi file is to be downloaded FROM
    [Parameter(Mandatory = $true)]
    [string] $SubInAclInstallerLocation,

    # Path where subinacl msi file is to be downloaded
    [Parameter(Mandatory = $true)]
    [string] $SubInAclMSIPath,

    # Override just in case the .exe path changes
    [Parameter(Mandatory = $true)]
    [string] $SubInAclExePath
)


function Install-Msi([string] $SubInAclMSIPath) {
    try {
        Write-Host "[INFO] Installing subinacl from $SubInAclMSIPath..."
        msiexec.exe /i $SubInAclMSIPath /quiet /norestart
        Write-Host "[INFO] Waiting to complete MSI installation..."

        # Sleep  while it installs in the background
        Start-Sleep -s 15
        Write-Host "[INFO] Install-MSI -Completed"
    }
    catch {
        Format-List -InputObject $PSItem.InvocationInfo
        Format-List -InputObject $_.Exception -Force
        Write-Host "[ERROR] Install-Msi failed with params:`n-SubInAclMSIPath: $SubInAclMSIPath"
        throw
    }
}

function Get-MSIFile([string] $Uri, [string] $DestinationPath) {
    Write-Host "[INFO] Downloading subinacl.msi from $Uri to destination $DestinationPath..."
    try {
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($Uri, $DestinationPath)
    }
    catch {
        Format-List -InputObject $PSItem.InvocationInfo
        Format-List -InputObject $_.Exception -Force
        Write-Host "[ERROR] Get-Executable failed with params:`n-Uri: $Uri`n-DestinationPath: $DestinationPath"
        throw
    }
}

function main {
    $SUBINACL_EXE = "subinacl.exe"
    $SUBINACL_MSI = "$SubInAclMSIPath\subinacl.msi"

    # Start from clean directory
    if (Test-Path $SubInAclMSIPath) {
        Remove-Item -Path $SubInAclMSIPath -Recurse
    }
    New-Item -Path $SubInAclMSIPath -ItemType Directory

    Get-MSIFile -Uri $SubInAclInstallerLocation -DestinationPath $SUBINACL_MSI
    Install-Msi $SUBINACL_MSI

    # Check that the operations were successful
    if (!(Test-Path -Path $SUBINACL_MSI -PathType Leaf)) {
        Write-Error -ErrorAction Stop -Message "[ERROR] Was not able to download subinacl.msi at $SUBINACL_MSI."
    }
    if (!(Test-Path -Path $SubInAclExePath -PathType Leaf)) {
        Write-Error -ErrorAction Stop -Message "[ERROR] The subinacl.exe file does not exist at $SubInAclExePath."
    }
}

main
