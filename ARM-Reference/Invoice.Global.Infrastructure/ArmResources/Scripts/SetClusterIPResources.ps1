<#
.SYNOPSIS
    This script will configure the IP Resources of each role deployed in a cluster
.DESCRIPTION
    After the creation of a cluster, the IP Resource for the clusters needs to be configured as well as the IP for the newly created resource
.OUTPUTS
    None.
#>
param (
    [string] $ILBStaticIP,
    [string] $ProbePort = "50001",
    [int]    $Retry = 2,
    [array]  $ClusterRoleName = "SQL"
)

function GetClusterIPSubnet {

    $ILBSubnetMask = $null   
    $Networks = Get-WmiObject Win32_NetworkAdapterConfiguration -EA SilentlyContinue | ? { $_.IPEnabled }
    foreach ($Network in $Networks) {            
        foreach ($subnet in $Network.IPSubnet) {
            if ($subnet -match '255.255.255') {
                $ILBSubnetMask = $subnet
            }
        }
    }
    return $ILBSubnetMask
}

function GetNetworkName {   
    return (Get-ClusterNetwork).Name
}

function GetClusterRoleIPResourceName {
    param(
        $ClusterRoleName
    )
    $ClusterIPResource = Get-ClusterResource | Where-Object { $_.ResourceType.Name -eq "IP Address" } | Where-Object { $_.OwnerGroup -match $ClusterRoleName }
    return  $ClusterIPResource.Name

}

function SetIpResource {
    param(
        $Values,
        $IPResourceName
    )
    Write-Verbose "Starting to set up IP Resource Parameters Named $IPResourceName" -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Starting to set up IP Resource Parameters Named $IPResourceName"
    $ctr = 1
    while ($ctr -le $Retry){
    Get-ClusterResource $IPResourceName | Set-ClusterParameter -Multiple $values -ErrorAction Stop
    $ctr++
    }
}

function ConfigureClusterIP {
    param(
        $NetworkName
    )
    $ClusterIPResourceName = (GetClusterRoleIPResourceName -ClusterRoleName "Cluster")
    $Values=@{"Address" = "169.254.1.1"; "SubnetMask" = "255.255.0.0"; "Network" = "$NetworkName"; "OverrideAddressMatch" = 1; "EnableDHCP" = 0}
    if (-Not ([string]::IsNullOrEmpty($ClusterIPResourceName))) {
        SetIpResource -Values $Values -IPResourceName $ClusterIPResourceName
    }
    else {
        Write-Verbose "This Cluster does not have a Dedicated Cluster IP" -Verbose
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "This Cluster does not have a Dedicated Cluster IP"
    }    
}

function ConfigureClusterRoleIP {
    param(
        $ClusterRoleName,
        $ILBStaticIP,
        $ProbePort,
        $NetworkName,
        $ILBSubnetMask
    )
    $ClusterIPResourceName = GetClusterRoleIPResourceName -ClusterRoleName $ClusterRoleName
    $Values = @{"Address" = "$ILBStaticIP"; "SubnetMask" = "$ILBSubnetMask"; "Network" = "$NetworkName"; "OverrideAddressMatch" = 1; "EnableNetBIOS" = 1; "ProbePort" = "$ProbePort"}
    SetIpResource -Values $Values -IPResourceName $ClusterIPResourceName
}

function StartClusterResources {
        
    $ctr = 0
    while ($ctr -le $Retry){

        $groups = (Get-ClusterGroup | Where-Object { $_.State -ne "Online" }).Name
        foreach ($group in $groups) {
        Start-ClusterGroup -Name $group
        }
        $ctr++

    }

}

function ConfigureClusterResources {

    new-EventLog -LogName Application -source 'AzureArmTemplates' -ErrorAction SilentlyContinue
    $NetworkName = GetNetworkName

    $ctr = 0
    while (([string]::IsNullOrEmpty($NetworkName)) -and $ctr -le 3) {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Failed to connect to the cluster Attempt Number: $ctr. We will retry in 2 minutes"
        Start-Sleep -Seconds 120
        $ctr++
        $NetworkName = GetNetworkName
        
    }

    if ([string]::IsNullOrEmpty($NetworkName)) {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Unable to connect to the cluster"
        throw "Unable to connect to the cluster"
    }

    Write-Verbose "The NetworkName of this cluster is $NetworkName" -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The NetworkName of this cluster is $NetworkName"
    $ILBSubnetMask = GetClusterIPSubnet
    Write-Verbose "The Subnet Mask of this cluster is $ILBSubnetMask" -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The Subnet Mask of this cluster is $ILBSubnetMask"
    ConfigureClusterIP -NetworkName $NetworkName
    ConfigureClusterRoleIP -ClusterRoleName $ClusterRoleName -ILBStaticIP $ILBStaticIP -ProbePort $ProbePort -NetworkName $NetworkName -ILBSubnetMask $ILBSubnetMask
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Configuration of the Role IP has Completed"
    StartClusterResources

}

ConfigureClusterResources