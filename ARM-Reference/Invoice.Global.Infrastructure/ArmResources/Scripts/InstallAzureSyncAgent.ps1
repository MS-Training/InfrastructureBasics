param (
    [Bool] $IsTest = $False,
     $StorageAccountName = "sahdimssperfdev",
     $KeyVaultName = "KeyVault-MSSales-Dev",
     $DownloadPath = "C:\\AzFilesResources\\",
     $ServicePrincipalName = "50c155f0-4115-4347-aa02-a42ed35b89b5",
     $Tenant = "72f988bf-86f1-41af-91ab-2d7cd011db47",
     $SubscriptionId = "ee5b949d-79c4-478e-bf73-3dc82b728c47",
     $ServicePrincipalSecret,
     $AzCmdletsFileName = "Az-Cmdlets.msi",
     $StorageSyncAgent2016FileName = "StorageSyncAgent_WS2016.msi",
     $StorageSyncAgent2019FileName = "StorageSyncAgent_WS2019.msi",
     $StorageSyncServiceName = "mssdevsyncservice",
     $ResourceGroup = "",
     $InstallerURI = "",
     $SASToken = ''
)

function DownloadSyncAgentInstaller {

    try{
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Downloading $($SyncAgentInstallerName) from $($InstallerURI)"
        $WebClient.DownloadFile($InstallerURI + $SyncAgentInstallerName + $SASToken, "$($DownloadPath)$($SyncAgentInstallerName)")
    }
    catch{
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -Message "Could not download $($SyncAgentInstallerName) from $($InstallerURI)"
        throw
    }
}
function DownloadAzModulesInstaller {
    
    try{
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Downloading $($AzCmdletsFileName) from $($InstallerURI)"
        $WebClient.DownloadFile($InstallerURI + $AzCmdletsFileName + $sastoken, "$($DownloadPath)$($AzCmdletsFileName)")
    }
    catch{
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -Message "Could not download $($AzCmdletsFileName) from $($InstallerURI)"
        throw
    }
}
function InstallAzureSyncAgent {
    try{
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing Azure Storage Sync Agent..."
        Start-Process -FilePath "$($DownloadPath)$($SyncAgentInstallerName)" -ArgumentList "/quiet" -Wait
    }
    catch {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -Message "InstallAzureSyncAgent Error"
        throw
    }
}
function InstallAzModules {
    try{
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing Az Powershell Modules..."
        Start-Process -FilePath "$($DownloadPath)$($AzCmdletsFileName)" -ArgumentList "/quiet" -Wait
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Az Powershell Modules Installation Complete..."
    }
    catch {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -Message "InstallAzModules Error"
        throw
    }
}
function RegisterServer {
    Param (
        $credential
    )
    
    try{
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Registering Server with Sync Service $($storageSyncServiceName)"
        Import-Module Az
        Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $Tenant -SubscriptionId $SubscriptionId

        $storageSync = Get-AzStorageSyncService -ResourceGroupName $ResourceGroup -Name $storageSyncServiceName
        
        Register-AzStorageSyncServer -ParentObject $storageSync
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Done registering server with Sync Service $($storageSyncServiceName)"
    }
    catch {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -Message "Register Server Error"
        throw
    }
}
function Main {
    $osver = [System.Environment]::OSVersion.Version
    $script:SyncAgentInstallerName
    if ($osver.Equals([System.Version]::new(10, 0, 17763, 0))) {
        $script:SyncAgentInstallerName = $StorageSyncAgent2019FileName
    } elseif ($osver.Equals([System.Version]::new(10, 0, 14393, 0))) {
        $script:SyncAgentInstallerName = $StorageSyncAgent2016FileName
    } else {
        throw [System.PlatformNotSupportedException]::new("Azure File Sync is only supported on Windows Server 2016, and Windows Server 2019")
    }

    try{
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Creating Download Directory..."
        if (Test-Path $DownloadPath) {
            Remove-Item -Path $DownloadPath -Recurse
        }
    
        New-Item -Path $DownloadPath -ItemType Directory 
    }
    catch {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -Message "Could Not Create Download Directory"
        throw
    }

    try{
        $script:WebClient = New-Object System.Net.WebClient
    }
    catch {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -Message "Could Not Create Web Client"
        throw
    }
    
    DownloadSyncAgentInstaller($WebClient, $DownloadPath)
    DownloadAzModulesInstaller($WebClient, $DownloadPath)

    InstallAzureSyncAgent
    InstallAzModules
    
    $secureString = ConvertTo-SecureString $ServicePrincipalSecret -AsPlainText -Force
    [System.Management.Automation.PSCredential]$credential =New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ServicePrincipalName, $secureString
    
    RegisterServer($credential)
}
if ($IsTest -eq $false) {
    main
}