<#
.SYNOPSIS
    This post scripts applies for restore TDE certs on SQL VM's
.DESCRIPTION
    After the VMs are created, this script will restore TDE cert using
	Keyvault.
.PARAMETER Cert
	Cert to be downloaded from KeyVault in base64 secure string
.PARAMETER CertName
	Cert to be downloaded from KeyVault
.PARAMETER Path
    Download and restore path for TDE Cert
.PARAMETER Password
    Password for restoring TDe cert
.PARAMETER PVKPath
    File Path for PVK converter
#>

param (
    $Cert,
	$CertName,
	$Path = 'C:\Temp\',
    $Password,
    $PVKPath = 'C:\AzureArmTemplates\',
    $SqlInstanceName = ''
)

function DownloadTDECertFromKV {
	param (
		[string] $KeyVaultName,
		[string] $CertName,
        [string] $Path,
        [string] $Password
	)
    try {
        $cert = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertName
        $secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $cert.Name -AsPlainText
        $secretByte = [Convert]::FromBase64String($secret)
        $x509Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($secretByte, "", "Exportable,PersistKeySet")
        $type = [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx
        $pfxFileByte = $x509Cert.Export($type, $Password)

        # Write to a file
        [System.IO.File]::WriteAllBytes($Path + $CertName +".pfx", $pfxFileByte)
    }
    catch {
    
        Write-Verbose "Error downloading to cerificate from Keyvault" -Verbose
        Write-Verbose $_ -Verbose
        throw
    }
}

function CreateCertFromSecret {
    param (
        $cert,
        $Password,
        $CertName
    )
    # $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cert.SecretValue)
    # $certBase64 = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "CertName :  $CertName"
    $secretByte = [Convert]::FromBase64String($cert)
    $x509Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($secretByte, $Password, "Exportable,PersistKeySet")
    $type = [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx
    $pfxFileByte = $x509Cert.Export($type, $Password)
    [System.IO.File]::WriteAllBytes($Path + $CertName +".pfx", $pfxFileByte)
    Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Cert Conversion Completed "
}

function InstallCDistributionForPVK {
    param (
        $installerPath
    )
    Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Installing C Distribution for PVK"
    $file = $installerPath + 'vcredist_x64_pvk.exe'
    $fileBaseName = ((Get-Item -Path $file).BaseName).ToUpper()
    $license = "IACCEPT$fileBaseName" + "LICENSETERMS=YES"

    Start-Process -FilePath $file -Wait -ArgumentList "/config unattended.xml /q $($license)" -PassThru
}

function ConvertPfxToPvk {
    param(
        $CertName,
        [string] $Path,
        $Password
    )

    try {
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Converting to Pfx to Pvk for : $CertName"
        $inputPath = $Path + $CertName +".pfx"
        $outputPath = $Path + $CertName
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Input Path for : $inputPath"
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Output Path for : $outputPath"
        C:\AzureArmTemplates\PVKConverter.exe -i $inputPath -o $outputPath -d $Password -e $Password
    }
    catch {
    
        Write-Verbose "Error converting to Pfx to Pvk" -Verbose
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Error converting to Pfx to Pvk"
        Write-Verbose $_ -Verbose
        throw
    }
}

function Get-SQLInstance {

    $InstanceName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances | Select-Object -ExpandProperty InstalledInstances | Where-Object { $_ -eq 'MSSQLSERVER' }
    $InstanceFullName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -Name $InstanceName | Select-Object -ExpandProperty $InstanceName;
    $ClusterName  = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$InstanceFullName\Cluster").ClusterName
    return $ClusterName
}

function DeleteExistingCertFiles {
    param (
        $Path,
        $CertName
    )

    Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Deleting certs if present"
    $CertFilePfx = $Path+$CertName+".pfx"
    $CertFile = $Path+$CertName+"_1.cer"
    $CertFilePvk = $Path+$CertName+"_1.pvk"

    if (Test-Path -Path $CertFilePfx) {
        Remove-Item $CertFilePfx
    }
    if (Test-Path -Path $CertFile) {
        Remove-Item $CertFile
    }
    if (Test-Path -Path $CertFilePvk) {
        Remove-Item $CertFilePvk
    }
    
}

function CreateTDECert{
    param(
        $CertName,
        $Path,
        $Password,
        $SqlInstanceName
    )

    try {
    
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "PVK CertName :  $CertName"
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Instance :  $SqlInstanceName"
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Cert Path :  $Path"

        $script = @"
            SET NOCOUNT ON
    
            DECLARE @Path VARCHAR(200) = '$Path'
            DECLARE @SQLString VARCHAR(1000) = ''
            DECLARE @CertName VARCHAR(200) = '$CertName'
            DECLARE @CertPwd VARCHAR(50) = '$Password'
            DECLARE @CertPath VARCHAR(100) = @Path+ @CertName + '_1.cer'
            DECLARE @KeyPath VARCHAR(100) = @Path+ @CertName + '_1.pvk'
        
            SELECT @SQLString ='
            CREATE CERTIFICATE ' + @CertName +
            ' FROM FILE =  ''' + @CertPath +
            ''' WITH PRIVATE KEY ( FILE =  '''+ @KeyPath +
            ''' ,DECRYPTION BY PASSWORD = '''+@CertPwd +''' )'
    
            EXEC(@SQLString)
            
            SET NOCOUNT OFF
"@
        Invoke-Sqlcmd -ServerInstance $SqlInstanceName -Query $script
    }
    catch {
    
        Write-Verbose "Error restoring TDE cert" -Verbose
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Error restoring TDE cert"
        Write-Verbose $_ -Verbose
        throw
    }
}
function Main{
    try {

        $vmName = $env:ComputerName
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " CertName :  $CertName"
        # $BSTRPassword = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        # $PasswordStr = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTRPassword )
        # DownloadTDECertFromKV $KeyVaultName $CertName $Path $PasswordStr
        InstallCDistributionForPVK $PVKPath
         

		if ((Get-Service -Name 'ClusSvc' -ErrorAction SilentlyContinue)) {

			$ActiveNode = (Get-ClusterGroup | Where-Object { $_.Name -like "*SQL*" }).OwnerNode
			Write-Verbose "Active node name is $($ActiveNode)" -verbose
			$vmName = $env:ComputerName
            
            # For s2d cluster
			if ($Activenode -eq $vmName) {
                
                Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Enabling cert for :  $vmName"
                if($SqlInstanceName.Length -eq 0)
                {
                    $SqlInstanceName = Get-SQLInstance
                }
                DeleteExistingCertFiles $Path $CertName
                CreateCertFromSecret $Cert $Password $CertName
                ConvertPfxToPvk $CertName $Path $Password
                CreateTDECert $CertName $Path $Password $SqlInstanceName
            }
        }
        else {

            $vmName = $env:ComputerName
            Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Enabling cert for :  $vmName"
            if($SqlInstanceName.Length -eq 0)
            {
                $SqlInstanceName = $vmName
            }
            DeleteExistingCertFiles $Path $CertName
            CreateCertFromSecret $Cert $Password $CertName
            ConvertPfxToPvk $CertName $Path $Password
            CreateTDECert $CertName $Path $Password $SqlInstanceName
        }
    }
    catch {

		Write-Verbose "Error trying to Restore TDE cert" -Verbose
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Error trying to Restore TDE cert"
		Write-Verbose $_ -Verbose
		throw
	}
}

if ($MyInvocation.InvocationName -ne '.') {
	Main
}