param(
    [Parameter(Mandatory = $true)]
    $ClusterName,
    [Parameter(Mandatory = $true)]
    $VMName,
    [Parameter(Mandatory = $true)]
    $InstanceCount,
    [Parameter(Mandatory = $true)]
    $saName,
    [Parameter(Mandatory = $true)]
    $accessKey,
    [Parameter(Mandatory = $true)]
    $ClusterSetupAccount,
    [Parameter(Mandatory = $true)]
    $ClusterSetupPassword,
    [Parameter(Mandatory = $true)]
    [string] $DriveString,
    [Parameter(Mandatory = $true)]
    [int32] $OSAllocationUnitSize
)
function ClusterExist {

    if (Get-Cluster -ErrorAction SilentlyContinue) {

        $clusterGroups = Invoke-Command -ScriptBlock {
            Get-ClusterGroup | Where-Object { ($_.IsCoreGroup -eq $False) -and ($_.GroupType -ne "ClusterStoragePool") }
        } -Credential $cred1 -ComputerName localhost

        if ($clusterGroups) {

            Write-Verbose 'Cluster Group Exist Skipping this PS' -Verbose
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Cluster Group Exist Skipping this PS"
            return $true

        }
        elseif (((Get-Cluster -ErrorAction SilentlyContinue | Get-ClusterNode | Measure-Object).Count) -eq $InstanceCount) {

            Write-Verbose 'Number of Instances is equal to the number of cluster nodes in this cluster Skipping this PS' -Verbose
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Number of Instances is equal to the number of cluster nodes in this cluster Skipping this PS"
            return $true
    
        }
        else {

            Write-Verbose 'We will start to create a cluster' -Verbose
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Cluster Validations tell us that we need to create a cluster"
            return $false
        }

    }
    else {
    
        return $false

    }
}

#region Variable Declaration
$Errors = $null
$workingdir = $pwd
$Shouldcontinue = $true
$serverdomain = (Get-WmiObject Win32_ComputerSystem).Domain
$LocalMachineName = $env:computername
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

#Validate if a Cluster and Cluster Role exist so that it won't be delete an existing role
if (ClusterExist) {
    $Shouldcontinue = $false
}

$logfile = "$logDir\ConfigureS2D$($(get-date).toString(‘yyyyMMddhhmm’)).log"
Add-Content $Logfile -Value "$(Get-Date) #########################Configure S2D Cluster##########################"
Add-Content $Logfile -Value "$(Get-Date) ################Running as $(whoami)###################"
#endregion

#region Checking if the other nodes are discovered via DNS
if ($Shouldcontinue) {
    o> "$(Get-Date) Checking if the other nodes are discovered via DNS"
    try {
        #start-sleep -Seconds 1200
        $ClusterNodes = @()
        if (($VMName.Length -gt 0) -and ($InstanceCount -gt 0)) {
            for ($icount = 1; $icount -le $InstanceCount; $icount++) {
                $ClusterNodes = $ClusterNodes + "$VMName$icount.$serverdomain"
            }
        }
        @($ClusterNodes) | Foreach-Object { 
            if ([string]::Compare(($_).Split(".")[0], $LocalMachineName, $true) -ne 0) { 
                while ($true) {
                    if (Test-Connection $_ -ErrorAction SilentlyContinue) {
                        o> "$(Get-Date) Able to ping the node: $_"
                        break;
                    }
                    else {
                        o> "$(Get-Date) Not able to ping the node: $_ , Sleeping for 1 minute"
                        Start-Sleep -Seconds 60  
                    }
                }
            }
        }
    }
    catch [System.Exception] {
        $ErrorMessage = $_
        $ShouldContinue = $false
        $Errors += "[E] : Could not sleep:  $_.Exception.Message "
        o> "$(Get-Date) Error while discovering other nodes over DNS"
    }
}
#endregion

#region Cleanup
if ($Shouldcontinue) {
    try {
        $ClusterNodes = @()
        if (($VMName.Length -gt 0) -and ($InstanceCount -gt 0)) {
            for ($icount = 1; $icount -le $InstanceCount; $icount++) {
                $ClusterNodes = $ClusterNodes + "$VMName$icount.$serverdomain"
            }
        }
        o> "$(Get-Date) Going to cleanup the cluster if present"
        if (get-cluster) {
            remove-cluster -Force
        }
        Start-Sleep -Seconds 60
        foreach ($ClusterNode in $ClusterNodes) {
            if ([string]::Compare(($ClusterNode).Split(".")[0], $LocalMachineName, $true) -ne 0) {
                Invoke-Command -ScriptBlock {
                    Clear-ClusterNode -force
                }-Credential $cred1 -ComputerName $ClusterNode
            }
        }
        #@($ClusterNodes) | Foreach-Object { Clear-ClusterNode "$_" -Force } 
    }
    catch [System.Exception] {
        $ErrorMessage = $_
        $ShouldContinue = $false
        $Errors += "[E] :  Cleanup nodes failed:  $_.Exception.Message "
        o> "$(Get-Date) Cleanup nodes failed"
    }
}
#endregion

