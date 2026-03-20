<#
.SYNOPSIS
    This post scripts applies customization to multiple IaaS VMs created.
.DESCRIPTION
    After the VMs are created, this script will configure the following vms settings.
    ################This Scripts will run after the VM is joined to a Domain.##################
    1.Enable File Sharing Windows Firewall.
    2.Update DNS Record
    3.Gpupdate to push domain policies
    4.Sets DSC MaxEnvelopeSizeKb
    5.Install AZ Module
    6.Install NTFSSecurity Module
    7.Set time zone
.PARAMETER TimeZone
    This is to set the time zone of the VM
.OUTPUTS
    None.
#>
param (
    [string] $timeZone
)
try {

    ###########################################################################################################################################################
    # Opens Windows Firewall for File Sharing
    ###########################################################################################################################################################
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Start Multiple Commands"
    Enable-NetFirewallRule -DisplayName "File and Printer Sharing*"
    ipconfig /registerdns
    Set-Item -Path WSMan:\localhost\MaxEnvelopeSizeKb -Value 2048 -ErrorAction SilentlyContinue

    ###########################################################################################################################################################
    # Install NTFSSecurity Module
    ###########################################################################################################################################################
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Install NTFS Module Starts"   
    if (-Not (Get-InstalledModule NTFSSecurity -ErrorAction SilentlyContinue)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Install-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue

        Install-Module NTFSSecurity -Force -confirm:$false -AllowClobber -ErrorAction SilentlyContinue
    }

    ###########################################################################################################################################################
    # Enable SMB Encryption
    ###########################################################################################################################################################
    Set-SmbServerConfiguration -EncryptData $true -RequireSecuritySignature $true -Force
    
    ###########################################################################################################################################################
    # Set Time zone to a specific time zone
    ###########################################################################################################################################################
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Set time zone $($timeZone)"  
    set-TimeZone -Name $timeZone

    Gpupdate /force
    shutdown /r /t 0
}
catch [System.Exception] {
    Write-Verbose "Error trying to apply post script to multiple VM deployment!" -Verbose
    Write-Verbose $_.Exception -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Error has Ocurred $_.Exception"
    throw
} 