param(
    [Parameter(Mandatory = $true)]
    $VMName,
    [Parameter(Mandatory = $true)]
    $ILBStaticIP,
    [Parameter(Mandatory = $true)]
    $ListenerName,
    [Parameter(Mandatory = $true)]
    $InstallerURI,
    [Parameter(Mandatory = $true)]
    $sqlImageOffer,
    [Parameter(Mandatory = $true)]
    $sysAdmins,
    [Parameter(Mandatory = $true)]
    $ClusterSetupAccount,
    [Parameter(Mandatory = $true)]
    $ClusterSetupPassword,
    [Parameter(Mandatory = $true)]
    [string] $SASToken)

#new-EventLog -LogName Application -source 'AzureArmTemplates' -ErrorAction SilentlyContinue


#region SQL Cluster Creation

try {

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Cluster SQL installation"
    
    $InstanceName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances -ErrorAction SilentlyContinue | Select-Object -ExpandProperty InstalledInstances | Where-Object { $_ -eq 'MSSQLSERVER' }         
    $InstanceFullName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -Name $InstanceName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $InstanceName;
    $ClusterName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$InstanceFullName\Cluster" -ErrorAction SilentlyContinue).ClusterName


    if (-not(Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue) -or (-not($ClusterName))) {
        $downloadFilesPath = "C:\SQLStartup\"
        $sqlSetupPath = "C:\SQLSetup\"
        $isPrimaryNode = $Env:ComputerName -eq ($VMName + '1')

        if ($isPrimaryNode) {
            $configFileName = "Config$sqlImageOffer.ini"
        }
        else {
            $configFileName = "ConfigAddNode$sqlImageOffer.ini"    
        }

        #1.Download SQL Iso and Sql Configuration.ini file Locally
        if (Test-Path $downloadFilesPath) {
            Remove-Item -Path $downloadFilesPath -Recurse
        }

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Downloading installation files from Storage"

        New-Item -Path $downloadFilesPath -ItemType Directory 
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($InstallerURI + "$sqlImageOffer.iso" + $sastoken, $downloadFilesPath + "$sqlImageOffer.iso")
        $WebClient.DownloadFile($InstallerURI + "$configFileName" + $sastoken, $downloadFilesPath + "$configFileName")
        $WebClient.DownloadFile($InstallerURI + "SSMS-Setup-ENU.exe" + $sastoken, $downloadFilesPath + "SSMS-Setup-ENU.exe")
                            
        #2. Mount iso copy Files to local Folder and Copy  Configuration.ini file in the same folder.
        if (Test-Path $sqlSetupPath) {
            Remove-Item -Path $sqlSetupPath -Recurse
        }

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Extracting installation files"
        New-Item -Path $sqlSetupPath -ItemType Directory
        $mountResult = Mount-DiskImage -ImagePath ($downloadFilesPath + "$sqlImageOffer.iso") -PassThru
        $volumeInfo = $mountResult | Get-Volume
        $driveInfo = Get-PSDrive -Name $volumeInfo.DriveLetter
        Copy-Item -Path ( Join-Path -Path $driveInfo.Root -ChildPath '*' ) -Destination $sqlSetupPath -Recurse
        Dismount-DiskImage -ImagePath ($downloadFilesPath + "$sqlImageOffer.iso")

        $ILBSubnetMask = $null
        $NetworkName = "Cluster Network 1"
        $Networks = Get-WmiObject Win32_NetworkAdapterConfiguration -EA SilentlyContinue | ? { $_.IPEnabled }
        foreach ($Network in $Networks) {            
            foreach ($subnet in $Network.IPSubnet) {
                if ($subnet -match '255.255.255') {
                    $ILBSubnetMask = $subnet
                }
            }
        }

        <#    Update Configuration.ini values of
            a. Need to look like this FAILOVERCLUSTERNETWORKNAME="MSSSB4DEVDMIVNN"
            b. Needs to look liket this FAILOVERCLUSTERIPADDRESSES="IPv4;10.106.224.10;Cluster Network 1;255.255.255.192"
            c. Modify the Cluster Setup Accounts AGTSVCACCOUNT & SQLSVCACCOUNT #>    
        #Update the INI File with the Cluster Specific values
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Updating INI File subnet mask: $ILBSubnetMask, ListenerName: $ListenerName, ClusterSetupAccount: $ClusterSetupAccount, SQLSysAdmins: $c "

        $a = $sysAdmins
        $b = '"' + $a -replace ",", '" "'
        $c = $b + '"'

        $keyValueList = @{
            FAILOVERCLUSTERNETWORKNAME = """$ListenerName"""
            AGTSVCACCOUNT              = """$ClusterSetupAccount"""
            SQLSVCACCOUNT              = """$ClusterSetupAccount"""
            SQLSYSADMINACCOUNTS        = "$c"
            FAILOVERCLUSTERIPADDRESSES = """IPv4;" + $ILBStaticIP + ";Cluster Network 1;" + $ILBSubnetMask + """"
        }                
        $FilePath = ($downloadFilesPath + $configFileName) 
        $content = Get-Content $FilePath
        $keyValueList.GetEnumerator() | ForEach-Object {
            if ($content -match "^$($_.Key)=") {
                $content = $content -replace "^$($_.Key)=(.*)", "$($_.Key)=$($_.Value)"
            }
        }
        $content | Set-Content $FilePath
                
        <#Copy modified .Ini into the same folder where the setup.exe is#>            
        Copy-Item ($downloadFilesPath + $configFileName) -Destination ($sqlSetupPath + $configFileName)

        #3. Start SQL install.
        Set-Location $sqlSetupPath
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Installing SQL Cluster from Schedule Task"
        $sqlSetupFilePath = $sqlSetupPath + "Setup.exe"
        $argList = $sqlSetupFilePath + " /SQLSVCPASSWORD=$ClusterSetupPassword /AGTSVCPASSWORD=$ClusterSetupPassword /ConfigurationFile=" + $sqlSetupPath + $configFileName
        schtasks /create /tn installSqlCluster /sc once /st (Get-Date -format HH:mm) /sd (Get-Date).AddDays(1).ToString("MM/dd/yyyy") /f /RL highest /ru $ClusterSetupAccount /rp $ClusterSetupPassword /tr $ArgList
        schtasks /run /tn installSqlCluster
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) SQL Installation Task was Triggered"
        Start-Sleep -Seconds 30
        schtasks /delete /tn installSqlCluster /f

        if ($isPrimaryNode) {
        
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Starting to check the status of the installation every 1 minute"

            $ctr = 0
            while (-not(Get-ClusterGroup -Name  "SQL Server (MSSQLSERVER)" -ErrorAction SilentlyContinue) -and $ctr -le 20) {
                Start-Sleep -Seconds 60
                $ctr++
                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) SQL Installation Check Number: $ctr"
            }
            $ctr = 0
            while ((Get-ClusterGroup -Name  "SQL Server (MSSQLSERVER)" -ErrorAction SilentlyContinue).State -ne "Online" -and $ctr -le 10) {
                Start-Sleep -Seconds 60
                $ctr++
                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) SQL Role Validation Check Number: $ctr"
            }
            if ((Get-ClusterGroup -Name  "SQL Server (MSSQLSERVER)").State -ne "Online") {
                Write-Error "SQL Failover Cluster creation failed to create SQL Role"
            }
            Get-Service -Name MSSQLSERVER -ErrorAction Stop
            #4. Update listener probe port to 50001
            $resourcename = (Get-ClusterResource | Where-Object { $_.Name -like "SQL IP Address*" }).Name
            $values = @{"Address" = "$ILBStaticIP"; "SubnetMask" = "$ILBSubnetMask"; "Network" = "$networkName"; "OverrideAddressMatch" = 1; "EnableNetBIOS" = 1; "ProbePort" = 50001 }
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Updating Listener Prope Port $values"
            Get-ClusterResource -Name $resourcename | Set-ClusterParameter -Multiple $values -ErrorAction Stop

            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Restarting SQL Role for Probe to take effect"
            $secureString = ConvertTo-SecureString $ClusterSetupPassword -AsPlainText -Force
            [System.Management.Automation.PSCredential ]$cred1 = New-Object System.Management.Automation.PSCredential ($ClusterSetupAccount, $secureString)               
            Invoke-Command -ScriptBlock {
                Stop-ClusterGroup -Name 'SQL Server (MSSQLSERVER)'
                Start-Sleep -Seconds 30
                Start-ClusterGroup -Name 'SQL Server (MSSQLSERVER)'
            } -Credential $cred1 -ComputerName localhost -ErrorAction Stop
            
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) SQL Failover Cluster has been successfully created"

        }
        else{
            $ctr = 0
            while (-Not (Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue) -and $ctr -le 20 ){
                Start-Sleep -Seconds 60
                $ctr++
                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) SQL Installation Check Number: $ctr"
            }
            Get-Service -Name MSSQLSERVER -ErrorAction Stop
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) This Node has been successfully added to the cluster"
        }

        $ssmsFilePath = $downloadFilesPath + "SSMS-Setup-ENU.exe"
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Installing SQL SSMS"
        Start-Process -FilePath $ssmsFilePath -ArgumentList "/install /quiet /norestart" -Wait
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) SQL SSMS Installation Completed"

    }
    else {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) SQL Instance is Already Installed Skipping this Script"
    }
}
    
catch [System.Exception] {
    throw $_
}

#endregion
