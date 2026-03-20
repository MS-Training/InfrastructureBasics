<#
.SYNOPSIS
    This scripts takes a list of accounts separated by a comma.
.DESCRIPTION
    This scripts takes a list of modules separated by a comma and grants them Logon as Service Rights.
.PARAMETER accountList
    This is a list of names of PowerShell Modules that need to 
.OUTPUTS
    None.
#>
param (
    $accountList
)


###########################################################################################################################################################
# Install PowerShell Modules Carbon
########################################################################################################################################################### 

Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Installation of Module Carbon Starts"  
if (-Not (Get-InstalledModule Carbon -ErrorAction SilentlyContinue)) {

    Install-Module -Name Carbon -Force -confirm:$false -AllowClobber -ErrorAction Stop
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Installation of Module Carbon Completes" 

}
else {

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Module Carbon is already installed. Skipping it!"
        
}

###########################################################################################################################################################
# Logon as Service Rights
###########################################################################################################################################################
$accountList = ($accountList).split(",")

foreach ($account in $accountList) {
        
    Grant-CPrivilege -Identity $account -Privilege SeServiceLogonRight
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Account $account has been granted Logon as Service Rights"  
    
}