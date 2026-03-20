<#
.SYNOPSIS
Copys all Pump Registry blobs from a source storage account to a VM and runs the registry files
.DESCRIPTION
    Using the azure storage context, content from the Container is copied to the VM at the VMPumpDirectory
.PARAMETER StorageAccountName
    storage account name
.PARAMETER Container
    Name of the container
.PARAMETER pumpPath
    location of registry files (G:\Pump)
.PARAMETER KeyVaultName
    Name of the keyvault
.PARAMETER VMName
    VM name of the pump server
.PARAMETER Container
    storage account container source
.PARAMETER VMPumpDirectory
    target vm module directory
.PARAMETER StorageAccountKey
    storage account key
.PARAMETER UserName
    The user name account
.PARAMETER UserAccountSecretdName
    The name of the useraccount secret in keyvault
.PARAMETER CertificateName
    Name of the certificate for ICMODS
.PARAMETERServicePrincipalPassword
.OUTPUTS
    None
#>

param (
    [String] $IsTest,
    [String] $KeyVaultName,
    [String] $UserName,
    [String] $UserAccountSecretName,
    [String] $driveLetterSecondaryNode,
    [String] $Tenant,
    [String] $ServicePrincipalName,
    [String] $GMSAUserName,
    [Parameter(Mandatory = $true)]
    $ServicePrincipalPassword
)

$ErrorActionPreference = "Stop"

function DeployingCPumpNewService {
    param(

    )

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Starting DeployingCPumpNewService" 
    function CreateNewService {
        param(
            [String] $ServiceName,
            [String] $PumpExePath,
            [String] $StartupType = "Automatic"
        )
        
        #$UserAccountSecurePassword = ConvertTo-SecureString -String $UserAccountPassword.SecretValueText -Force -AsPlainText
        #$credential = New-Object System.Management.Automation.PSCredential($UserName, $script:UserAccountPassword.SecretValue)
        #New-Service -Name $ServiceName -StartupType $StartupType -BinaryPathName $PumpExePath -Credential $credential -Verbose

        New-Service -Name $ServiceName -StartupType $StartupType -BinaryPathName $PumpExePath -Verbose
        $ServiceObject = Get-WmiObject -Class Win32_Service -Filter "Name='$($ServiceName)'"
        $ServiceObject.StopService() | out-null       
        $ServiceObject.Change($null, $null, $null, $null, $null, $null, $GMSAUserName, $null, $null, $null, $null)
    }

    $Pumps = @{
        'XPump'                = "$($driveLetterSecondaryNode)\CMODS\XPump\XPump.exe" ;
        'CPump'                = "$($driveLetterSecondaryNode)\CMODS\CPump\CPump.exe";
        'EDIPump'              = "$($driveLetterSecondaryNode)\CMODS\EDIPump\EDIPump.exe";
        'CopyAzureICMODsFiles' = "$($driveLetterSecondaryNode)\AzureFileService\CopyAzureICMODSFiles.exe";
        'CPUMPNew'             = "$($driveLetterSecondaryNode)\CMODSNEW\CPUMP\Microsoft.IT.MSSales.CPump.CPumpWindowsService.exe";
    }

    foreach ($key in $Pumps.keys) {
        if (!(Get-Service -Name $($key) -ErrorAction SilentlyContinue)) {
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing $($key) from location $($Pumps.Item($key))" 
            CreateNewService -ServiceName $key -PumpExePath $($Pumps.Item($key))
        }
        else {
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$($Key) already exists." 
        }
    }

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Completed Deploying CPumpNew" 
}

function main {

try{


    $ServicePrincipalSecurePassword = ConvertTo-SecureString -String $ServicePrincipalPassword -Force -AsPlainText
    $credential = New-Object System.Management.Automation.PSCredential($ServicePrincipalName, $ServicePrincipalSecurePassword)
    Import-Module az
    Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $Tenant
    $script:UserAccountPassword = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $UserAccountSecretName

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing CPumpNew service..." 
    DeployingCPumpNewService

}

catch{
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$($_.Exception.ToString())" 
}
    #starting services
}
if ($IsTest -eq "False") {
    main
}
