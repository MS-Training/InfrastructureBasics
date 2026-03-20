param(
    [Parameter(Mandatory = $true)]
    $ILBStaticIP,
    [Parameter(Mandatory = $true)]
    $ClusterSetupAccount,
    [Parameter(Mandatory = $true)]
    $ClusterSetupPassword,
    [Parameter(Mandatory = $true)]
    $clusterRoleName)

#new-EventLog -LogName Application -source 'AzureArmTemplates' -ErrorAction SilentlyContinue
try {   
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Adding File Server Role"
        $downloadFilesPath = "C:\AzureArmTemplates\"  

        #Creating a Scheduled Task to execute Add-ClusterFileServerRole 
        Set-Location $downloadFilesPath
        $downloadPSPath = $downloadFilesPath + "AddFileServerRoleTask.ps1"
        $argList = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -Command & '$downloadPSPath' $ILBStaticIP $clusterRoleName"
        schtasks /create /tn addFileServerRole /sc once /st (Get-Date -format HH:mm) /sd (Get-Date).AddDays(1).ToString("MM/dd/yyyy") /f /RL highest /ru $ClusterSetupAccount /rp $ClusterSetupPassword /tr $ArgList
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) completed creating the new task"
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
