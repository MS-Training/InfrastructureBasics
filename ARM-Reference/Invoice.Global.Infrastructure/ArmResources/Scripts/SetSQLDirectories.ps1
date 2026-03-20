<#
.SYNOPSIS
    This script will create and set NTFS permissions to SQL Directories.
.DESCRIPTION
    After the VMs are created, this script will configure the following vms settings.
    ################This Scripts will Set Up All Needed Directories, NTFS Permissions for SQL Server##################
.OUTPUTS
    None.
#>
param (
    [string] $SQLDriveList = "H,M,O,D",
    [string] $Accounts
)

$SqlInitialPath = ":\MSSqlServer\MSSQL\DATA"
new-EventLog -LogName Application -source 'AzureArmTemplates' -ErrorAction SilentlyContinue

function Set-NTFSPermissions {
    param (
        [string] $Path,
        [string] $Accounts
    )

    #Adding the Rule
    Add-NTFSAccess -Path $Path -Account "CREATOR OWNER" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    Add-NTFSAccess -Path $Path -Account "BUILTIN\Users" -AccessRights "ReadAndExecute" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    Add-NTFSAccess -Path $Path -Account "NT AUTHORITY\SYSTEM" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    Add-NTFSAccess -Path $Path -Account "BUILTIN\Administrators" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    Add-NTFSAccess -Path $Path -Account "NT SERVICE\MSSQLSERVER" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    Add-NTFSAccess -Path $Path -Account "NT SERVICE\SQLSERVERAGENT" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow

    #Adding Service Accounts
    if($Accounts){

        $AccountList = ($Accounts).split(",")
        foreach ($Account in $AccountList) {

            Add-NTFSAccess -Path $Path -Account $Account -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow

        }
    }

}

function Build-Path{
    param (
        [string] $Path
    )

    if (-Not (Test-Path $Path)) {

        New-Item -Path $Path -ItemType directory

    }
    
    Set-NTFSPermissions -Path $Path -Accounts $Accounts
}

function Get-SQLInstance{

    $InstanceName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances | Select-Object -ExpandProperty InstalledInstances | Where-Object { $_ -eq 'MSSQLSERVER' }
    $InstanceFullName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -Name $InstanceName | Select-Object -ExpandProperty $InstanceName;

    return $InstanceFullName
}

function Configure-SQLDirectories{

    $InstanceFullName = Get-SQLInstance
    $SQLDriveList = $SQLDriveList.split(',')

    foreach($drive in $SQLDriveList) {
        $driveExist = Get-WmiObject -Class win32_volume | Where-Object {$_.DriveLetter -match $drive}
        
        if($driveExist){

            $Path = $drive + $SqlInitialPath
            $Path = $Path.replace('MSSqlServer', $InstanceFullName)
            Build-Path -Path $Path
            $ErrorPath = $(split-path $("$Path") -Parent) + "\Log"
            Build-Path -Path $ErrorPath
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Directory $Path has been created"
        
        }
        else{

            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Drive $drive does not exist"

        }
       
    }

}

Configure-SQLDirectories
