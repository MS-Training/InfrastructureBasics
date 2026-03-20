param(
    [Parameter(Mandatory = $true)]
    $ILBStaticIP,
    [Parameter(Mandatory = $true)]
    $clusterRoleName,
    [Parameter(Mandatory = $true)]
    $CFileServerNewRoleName
)

$ErrorActionPreference = "Stop"
    function addDependency {
    param(
        $storageVolume
    )
    $DependencyExpression = (Get-ClusterResourceDependency -Resource $CFileServerNewRoleName -ErrorAction SilentlyContinue).DependencyExpression -split "and"
    $dependencies = @()
    foreach ($dependency in $DependencyExpression) {
        $dependencies += $dependency.Trim().Trim("(").Trim(")").Trim("[").Trim("]")
    }
    foreach ($resource in $storageVolume){
        $depend = $dependencies | Where-Object { $_ -eq $resource }
        if (!$depend -or $depend -eq ""){
            Add-ClusterResourceDependency -Resource $CFileServerNewRoleName -Provider $resource
        }
    }
}
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Addition of File Server Role using the Task Scheduled"
    $storageVolume = (Get-ClusterResource | where {$_.Resourcetype.Name -eq "Physical Disk"} | where {$_.OwnerGroup -ne "Cluster Group"}).Name
    Get-clusterGroup -Name $clusterRoleName | Add-ClusterResource -Name $CFileServerNewRoleName -ResourceType "Generic Service" -Group $clusterRoleName | Set-clusterParameter -Name ServiceName -Value $CFileServerNewRoleName
    addDependency($storageVolume)
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "CPumpnew server Role successfully added"
    Add-ClusterFileServerRole -Storage $storageVolume -name $clusterRoleName -StaticAddress $ILBStaticIP -ErrorAction Stop
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "File server Role successfully added"     
    Stop-ClusterGroup -Name $($using:clusterRoleName)
    Start-Sleep -Seconds 30
    Start-ClusterGroup -Name $($using:clusterRoleName)