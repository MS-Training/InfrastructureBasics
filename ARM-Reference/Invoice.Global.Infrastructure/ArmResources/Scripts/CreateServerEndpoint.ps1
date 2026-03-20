param (
    [Bool] $IsTest = $False,
     $ServicePrincipalName,
     $Tenant,
     $SubscriptionId,
     $ServicePrincipalSecret,
     $StorageSyncServiceName,
     $ResourceGroup,
     $ClusterName,
     $ConfigFilePath
)

function Main {
    $secureString = ConvertTo-SecureString $ServicePrincipalSecret -AsPlainText -Force
    [System.Management.Automation.PSCredential]$credential =New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ServicePrincipalName, $secureString

    Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $Tenant -SubscriptionId $SubscriptionId

    $servers = Get-AzStorageSyncServer -ResourceGroupName $ResourceGroup -StorageSyncServiceName $StorageSyncServiceName

    $cluster = $servers.Where({$_.FriendlyName -like "$($ClusterName)*" -and $_.ServerRole -eq "ClusterName"})

    $SyncGroupConfigs = Get-Content $ConfigFilePath | ConvertFrom-Json

    foreach($syncGroupConfigItem in $SyncGroupConfigs){
        $syncGroup = Get-AzStorageSyncGroup -ResourceGroupName $ResourceGroup -StorageSyncServiceName $StorageSyncServiceName -Name $syncGroupConfigItem.Name

        try{
            Write-Output "Registering Server Endpoint $($syncGroupConfigItem.Directory) to Sync Group $($syncGroupConfigItem.Name)"
            New-AzStorageSyncServerEndpoint -Name $cluster.ClusterName -SyncGroup $syncGroup -ServerResourceId $cluster.ResourceId -ServerLocalPath "$($syncGroupConfigItem.Directory)"
        }
        catch
        {
            Write-Error -Message "Could Not Create Server Endpoint" -Exception $_.Exception
            throw
        }
    }
}
if ($IsTest -eq $false) {
    main
}