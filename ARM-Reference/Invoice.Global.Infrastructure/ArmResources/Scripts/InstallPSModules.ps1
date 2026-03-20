<#
.SYNOPSIS
    This scripts takes a list of modules separated by a comma.
.DESCRIPTION
    This scripts takes a list of modules separated by a comma.
.PARAMETER modulesList
    This is a list of names of PowerShell Modules that need to 
.OUTPUTS
    None.
#>
param (
    $modulesList
)


###########################################################################################################################################################
# Install PowerShell Modules
###########################################################################################################################################################
Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Installation of Modules Starts"   
    
$modulesList = ($modulesList).split(",")

foreach ($module in $modulesList) {
        
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Installation of Module $module Starts"  
    if (-Not (Get-InstalledModule $module -ErrorAction SilentlyContinue)) {

        Install-Module -Name $module -Force -confirm:$false -AllowClobber -ErrorAction Stop
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Installation of Module $module Completes" 
    
    }
    else {

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Module $module is already installed. Skipping it!"
            
    }
    
}