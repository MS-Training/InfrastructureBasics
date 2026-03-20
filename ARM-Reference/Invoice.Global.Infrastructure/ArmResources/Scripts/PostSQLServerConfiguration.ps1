<#
.SYNOPSIS
    Creates the required folders, shares and registry settings
.DESCRIPTION
    Creates the required folders, shares and registry settings.
.PARAMETER StartupParameters
    List of Trace Flags to be added to the sql instance
#>
param (
    $StartupParameters = "-T634,-T1118,-T1222,-T2467,-T2505,-T3605,-T7451,-T8004,-T8026,-T9347,-T9348",
    $EnableDtc = $true
)

<#
.SYNOPSIS
    This function sets the network DTC properties of a VM
.DESCRIPTION
    The functino receives two parameters and applies the appropriate DTC security based on those parameters.
.PARAMETER NetworkDtcName
    This parameter is the name of the Network DTC property.
.PARAMETER ParameterValue
    This parameter sets the value of the property name. 1 or 0.
.OUTPUTS
    None.
#>
function EnableDtcSettings {
    param(
        [String] $NetworkDtcName,
        [Int] $ParameterValue
    )

    Write-Verbose "Setting Network Property for $NetworkDtcName" -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Setting Network Property for $NetworkDtcName"
    Set-ItemProperty -Path HKLM:\Software\Microsoft\MSDTC\Security -Name $NetworkDtcName -Value $ParameterValue
}

<#
.SYNOPSIS
    This function retrieves objects from HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL that has MSSQL in it
.OUTPUTS
    Instanceobjects.
#>
function GetPropertiesMatching {
    param(
        [String] $itemPath,
        [String] $valueMatch,
        [String] $matchProperty
    )

    $property = Get-ItemProperty $itemPath
    $instancesObject = $property.psobject.properties | Where-Object { $_.$matchProperty -like $valueMatch }
    return $instancesObject
}

<#
.SYNOPSIS
    This function adds parameters to a MSSSQLServer registry.
.DESCRIPTION
    This function first gets a list of isntances and splits the parameters to add. If there are instances, it iterates
    through the list of isntances and adds each paramter one at a time.
.PARAMETER ServerName
    The name of the server where the parameters need to be added.
.PARAMETER ParametersToAdd
    The parameters to be added separated by commas and with no spaces.
.OUTPUTS
    None.
#>
function AddTraceFlags {
    param (
        [String] $ServerName,
        [String] $ParametersToAdd
    )
    $sqlInstancePath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL"
    Write-Verbose("Getting properties from $sqlInstancePath with version matching MSSQL*") -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Getting properties from $sqlInstancePath with version matching MSSQL*"
    $instances = $(GetPropertiesMatching -itemPath "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL" -valueMatch "MSSQL*" -matchProperty "Value").Value

    # get all the parameters you input
    $parameters = $ParametersToAdd.split(",")

    # add all the startup parameters
    if ($instances) {
        foreach ($instance in $instances) {

            $ins = $instance.split('.')[1]

            if ($ins -eq "MSSQLSERVER") {

                $instanceName = $ServerName

            }
            else {

                $instanceName = $ServerName + "\" + $ins

            }

            $regKey = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$instance\MSSQLServer\Parameters"
			 
            # get all the registry keys for trace flags   
            $traceFlags = $(GetPropertiesMatching -itemPath $regKey -valueMatch "-T*" -matchProperty "Value").Name
            $traceFlagCount = $traceFlags.count

            #Remove all exisitng trace flags -- added to correct the issue in all the servers
            foreach ($traceFlag in $traceFlags) {

                Remove-ItemProperty -Path $regKey -Name $traceFlag
                Write-Verbose "Removed TraceFlag : $traceFlag" -Verbose
                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Removed TraceFlag : $traceFlag"

            }

            Write-Verbose("Getting properties from $regKey with name matching SQLArg*") -Verbose
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Getting properties from $regKey with name matching SQLArg*"
            $paramObject = GetPropertiesMatching -itemPath $regKey -valueMatch "SQLArg*" -matchProperty "Name"
            $count = $paramObject.count

            foreach ($parameter in $parameters) {

                if ($parameter -notin $paramObject.value) {

                    $newRegProp = "SQLArg$($count)"
                    Write-Verbose "Adding startup parameter:$($newRegProp) for $instanceName" -Verbose
                    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Adding startup parameter:$($newRegProp) for $instanceName"
                    Set-ItemProperty -Path $regKey -Name $newRegProp -Value $parameter
                    Write-Verbose "Parameter:$($newRegProp) and Value $parameter added sucessfully to $instanceName!" -Verbose
                    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Parameter:$($newRegProp) and Value $parameter added sucessfully to $instanceName!"
                    $count = $count + 1

                }
            }
        }
    }
    
    Write-Verbose "Added trace flags Completed." -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Added trace flags Completed."
	
    #check if a forece restart is needed.
    $newTraceFlags = $(GetPropertiesMatching -itemPath $regKey -valueMatch "-T*" -matchProperty "Value").Name
    $newTraceFlagCount = $newTraceFlags.count
    
    if ($traceFlagCount -ne $newTraceFlagCount) {

        Write-Verbose "Existing traceflag count $traceFlagCount ,  New traceflag count $newTraceFlagCount" -Verbose
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Existing traceflag count $traceFlagCount ,  New traceflag count $newTraceFlagCount"

        if (-Not(Get-Service -Name 'ClusSvc' -ErrorAction SilentlyContinue)) {

            Restart-Service -Force MSSQLSERVER #$ins
            Write-Verbose "SQL Service restart Completed for $ins." -Verbose
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "SQL Service restart Completed for $ins."

        }
    }
    else {

        Write-Verbose "No changes to Trace flags for $ins." -Verbose
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "No changes to Trace flags for $ins."

    }
}

function Main {

    $vmName = $env:ComputerName
    if ($EnableDtc) {

        #Enabling Network DTC setting
        EnableDtcSettings -NetworkDtcName 'NetworkDtcAccess' -ParameterValue 1
        EnableDtcSettings -NetworkDtcName 'NetworkDtcAccessTransactions' -ParameterValue 1
        EnableDtcSettings -NetworkDtcName 'NetworkDtcAccessOutbound' -ParameterValue 1
        EnableDtcSettings -NetworkDtcName 'NetworkDtcAccessInbound' -ParameterValue 1

    }

    if ((Get-Service -Name 'ClusSvc' -ErrorAction SilentlyContinue)) {

        $ActiveNode = (Get-ClusterGroup | Where-Object { $_.Name -like "*SQL*" }).OwnerNode
        $vmName = $env:ComputerName

        if ($Activenode -eq $vmName) {

            #get all the instances on a server and add startup paramertes
            AddTraceFlags -ServerName $vmName -ParametersToAdd $StartupParameters
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Finished setting TraceFlags in the SQL Cluster"

        }      
    }
    else {

        AddTraceFlags -ServerName $vmName -ParametersToAdd $StartupParameters

    }
}

Main