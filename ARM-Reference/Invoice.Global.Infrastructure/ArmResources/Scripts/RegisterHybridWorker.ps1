<#
.DESCRIPTION
Install required script for Registering the Hybrid Worker
#>
param (
    [string] $HybridGroupName,
    [string] $AutomationPrimaryKey,
    [string] $AutomationEndpoint
)
try {
    
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 2000 -entrytype Information -message "RegisterHybridWorker - starts"

        # Stop the script if any errors occur
        $ErrorActionPreference = "Stop"
      
            # Change the directory to the location of the hybrid registration module
            Set-Location "$env:ProgramFiles\Microsoft Monitoring Agent\Agent\AzureAutomation"
            $version = (Get-ChildItem | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
            Set-Location "$version\HybridRegistration"
    
            # Import the module
            Import-Module (Resolve-Path('HybridRegistration.psd1'))

            # Register the hybrid runbook worker
            Write-Verbose "Adding the hybrid runbook worker" -Verbose
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 2001 -entrytype Information -message "RegisterHybridWorker -  Adding the hybrid runbook worker"
            
            $RegKey = "HKLM:\SOFTWARE\Microsoft\HybridRunbookWorker\*\"+$HybridGroupName   
               
            if (-Not(Test-Path $RegKey)) {
                Add-HybridRunbookWorker -Name $HybridGroupName -EndPoint $AutomationEndpoint -Token $AutomationPrimaryKey
            }else{
                Write-Verbose "Hybrid worker already registerd" -Verbose
                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 2002 -entrytype Information -message "Hybrid worker already registered"
            }
   
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 2002 -entrytype Information -message "RegisterHybridWorker -  Adding the hybrid runbook worker complete"
}
catch {
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 2003 -entrytype Error -message "RegisterHybridWorker -  Error in Registering the hybrid runbook worker"
    Write-Host -ForegroundColor Red -BackgroundColor Black "Error in Registering the hybrid runbook worker"
    Write-Host -ForegroundColor Red -BackgroundColor Black $_
    throw
}