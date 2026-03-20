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
.PARAMETER Container
    storage account container source
.PARAMETER VMPumpDirectory
    target vm module directory
.PARAMETER StorageAccountKey
    storage account key
.PARAMETER ServiceAccountName
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
    [String] $ServiceAccountName,
    [String] $driveLetter,
    [String] $pumpEnvironment,
    [String] $downloadsDirectory = "C:\AzureArmTemplates\",
    [Parameter(Mandatory = $true)]
    $ServiceAccountPassword
)

$ErrorActionPreference = "Stop"


function RunRegistryFilesOnVM {
    param(

    )
    $regFilesPath = $downloadsDirectory
    $registryFiles = Get-ChildItem $regFilesPath -Filter *.reg
    $registryFiles

    foreach ($file in $registryFiles) {
        Start-Process reg -ArgumentList "import $regFilesPath\$file"
    }
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Completed updating registries" 
}

function UpdateEDIRegistryToCorrectDriver {
    param(

    )
    Function SetRegKey {
        param ($enableMasking)
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "----Starting Updating the registry for $env:computername ----" 
        Write-Host("Before:")
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\SQL Server' -Name "Driver").Driver
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\SQL Server' -Name "Setup").Setup
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\SQL Server' -Name "Driver").Driver
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\SQL Server' -Name "Setup").Setup

        if ($enableMasking) {
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\SQL Server' -Name 'Driver' -Value 'C:\WINDOWS\system32\msodbcsql13.dll' -Type ExpandString
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\SQL Server' -Name 'Setup' -Value 'C:\WINDOWS\system32\msodbcsql13.dll' -Type ExpandString
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\SQL Server' -Name 'Driver' -Value 'C:\WINDOWS\SysWOW64\msodbcsql13.dll' -Type String
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\SQL Server' -Name 'Setup' -Value 'C:\WINDOWS\SysWOW64\msodbcsql13.dll' -Type String
        }
        else {
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\SQL Server' -Name 'Driver' -Value '%WINDIR%\system32\SQLSRV32.dll' -Type ExpandString
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\SQL Server' -Name 'Setup' -Value '%WINDIR%\system32\sqlsrv32.dll' -Type ExpandString
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\SQL Server' -Name 'Driver' -Value 'C:\WINDOWS\system32\sqlsrv32.dll' -Type String
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\SQL Server' -Name 'Setup' -Value 'C:\WINDOWS\system32\sqlsrv32.dll' -Type String
        }
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "After:" 
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\SQL Server' -Name "Driver").Driver
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\SQL Server' -Name "Setup").Setup
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\SQL Server' -Name "Driver").Driver
        (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\SQL Server' -Name "Setup").Setup
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "----Finished Updating the registry----" 
    }
    $testPathForODBC13 = (Test-Path -Path 'C:\WINDOWS\SysWOW64\msodbcsql13.dll')
    $testPathSQL = (Test-Path -Path 'HKLM:\SOFTWARE\ODBC\ODBCINST.INI\SQL Server')
    $testPathWow6432SQL = (Test-Path -Path 'HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\SQL Server')
    if ($testPathForODBC13) {
        if ($testPathSQL -and $testPathWow6432SQL) {
            SetRegKey -enableMasking $True
        }
        else {
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The keys [HKLM:\SOFTWARE\ODBC\ODBCINST.INI\SQL Server] and [HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBCINST.INI\SQL Server] do not exist. Please reach out to msssapphire@microsoft.com" 
        }
    }
    else {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The odbcsql13 driver does not exist in the system. Please reach out to msssapphire@microsoft.com" 
    } 
}

function MovePumpFilesToDirectory {
    param(

    )
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Moving Pump Files from  $($driveletter)\$($pumpEnvironment) to $($driveletter)..." 
    Copy-Item -Path "$downloadsDirectory$($pumpEnvironment)\$($pumpEnvironment)\*" -Destination "$($driveletter)\" -Recurse -Force  -confirm:$false
}

function ExceptionCatchRetryHandler {

    param (
        [scriptBlock] $PrimaryExectionBlock,
        $PrimaryExectionBlockParameters,
        $AppInsightsParams,
        [switch] $UseExponentialBackOff,
        [Int] $TotalRetries = 4,
        [Int] $BaseRetryWaitTimeInSeconds = 30
    )

    $retries = $TotalRetries
    $completedSuccessfully = $false

    do {
        try {

            $output = $PrimaryExectionBlock.Invoke($PrimaryExectionBlockParameters)
            $completedSuccessfully = $true

        }
        catch {
            Write-Verbose "Failed to run execution block" -Verbose
            Write-Verbose $_ -Verbose

            $retries -= 1

            if ($AppInsightsParams) {
                $AppInsightsParams.Exception = $_.Exception
                LogAppInsightsEvent @AppInsightsParams
            }

            if ($UseExponentialBackOff) {
                $BaseRetryWaitTimeInSeconds *= 2
            }

            if ($retries -gt 0) {
                Write-Verbose "Going to wait $BaseRetryWaitTimeInSeconds and then try again" -Verbose
                Start-Sleep -s $BaseRetryWaitTimeInSeconds
            }
            else {
                Write-Verbose "Execution block continues to fail after $TotalRetries retries. Throwing exception." -Verbose
                throw
            }
        }

    }until($completedSuccessfully -eq $true)

    $output
}

function CleanDirectoryAndContent {
    $cmodsPath = "$($driveletter)\CMODS"
    $cmodsnewPath = "$($driveletter)\CMODSNew"
    $azureFileServicePath = "$($driveletter)\AzureFileService"
    if (Test-Path $cmodsPath) {
        Remove-Item -LiteralPath $cmodsPath -recurse -Force -Verbose
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The directory $($cmodsPath) was removed"   
    }
    else {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The directory $($cmodsPath) doesn't exist"
    }
    if (Test-Path $cmodsnewPath) {
        Remove-Item -LiteralPath $cmodsnewPath -recurse -Force -Verbose
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The directory $($cmodsnewPath) was removed"
    }
    else {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The directory $($cmodsnewPath) doesn't exist"
    }
    if (Test-Path $azureFileServicePath) {
        Remove-Item -LiteralPath $azureFileServicePath -recurse -Force -Verbose
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The directory $($azureFileServicePath) was removed"
    }
    else {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "The directory $($azureFileServicePath) doesn't exist"
    }
}


function CopyingLibrariesToSystemRoot {
    param(

    )
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Moving dlls.." 
    Copy-Item -Path "$($driveletter)\Libraries\*" -Destination "C:\Windows\SysWOW64"  -Recurse -Force
}

function DeployingPumpServices {
    param(

    )

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Starting Deploying Pumps" 
    function CreateNewService {
        param(
            [String] $ServiceName,
            [String] $PumpExePath,
            [String] $StartupType = "Automatic"
        )

        $ServiceAccountPassword = ConvertTo-SecureString -String $ServiceAccountPassword -Force -AsPlainText
        $credential = New-Object System.Management.Automation.PSCredential($ServiceAccountName, $ServiceAccountPassword)
        New-Service -Name $ServiceName -StartupType $StartupType -BinaryPathName $PumpExePath -Credential $credential -Verbose     
    }

    $Pumps = @{
        'XPump'                              = 'G:\CMODS\XPump\XPump.exe' ;
        'CPump'                              = 'G:\CMODS\CPump\CPump.exe';
        'EDIPump'                            = 'G:\CMODS\EDIPump\EDIPump.exe';
        'CPUMPNew'                           = 'G:\CMODSNEW\CPUMP\Microsoft.IT.MSSales.CPump.CPumpWindowsService.exe'
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

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Completed Deploying Pumps" 
}

function CreateDesktopFolderInSystemProfile {
    #A Desktop folder is necessary in the systemprofile folder to open file by Excel
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Adding a Desktop folder under  C:\Windows\SysWOW64\config\systemprofile\ for Excel 2007" 
    $systemProfilePath = 'C:\Windows\SysWOW64\config\systemprofile\Desktop'
    
    If (!(test-path $systemProfilePath)) {
        Write-Verbose "Creating directory $systemProfilePath" -Verbose 
        New-Item -Path $systemProfilePath -ItemType Directory
    }
    else {
        Write-Verbose "Directory $systemProfilePath already exists" -Verbose
    }
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Finished creating desktop folder" 
}

function installOffice {
    if (Test-Path "HKLM:\Software\Microsoft\Office\12.0") {

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Office 2007 is already installed.  Skipping..." 
    }
    else {
       
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Office 2007 is not installed.  Installing..." 
        Start-Process -FilePath "$($downloadsDirectory)OfficeEnterprise_2007/setup.exe" -Wait -ArgumentList "/config unattended.xml" -PassThru
    }

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Finished installing Office 2007 to $env:COMPUTERNAME" 
}

function installdotNet35 {

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Downloading .NET 3.5 Framework from blob storage" 

    if ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer").UseWUServer) {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Setting windows update AU registry value" 
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "UseWUServer" -Value 0
    }
    else {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Windows AU registry value already set" 
    }

    Install-WindowsFeature Net-Framework-Core

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Finished installing .NET 3.5 to $env:COMPUTERNAME" 
}

function installVisualC {

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Downloading Visual C++ from blob storage" 
    Start-Process "$($downloadsDirectory)vcredist_x64.exe" -Wait -ArgumentList "/q"

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Finished installing Visual C++" 
}

function installODBCDriver {

    if ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft ODBC Driver 13 for SQL Server" -ErrorAction SilentlyContinue)) {

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "SQL Server 2017 ODBC Driver $fileName is already Installed. Skipping..."

    }
    else{

        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Downloading ODBC driver from blob storage" 
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing driver" 
        Start-Process msiexec.exe -Wait -ArgumentList "/I $($downloadsDirectory)msodbcsql.msi /q /qb IACCEPTMSODBCSQLLICENSETERMS=YES ALLUSERS=1 /norestart"

    }

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Finished installing ODBC driver" 
}

