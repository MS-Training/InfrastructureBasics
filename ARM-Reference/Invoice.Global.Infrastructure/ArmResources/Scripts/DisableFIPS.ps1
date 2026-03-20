<#
.SYNOPSIS
     Enable or Disable FIPS Algoritm Policy
.DESCRIPTION
    Enable or Disable FIPS Algoritm Policy
.PARAMETER configurationNames
    Configuration Names
.PARAMETER EndpointUrl
    Automation Account Endpoint Url
.PARAMETER aaKey
    Automation Account Primary Key
.PARAMETER disableFips
    Disable or Enable Flag 
        0- Disable
        1- Enable
.OUTPUTS
    None
#>
param(
        [string] $configurationNames = "MSITNoPAK5.ISRM_GC",
        [string] $endpointUrl,
        [string] $aaKey,
        [int] $disableFips = 0
    )

function UpdateDscLocalConfigurationManager {
    param(
        $configurationNames
    )

    new-EventLog -LogName Application -source 'AzureArmTemplates' -ErrorAction SilentlyContinue
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Verify if the Configuration Name is already set as $configurationNames"
    $output = (Get-DscLocalConfigurationManager).ConfigurationDownloadManagers.ConfigurationNames    
    if($output -eq $configurationNames){
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Configuration Name is already set as $configurationNames. Skipping this execution..."
        return
    }

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Executing Get-DscLocalConfigurationManager and rest of the logic, to set Configuration Name as $configurationNames"
    # Read Dsc Local Configuration Manager Configuration
    $dscLocalConfig = Get-DscLocalConfigurationManager

    if($dscLocalConfig.ConfigurationDownloadManagers.Count -gt 0){

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Found at least one item in ConfigurationDownloadManagers"       

        # Create the metaconfigurations
        $Params = @{
            RegistrationUrl = $endpointUrl
            RegistrationKey = $aaKey
            ComputerName = @('localhost')
            RefreshFrequencyMins = $dscLocalConfig.RefreshFrequencyMins
            ConfigurationModeFrequencyMins = $dscLocalConfig.ConfigurationModeFrequencyMins
            ConfigurationNames = $configurationNames #'MSITNoPAK5.ISRM_GC'
            RebootNodeIfNeeded = $dscLocalConfig.RebootNodeIfNeeded
            AllowModuleOverwrite = $dscLocalConfig.AllowModuleOverwrite
            ConfigurationMode = 'ApplyOnly'
            ActionAfterReboot = $dscLocalConfig.ActionAfterReboot
            RefreshMode = $dscLocalConfig.RefreshMode
        }

        $params
        
    }
    else{
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "ConfigurationDownloadManagers are not present, skipping.."
    return
    }

    # Use PowerShell splatting to pass parameters to the DSC configuration being invoked
    # For more info about splatting, run: Get-Help -Name about_Splatting
    DscMetaConfigs @Params
    cd DscMetaConfigs

    Set-DscLocalConfigurationManager -path .\

}

# The DSC configuration that will generate metaconfigurations
[DscLocalConfigurationManager()]
Configuration DscMetaConfigs { 
    param 
    (
        [Parameter(Mandatory=$True)] 
        [String]$RegistrationUrl,
        [Parameter(Mandatory=$True)] 
        [String]$RegistrationKey,
        [Parameter(Mandatory=$True)] 
        [String[]]$ComputerName,
        [Int]$RefreshFrequencyMins = 300, 
        [Int]$ConfigurationModeFrequencyMins = 450, 
        [String]$ConfigurationMode = 'ApplyOnly', 
        [String]$ConfigurationNames,
        [Boolean]$RebootNodeIfNeeded,
        [String]$ActionAfterReboot,
        [Boolean]$AllowModuleOverwrite,
        [String]$RefreshMode = 'Pull'
    )
    
    # Verify the RefreshMode, if null or empty then use "Pull" as it's default value 
    if($RefreshMode -eq $null -or $RefreshMode -eq ""){
        $RefreshMode = 'Pull'
    }


    Node $ComputerName
    {  
        Settings 
        { 
            RefreshFrequencyMins = $RefreshFrequencyMins 
            RefreshMode = $RefreshMode 
            ConfigurationMode = 'ApplyOnly'
            AllowModuleOverwrite   = $AllowModuleOverwrite 
            RebootNodeIfNeeded = $RebootNodeIfNeeded 
            ActionAfterReboot = $ActionAfterReboot 
            ConfigurationModeFrequencyMins = $ConfigurationModeFrequencyMins 
        }

        ConfigurationRepositoryWeb AzureAutomationDSC 
        { 
            ServerUrl = $RegistrationUrl 
            RegistrationKey = $RegistrationKey 
            ConfigurationNames = $ConfigurationNames 
        }

        ResourceRepositoryWeb AzureAutomationDSC 
        { 
            ServerUrl = $RegistrationUrl 
            RegistrationKey = $RegistrationKey 
        }

        ReportServerWeb AzureAutomationDSC 
        { 
            ServerUrl = $RegistrationUrl 
            RegistrationKey = $RegistrationKey 
        }
    }   

}

function  ValidateDscLocalConfigurationManager {
    param (
        $configurationNames
    )
    
    $output = (Get-DscLocalConfigurationManager).ConfigurationDownloadManagers.ConfigurationNames
    
    if($output -eq $configurationNames){
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "(Get-DscLocalConfigurationManager).ConfigurationDownloadManagers.ConfigurationNames is set to '$configurationNames'" 
    }
    else{
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "(Get-DscLocalConfigurationManager).ConfigurationDownloadManagers.ConfigurationNames is **NOT** set to '$configurationNames'"
    }

}


function SetFIPSAlgorithmPolicy {
    param (
        $disableFips
    )

    $exists = Test-Path HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy

    if($exists) {

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Value to set : '$disableFips'"
        $currentPolicy = Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy
        $current = $currentPolicy.Enabled
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The Current FIPS Algorithm Policy is '$current'" 
        
        if($currentPolicy.Enabled -eq $disableFips){
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The FIPS Algorithm Policy is already set to the desired value '$disableFips'"
        }
        if($currentPolicy.Enabled -ne $disableFips){
            Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy -Name Enabled -Value $disableFips
            $policyOutput = Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FIPSAlgorithmPolicy
            $newPolicy= $policyOutput.Enabled
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The New FIPS Algorithm Policy is set to '$newPolicy' . [0-Disable, 1-Enable]"
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Rebooting the server to reflect the change"
            shutdown /r /t 0
        }
    }
    else{
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "FIPS Algorithm Policy Regedit Key/Value not found."
    }

}

function Main {

        UpdateDscLocalConfigurationManager -configurationNames $configurationNames

        ValidateDscLocalConfigurationManager -configurationNames $configurationNames      

        # Disable/Enable FIPS Algorithm Policy   
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Starting to set FIPs Policy"
        SetFIPSAlgorithmPolicy -disableFips $disableFips

}

Main