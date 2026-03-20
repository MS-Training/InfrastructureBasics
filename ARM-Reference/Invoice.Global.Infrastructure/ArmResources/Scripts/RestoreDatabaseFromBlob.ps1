<#
.SYNOPSIS
    This post scripts Restores backup files from Blob container.
    Script should be run on VM's where DB's needs to be restored.
    Cluster configuration is also handle by this script
.DESCRIPTION
    This script will Restore backup files from Blob container onto SQL VM
    using SQL credential object. SQL credential should be created before hand
.PARAMETER DatabaseList
	List Databases to be restored
    eg : 'Budget,Forecast'
.PARAMETER RestoreDataFileDestination
	Location for data files for Databases
.PARAMETER RestoreLogFileDestination
    Location for log files for Databases
.PARAMETER StorageAccount
    Storage Name for DB backups
.PARAMETER Container
    Conatiner Name for DB backups
.PARAMETER ServerName
    ServerName is basically folder name inside the storage container
.PARAMETER BackupFileCount
    Number of backup files present in blob
.PARAMETER Date
    Restore date for backups to be restored
    #>
param (
    $DatabaseList,
    $RestoreDataFileDestination,
    $RestoreLogFileDestination,
    $StorageAccount,
    $Container,
    $ServerName,
    $SoxDbName,
    $BackupFileCount = 0,
    $Date
)

