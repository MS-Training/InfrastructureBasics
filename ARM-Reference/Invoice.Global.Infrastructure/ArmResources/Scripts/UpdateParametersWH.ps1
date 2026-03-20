
param (
    $baseName,
    $ThreeLetterEnv,
    $ThreeLetterClusterSuffix
)
function UpdateParameters{
    param(
        $baseName,
        $ThreeLetterEnv,
        $ThreeLetterClusterSuffix,
        $SqlInstanceName
    )

    $script = @"

        RAISERROR ('Running UpdateParametersWH script',0,1) WITH NOWAIT
        DECLARE
        @PrimaryMTServer NVARCHAR(50) 
        ,@SecondaryMTServer NVARCHAR(50)
        ,@FactoryServer NVARCHAR(50)
        ,@BaseName nvarchar(10) = '$baseName'
        ,@ThreeLetterEnv nvarchar(10) = '$ThreeLetterEnv'
        ,@clusterPostFix nvarchar(10) = '$ThreeLetterClusterSuffix'
        ,@FactoryNode1 NVARCHAR(50)
        ,@FactoryNode2 NVARCHAR(50)
        ,@WHServer NVARCHAR(50)
        ,@FileServer NVARCHAR(50)
        ,@LogServer NVARCHAR(50)

        SELECT @PrimaryMTServer = concat(@BaseName,@ThreeLetterEnv,'MT',@clusterPostFix);
        SELECT @SecondaryMTServer = concat(@BaseName,@ThreeLetterEnv,'MT',@clusterPostFix);
        SELECT @FactoryServer = concat(@BaseName,@ThreeLetterEnv,'FAC1',@clusterPostFix);
        SELECT @FactoryNode1 = concat(@BaseName,@ThreeLetterEnv,'FAC1');
        SELECT @FactoryNode2 = concat(@BaseName,@ThreeLetterEnv,'FAC2');
        SELECT @WHServer = concat(@BaseName,@ThreeLetterEnv,'WH',@clusterPostFix);
        SELECT @FileServer = concat(@BaseName,@ThreeLetterEnv,'FILE',@clusterPostFix);
        SELECT @LogServer = CASE WHEN @@SERVERNAME LIKE '%PAB%' THEN 'Medway' ELSE '' END


        IF @@SERVERNAME LIKE '%WH%'
        BEGIN
            IF @BaseName IS NOT NULL AND @ThreeLetterEnv IS NOT NULL AND @clusterPostFix IS NOT NULL
            BEGIN
            
            MERGE Management..Parameters AS TARGET
            USING (
                SELECT * FROM (VALUES 
                ('ReleaseManagerEnvironmentID',NULL,NULL,NULL,NULL),
                ('WHServer',NULL,NULL,NULL,NULL),
                ('FactoryServer',NULL,NULL,@FactoryServer,NULL),
                ('PrimaryMTServer',NULL,NULL,@PrimaryMTServer,NULL),
                ('SecondaryMTServer',NULL,NULL,@SecondaryMTServer,NULL),
                ('MSSalesDB',NULL,NULL,'MSSales',NULL),
                ('MiddleTierDB',NULL,NULL,'MSRMetadata',NULL),
                ('QueriesTimeout',NULL,0,NULL,NULL),
                ('RestoreMinDaily',NULL,300,NULL,NULL),
                ('RestoreMinALL',NULL,600,NULL,NULL),
                ('RestoreModeDaily',NULL,3,NULL,NULL),
                ('RestoreModeAll',NULL,2,NULL,NULL),
                ('Analyst',NULL,NULL,'MSSOPS',NULL),
                ('RetryAttempts',NULL,3,NULL,NULL),
                ('RetryInterval',NULL,NULL,'00:00:30',NULL),
                ('JobLogsServer',NULL,NULL,@LogServer,NULL),
                ('JobGroupName',NULL,NULL,NULL,NULL),
                ('WaitTimeforDelay',NULL,NULL,'00:10:00',NULL),
                ('DSLProcName',NULL,NULL,'DSLGet',NULL),
                ('EDW Delta Retention Duration',NULL,15,NULL,NULL),
                ('UpdateNRSOnlyBeginFiscalMonthId',NULL,265,NULL,'Begin Fiscal Month Id for UpdateNRSOnlyForNonQualified factory'),
                ('UpdateNRSOnlyEndFiscalMonthId',NULL,324,NULL,'End Fiscal Month Id for UpdateNRSOnlyForNonQualified factory'),
                ('SAPRARRedoStartFMID',NULL,381,NULL,'Start FiscalMonthID for SAPRAR Redo Process'),
                ('SAPRARRedoEndFMID',NULL,384,NULL,'End FiscalMonthID for SAPRAR Redo Process'),
                ('TransformFutureNumberofRowsInEachThread',NULL,NULL,'250000','Number of rows in each thread of TransformFuture factory'),
                ('AzureChannelOldestMonthID',NULL,301,NULL,NULL),
                ('AzureAZCopyExePath',NULL,NULL,'C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy\AzCopy','Path where AZCopy exe is'),
                ('AzureInventoryOldestMonthID',NULL,301,NULL,NULL),
                ('CBRRStagingDatafilePath',NULL,NULL,'H:\MSSQL15.MSSQLSERVER\MSSQL\DATA','Path for CBRRStaging data file'),
                ('CBRRStagingLogfilePath',NULL,NULL,'O:\MSSQL15.MSSQLSERVER\MSSQL\DATA','Path for CBRRStaging log file'),
                ('AzureChannelBCPOutFolderName',NULL,NULL,'H:\BCPChannelout\','Path in the where BCP channel files are copied to before moving to azure'),
                ('AzureInventoryBCPOutFolderName',NULL,NULL,'H:\BCPInventoryout\','Path in the where BCP inventory files are copied to before moving to azure'),
                ('AzureDestinationChannelBlobPath',NULL,NULL,NULL,'Blob path where channel bcp files are copied to'),
                ('AzureDestinationChannelBlobPathKey',NULL,NULL,NULL,'Access key for storage account where channel bcp files are copied to'),
                ('AzureDestinationInventoryBlobPath',NULL,NULL,NULL,'Blob path where inventory bcp files are copied to'),
                ('AzureDestinationInventoryBlobPathKey',NULL,NULL,NULL,'Access key for storage account where inventory bcp files are copied to'),
                ('AzureDestinationBlobChannelTriggerFilePath',NULL,NULL,NULL,'Blob path where trigger file for channel spark job is copied to'),
                ('AzureDestinationBlobInventoryTriggerFilePath',NULL,NULL,NULL,'Blob path where trigger file for inventory spark job is copied to'),
                ('MOATriggerDateBudget','2021-06-30 19:16:33.973',NULL,NULL,'Data used by MSSalesOnAzure for handshake'),
                ('MOATriggerDateForecast','2021-05-10 13:06:11.573',NULL,NULL,'Data used by MSSalesOnAzure for handshake'),
                ('MOATriggerDateDomains','2021-07-03 16:47:51.013',NULL,NULL,'Data used by MSSalesOnAzure for handshake'),
                ('PushDataToOnPremMiddleTier',NULL,1,NULL,'Flag to determine if data has to be pushed to OnPremMiddleTier'),
                ('MaxFiscalMonthID',NULL,852,NULL,'Max Future fiscal month to process'),
                ('SkipDeleteFactorySupervisorJob',NULL,0,NULL,'Delete FactorySupervisor jobs looking at Factory table: 0 - not to delete the jobs, 1 - delete the jobs'),
                ('xpcmdshellFeatureFlag',NULL,1,NULL,'xp_cmdShell Feature Flag - 1 - Use Proxy Login - 0 - Use SysAdmin'),
                ('MRRRedoStartFMID',NULL,380,NULL,'Start FiscalMonthID for MRR Redo Process'),
                ('MRRRedoEndFMID',NULL,382,NULL,'End FiscalMonthID for MRR Redo Process'),
                ('MRRRedoFutureMode',NULL,1,NULL,'Run the MRR Redo for future months'),
                ('HPreFacCycleFlag',NULL,NULL,'Special','h_PreFac processing cycle, is updated as part of h_Prefac job run'),
                ('EAABRToCBRRAuditThreshold',NULL,0,NULL,'Threshold to let the audit pass for revenue amount variance in EA ABR enrollments')
                ) AS vtable ([ParamName],[ParamDate],[ParamNumber],[ParamChar],[ParamDescription])
            ) AS SOURCE
            ON (TARGET.ParamName = SOURCE.ParamName)
            WHEN NOT MATCHED BY TARGET THEN
                INSERT ([ParamName],[ParamDate],[ParamNumber],[ParamChar],[ParamDescription]) 
                VALUES (SOURCE.ParamName,SOURCE.ParamDate,SOURCE.ParamNumber,SOURCE.ParamChar,SOURCE.ParamDescription)
            WHEN MATCHED THEN UPDATE SET
                TARGET.ParamChar = SOURCE.ParamChar,
                TARGET.ParamNumber = SOURCE.ParamNumber,
                TARGET.ParamDate = SOURCE.ParamDate,
                TARGET.ParamDescription = SOURCE.ParamDescription;

            PRINT N'done with merge in Management Parameters'
            
            ---Operations Management--

            MERGE Operations..Parameters AS TARGET
            USING (
            SELECT * FROM (VALUES
            ('ApplicationName',NULL,NULL,'MS-Sales 3.0'),
            ('AuditSQLAgentLogData','2019-01-24 05:22:00.927',15,'Date and Num used to see if mail has been sent'),
            ('AuditSQLAgentLogData2','2017-08-15 14:16:15.110',15,'Date and Num used to see if mail has been sent used on retry'),
            ('Backup','2000-12-01 19:08:41.910',1,'mssql\bak'),
            ('BackupConcurrency','2006-03-27 05:12:01.570',2,'How many DBCC or backup jobs can be run at once'),
            ('BackupLocation','2006-03-27 05:12:01.570',0,'H:\MSSQL\BAK'),
            ('BackupPanSales',NULL,2,NULL),
            ('BlockCont_Blk_Threshold','2004-06-24 05:56:44.380',1,'How many need to Continuously block'),
            ('BlockingMailData','2021-07-05 01:35:46.300',15,'Date and Num used to see if mail has been sent'),
            ('BlockingMailData_test','2018-06-28 03:15:21.197',15,'Date and Num used to see if mail has been sent'),
            ('BlockMaxThreshold','2004-06-24 05:57:20.270',20,'Reporting blocked over threshold'),
            ('BlockTime_Threshold_min','2004-06-24 05:56:41.117',60,'Continuously blocking time in minutes'),
            ('CheckServerFunction',NULL,NULL,'Yes'),
            ('ClusterApplicationName',NULL,NULL,'MSSalesEVA'),
            ('ClusterLogServer',NULL,NULL,'OKANOGAN'),
            ('ClusterManagerCountThreshold','2000-11-21 18:28:35.707',3,NULL),
            ('ClusterManagerWaitPeriod','2000-11-21 18:28:35.707',NULL,'1:00:00'),
            ('DBSpaceMailData','2014-01-24 04:33:25.570',NULL,'Date value to check when the mail was sent last.'),
            ('DRFlag',NULL,0,'0: DR is inactive. 1: DR is active'),
            ('ErrorLogThresholdSizeMB','2004-03-23 00:20:06.573',80,'Used by the sproc RecycleLog'),
            ('FactoryServer',NULL,NULL, @FactoryServer),
            ('FailPath',NULL,0,'H:\SQLJOB\LOG\FAIL'),
            ('FileServer','2021-05-05 12:34:00.960',NULL,@FileServer),
            ('FinishPath',NULL,0,'H:\SQLJOB\LOG\DONE'),
            ('LogIndexesUsed','2007-05-25 03:59:12.550',0,'Operations'),
            ('LogServer','2013-10-26 17:10:00.000',NULL,@LogServer),
            ('LogSpaceMailData','2015-12-24 05:10:08.227',NULL,'Date value to check when the mail was sent last.'),
            ('LRQ_MailAlias','2004-08-16 02:39:54.533',0,''),
            ('LSreset_pansales','2017-03-22 16:55:17.273',0,'0 is DIff and 1 is FULL'),
            ('MailAlias',NULL,NULL,'fe-core-tooling@microsoft.com'),
            ('MailFrom','2005-07-04 02:18:19.583',0,'MSSIT'),
            ('MsBatchCmdLineTool','2014-12-29 05:33:41.720',0,'\\msbsql05\msb_a_tools\ntbc'),
            ('NotificationMailAlias',NULL,NULL,'MSSA01'),
            ('NotificationServer',NULL,NULL,'WASHOUGAL'),
            ('NotifyExecutablePath',NULL,NULL,'H:\SSITMAIL\CDO\'),
            ('NotifyExecutableSource',NULL,NULL,'\\CEDAR\SSITMAIL\CDO\'),
            ('NotifyProfile',NULL,NULL,'MSSIT'),
            ('PageAlias',NULL,NULL,'BIFINA01@microsoft.com'),
            ('PagerSystem',NULL,NULL,' '),
            ('PrimaryMTServer','2013-10-26 17:10:00.000',NULL,@PrimaryMTServer),
            ('ProdTFactoryNode1','2016-04-07 14:20:28.960',0,@FactoryServer),
            ('ProdTFactoryNode2','2016-04-07 14:20:28.960',0,@FactoryServer),
            ('ProdWHServer','2016-04-07 14:20:28.960',0,@WHServer),
            ('SecondaryMTServer','2013-10-26 17:10:00.000',NULL,@PrimaryMTServer),
            ('ServerFunctionCS',NULL,NULL,'ClusterServer'),
            ('SMTPServer',NULL,0,'SMTPHOST.redmond.corp.microsoft.com'),
            ('SQLJOB_BINPath',NULL,NULL,'H:\SQLJOB\BIN'),
            ('SQLJOB_CMDPath',NULL,NULL,'H:\SQLJOB\CMD'),
            ('SQLJOB_DataPath',NULL,NULL,'H:\SQLJOB\DAT'),
            ('SQLJOB_LogPath',NULL,NULL,'H:\SQLJOB\LOG'),
            ('SQLJOB_MiscPath',NULL,NULL,'H:\SQLJOB\MISC'),
            ('SQLJOB_Path',NULL,NULL,'H:\SQLJOB\'),
            ('SQLJOB_SQLPath',NULL,NULL,'H:\SQLJOB\SQL'),
            ('u_mthend','2021-07-02 05:15:28.417',0,'Flag for the batch job u_mthend to run or not.'),
            ('UATFactoryNode1',NULL,0,@FactoryNode1),
            ('UATFactoryNode2',NULL,0,@FactoryNode2),
            ('UATWHServer',NULL,0,@WHServer),
            ('UseZSwitchInRoboCopy',NULL,0,'Set to 0 if /Z should not be used in RoboCopy. 1 would run RoboCopy with /Z switch.'),
            ('wwtest','2003-10-30 10:58:50.250',0,'y')
            ) AS vtable ([ParamName],[ParamDate],[ParamNumber],[ParamChar])
            ) AS SOURCE
            ON (TARGET.ParamName = SOURCE.ParamName)
            WHEN NOT MATCHED BY TARGET THEN
                INSERT ([ParamName],[ParamDate],[ParamNumber],[ParamChar]) 
                VALUES (SOURCE.ParamName,SOURCE.ParamDate,SOURCE.ParamNumber,SOURCE.ParamChar)
            WHEN MATCHED THEN UPDATE SET
                TARGET.ParamChar = SOURCE.ParamChar,
                TARGET.ParamNumber = SOURCE.ParamNumber,
                TARGET.ParamDate = SOURCE.ParamDate;
            
            PRINT N'done with merge in Operations Parameters'
            END

        END

"@

    Invoke-Sqlcmd -ServerInstance $SqlInstanceName -Query $script
}

function Main{
    try {

        $vmName = $env:ComputerName
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Updating WH params for VM :  $vmName"

		if ((Get-Service -Name 'ClusSvc' -ErrorAction SilentlyContinue)) {
            $ActiveNode = (Get-ClusterGroup | Where-Object { $_.Name -like "*SQL*" }).OwnerNode
			Write-Verbose "Active node name is $($ActiveNode)" -verbose
			$vmName = $env:ComputerName

            # For s2d cluster
			if ($Activenode -eq $vmName) {
                Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Updating WH params credential : $vmName"
                $SqlInstanceName = Get-SQLInstance
                UpdateParameters $baseName $ThreeLetterEnv $ThreeLetterClusterSuffix $SqlInstanceName
            }
        }
        else {

            $vmName = $env:ComputerName
            Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Updating WH params credential : $vmName"
            UpdateParameters $baseName $ThreeLetterEnv $ThreeLetterClusterSuffix $SqlInstanceName
        }
    }
    catch
    {
        Write-Verbose "Error updating WH params " -Verbose
        Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message " Error updating  WH params "
		Write-Verbose $_ -Verbose
		throw
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Main
}