#region Enable CredSSP
if ($Shouldcontinue) {
    try {
        o> "$(Get-Date) Enable CredSSP for the Primary node to Create cluster"
        $workingdir = $pwd
        Set-Location wsman:
        Set-Location .\localhost
        set-item .\Service\Auth\CredSSP true
        set-item .\service\AllowUnencrypted true
        set-item .\service\EnableCompatibilityHttpListener true
        winrm qc /force
        start-sleep 15
        Enable-wsmancredssp -role client -delegatecomputer *.microsoft.com -Force
        Set-Location $workingdir.Path
    }
    catch [System.Exception] {
        $ErrorMessage = $_
        $ShouldContinue = $false
        $Errors += "[E] : Enable Credssp Failed:  $_.Exception.Message "
        o> "$(Get-Date) Enable Credssp Failed"
    }
}
#endregion

#region Cluster Creation
if ($Shouldcontinue) {
    try {
        o> "$(Get-Date) WSFC Creation"
        Invoke-Command -ScriptBlock {
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
            $serverdomain = $using:serverdomain
            $ClusterName = $using:ClusterName
            $VMName = $using:VMName
            $InstanceCount = $using:InstanceCount
            $saName = $using:saName
            $accessKey = $using:accessKey
            w> "$(Get-Date) Input::Cluster Name:  $ClusterName"
            w> "$(Get-Date) Input::Instance Count:  $InstanceCount"
            w> "$(Get-Date) Input::VMName:  $VMName"
            w> "$(Get-Date) Input::SAName:  $saName"
            import-module FailoverClusters
            $ClusterNodes = @()
            if (($VMName.Length -gt 0) -and ($InstanceCount -gt 0)) {
                for ($icount = 1; $icount -le $InstanceCount; $icount++) {
                    $ClusterNodes = $ClusterNodes + "$VMName$icount.$serverdomain"
                }
            }
            w> "$(Get-Date) Cluster Nodes are $ClusterNodes "
            Import-Module ServerManager
            $LocalMachineName = $env:computername                   
            #@($ClusterNodes) | Foreach-Object { Clear-ClusterNode "$_" -Force } 
            $CurrentCluster = $null
            $CurrentCluster = Get-Cluster 2> $null
            if ($CurrentCluster -ne $null) {
                throw "There is an existing cluster on this machine. Please remove any existing cluster settings from the current machine before running this script"
                exit 1
            }   
            $VLength = 4
            $Random = 1..$VLength | ForEach-Object { Get-Random -Maximum 9 }  
            $ClusterName = $ClusterName + [string]::join('', $Random)
            Start-Sleep -Seconds 5
            w> "$(Get-Date) Cluster Name: $ClusterName will be created on primary node"
            $result = New-Cluster -Name $ClusterName -NoStorage -Node $LocalMachineName -Verbose

            $CurrentCluster = $null
            $CurrentCluster = Get-Cluster

            if ($CurrentCluster -eq $null) {
                w> "$(Get-Date) Cluster Name: $ClusterName could not be created"
                throw "Cluster does not exist"
                exit 1
            }

            Start-Sleep -Seconds 5
            Stop-ClusterResource "Cluster Name" -Verbose
            w> "$(Get-Date) Stopping Cluster resource for Cluster Name: $ClusterName"
            $AllClusterGroupIPs = Get-Cluster | Get-ClusterGroup | Get-ClusterResource | Where-Object { $_.ResourceType.Name -eq "IP Address" -or $_.ResourceType.Name -eq "IPv6 Tunnel Address" -or $_.ResourceType.Name -eq "IPv6 Address" }
            $NumberOfIPs = @($AllClusterGroupIPs).Count

            Start-Sleep -Seconds 5
            $AllClusterGroupIPs | Stop-ClusterResource
            $AllIPv4Resources = Get-Cluster | Get-ClusterGroup | Get-ClusterResource | Where-Object { $_.ResourceType.Name -eq "IP Address" }
            $FirstIPv4Resource = @($AllIPv4Resources)[0]
		  
            Start-Sleep -Seconds 5
            $AllClusterGroupIPs | Where-Object { $_.Name -ne $FirstIPv4Resource.Name } | Remove-ClusterResource -Force
            $NameOfIPv4Resource = $FirstIPv4Resource.Name

            Start-Sleep -Seconds 5
            w> "$(Get-Date) Setting Cluster IP"
            Get-ClusterResource $NameOfIPv4Resource | Set-ClusterParameter -Multiple @{"Address" = "169.254.1.1"; "SubnetMask" = "255.255.0.0"; "Network" = "Cluster Network 1"; "OverrideAddressMatch" = 1; "EnableDHCP" = 0 }
            $ClusterNameResource = Get-ClusterResource "Cluster Name"
            $ClusterNameResource | Start-ClusterResource -Wait 60

            if ((Get-ClusterResource "Cluster Name").State -ne "Online") {
                w> "$(Get-Date) There was an error onlining the cluster name resource"
                throw "There was an error onlining the cluster name resource"
                exit 1
            }
            Start-Sleep -Seconds 60           
            w> "$(Get-Date) Going to add other nodes into the cluster"
            @($ClusterNodes) | Foreach-Object { 
                if ([string]::Compare(($_).Split(".")[0], $LocalMachineName, $true) -ne 0) { 
                    #Add-ClusterNode "$_" -NoStorage
                    while ($true) {
                        w> "$(Get-Date) Going to add the node: $_"
                        Add-ClusterNode "$_" -NoStorage
                        if ((get-clusternode -Name $_.Tostring() -ErrorAction SilentlyContinue) -ne $null ) {
                            w> "$(Get-Date) Node:$_ has been successfully added to the cluster"
                            break;
                        }
                        else {
                            w> "$(Get-Date) The Node $_ is not added to the Cluster , Sleeping for 1 minute"
                            Start-Sleep -Seconds 60  
                        }
                    }
		                       
                } 
            }

            ipconfig /registerdns
            w> "$(Get-Date) Starting to check for cluster dns resolution"
    
            while (-not (Resolve-DnsName $ClusterName)) {  
                ipconfig /registerdns                                    
                w> "$(Get-Date) Cluster DNS Resolution is not ready.We will retry in 5 minutes"
                Start-Sleep -Seconds 300
            }
         
            # Enable Cloud Witness
            w> "$(Get-Date) Going to add CloudWitness"
            #Convert storage Account name to lower case
            get-cluster | Set-ClusterQuorum –CloudWitness -AccountName $saName -AccessKey $accessKey
            w> "$(Get-Date) CloudWitness has been added"
            
        } -Credential $cred1 -ComputerName localhost -Authentication credssp -ArgumentList ($logfile)
    }
    catch [System.Exception] {
        $ErrorMessage = $_
        $ShouldContinue = $false
        $Errors += "[E] : Could not Create Cluster:  $_.Exception.Message "
        o> "$(Get-Date) Error while Creating Cluster"
    }
}
#endregion

