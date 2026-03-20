<#
.SYNOPSIS
    This post scripts applies customization to multiple IaaS VMs created.
.DESCRIPTION
    After the VMs are created, this script will configure the following vms settings.
    ################This Scripts will Set Up All Needed Directories, NTFS Permissions and will share the parent folder ##################
.OUTPUTS
    None.
#>
param (
    [Parameter(Mandatory = $true)]
    [array] $Paths,
    [Parameter(Mandatory = $true)]
    [array] $Accounts
)
try {
    new-EventLog -LogName Application -source 'AzureArmTemplates' -ErrorAction SilentlyContinue
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Directories Event Log Source was Created"
    $PathsList = ($Paths).split(",")

    $isCluster= Get-Service -Name 'ClusSvc' -ErrorAction SilentlyContinue

    foreach ($Path in $PathsList) {

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The Path to be created is $Path"

        $driveExist = $true
        $drive = ($Path).split(":")
        
        if($isCluster){
            $driveExist = Get-WmiObject -Class win32_volume | Where-Object {$_.DriveLetter -match $drive[0]} -ErrorAction SilentlyContinue
        }

        if ((-Not (Test-Path $Path)) -and ($driveExist)) {
        
            New-Item -Path $Path -ItemType directory
            Add-NTFSAccess -Path $Path -Account "CREATOR OWNER" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
            Add-NTFSAccess -Path $Path -Account "NT AUTHORITY\SYSTEM" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
            Add-NTFSAccess -Path $Path -Account "BUILTIN\Administrators" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
            Add-NTFSAccess -Path $Path -Account "BUILTIN\Users" -AccessRights "ReadAndExecute" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow

            $AccountList = ($Accounts).split(",")
            foreach ($Account in $AccountList) {

                Add-NTFSAccess -Path $Path -Account $Account -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow

            }
        }

        $subFolderCount = ($path).split("\")
        $shareName = (Get-Item -Path "$Path").Name

        if($driveExist){

            if ((-Not (Get-SmbShare $shareName -ErrorAction SilentlyContinue)) -and ($subFolderCount.Count -eq 2) -and ($driveExist)) {

                New-SmbShare -Name $shareName -Path "$Path" -FullAccess 'Everyone'
    
            }
        }
        else{
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Drive $($drive[0]) does not exist. Skipping SMBShare Creation"
        }
        

    }
}
catch [System.Exception] {
    Write-Verbose "Error trying to create Directories and Shares" -Verbose
    Write-Verbose $_.Exception -Verbose
    throw
} 