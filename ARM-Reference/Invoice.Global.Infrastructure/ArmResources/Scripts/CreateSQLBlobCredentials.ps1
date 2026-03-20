<#
.SYNOPSIS
    This post scripts applies for restore TDE certs on SQL VM's
.DESCRIPTION
    Creating credentials for BLOB
.PARAMETER BackupStorageAccount
	Name of BLOB storage account
.PARAMETER BackupStorageContainer
	Name of container
.PARAMETER BackupStorageContainerSASToken
    SAS token for container
#>

param (
    $BackupStorageAccount,
    $BackupStorageContainer,
    $BackupStorageContainerSASToken
)

function CreateCredentials{
    param(
        $BackupStorageAccount,
        $BackupStorageContainer,
        $BackupStorageContainerSASToken,
        $SqlInstanceName
    )

    $script = @"

        DECLARE @StorageContainerSASToken NVARCHAR(255), @BackupURL NVARCHAR(1500)
        DECLARE @SQL NVARCHAR(MAX) = NULL
        DECLARE @StorageAccountDetails TABLE (StorageAccount NVARCHAR(255) NOT NULL,StorageContainer NVARCHAR(255) NOT NULL,StorageContainerSASToken NVARCHAR(255) NOT NULL)

        INSERT INTO @StorageAccountDetails
        SELECT '$BackupStorageAccount', '$BackupStorageContainer', '$BackupStorageContainerSASToken' 

        WHILE EXISTS (SELECT * FROM @StorageAccountDetails)
        BEGIN

            SELECT TOP 1 @BackupURL= 'https://' + StorageAccount + '.blob.core.windows.net/' + StorageContainer, @StorageContainerSASToken = StorageContainerSASToken 
            FROM @StorageAccountDetails
            ORDER BY StorageContainerSASToken 

            RAISERROR ('Running CreateCredentials script for %s' ,0,1, @BackupURL) WITH NOWAIT

            IF EXISTS  
            (SELECT * FROM sys.credentials   
            WHERE name = @BackupURL)  
            BEGIN
                SET @SQL = 'DROP CREDENTIAL [' + @BackupURL + ']'
                EXEC SP_EXECUTESQL @SQL
            END

            SET @SQL = 'CREATE CREDENTIAL [' + @BackupURL + '] WITH IDENTITY = ''SHARED ACCESS SIGNATURE'',  SECRET = ''' + @StorageContainerSASToken + ''''
            EXEC SP_EXECUTESQL @SQL

            DELETE FROM @StorageAccountDetails WHERE StorageContainerSASToken = @StorageContainerSASToken 
            RAISERROR ('Ran CreateCredentials script for %s' ,0,1, @BackupURL) WITH NOWAIT
        END
"@
    Invoke-Sqlcmd -ServerInstance $SqlInstanceName -Query $script
}

function Get-SQLInstance {

    $InstanceName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances | Select-Object -ExpandProperty InstalledInstances | Where-Object { $_ -eq 'MSSQLSERVER' }
    $InstanceFullName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -Name $InstanceName | Select-Object -ExpandProperty $InstanceName;
    $ClusterName  = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$InstanceFullName\Cluster").ClusterName
    return $ClusterName
}

function Main{
    try {

        $vmName = $env:ComputerName
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Creating SQL Blob credential for VM :  $vmName"
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Creating SQL Blob credential for Container :  $BackupStorageContainer"
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Creating SQL Blob credential for StorageAccount :  $BackupStorageAccount"
        $sasLength = $BackupStorageContainerSASToken.Length
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " SAS length : $sasLength"

        $BackupStorageContainerSASToken = if ($BackupStorageContainerSASToken[0] -eq '?')  {$BackupStorageContainerSASToken.Substring(1)} else {$BackupStorageContainerSASToken}

		if ((Get-Service -Name 'ClusSvc' -ErrorAction SilentlyContinue)) {
            $ActiveNode = (Get-ClusterGroup | Where-Object { $_.Name -like "*SQL*" }).OwnerNode
			Write-Verbose "Active node name is $($ActiveNode)" -verbose
			$vmName = $env:ComputerName

            # For s2d cluster
			if ($Activenode -eq $vmName) {
                Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Creating SQL Blob credential : $vmName"
                $SqlInstanceName = Get-SQLInstance
                CreateCredentials $BackupStorageAccount $BackupStorageContainer $BackupStorageContainerSASToken $SqlInstanceName
            }
        }
        else {

            $vmName = $env:ComputerName
            Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Creating SQL Blob credential : $vmName"
            CreateCredentials $BackupStorageAccount $BackupStorageContainer $BackupStorageContainerSASToken $vmName
        }
    }
    catch
    {
        Write-Verbose "Error trying to create SQL Blob credential" -Verbose
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Error trying to create SQL Blob credential"
		Write-Verbose $_ -Verbose
		throw
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Main
}