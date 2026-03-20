param(
    [Parameter(Mandatory = $True)]
    [system.String]$Services,

    [Parameter(Mandatory = $True)]
    [System.String] $ServerName,

    [Parameter(Mandatory = $True)]
    [ValidateSet('Stop', 'Start')]
    [System.String] $Action,

    [Parameter(Mandatory = $False)]
    [System.String]$IsCluster = 'false',

    [Parameter(Mandatory = $False)]
    [System.Boolean]$IsTest = $False
)

function StartService {
    param(
        [System.String] $Service
    )

    if($IsCluster.ToLowerInvariant() -eq 'true'){
        StartClusterResource -Service $Service
    } else {
        StartLocalService -Service $Service
    }
}

function StopService {
    param(
        [System.String] $Service
    )

    if($IsCluster.ToLowerInvariant() -eq 'true'){
        StopClusterResource -Service $Service
    } else {
        StopLocalService -Service $Service
    }
}
function StartLocalService{
    param(
        [System.String] $Service
    )

    $ServiceObject = Get-Service -ComputerName $ServerName | Where-Object { $_.Name.ToLower() -eq $Service.ToLower() }

    if ($ServiceObject) {

        if ($ServiceObject.Status -ne 'Running') {
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service in $ServerName is not running, attempting to start it"

            Get-Service -ComputerName $ServerName -Name $Service | Start-Service

            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service in $ServerName has been started"
        }
        else {
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service in $ServerName is running"
        }
    }
    else {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service does not exist on $ServerName, Skipping"
    }
}

function StartClusterResource{
    param(
        [System.String] $Service
    )

    $ServiceObject = Get-ClusterResource -Name $Service

    if ($ServiceObject) {

        if ($ServiceObject.State -ne 'Online') {                
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service in $ServerName is not running in cluster, Trying to start cluster resource"

            Start-ClusterResource -name $Service

            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "Cluster $Service in $ServerName has been started"
        }
        else {
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service in $ServerName is running"
        }
    }
    else {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service does not exist on $ServerName, Skipping"
    }
}

function StopLocalService{
    param(
        [System.String] $Service
    )

    $ServiceObject = Get-Service -ComputerName $ServerName | Where-Object { $_.Name.ToLower() -eq $Service.ToLower() }

    if ($ServiceObject) {

        if ($ServiceObject.Status -eq 'Running') {
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service in $ServerName is running, Trying to Stop"

            Get-Service -ComputerName $ServerName -Name $Service | Stop-Service -Force

            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service in $ServerName has been stopped"
        }
        else {
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service in $ServerName is not running, Skipping"
        }
    }
    else {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service does not exist on $ServerName, Skipping"
    }
}

function StopClusterResource{
    param(
        [System.String] $Service
    )

    $ServiceObject = Get-ClusterResource -Name $Service

    if ($ServiceObject) {

        if ($ServiceObject.State -eq 'Online') {                
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service in $ServerName is running in cluster, Trying to Stop cluster resource"

            Stop-ClusterResource -name $Service

            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "Cluster $Service in $ServerName has been stopped"
        }
        else {
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service in $ServerName is not running, Skipping"
        }
    }
    else {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -Entrytype Information -Message "$Service does not exist on $ServerName, Skipping"
    }

}

function Main {
    $ServicesList = $Services.Split(",")

    foreach($Service in $ServicesList){     
        if($Action -eq 'Start'){
            StartService -Service $Service
        } else {
            StopService -Service $Service
        }
    }
}

if ($IsTest -eq $false) {
    Main
}