function importCertificateForICMODS {
    $pfxPath = "$($driveletter)\Temp\icmodscert.pfx"
    $tempPath = "$($driveletter)\Temp"
    $pathExists = Test-Path $tempPath
    if ($pathExists) {
        Write-Verbose "Path exists" -Verbose    
    }
    else {
        New-Item -Path $tempPath -ItemType Directory -Verbose
    }
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Downloading certificate from keyvault $KeyVaultName $CertificateName" 

    $cert_using_AzKeyvaultCertificate = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -CertificateName $CertificateName
    $certBytes_for_AzKeyvaultCertificate = [System.Convert]::FromBase64String($cert_using_AzKeyvaultCertificate.SecretValueText)
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) certBytes_for_AzKeyvaultCertificate.count : $($certBytes_for_AzKeyvaultCertificate.Count)"

    $cert = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $CertificateName
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Inside importCertificateForICMODS CertName: $($cert.Name)"
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Cert.Expires: $($cert.Expires)"
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Cert.Enabled: $($cert.Enabled)"
    $certBytes = [System.Convert]::FromBase64String($cert.SecretValueText)
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) certBytes.count : $($certBytes.Count)"
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
    $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $certCollection.Import($certBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
    $pfxFileByte = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::pkcs12)

    # Write to a file
    [System.IO.File]::WriteAllBytes($pfxPath, $pfxFileByte)

}
function main {

    try {
        $nodeName = $env:COMPUTERNAME

 
        if(($nodeName.Substring($nodeName.length -1,1)) -eq 1 ){

            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Clean directory and content..." 
            ExceptionCatchRetryHandler -PrimaryExectionBlock $Function:CleanDirectoryAndContent -UseExponentialBackOff -TotalRetries 5
    
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Moving files..." 
            MovePumpFilesToDirectory
        
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Copying required libraries on system root..." 
            CopyingLibrariesToSystemRoot
    
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Running registry files..." 
            RunRegistryFilesOnVM
    
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing Pump services..." 
            DeployingPumpServices
    
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Creating Desktop Folder in systemprofile..." 
            CreateDesktopFolderInSystemProfile
    
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing Office 2007 (for xpump)..." 
            installOffice
    
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing .NET..." 
            installdotNet35
    
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing Visual C..." 
            installVisualC
    
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing ODBC driver..." 
            installODBCDriver
    
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Updating Driver key for EDI Pump..." 
            UpdateEDIRegistryToCorrectDriver
    
            ##Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing Certificate required for ICMODs..." 
            ##importCertificateForICMODS

            shutdown /r /t 0

        }
        else{

            Start-Sleep 30            
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Installing Pump services..." 
            DeployingPumpServices
        }

    }

    catch {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$($_.Exception.ToString())" 
        throw $($_.Exception.ToString())
    }
    #starting services
}
if ($IsTest -eq "False") {
    main
}