function RestoreDatabase{
param(
    $DatabaseList,
    $RestoreDataFileDestination,
    $RestoreLogFileDestination,
    $DropAndRestore,
    $StorageAccount,
    $Container,
    $ServerName,
    $SoxDbName,
    $BackupFileCount,
    $Date
)
    $script = @"

    DECLARE @DatabaseList VARCHAR(8000) =  '$DatabaseList'
        ,@RestoreDataFileDestination VARCHAR(1000) = '$RestoreDataFileDestination'
        ,@RestoreLogFileDestination VARCHAR(1000) = '$RestoreLogFileDestination'
        ,@DropAndRestore BIT = 'true'
        ,@StorageAccount VARCHAR(250) = '$StorageAccount'
        ,@Container VARCHAR(250) = '$Container'
        ,@ServerName VARCHAR(250) = '$ServerName'
        ,@Date VARCHAR(250) = '$Date'
        ,@SoxDbName VARCHAR(250) = '$SoxDbName'
        ,@BackupFileCount INT = $BackupFileCount -- Parameter Number of backup files. If 0 is provided, SOXBackupMetadata from Management/Platform table will be queried
        
    SET NOCOUNT ON
    DECLARE
            @DatabaseName VARCHAR(500)
        ,@URLPath VARCHAR(8000)
        ,@Cmd VARCHAR(8000)
        ,@PrimaryBackupURL VARCHAR(1000)
        ,@Num INT
        ,@NumBackupFiles INT
        ,@BackupFilesQuery VARCHAR(1000)
    
    DECLARE @NumBackupFilesTable TABLE (FileCount INT)

    --Table for capturing the result from RESTORE FILELISTONLY
    DROP TABLE IF EXISTS #RestoreFileListTable
    CREATE TABLE #RestoreFileListTable (
        [LogicalName]           NVARCHAR(128),
        [PhysicalName]          NVARCHAR(260),
        [Type]                  CHAR(1),
        [FileGroupName]         NVARCHAR(128),
        [Size]                  NUMERIC(20,0),
        [MaxSize]               NUMERIC(20,0),
        [FileID]                BIGINT,
        [CreateLSN]             NUMERIC(25,0),
        [DropLSN]               NUMERIC(25,0),
        [UniqueID]              UNIQUEIDENTIFIER,
        [ReadOnlyLSN]           NUMERIC(25,0),
        [ReadWriteLSN]          NUMERIC(25,0),
        [BackupSizeInBytes]     BIGINT,
        [SourceBlockSize]       INT,
        [FileGroupID]           INT,
        [LogGroupGUID]          UNIQUEIDENTIFIER,
        [DifferentialBaseLSN]   NUMERIC(25,0),
        [DifferentialBaseGUID]  UNIQUEIDENTIFIER,
        [IsReadOnly]            BIT,
        [IsPresent]             BIT,
        [TDEThumbprint]         VARBINARY(32),
        [SnapshotUrl]           NVARCHAR(360)
    )

    DROP TABLE IF EXISTS #BackupFiles
    CREATE TABLE #BackupFiles (ID INT IDENTITY, URL VARCHAR(500))

    -- Table for list of databases
    DROP TABLE IF EXISTS #DBListPerType
    SELECT [value] as DatabaseName  
    INTO #DBListPerType
        FROM STRING_SPLIT( @DatabaseList, ',')
        
    --Loop through each database and restore 
    WHILE EXISTS (SELECT 1 FROM #DBListPerType AS dlpt)
    BEGIN
    SELECT TOP 1 @DatabaseName = dlpt.DatabaseName FROM #DBListPerType AS dlpt ORDER BY dlpt.DatabaseName
    
    -- Drop the database
    IF EXISTS (SELECT 1 FROM sys.databases AS d WHERE d.name = @DatabaseName AND @DropAndRestore = 0)
    BEGIN
        SELECT 'Database '+@DatabaseName+' already exists and DropAndRestore flag is passed as 0. Skipping the database'
    END

    ELSE
    BEGIN
        EXEC ('
        ALTER DATABASE [' + @DatabaseName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE IF EXISTS [' + @DatabaseName + '];'
        );
        
        -- Get all the backup files
        SET @URLPath = 'https://' + @StorageAccount + '.blob.core.windows.net/' + @Container
        SET @Num = 1
        IF(@BackupFileCount != 0)
        BEGIN
        SET @NumBackupFiles = @BackupFileCount
        END
        ELSE
        BEGIN
        SET @BackupFilesQuery = 'SELECT NumberOfBackupFiles FROM ' + @SoxDbName + '.dbo.SOXBackupMetadata WHERE DatabaseName = ' + '''' + @DatabaseName + ''''
        INSERT @NumBackupFilesTable
        EXEC(@BackupFilesQuery)
        SELECT @NumBackupFiles = FileCount from @NumBackupFilesTable
        END
        WHILE(@Num <= @NumBackupFiles)
        BEGIN
            INSERT INTO #BackupFiles VALUES(@ServerName + '/' + @DatabaseName + '/' + @DatabaseName + '_' + @Date + '_' + CAST(@Num as varchar(10)) + '.bak')
            SET @Num = @Num + 1
        END

        DELETE #BackupFiles WHERE URL IS NULL
        IF EXISTS (SELECT * FROM #BackupFiles)
        BEGIN
        SELECT @PrimaryBackupURL = URL FROM #BackupFiles WHERE ID = 1
        -- Get the data files and log files from the backup
        INSERT INTO #RestoreFileListTable
        EXEC('RESTORE FILELISTONLY FROM URL = ''' + @URLPath + '/' + @PrimaryBackupURL + '''')
        END
        
        SELECT @Cmd = N'RESTORE DATABASE [' + @DatabaseName + '] FROM ' 
        SELECT @Cmd = @Cmd + ' URL = ''' +  @URLPath + '/' + URL + ''',' FROM #BackupFiles 
        SET @Cmd = LEFT(@Cmd, LEN(@Cmd) - 1) 
        SET @Cmd += ' 
            WITH FILE = 1,'
        --- Files
        SELECT @Cmd = @Cmd + N'
            MOVE ''' + LogicalName + ''' TO ''' + @RestoreDataFileDestination + '\' + LogicalName + '.ndf' + ''','
            FROM #RestoreFileListTable
            WHERE Type = 'D'
        --- Logs
        SELECT @Cmd = @Cmd + N'
            MOVE ''' + LogicalName + ''' TO ''' + @RestoreLogFileDestination + '\' + LogicalName + '_log.ldf' + ''', '
            FROM #RestoreFileListTable
            WHERE Type = 'L'
        SET @Cmd += ' REPLACE, NOUNLOAD,  STATS = 1'

        SELECT 'Restoring database '+@DatabaseName
        EXEC (@Cmd)
    END

    DELETE FROM #DBListPerType WHERE DatabaseName = @DatabaseName
    TRUNCATE TABLE #BackupFiles
    TRUNCATE TABLE #RestoreFileListTable

    END
"@
    Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Executing SQL Script "
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
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Restoring databases on :  $vmName"
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Database List :  $DatabaseList"
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " StorageAccount :  $StorageAccount"
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " StorageAccountContainer :  $Container"
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " DropAndrestore :  $DropAndRestore"

		if ((Get-Service -Name 'ClusSvc' -ErrorAction SilentlyContinue)) {
            $ActiveNode = (Get-ClusterGroup | Where-Object { $_.Name -like "*SQL*" }).OwnerNode
			Write-Verbose "Active node name is $($ActiveNode)" -verbose
			$vmName = $env:ComputerName

            # For s2d cluster
			if ($Activenode -eq $vmName) {
                Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Restoring databases on : $vmName"
                $SqlInstanceName = Get-SQLInstance
                RestoreDatabase $DatabaseList $RestoreDataFileDestination $RestoreLogFileDestination $DropAndRestore $StorageAccount $Container $ServerName $SoxDbName $BackupFileCount $Date
            }
        }
        else {

            $vmName = $env:ComputerName
            Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Restoring databases on : $vmName"
            RestoreDatabase  $DatabaseList $RestoreDataFileDestination $RestoreLogFileDestination $DropAndRestore $StorageAccount $Container $ServerName $SoxDbName $BackupFileCount $Date
        }
    }
    catch
    {
        Write-Verbose "Error trying to Restore databases from Blob " -Verbose
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Error trying to Restore databases from Blob"
		Write-Verbose $_ -Verbose
		throw
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Main
}