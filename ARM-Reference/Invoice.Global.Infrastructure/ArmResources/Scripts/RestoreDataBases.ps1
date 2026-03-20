<#
.SYNOPSIS
    This script will trigger the restore of database backups that are stored in a given directory.
.DESCRIPTION

.OUTPUTS
    None.
#>

param(
    $backupsPath,
    $dbGroupList
)

[System.Collections.ArrayList]$backUps = @()

function Get-RestoreDirectories{
    param(
        [string] $backupsPath
    )

    #Get the list of Directories where Backups are stored

    return (Get-ChildItem -Path $backupsPath).BaseName
}

function Set-BackupDetails {
    param(        
        [string] $dbName,
        [string] $backUpFilePath,
        [string] $backUpFileBaseName,
        [int] $backUpFileCount
    )

    $dbBackup = New-Object PSObject
    $dbBackup | Add-Member -MemberType NoteProperty -Name dbName -Value $dbName
    $dbBackup | Add-Member -MemberType NoteProperty -Name backUpPath -Value $backUpFilePath
    $dbBackup | Add-Member -MemberType NoteProperty -Name backUpFileBaseName -Value $backUpFileBaseName
    $dbBackup | Add-Member -MemberType NoteProperty -Name backUpFileCount -Value $backUpFileCount

    return $dbBackup
}

function Get-BackupPath {
    param(
        [string] $backUpsPath,
        [string] $directoryName
    )

    return $backUpsPath + $directoryName
}

workflow RestoreDataBases{
    param(
        $backups
    )

    foreach -parallel -throttlelimit 20 ($backup in $backups) {

        InlineScript{

            for( $i=0; $i -lt $using:backup.backUpFileCount; $i++){
            
                $fileNumber =$i+1
                $qstring = $qstring + "DISK = N'" + $using:backup.backUpPath + '\'+ $using:backup.backUpFileBaseName +$fileNumber + ".BAK'"

                if ($i -lt $using:backup.backUpFileCount-1){
                    $qstring =$qstring + ","
                }
            }

            $dbname =$using:backup.dbName
            if($dbname -match "MSSALES0")
            {
            $standByFolder=$using:backup.backUpPath + "StandBy"
            $q = "RESTORE DATABASE [$dbname] FROM  $qstring WITH REPLACE" + ", STANDBY = N'$standByFolder\" + $dbname +"-RollbackUndo.BAK'"
            }
            else{
            $q = "RESTORE DATABASE [$dbname] FROM  $qstring WITH REPLACE"
            }
            Write-Verbose $q -Verbose
            Invoke-Sqlcmd -Database master -Query $q -QueryTimeout 10000

            if ($dbname.ToUpper() -eq "MSSALES"){
            Invoke-Sqlcmd -Database master -Query "ALTER DATABASE [MSSales] SET  READ_ONLY WITH NO_WAIT" -QueryTimeout 10000
            }
        }    
    }
}

