<#
.SYNOPSIS
    This scripts attached data disks to VM.
.DESCRIPTION
    After the VMs are filed over, this script will build and attach disks
.PARAMETER ResourceGroupName
    This is the resource group used for the VMs
.PARAMETER VMName
    This is the name of the VM
.PARAMETER numberOfInstances
    The number of VMs with the given name.
.PARAMETER NewDiskSize
    This is the size of each new disk created (NOT each storage pool)
.PARAMETER DiskType
    This is usually set to Premium_LRS. It can also be set to Standard_LRS.
.PARAMETER CacheSetting
    This is almost always set to ReadOnly for these purposes.
.PARAMETER $totalDisks
    This is the number of total disks to be attached to the VM 
.PARAMETER ResiliencySetting
    This is almost always set to simple.
.PARAMETER Test 
    This is to configure VMs post ASR test failover
.OUTPUTS
    None.
#>

[cmdletbinding()]

param (
    [string] $ResourceGroupName,
    [string] $VMName,
    [int]    $numberOfInstances,
    [int]    $NewDiskSize = 1024,
    [string] $DiskType = "Premium_LRS",
    [string] $CacheSetting = "ReadOnly",
    [int]    $totalDisks = 10,
    [string] $ResiliencySetting = "simple",
    [string] $TestMode = "Yes"
)

$ErrorActionPreference = "Stop"

try {

    Write-Verbose "Set execution policy" -verbose
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process -force 

    ###########################################################################################################################################################
    # Find VM
    ###########################################################################################################################################################
    
    Write-Verbose "Creating list of VMs" -verbose
     
    $listOfVms = @()

    if ($numberOfInstances -gt 1) {
        for ($i = 1; $i -lt $numberOfInstances + 1; $i++) {
            if ($TestMode -eq "Yes") {
                $listOfVms += $VMName + $i + '-test'
            }
            else {
                $listOfVms += $VMName + $i
            }
        }
    }
    else {
        if ($TestMode -eq "Yes") {
            $listOfVms += $VMName + '-test'
        }
        else {
            $listOfVms += $VMName 
        }
    }

    Write-Verbose "Here are a list of all the VMs:" -verbose

    foreach ($vmMember in $listOfVms) {
        Write-Verbose "$VMMember" -verbose
    }

    ###########################################################################################################################################################
    # Begin a for loop for each VM created
    ###########################################################################################################################################################

    workflow AddDiskFlow {

        Param(
            [string[]] $listOfVms,
            [string] $ResourceGroupName,
            [int] $totalDisks,
            [int] $NewDiskSize,
            [string] $CacheSetting
        ) 


        function DoWork($launchedVM , $ResourceGroupName, $totalDisks, $NewDiskSize, $CacheSetting) {

            $vm = Get-AzVm -ResourceGroupName $ResourceGroupName -Name $launchedVM
        
            if (!($vm)) {
                Write-Verbose "VM [$($LaunchedVM)] not found" -verbose
            } 
            else {
                Write-Verbose "VM [$($LaunchedVM)] found in $($ResourceGroupName)" -verbose 
                Write-Verbose "Attaching $($totalDisks) $($NewDiskSize) disk(s) to $($VM.Name) - Server currently has $($vm.StorageProfile.DataDisks.Count) disks already assigned." -verbose


                ###########################################################################################################################################################
                # Begin attaching disk
                ###########################################################################################################################################################

                $vm = Get-AzVm -ResourceGroupName $ResourceGroupName -Name $launchedVM

                Write-Verbose " Resource group: $($vm.ResourceGroupName) and provided total disk count $totalDisks" -verbose
                # Identify the exisitng disks LUN on this VM to ensure no name conflicts
                $existingLUN = $($vm.StorageProfile.DataDisks).Lun
                Write-Verbose " Existing Lun found: $($existingLUN) with $($vm.StorageProfile.DataDisks.Count) disks" -verbose
    
                for ($diskNum = 1; $diskNum -LE $($totalDisks); $diskNum++) {

                    $newLun = $diskNum

                    $diskName = "$($vm.Name.toUpper())-DATADISK-$($newLun)"

                    #Skip the drive name with existing SQL data disk LUN to avoid conflict.As one number will be skip $totalDisks +1 to take care of total number of disk

                    if ($newLun -eq $existingLUN) {   
                        if (Get-AzDisk -DiskName $diskName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue) {
                            Remove-AzDisk -DiskName $diskName -ResourceGroupName $ResourceGroupName -Confirm:$false -Force
                        }
            
                        $totalDisks = $totalDisks + 1
                        continue
                    }

                    Write-Verbose " Checking for disk name conflicts: $($diskName)" -verbose

                    $dataDisk = Get-AzDisk -ResourceGroupName $vm.ResourceGroupName | Where-Object { $_.Name -EQ $diskName }
    
                    if ($vm.StorageProfile.DataDisks | Where-Object { $_.Name -EQ $diskName }) { 
                        Write-Verbose "  Disk named $($diskName) already added to VM." -verbose
           
                    } 
                    else { 
                        Write-verbose "  Adding $($diskName) to VM." -verbose
                        Add-AzVMDataDisk -VM $vm -Name $diskName -ManagedDiskId $dataDisk.Id -Lun $newLun -CreateOption Attach -Caching $cacheSetting
                        Write-Verbose "  Add $($diskName) to VM completed." -verbose
                    }
                    Write-Verbose "Lun $($NewLun) added for disk ($($datadisk.Id))" -verbose
        
                }
    
                Write-Verbose " Current disks attached: $($vm.StorageProfile.DataDisks.Count)" -verbose
                Write-Verbose " Updating $($vm.Name) to register new disks" -verbose
                Update-AzVM -VM $vm -ResourceGroupName $vm.ResourceGroupName
                Write-Verbose " Total disks attached: $($vm.StorageProfile.DataDisks.Count)" -verbose
                Write-Verbose " Completed update to $($vm.Name)" -verbose 

                ###########################################################################################################################################################
                # End attaching disk
                ###########################################################################################################################################################
            
                Write-Verbose "Disk attachment completed on $($VM.Name)" -verbose
                Write-Verbose "Done" -verbose
            }

            Write-Verbose "VM setup for $($vm.name) has finished." -verbose

        }

        foreach -parallel ($launchedVM in $listOfVms) { DoWork -launchedVM $launchedVM -ResourceGroupName $ResourceGroupName -totalDisks $totalDisks -NewDiskSize $NewDiskSize -CacheSetting $CacheSetting }
    }

    #Eventhough this script is running through Azure powersehll task but Powershell workflow still need to run Connect to run commands on Azure

    AddDiskFlow -listOfVms $listOfVms -ResourceGroupName $ResourceGroupName -totalDisks $totalDisks -NewDiskSize $NewDiskSize -CacheSetting $CacheSetting

    Write-Verbose "Multiple VM Setup has finished." -verbose
}
catch {
    Write-Verbose "Error trying to apply post script to multiple VM deployment!" -Verbose
    Write-Verbose $_.Exception -Verbose
    throw
} 

