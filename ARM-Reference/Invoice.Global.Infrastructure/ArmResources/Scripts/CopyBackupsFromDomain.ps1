<#
This script will be copying Budget,forecast and Domains Backups from
Domain server to target server.
All Backups needs to be in [DB][digit].bkp format
for example Budget1.bkp,Budget2.bkp
#>
param(
    [String]$serviceAccountName,
    [String]$serviceAccountPassword,
    [String]$source,
    [String]$destination = "E:\Backups\",
    [String]$sourceDirectories =  'Budget_Backup,Domains_Backup,Forecast_Backup',
    [String]$mtCluster = 'MSSMSRMT',
    [String]$env,
    [String]$mtServerName
)

<#getMTNode will return MT Cluster head node which is required to make remoate connection to MT Cluster#>
function getMTNode{
   param (
       $mtServerName,
       [System.Management.Automation.PSCredential] $cred1
   )
   $remotesession = New-PSSession -ComputerName $mtServerName -Credential $cred1
   return Invoke-Command -ScriptBlock{
       (Get-ClusterGroup | Where-Object {$_.name -Match 'SQL'}).OwnerNode.Name
   } -Session $remotesession

}

<#getActiveDBList will return Active Budget,Forecast and Domain DB name#>
function getActiveDBList{ 
   param (
       $MTHeadNode,
       [System.Management.Automation.PSCredential] $cred1,
       $mtserverInstance
   )  
   $remotesession =New-PSSession -ComputerName $MTHeadNode -Credential $cred1
   Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Connecting to MT Server $mtserverInstance"
   return Invoke-Command -ScriptBlock{
       $q = "SELECT ParamChar from msrmetadata.dbo.Parameters (nolock) where paramname in ('CurrentBudgetDatabase' , 'CurrentDomainsDatabase' , 'CurrentForecastDatabase')"
       Invoke-Sqlcmd -ServerInstance $Using:mtserverInstance -Query $q -QueryTimeout 300 | select-object -expand ParamChar
   } -Session $remotesession
}

<#validateBackupFile will validate backup file name#>
function validateBackupFile{
   param(
   $fileName,
   $dbName)

   $validBkpRegx = '^'+$dbname+'\d'+'$'

   return $fileName -match $validBkpRegx
}

try {

   $secureString = ConvertTo-SecureString $serviceAccountPassword -AsPlainText -Force
   [System.Management.Automation.PSCredential]$cred1 = New-Object System.Management.Automation.PSCredential ($serviceAccountName, $secureString)

   $dbDirectoryList = $sourceDirectories.Split(',')

     $MTHeadNode = getMTNode $mtServerName $cred1

     $mtserverInstance = $mtCluster+$env

     $activeDBList = getActiveDBList $MTHeadNode $cred1 $mtserverInstance

       $activeDBList 

   foreach($dbDirectory in $dbDirectoryList){

       $sourceDirectory = $source+$dbDirectory
       Write-Verbose "Starting to Copy All Data from $sourceDirectory to $destination" -Verbose
       Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Starting to Copy All Data from $source to $destination"

       if(-not (Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'N:'")) {
           Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date)Mapping N: drive to $sourceDirectory."
           New-PSDrive -Name N -PSProvider FileSystem -Root $sourceDirectory -Credential $cred1
       }

       #Make sure the drive mapping suceeded.
       if (-not (Test-Path N:\ )) {
           Write-Verbose "Share not available." -Verbose  
           Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Share not available."
       throw
       }

       Get-PSDrive -Name N -PSProvider Filesystem | Select -first 1 | %{$sourceDirectory = $_.Root + $_.CurrentLocation} -InformationAction Ignore
       Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Connecting to MT Server to get Active Db Name"


       if($activeDBList.Length -eq 0){
           Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -message "Active DB list is empty.Either job is not able to conect to MT server or the returned result is not correct : $mtserverInstance"
            if((Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'N:'")) {
                Write-Verbose "Removing Mapped drive: N." -Verbose
                   Remove-PSDrive -Name N
              }
           
           throw "Active DB list is empty.Either job is not able to conect to MT server or the returned result is not correct"
       }

       Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Active DB list : $activeDBList"

       $backupFiles = Get-ChildItem -recurse ('N:') -File

       #Below loop will rename all file as active db and copy to target directory
       foreach($file in $backupFiles){
           $fileName = [System.IO.Path]::GetFileNameWithoutExtension($file)
           $dbName = $dbDirectory.split('_')[0]

           $isValidFile = validateBackupFile $fileName $dbName

           Write-Verbose "File validation $fileName ,dbname - $dbName : $isValidFile" -Verbose

           #If Backup file do not follow DB-[1,2].bkp convention then do not copy
           if(-not $isValidFile){
                Write-Verbose "Invalid file found $fileName.Skipping copy" -Verbose
                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Invalid file found $fileName.Skipping copy"
               continue;
           }

           #if its valid backup then rename and copy
           $dbRegex = $dbName+"*"
           $fileNumber = $fileName.Substring($fileName.Length-1)  
           $activeDB =   $activeDBList | Where-Object {$_ -like $dbRegex}
           $newName = $activeDB+'Full-'+$fileNumber+'.bak'  
           $fullSourcePath = 'N:\'+$file

           $fullTargetPath = $destination+'\'+$newName
           Write-Verbose "Copying $fileName to $fullTargetPath" -Verbose
           Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Copying $fullTargetPath"
           Copy-Item $fullSourcePath -Destination $fullTargetPath

           Write-Verbose "Completed copying $fullTargetPath" -Verbose
           Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Completed copying $fullTargetPath"
       }
       Write-Verbose "Mapping N: drive to $sourceDirectory." -Verbose
       Write-Verbose "Removing mapped drive: N:" -Verbose
       Remove-PSDrive -Name N
   
   }
 
   Write-Verbose "Completed copying data" -Verbose
   Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Completed copying data"
   }
catch {
   $message = "Copy from Domain server to $destination failed."
   Write-Host -ForegroundColor Red -BackgroundColor Black $message
   Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message $message

   if((Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'N:'")) {
       Write-Verbose "Removing Mapped drive: N." -Verbose
       Remove-PSDrive -Name N
   }

   throw $_
} 