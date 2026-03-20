param(
    [Parameter(Mandatory = $true)]
    $ILBStaticIP,
    [Parameter(Mandatory = $true)]
    $ClusterSetupAccount,
    [Parameter(Mandatory = $true)]
    $ClusterSetupPassword,
    [Parameter(Mandatory = $true)]
    $clusterRoleName,
    [Parameter(Mandatory = $true)]
    $CFileServerNewRoleName,
    [Parameter(Mandatory = $true)]
    $PowershellScheduleTaskBlobUrl,
    [Parameter(Mandatory = $true)]
    [string] $SASToken)

#new-EventLog -LogName Application -source 'AzureArmTemplates' -ErrorAction SilentlyContinue
try {   
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Addition of File Server Role"
        $downloadFilesPath = "C:\ArmAutomation\"

        if (Test-Path $downloadFilesPath) {
            Remove-Item -Path $downloadFilesPath -Recurse
        }

        New-Item -Path $downloadFilesPath -ItemType Directory 
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($PowershellScheduleTaskBlobUrl + $SASToken, $downloadFilesPath + "AddClusterRoleTask.ps1")

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Restarting File Server Role for Probe to take effect"
        $servers = (Get-ClusterNode).Name
        foreach ($server in $servers) {Install-WindowsFeature -Name file-services -ComputerName $server}        

        #Creating a Scheduled Task to execute Add-ClusterFileServerRole 
        Set-Location $downloadFilesPath
        $downloadPSPath = $downloadFilesPath + "AddClusterRoleTask.ps1"
        $argList = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command & '$downloadPSPath' $ILBStaticIP $clusterRoleName $CFileServerNewRoleName"
        schtasks /create /tn addFileServerRole /sc once /st (Get-Date -format HH:mm) /sd (Get-Date).AddDays(1).ToString("MM/dd/yyyy") /f /RL highest /ru $ClusterSetupAccount /rp $ClusterSetupPassword /tr $ArgList
        schtasks /run /tn addFileServerRole
        Start-Sleep -Seconds 30
        schtasks /delete /tn addFileServerRole /f
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) End of Script"
}
    
catch [System.Exception] {
    $ErrorMessage = $_
    $Errors += "[E] : Could not Setup Cluster: " +  $_.Exception.Message
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -message $Errors + " " + $ErrorMessage
    throw $Errors
}

#endregion