function Main {
    param(
        $backupsPath,
        $dbGroupList
    )

    #Gets List Of DBs
    $dbGroupList = $dbGroupList.split(',')
    #Gets List Of DBs that have snapshots to later drop the snapshot and restore the db
    $dbSnapshotList = Invoke-Sqlcmd -Database master -Query "select name from sys.databases where source_database_id is not null" -QueryTimeout 10000

    foreach ($dbGroup in $dbGroupList){

        ###Restore SHARDS all the MSSales Dbs (Does not include the MSSales Db)
        if($dbGroup.toUpper() -eq "SHARDS"){
            
            $standByFolder = $backupsPath + "StandBy"
            if (-Not (Test-Path $standByFolder)) {
                New-Item -Path $standByFolder -ItemType directory
            }
            $shardFiles=Get-ChildItem -Path $backUpsPath | Where-Object {$_.Name -match "FULL"} | Where-Object {$_.Extension -match "BAK"} | Where-Object {$_.BaseName.ToUpper() -match "MSSALES"}
            $dbNames = $shardFiles.BaseName 
            $dbNames = ($dbNames.split('-') | Where-Object {$_ -match "FULL"} | select -Unique)
            $dbNames = $dbNames.replace('Full','')

             foreach($dbName in $dbNames){

                $fileList = Get-ChildItem -Path $backUpsPath | Where-Object {$_.Name -match "FULL"} | Where-Object {$_.Extension -match "BAK"} | Where-Object {$_.BaseName -match "$dbName"}

                $backUpFileBaseName = $fileList.BaseName
                $backUpFileBaseName = ($backUpFileBaseName.split('-') | Where-Object {$_ -match $dbName} | select -Unique)
                $backUpFileBaseName = "$backUpFileBaseName-"
                $backUpFileCount = $fileList | Measure-Object

                $backupDetail = Set-BackupDetails -backUpFilePath $backUpsPath -dbName $dbName -backUpFileBaseName $backUpFileBaseName -backUpFileCount $backUpFileCount.count

                if($backupDetail){

                    $backUps.Add($backupDetail)

                }
             }
        }

        ###Restore MSSales Database
        elseif($dbGroup.toUpper() -eq "MSSALES"){

             $msSalesFiles=Get-ChildItem -Path $backUpsPath | Where-Object {$_.Name.toUpper() -notmatch "FULL"} | Where-Object {$_.Extension -match "BAK"} | Where-Object {$_.BaseName.toUpper() -match "MSSALES"}
             $msSalesFilesCount = $msSalesFiles | Measure-Object

             $backupDetail = Set-BackupDetails -backUpFilePath $backUpsPath -dbName "MSSales" -backUpFileBaseName "MSSales" -backUpFileCount $msSalesFilesCount.count

            if($backupDetail){

                $backUps.Add($backupDetail)

            }

        }

        ##Restores any other backups files that are stored in the same directory
        else{

             $dbBackupFiles=Get-ChildItem -Path $backUpsPath | Where-Object {$_.Name.ToUpper() -match "FULL"} | Where-Object {$_.Extension -match "BAK"} | Where-Object {$_.BaseName.toUpper() -notmatch "MSSALES"} | Where-Object {$_.BaseName.toUpper() -match $dbGroup.toUpper()}
             $dbNames = $dbBackupFiles.BaseName
             $dbNames = ($dbNames.split('-') | Where-Object {$_ -match "FULL"} | select -Unique)
             $dbNames = $dbNames.replace('Full','')

             foreach($dbName in $dbNames){

                foreach ($dbSnapshot in $dbSnapshotList){

                    $dbSnapshot = $dbSnapshot.name

                    if($dbName -match $dbSnapshot){

                        Invoke-Sqlcmd -Database master -Query "drop database $dbSnapshot" -QueryTimeout 10000
                        
                    }
                }    
                
                $fileList = Get-ChildItem -Path $backUpsPath | Where-Object {$_.Name -match "FULL"} | Where-Object {$_.Extension -match "BAK"} | Where-Object {$_.BaseName -match "$dbName"}

                $backUpFileBaseName = $fileList.BaseName
                $backUpFileBaseName = ($backUpFileBaseName.split('-') | Where-Object {$_ -match $dbName} | select -Unique)
                $backUpFileBaseName = "$backUpFileBaseName-"
                $backUpFileCount = $fileList | Measure-Object

                $backupDetail = Set-BackupDetails -backUpFilePath $backUpsPath -dbName $dbName -backUpFileBaseName $backUpFileBaseName -backUpFileCount $backUpFileCount.count

                if($backupDetail){

                    $backUps.Add($backupDetail)

                }
             }
        }
    }
    $dbListDetails = ConvertTo-Json $backUps
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "DataBase Details: $dbListDetails"
    RestoreDataBases -backups $backUps
}

Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "backupsPath : $backupsPath"
Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "dbGroupList : $dbGroupList"
Main -backupsPath $backupsPath -dbGroupList $dbGroupList