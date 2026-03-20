param(
    [Parameter(Mandatory = $true)]
    $ILBStaticIP,
    [Parameter(Mandatory = $true)]
    $clusterRoleName
)

#$ErrorActionPreference = "Stop"
Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Starting to configure File Server Cluster Role"
$clusterRoleExist= (Get-ClusterGroup | Where-Object { ($_.Name -eq $clusterRoleName)})

if ($clusterRoleExist) {

    Write-Verbose "Cluster Role $($clusterRoleName) Already Exist, Skipping this PS" -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Cluster Role $($clusterRoleName) Already Exist, Skipping this PS"
   
}
else {

    Write-Verbose "We will start to create Cluster Role $($clusterRoleName)" -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "We will start to create Cluster Role $($clusterRoleName)"
    
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Addition of File Server Role using the Task Scheduled"
    $storageVolume = (Get-ClusterResource | Where-Object {$_.Resourcetype.Name -eq "Physical Disk"} | Where-Object {$_.OwnerGroup -eq "Available Storage"}).Name
    Add-ClusterFileServerRole -Storage $storageVolume -name $clusterRoleName -StaticAddress $ILBStaticIP -ErrorAction Stop
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "File server Role successfully added"
    Stop-ClusterGroup -Name $($using:clusterRoleName)
    Start-Sleep -Seconds 30
    Start-ClusterGroup -Name $($using:clusterRoleName)

}
