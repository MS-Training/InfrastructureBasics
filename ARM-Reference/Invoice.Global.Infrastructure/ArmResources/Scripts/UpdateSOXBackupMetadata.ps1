<#
.SYNOPSIS
    Updates SOXBackupMetadata table with new storage account URL
.DESCRIPTION
    Updates SOXBackupMetadata table with new storage account URL
.PARAMETER ServicePrincipalPassword
    The service principal's password to log in to azure.
.PARAMETER ConfigFilePath
    The path to the config file.
.PARAMETER Env
    Environment being deployed by ADO BCDR Release
.PARAMETER Recover
    During a BCDR Test, the values updated will need to be reverted, Recover=True will return to the original values.
.PARAMETER IsTest
    Test flag
#>
param (        
    [SecureString] $ServicePrincipalPassword,
    [String] $ConfigFilePath, 
    [String] $Env,
    [bool] $Recover =  $false, 
    [bool] $IsTest = $false
)
$ErrorActionPreference = "Stop"

<#
.SYNOPSIS
    Executes update query on database
.DESCRIPTION
    Executes update query on database
.PARAMETER DBServer
    Server name to execute command on
.PARAMETER DBName
    Database name to update   
.PARAMETER ExistingStorageAccountName
    Old Storage account name to replace
.PARAMETER NewStorageAccountName
    New (BCDR Region) Storage account name to use
.OUTPUTS
    None
#>
function updateSOXBackupStorageAccountURL{  
    param(
        [string] $DBServer,
        [String] $DBName,
        [string] $ExistingStorageAccountName,
        [string] $NewStorageAccountName,
        [bool] $IsTest = $false 
    )

    Write-Verbose "Updating SOXBackup Table BACKUP URL Column..." -Verbose
        
    $query =
        "Update [dbo].[SOXBackupMetadata]
            SET [BackupToURL] = REPLACE([BackupToURL], $ExistingStorageAccountName, $NewStorageAccountName)
        WHERE
            [BackupToURL] like '%$ExistingStorageAccountName%'
        "

    if (!test){
        Write-Verbose -Verbose "Server: $DBServer, Table: $DBName, Query: $query"
    }
    else {
        Invoke-SqlCmdWithRetries -ServerInstance $DBServer -Database $DBName -Query $query
    }

    Write-Verbose "SOX Metadata Table updated.." -Verbose
}

<#
.SYNOPSIS
    Main is used as the entry point in the script and will run all functions
.DESCRIPTION
    Main is used as the entry point in the script and will run all functions
.OUTPUTS
    None
#>
function main {
    param(
        [bool] $IsTest = $false 
    )
    try{
        Import-Module "ConfigManagement.psm1" -Force 

        Write-Verbose "Loading config and sql credentials..." -Verbose        
        $config = LoadConfig $ConfigFilePath

        # Login to Azure, use the override subscription because this ADO task runs before the substitution task.       
        LogIntoAzure -ServicePrincipalName $config.Environment.Parameters.servicePrincipalName `
            -ServicePrincipalPassword $ServicePrincipalPassword `
            -Tenant $config.Environment.Parameters.tenantId `
            -SubscriptionId $config.BCDR.Overrides.Environment.Parameters.subscriptionId | Out-Null  

        if ($Recover) {
            $existingAccount = $config.BCDR.Overrides.Environment.Parameters.SOXBackupStorageAccountName
            $newAccount = $config.Environment.Parameters.SOXBackupStorageAccountName
        }
        else {
            $existingAccount = $config.Environment.Parameters.SOXBackupStorageAccountName
            $newAccount = $config.BCDR.Overrides.Environment.Parameters.SOXBackupStorageAccountName
        }

        Write-Verbose "Perform BackupURL Update." -Verbose                
        # Must replace the env values below as this ADO task is run before the replacement task.
        updateSOXBackupStorageAccountURL -DBServer $config.Environment.Parameters.orchestrationServerName `
            -DBName $config.Environment.Parameters.orchestrationDatabaseName `
            -OldStorageAccountName $existingAccount.Replace("[Env]", $Env) `
            -NewStorageAccountName $newAccount.Replace("[Env]", $Env)
            -IsTest $IsTest

    }
    catch  {                
        Write-Verbose "UpdateSOXBackupMetadata: Failed to update SOX BackupURL." -Verbose
        Write-Verbose $_ -Verbose
        Write-Verbose "Stacktrace: $($PSItem.ScriptStackTrace)" -Verbose
        throw 
    }
    
}

if ($IsTest -eq $false) {
    main $IsTest
}
    
