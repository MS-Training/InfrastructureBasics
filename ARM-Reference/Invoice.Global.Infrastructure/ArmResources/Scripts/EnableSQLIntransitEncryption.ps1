<#
.SYNOPSIS
    This post scripts applies for enabling SQL in transit encryption on SQL VM's.
.DESCRIPTION
    After the VMs are created, this script will create In-transit certificates.
    This script also re-initiate In-transit Certificates whenever VM boots
.PARAMETER SQLServiceAccount
    SQLServiceAccount in order to provide folder level access 
.PARAMETER StartupFlag
	Startup flag 1 checks whether InTransit SQL encryption is configure, Configures it
    Startup flag 0 configure Vm's InTransit encryption and also sets the script as startup task
#>

param (
    $SQLServiceAccount = "NT Service\MSSQLServer",
    $StartupFlag = 0,
    $ScheduledTaskPath = 'C:\ScheduleTasks',
    $CopyPath = 'C:\AzureArmTemplates\',
    $ConfigStartupflag = 0
)

function Get-Cert-By-FullHostname {
    param (
        [String] $FullHostName
    )

    Try {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Getting Cert By FullHostname $FullHostName"
        $CertItem = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { ($_.DnsNameList -contains $FullHostName) -and ($_.DnsNameList.Count -eq 1) }
    }
    Catch {
        "Error: unable to locate certificate for " + $FullHostName
        Exit
    }
    $CertItem
}

function Get-Cert-By-Issuer {
    param (
        [String] $Issuer
    )

    Try {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Getting Cert Issed By $Issuer"
        $CertItem = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { ($_.Subject -contains $Issuer) }
    }
    Catch {
        "Error: unable to locate certificate issued by " + $Issuer
        Exit
    }
    $CertItem
}

function Set-ThumbprintAndEncryption {
    param (
        [String] $CertThumbprint,
        [String] $RegKeyPath
    )
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Set Thumbprint and Encryption"
    if (-not($CertThumbprint)) {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Thumbprint is NULL : $CertThumbprint"
    }
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "ThumbPrint : $CertThumbprint"
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Registry path : $RegKeyPath"
    Set-ItemProperty -Path $RegKeyPath -Name ForceEncryption -Value "1"
    Set-ItemProperty -Path $RegKeyPath -Name Certificate -Value $CertThumbprint
}

function Add-Account-With-Permissions {
    param (
        [String] $AclPath,
        [String] $Account,
        [String] $Level,
        [String] $Access
    )
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message  "Manage Key: Adding $Account with Level $Level and Access $Access"
    $Permissions = Get-Acl -Path $AclPath
    $Rule = New-Object security.accesscontrol.filesystemaccessrule $Account, $Level, $Access
    $Permissions.AddAccessRule($Rule)
    Try {
        Set-Acl -Path $AclPath -AclObject $Permissions
    }
    Catch {
        "Error: unable to set ACL on certificate"
        Exit
    }
}

function Copy-Script {
    param(
        [String] $ScheduledTaskPath
    )

    if (!(Test-Path -Path $ScheduledTaskPath)) {
        New-Item -Path $ScheduledTaskPath -ItemType Directory
    }
    
    $currentPath = Get-Location
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Current Path : $currentPath"
    $file = $currentPath.Path + '\Scripts\EnableSQLIntransitEncryption.ps1'
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Copying Scheduled task file : $file"
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "SchedulePath : $ScheduledTaskPath"
    Copy-Item $file $ScheduledTaskPath -Force
}
function Restart-SQL {
    param(
        [String] $CurrentHostName
    )
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Stopping MSSQLSERVER on $CurrentHostName"
    Get-Service -Computer $CurrentHostName -Name MSSQLSERVER | Stop-Service -Force
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Starting MSSQLSERVER on $CurrentHostName"
    Get-Service -Computer $CurrentHostName -Name MSSQLSERVER | Start-Service
    Start-Service -Name "SQLSERVERAGENT"
}