#region Extract the Cluster name and Nodes
if ($Shouldcontinue) {
    try {
        $ClusterName = (Get-Cluster).Name
        $ClusterNodes = @()
        if (($VMName.Length -gt 0) -and ($InstanceCount -gt 0)) {
            for ($icount = 1; $icount -le $InstanceCount; $icount++) {
                $ClusterNodes = $ClusterNodes + "$VMName$icount.$serverdomain"
            }
        }	
    }
    catch [System.Exception] {
        $ErrorMessage = $_
        $ShouldContinue = $false
        $Errors += "[E] : Error while extracting Custer Name and Nodes:  $_.Exception.Message "
        o> "$(Get-Date) Error while extracting Custer Name and Nodes"
    }
	
    o> "$(Get-Date) Cluster Name:  $ClusterName"
    o> "$(Get-Date) Cluster Nodes are $ClusterNodes "
}
#endregion

#region Disable CredSSP
if ($Shouldcontinue) {
    try {
        o> "$(Get-Date) Disable CredSSP at Primary node"
        Disable-WSManCredSSP -Role client
    }
    catch [System.Exception] {
        $ErrorMessage = $_
        $ShouldContinue = $false
        $Errors += "[E] : Disble Credssp Failed:  $_.Exception.Message "
        o> "$(Get-Date) Disble Credssp Failed"
    }
}
#endregion

#region Throw Error
if ($ShouldContinue -eq $false) {

    if (ClusterExist) {

        o> "$(Get-Date) Cluster Already Exist Skipping this PS"
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Cluster Already Exist Skipping this PS"
    }
    else {
        throw "S2D Cluster setup Failed with error: $Errors "
    }
    
}
o> "$(Get-Date) ######################Setup S2D Cluster Completed#######################"
#endregion