<#
.SYNOPSIS
    This post scripts applies customization to mltiple IaaS VMs created.
.DESCRIPTION
    this script will build storage pools
.PARAMETER DriveString
    This is the name of each disk wanted and the number of disks in each
    storage pool/drive. 
.PARAMETER ResiliencySetting
    This is almost always set to simple.
.PARAMETER OSAllocationUnitSize
    This is almost always set to the value 65536.
.PARAMETER InterleaveValue
    This is almost always set to 262144.
.OUTPUTS
    None.
#>
param (
    [string] $DriveString,    
    [string] $ResiliencySetting,
    [int32]  $OSAllocationUnitSize,
    [int32]  $InterleaveValue
)

                try {

                   # Change E: => F: to move DVD to F because E will be utilized as a data disk.
                    Write-Verbose "Change E: => F: to move DVD to F because E will be utilized as a data disk" -verbose
                    
                    $drive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'E:' AND DriveType = '5'"
                    if($drive) {
                        Set-WmiInstance -input $drive -Arguments @{DriveLetter="F:"}
                    }
                } 
                catch{
                    [string]$errorMessage = $Error[0].Exception
                    if([string]::IsNullOrEmpty($errorMessage) -ne $true) {
                        Write-Verbose $errorMessage -verbose
                    } else {$errorMessage}
                }

# Variables
$dictionary = @{ }
   
Write-Verbose "Creating hashtable of drives" -verbose
    
# Split input string into pairs
$dictionaryStep1 = $DriveString.split(',')

foreach ($pair in $DictionaryStep1) {
    $key, $value = $pair.Split(':')
    $dictionary[$key] = $value
}
    
Write-Verbose "Here are the drives and number of disks to be installed" -verbose

foreach ($drive in $dictionary.GetEnumerator()) {
    Write-Verbose "Drive letter: $($Drive.key) with $($Drive.value) disks" -verbose
}

###########################################################################################################################################################
# Create storage pools
###########################################################################################################################################################

$dataDiskNumberCnt = 2
            
foreach ($drive in $dictionary.GetEnumerator()) {
    if ($drive.key -eq "H") {
        $dataDiskNumber = 1
        $volumeName = "Data"
        $friendlyName = "Data-"
    }
    elseif ($drive.key -eq "E") {
        $dataDiskNumber = ""
        $volumeName = "Backups"
        $friendlyName = "Backups-"
    }
    elseif ($drive.key -eq "T") {
        $dataDiskNumber = 2
        $volumeName = "TempDB"
        $friendlyName = "TempDB-"
    }
    elseif ($drive.key -eq "O") {
        $dataDiskNumber = 1
        $volumeName = "Logs"
        $friendlyName = "Logs-"
    }
    elseif ($drive.key -eq "M") {
    $dataDiskNumber = 3
    $volumeName = "SQLSysFiles"
    $friendlyName = "SQLSysFiles-"
    }
    elseif ('HETO' -notmatch $drive.key) {
        $dataDiskNumber = $dataDiskNumberCnt
        $volumeName = "Data$dataDiskNumberCnt"
        $friendlyName = "Data$dataDiskNumberCnt-"
        $dataDiskNumberCnt ++
    }

    ###########################################################################################################################################################
    # Create storage pool
    ###########################################################################################################################################################
			   
    $driveName = "Data$dataDiskNumber"
			   
    Write-Verbose "Creating storage pool..." -verbose			   
			   
    # Select Available Disks
    $poolCount = Get-PhysicalDisk -CanPool $true | Sort-Object PhysicalLocation | Where-Object { $_.OperationalStatus -EQ "OK" }

    $availablePhysicalDisk = $poolCount | Measure-Object
    $driveLetter = $drive.key

    if (($availablePhysicalDisk.count -GT 0) -and -not(Get-WmiObject -Class win32_volume -Filter "DriveLetter = '${driveLetter}:'")) {

        if ($Drive.value -GT 0) { 
            $physicalDisks = $poolCount | Select-Object -First $Drive.value
        }
        else { 
            $physicalDisks = $poolCount
        }
                        
        Write-Verbose "Pool-able: $($PhysicalDisks.Count)" -verbose
                        
        $totalDiskSpace = ($physicalDisks | Measure-Object -Sum Size).Sum
        $totalDiskSpace = [Math]::Round(($totalDiskSpace / 1024 / 1024 / 1024 / 1024).ToDouble($null), 1)
                        
        Write-Verbose "Total space on raw poolable disk: $($TotalDiskSpace) TB" -verbose
        $newFriendlyName = "$($FriendlyName)$($totaldiskspace.ToString($null))TB"
                        
        if (Get-StoragePool -FriendlyName $newFriendlyName -ErrorAction SilentlyContinue) {
            $newFriendlyName += "_@$((Get-Date).ToString("yyyyMMdd-hhmm"))"
            Write-Verbose "Duplicate name found - appended date to storage pool name.  This can be renamed at a later point." -verbose
        }
        Write-Verbose "Derived pool name: $($newFriendlyName)" -verbose
                        
        $Pool = New-StoragePool -FriendlyName $newFriendlyName `
            -StorageSubSystemUniqueId (Get-StorageSubSystem -FriendlyName "*Storage*").uniqueID `
            -PhysicalDisks $physicalDisks
                        
        Write-Verbose "Pool created: $($Pool.FriendlyName)" -verbose
        $physicalDisks =$physicalDisks | Measure-Object
        $NumberOfColumns = $physicalDisks.Count
        if ($NumberOfColumns -gt 8) {
            $NumberOfColumns = 8 
        }
        $vDisk = $pool `
        | New-VirtualDisk -FriendlyName $driveName -Interleave $InterleaveValue `
            -NumberOfColumns $NumberOfColumns `
            -ResiliencySettingName $ResiliencySetting `
            -UseMaximumSize 
                        
        Write-Verbose "Virtual Disk created: $($VDisk.FriendlyName)" -verbose
        Write-Verbose "Initializing disk for use" -verbose
        $newVolume = $vDisk | Initialize-Disk -PartitionStyle GPT -PassThru `
        | New-Partition -AssignDriveLetter -UseMaximumSize
                        
        Write-Verbose "Disk letter $($NewVolume.DriveLetter) will be added to current partition" -verbose	
                        
                        
        if ($drive.key -NE "GG") {
            Set-Partition -NewDriveLetter $drive.key -DriveLetter $newVolume.DriveLetter -ErrorAction SilentlyContinue
        }
                        
        Write-Verbose "Please note the next command may raise a UI for formatting the drive." -verbose
                        
        $newVolume | Format-Volume -FileSystem NTFS `
            -NewFileSystemLabel $volumeName `
            -AllocationUnitSize $OSAllocationUnitSize `
            -Confirm:$false `
            -Force
    }
    else{
        Write-Verbose "There are no available Physical Disks to Create New Storage Pools" -Verbose
    }

}