function ConfigureScheduledTask {
    try {

        $TaskAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $('-NoLogo -NonInteractive -ExecutionPolicy ByPass -Command "c:\\ScheduleTasks\\EnableSQLIntransitEncryption.ps1 -StartupFlag 1"');
        $TaskTrigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay (New-TimeSpan -Seconds 30);
        $TaskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Limited ;
        $ScheduledTask = Register-ScheduledTask -TaskName SqlEncryptionInTransit -TaskPath '\' -Action $TaskAction -Trigger $TaskTrigger -Principal $TaskPrincipal -ErrorAction SilentlyContinue
    }
    Catch {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Error: unable to create scheduled task "
        Exit
    } 
}
function Test-SQLConnection {
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]$ConnectionString
    )
    try
    {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
        OpenSqlConnection -Connection $sqlConnection
        CloseSqlConnection -Connection $sqlConnection

        return $true
    }
    catch
    {
        return $false
    }
}
function OpenSqlConnection {
    Param (
        [System.Data.SqlClient.SqlConnection] $Connection
    )
    $sqlConnection.Open()
}
function CloseSqlConnection {
    Param (
        [System.Data.SqlClient.SqlConnection] $Connection
    )
    $sqlConnection.Close()
}
function Main {

    $CurrentHostName = hostname
    $SQLInstanceFullName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -Name 'MSSQLSERVER' | Select-Object -ExpandProperty 'MSSQLSERVER';
    $RegKeyPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\" + $SQLInstanceFullName +"\MSSQLServer\SuperSocketNetLib"
    $CertIssuer = "DC=Windows Azure CRP Certificate Generator"
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Startup flag is : $StartupFlag"

    if ($StartupFlag -eq 0) {
        Copy-Script $ScheduledTaskPath
        ConfigureScheduledTask
    }

    if ((Get-Service -Name 'ClusSvc' -ErrorAction SilentlyContinue)) {

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$CurrentHostName is clustered"
        $RegistryCertificateObject = Get-ItemProperty $RegKeyPath
        $CertItem = Get-Cert-By-Issuer -Issuer $CertIssuer
        
        $CertThumbPrint = $CertItem.Thumbprint
        $RegThumbPrint = $RegistryCertificateObject.Certificate
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Cert ThumbPrint : $CertThumbPrint"
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Reg ThumbPrint : $RegThumbPrint"
        
        if ( !($CertItem.Thumbprint -eq $RegistryCertificateObject.Certificate)) {

            Set-ThumbprintAndEncryption -CertThumbprint $CertItem.Thumbprint -RegKeyPath $RegKeyPath
            
            $Filename = $CertItem.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
            $AclPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\" + $Filename
            $Level = "FullControl"
            $Access = "Allow"   
            Add-Account-With-Permissions -AclPath $AclPath -Account $SQLServiceAccount -Level $Level -Access $Access

        }
    }
    else {

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$CurrentHostName is NOT clustered"
        $CurrentHost = [System.Net.Dns]::GetHostByName($CurrentHostName)
        $RegistryCertificateObject = Get-ItemProperty $RegKeyPath

        $CertItem = Get-Cert-By-FullHostname -FullHostName $CurrentHost.Hostname

        $CertThumbPrint = $CertItem.Thumbprint
        $RegThumbPrint = $RegistryCertificateObject.Certificate
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Cert ThumbPrint : $CertThumbPrint"
		Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Reg ThumbPrint : $RegThumbPrint"

        if ( !($CertItem.Thumbprint -eq $RegistryCertificateObject.Certificate)) {
            
            Set-ThumbprintAndEncryption -CertThumbprint $CertItem.Thumbprint -RegKeyPath $RegKeyPath
            
            $Filename = $CertItem.PrivateKey.CspKeyContainerInfo.UniqueKeyContainerName
            $AclPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\" + $Filename
            $Level = "FullControl"
            $Access = "Allow"
        
            if ($StartupFlag -eq 0) {
                Add-Account-With-Permissions -AclPath $AclPath -Account $SQLServiceAccount -Level $Level -Access $Access
                Copy-Script $ScheduledTaskPath
                ConfigureScheduledTask
                #Restart-SQL -CurrentHostName $CurrentHostName
                
            }
        }
    }
    #Scenario - VMs are already configured with Intransit encryption and it needs to be registered as startup task
    if($ConfigStartupflag -eq 1){
        Copy-Script $ScheduledTaskPath
        ConfigureScheduledTask
    }

    #Validation Steps for testing SQL Connection
    if(!(Test-SQLConnection "Data Source=$($CurrentHostName);database=master;Integrated Security = true" )){
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "SQL Connection check has failed"
    }
    else {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "SQL Connection check has passed!"
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Main
}