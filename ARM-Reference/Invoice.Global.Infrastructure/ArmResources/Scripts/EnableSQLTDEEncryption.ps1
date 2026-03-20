<#
.SYNOPSIS
    This post scripts applies for enabling TDE encryption on SQL VM's
.DESCRIPTION
    After the VMs are created, this script will create TDE cert using
	Master key PWD and set TDE SQL set encryption on all DB's
	Cert will be then backed up on $Path location
.PARAMETER MasterKeyPWD
    This is used for creating database master key
.PARAMETER CertPwd
	This is used for creating cert on databases
.PARAMETER Path
    Path for backuping up cert of VM's
#>
param (
	[string] $MasterKeyPWD,
	[string] $CertPwd,
	[string] $Path = 'C:\Temp'
)


function ConfigureTDECert {
	param (
		[string] $MasterKeyPWD,
		[string] $CertPwd,
		[string] $SqlInstanceName
	)


	$script = @"
				SET NOCOUNT ON
		
				DECLARE @Path VARCHAR(200)
				DECLARE @SQLString VARCHAR(1000) = ''
				DECLARE @DBName VARCHAR(50)
				DECLARE @DBWithNoKey AS TABLE (DBName VARCHAR(50))
				DECLARE @DBWithNoTDE AS TABLE (DBName VARCHAR(50))
				DECLARE @CertName VARCHAR(200)
				DECLARE @MKP VARCHAR(50) = '$MasterKeyPWD'
				DECLARE @CertPwd VARCHAR(50) = '$CertPwd'

				IF @MKP LIKE '%(MasterKeyPWD)' 
				BEGIN
					RAISERROR('Value for (MasterKeyPWD) not supplied',18,127) WITH NOWAIT
				END
				ELSE IF @CertPwd LIKE '%(CertPwd)' 
				BEGIN
					RAISERROR('Value for (CertPwd) not supplied',18,127) WITH NOWAIT
				END
				ELSE
				BEGIN

					SET @Path = isnull(@Path, 'C:\Temp\') + @@servername + '_' + replace(convert(VARCHAR(30), getdate(), 126), ':', '')
					SET @CertName = isnull(@CertName, 'FSATDECert') + @@servername
				
					------------------------------------------------------------------------------------
					--- Create database master key (DMK), open it up and back it up.
					------------------------------------------------------------------------------------
					IF NOT EXISTS (
							SELECT b.name
								,a.crypt_type_desc
							FROM sys.key_encryptions a WITH (NOLOCK)
							INNER JOIN sys.symmetric_keys b WITH (NOLOCK) ON a.key_id = b.symmetric_key_id
							WHERE b.name = '##MS_DatabaseMasterKey##'
							)
					BEGIN
						SELECT 'Creating Master Key...'
				
						SET @SQLString = 'CREATE MASTER KEY ENCRYPTION BY PASSWORD = ''' + @MKP + ''''
				
						EXEC (@SQLString)
				
						SELECT 'Opening Master Key...'
				
						SET @SQLString = 'OPEN MASTER KEY DECRYPTION BY PASSWORD = ''' + @MKP + ''''
				
						EXEC (@SQLString);
				
						SELECT 'Backup Master Key...'
				
						SET @SQLString = 'BACKUP MASTER KEY TO FILE = ''' + @Path + '_DMK.dmk'' ENCRYPTION BY PASSWORD = ''DMK' + @MKP + ''''
				
						EXEC (@SQLString);
					END
					ELSE
						SELECT 'Master Key Already Exists...'
				
					------------------------------------------------------------------------------------
					--- Create a certificate and take backup of that certificate.
					------------------------------------------------------------------------------------
					IF NOT EXISTS (
							SELECT [name]
							FROM sys.certificates WITH (NOLOCK)
							WHERE pvt_key_encryption_type_desc = 'ENCRYPTED_BY_MASTER_KEY'
							)
					BEGIN
						SELECT 'Creating Certificate...'
				
						USE master;
				
						SET @SQLString = 'CREATE CERTIFICATE ' + @CertName + ' WITH SUBJECT = ''MSSalesFSASelfSignedCertDev'''
				
						EXEC (@SQLString);
				
						SELECT 'Backup Certificate ...'
				
						SET @SQLString = 'BACKUP CERTIFICATE ' + @CertName + ' TO FILE = ''' + @Path + '_CertForTDE.cer''' + ' WITH PRIVATE KEY ( 
							FILE = ''' + @Path + '_CertPvtKeyTDE.pkv'', 
							ENCRYPTION BY PASSWORD = ''' + @CertPwd + ''')'
				
						EXEC (@SQLString);
					END
					ELSE
						SELECT 'Certificate Already Exists...'
				
					------------------------------------------------------------------------------------
					--- Create Database Encryption Key for databases that dont have the Key.
					------------------------------------------------------------------------------------
					INSERT INTO @DBWithNoKey (DBName)
					SELECT [name]
					FROM sys.databases d(NOLOCK)
					LEFT JOIN sys.dm_database_encryption_keys ek WITH (NOLOCK) ON d.database_id = ek.database_id
					WHERE d.is_master_key_encrypted_by_server = 0
						AND (
							encryption_state IS NULL
							OR encryption_state = 0
							)
						AND [name] NOT IN (
							'master'
							,'model'
							,'tempdb'
							,'msdb'
							,'resource'
							)
					ORDER BY [name]
				
					WHILE (
							SELECT count(*)
							FROM @DBWithNoKey
							) > 0
					BEGIN
						SELECT TOP 1 @DBName = DBName
						FROM @DBWithNoKey
				
						SET @SQLString = 'Use ' + @DBName + '; ' + 'CREATE DATABASE ENCRYPTION KEY WITH ALGORITHM = AES_256 ENCRYPTION BY SERVER CERTIFICATE ' + @CertName
				
						SELECT 'Enabling Database Key for ' + @DBName
				
						EXEC (@SQLString)
				
						DELETE
						FROM @DBWithNoKey
						WHERE DBName = @DBName
					END
					
					------------------------------------------------------------------------------------
					--- Turn TDE (Transparent Data Encryption) On
					------------------------------------------------------------------------------------
					INSERT INTO @DBWithNoTDE (DBName)
					SELECT [name]
					FROM sys.databases d(NOLOCK)
					LEFT JOIN sys.dm_database_encryption_keys ek WITH (NOLOCK) ON d.database_id = ek.database_id
					WHERE d.is_master_key_encrypted_by_server = 0
						AND (encryption_state = 1)
						AND [name] NOT IN (
							'master'
							,'model'
							,'tempdb'
							,'msdb'
							,'resource'
							)
					ORDER BY [name]
				
					WHILE (
							SELECT count(*)
							FROM @DBWithNoTDE
							) > 0
					BEGIN
						SELECT TOP 1 @DBName = DBName
						FROM @DBWithNoTDE
				
						SET @SQLString = 'ALTER DATABASE ' + @DBName + ' SET ENCRYPTION ON'
				
						SELECT 'Enabling TDE for ' + @DBName
				
						EXEC (@SQLString)
				
						DELETE
						FROM @DBWithNoTDE
						WHERE DBName = @DBName
					END
				
				END
				
				SET NOCOUNT OFF
"@


Write-Verbose  "Enabling TDE for  [$($SqlInstanceName)] " -verbose
Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Enabling TDE for  $SqlInstanceName"
Invoke-Sqlcmd -ServerInstance $SqlInstanceName -Query $script 

}

function Get-SQLInstance {

    $InstanceName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances | Select-Object -ExpandProperty InstalledInstances | Where-Object { $_ -eq 'MSSQLSERVER' }
    $InstanceFullName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -Name $InstanceName | Select-Object -ExpandProperty $InstanceName;
    $ClusterName  = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$InstanceFullName\Cluster").ClusterName
    return $ClusterName
}

function CreateBackupCertFilePath {
	param (
		[string] $Path
	)
	
	if (!(Test-Path -Path $Path)) {
		New-Item -Path $Path -ItemType Directory
	}
}

function Main{

	try {

		Write-Verbose  "Creating Certificate Backup Paths for  [$($env:ComputerName)] " -verbose
		CreateBackupCertFilePath $Path

		if ((Get-Service -Name 'ClusSvc' -ErrorAction SilentlyContinue)) {

			$ActiveNode = (Get-ClusterGroup | Where-Object { $_.Name -like "*SQL*" }).OwnerNode
			Write-Verbose "Active node name is $($ActiveNode)" -verbose
			$vmName = $env:ComputerName
	
			if ($Activenode -eq $vmName) {

				$SqlInstanceName = Get-SQLInstance
				Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Active Node :  $ActiveNode"
				ConfigureTDECert $MasterKeyPWD $CertPwd $SqlInstanceName
			}
		}
		else {
		
			$vmName = $env:ComputerName
			ConfigureTDECert $MasterKeyPWD $CertPwd $vmName
		}
	}
	catch {
		
		Write-Verbose "Error trying to enable TDE" -Verbose
		Write-Verbose $_ -Verbose
		throw
	}
}

if ($MyInvocation.InvocationName -ne '.') {
	Main
}