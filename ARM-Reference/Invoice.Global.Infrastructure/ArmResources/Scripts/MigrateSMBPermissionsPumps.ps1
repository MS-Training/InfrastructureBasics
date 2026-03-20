
# Create mapping for the drives from Source to Target
$driveMap = @{
    "d" = "h";
    "f" = "i";
}
function splitPath {
    param($sourcePath)
    $splits = $sourcePath.Split(":")
    $mappedDrive = $driveMap[$splits[0]]
    if ([string]::IsNullOrEmpty($mappedDrive)) {   
        $targetPath = $sourcePath
    }
    else {           
        $targetPath = $mappedDrive, $splits[1] -join ":"
    }
    return $targetPath
}
function getSmbShare {
    param(
        $serverName
    )
    # Get SMB shares in the server
    $remotesshare = Invoke-Command -ComputerName $serverName -ScriptBlock { 
        Get-SmbShare -Special $false
    }
    $filteredSmb = $remotesshare 
    # | Where-Object {($_.Name -eq 'CMODSNEW') -or ($_.Name -eq 'CpumpNewLogs')}
    return $filteredSmb
}
function getSmbShareAccess {
    param($smbShares, $serverName)
    # For each SMB, get the accounts who have any special permissions
    $smbShareAccess = Invoke-Command -ComputerName $serverName -ScriptBlock {
        $eachSmbPermissions = new-object psobject
        $smbPermissions = @()
        Foreach ($smbShare in $args) {
            $eachSmbPermissions = Get-SmbShareAccess -Name $smbShare.Name
            $smbPermissions += $eachSmbPermissions
        }
        return $smbPermissions
    } -ArgumentList $smbShares
    return $smbShareAccess
}
function setSmbPermissions {
    param(
        $smbShares,
        $smbPermissions
    )

    foreach ($smbShare in $smbShares) {
        try {
            
            # Check if smb share already exists for a given name
            $existingSmb = Get-SmbShare -Name $smbShare.Name -ea 0
            if ($existingSmB) { 
                Write-Host "$($smbShare.Name) already exists in target server" -Verbose
                continue
            }
            # Extract mapping path for drives on Target server
            $smbPath = splitPath $smbShare.Path
            if (Test-Path $smbPath) {         
                # Create SMB share that corresponds to source server and remove default permissions
                New-SmbShare -Name $smbShare.Name -Path $smbPath -Description $smbShare.Description -EncryptData $True
                Revoke-SmbShareAccess -Name $smbShare.Name -AccountName "Everyone" -Force -ErrorAction SilentlyContinue
            }
            else {
                Write-Host "$smbPath does not exist in target server" -Verbose
                continue 
            }
          
        }
        catch {
            Write-Host $_
        }
    }
    
    #Grant access rights to each account
    foreach ($permission in $smbPermissions) {
        try {
            Grant-SmbShareAccess -Name $permission.Name -AccountName $permission.AccountName -AccessRight $permission.AccessRight -Force
        }
        catch {
            Write-Host $_
        }
    }
}
<#
==============README=================
1. Fill in $driveMap dictionary for mapping source and target server drive maps
2. Run all the commands for Get SMB shares and SET smb shares
#>
$ErrorActionPreference = "SilentlyContinue"
Stop-Transcript | Out-Null
$ErrorActionPreference = "Continue"
Start-Transcript -Path "C:\AzureArmTemplates\logSMB8.txt" -append
$smbShares = Import-Csv -Path "C:\AzureArmTemplates\Pump-get-smbshare.csv"
$smbPermissions = Import-Csv -Path "C:\AzureArmTemplates\Pump-get-smbshareccess.csv"

setSmbPermissions $smbShares $smbPermissions
Stop-Transcript