param(
    [Parameter(Mandatory = $true)]
    $ClusterSetupAccount,
    [Parameter(Mandatory = $true)]
    $ClusterSetupPassword,
    [Parameter(Mandatory = $true)]
    [string] $DriveString,
    [Parameter(Mandatory = $true)]
    [int32] $OSAllocationUnitSize
)

function ClusterS2DStorageExist {

    if (Get-Cluster -ErrorAction SilentlyContinue) {

        $clusterS2DStorage = Invoke-Command -ScriptBlock {
            Get-StoragePool | Where-Object {($_.FriendlyName -match "S2D")}
        } -Credential $cred1 -ComputerName localhost

        if ($clusterS2DStorage) {

            Write-Verbose 'Cluster S2D Storage is already enabled Skipping this PS' -Verbose
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Cluster S2D Storage is already enabled Skipping this PS"
            return $true

        }
        else {

            Write-Verbose 'We will start to create the S2D Storage Pool for the cluster' -Verbose
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "We will start to create the S2D Storage Pool for the cluster"
            return $false
        }

    }
    else {
    
        return $false

    }
}

#region Variable Declaration
$Errors = $null
$Shouldcontinue = $true
$secpasswd = ConvertTo-SecureString $ClusterSetupPassword -AsPlainText -Force
[System.Management.Automation.PSCredential ]$cred1 = New-Object System.Management.Automation.PSCredential ($ClusterSetupAccount, $secpasswd)
function o> {
    param([string]$logstring)
    $logstring

    if ($(Test-Path $logFile)) {
        Add-Content $Logfile -Value $logstring
    }
    else {
        Write-Host $logstring
    }
}
$logDir = "D:\Logs"
if ((Test-Path -Path $logDir) -eq $false) {
    New-Item -Path $logDir -ItemType directory
}

if (ClusterS2DStorageExist) {
    $Shouldcontinue = $false
}

$logfile = "$logDir\ConfigureS2D$($(get-date).toString(‘yyyyMMddhhmm’)).log"
Add-Content $Logfile -Value "$(Get-Date) #########################Configure S2D Cluster Storage##########################"
Add-Content $Logfile -Value "$(Get-Date) ################Running as $(whoami)###################"
#endregion

#region Cluster Storage Setup
if ($Shouldcontinue) {
    Invoke-Command {
        param($logfile)
        function w> {
            param([string]$logstring)
            $logstring

            if ($(Test-Path $logFile)) {
                Add-Content $Logfile -Value $logstring
            }
            else {
                Write-Host $logstring
            }
        }
        # Configure Virtual Disks
        w> "$(Get-Date) Enabling ClusterS2D"
        Enable-ClusterS2D -Confirm:$false
        w> "$(Get-Date) ClusterS2D has been enabled"
    
        w> "$(Get-Date) Starting to create Virtual Disks"
        # Split input string into pairs
        $dictionary = @{ }
        $DriveString = $using:DriveString
        $OSAllocationUnitSize = $using:OSAllocationUnitSize
    
        $dictionaryStep1 = $DriveString.split(',')
        foreach ($pair in $DictionaryStep1) {
            $key, [int64]$value = $pair.Split(':')
            $dictionary[$key] = $value
        }
        w> "$(Get-Date) Here are the drives and number of disks to be installed"
    
        foreach ($drive in $dictionary.GetEnumerator()) {
            w> "VirtualDrive letter: $($Drive.key) with Size of $($Drive.value) GB" -verbose
        }
    
        $dataDiskNameNumber = 2
        foreach ($drive in $dictionary.GetEnumerator()) {
            if ($drive.key -eq "H") {
                $accessPath = "H:"
                [int64]$Size = $drive.Value * 1024 * 1024 * 1024
                $volumeName = "Data"
            }
            elseif ($drive.key -eq "E") {
                $accessPath = "E:"
                [int64]$Size = $drive.Value * 1024 * 1024 * 1024
                $volumeName = "Backups"
            }
            elseif ($drive.key -eq "T") {
                $accessPath = "T:"
                [int64]$Size = $drive.Value * 1024 * 1024 * 1024
                $volumeName = "TempDB"
            }
            elseif ($drive.key -eq "O") {
                $accessPath = "O:"
                [int64]$Size = $drive.Value * 1024 * 1024 * 1024
                $volumeName = "Logs"
            }
            elseif ($drive.key -eq "M") {
                $accessPath = "M:"
                [int64]$Size = $drive.Value * 1024 * 1024 * 1024
                $volumeName = "SQLSysFiles"
            }
            elseif ('HETO' -notmatch $drive.key) {
                $volumeName = "Data$dataDiskNameNumber"
                $accessPath = -join ($drive.key, ":")
                [int64]$Size = $drive.Value * 1024 * 1024 * 1024
                $dataDiskNameNumber ++
            }
    
            New-Volume -StoragePoolFriendlyName S2D* -FriendlyName $volumeName -FileSystem NTFS -Size $Size -AccessPath $accessPath -AllocationUnitSize $OSAllocationUnitSize
    
        }
        w> "$(Get-Date) Virtual Disks have been created!"
    
        # Validate Cluster
        w> "$(Get-Date) Validating the cluster"
        Test-Cluster -ErrorAction Stop
        w> "$(Get-Date) Cluster Validation has completed"

    } -Credential $cred1 -ComputerName localhost -ArgumentList ($logfile)

}
#endregion

#region Throw Error
if ($ShouldContinue -eq $false) {

    if (ClusterS2DStorageExist) {

        o> "$(Get-Date) Cluster Storage Already Exist Skipping this PS"
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Cluster Already Exist Skipping this PS"
    }
    else {
        throw "S2D Cluster setup Failed with error: $Errors "
    }
    
}
o> "$(Get-Date) ######################Enable S2D Cluster Storage Completed#######################"
#endregion