<#
.SYNOPSIS
    This will execute a PowerShells Locally.
.DESCRIPTION
    The Following will happen.
    1. It will download a Powershell Stored in an Azure Storage Account Blob locally to the VM
    2. It will execute a given PowerShell File with its parameters given as powerShellCommands Parameter
    3. PowerShellCommands parameters format needs to be like this PowerShellFileName1;ItsSwitches,PowerShellFileName2;ItsSwitches i.e 'RestoreDataBases.ps1;-backupsPath "H:\Backups\"*RestoreDataBases1.ps1;-backupsPath "H:\Backups\"'
    4. Each PowerShell Command needs to be separated with a *
    4. The Local Directory where the Files will be downloaded to
    5. storageAccountUri it takes the URI of the store Account where the Files are initially stored. i.e https://mssalesarmtemplates.blob.core.windows.net/armtemplates/Scripts/ it is case sensitive
    6. sastoken a temporary read sas token to the storage account
.OUTPUTS
    None.
#>
param (
    $serviceAccount,
    $serviceAccountPassword,
    $resourcesPath = "C:\AzureArmTemplates\",
    $powerShellCommands ='RestoreDataBases.ps1;-backupsPath H:\Backups\ -dbGroupList Shards,Budget,Domains,MSSales,Forecast',
    $storageAccountUri ="https://mssalesarmtemplates.blob.core.windows.net/armtemplates/Scripts/",
    $sastoken
)

function Set-Credential {
    param (
    $ServiceAccount,
    $ServiceAccountPassword
    )

    $securePassword = ConvertTo-SecureString $serviceAccountPassword -AsPlainText -Force

    return [System.Management.Automation.PSCredential ]$credential = New-Object System.Management.Automation.PSCredential ($ServiceAccount, $securePassword)  
}

function Set-NTFSPermissions {
    param (
        $path,
        $serviceAccount
    )

    Add-NTFSAccess -Path $path -Account "CREATOR OWNER" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    Add-NTFSAccess -Path $path -Account "BUILTIN\Users" -AccessRights "ReadAndExecute" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    Add-NTFSAccess -Path $path -Account "NT AUTHORITY\SYSTEM" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    Add-NTFSAccess -Path $path -Account "BUILTIN\Administrators" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow

    if(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances | Select-Object -ExpandProperty InstalledInstances | Where-Object { $_ -eq 'MSSQLSERVER' }){
        
        Add-NTFSAccess -Path $path -Account "NT SERVICE\MSSQLSERVER" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
        Add-NTFSAccess -Path $path -Account "NT SERVICE\SQLSERVERAGENT" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    }

    if($serviceAccount){

        Add-NTFSAccess -Path $path -Account $serviceAccount -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    }
}

function Set-LocalDirectory{
    param (
        $resourcesPath
    )

    if (-Not (Test-Path $resourcesPath)) {

        New-Item -Path $resourcesPath -ItemType directory
    }
    Set-NTFSPermissions -path $resourcesPath -serviceAccount $serviceAccount
}

function Get-Work{
    param (
       $commands
    )

    $workDictionary = @{ }
    $workList = $commands.split('*')

    foreach ($pair in $workList) {

        $key, $value = $pair.Split(';')
        $workDictionary[$key] = $value
    }

    return $workDictionary
}

function Get-PowerShellFiles{
    param (
       $powerShellCommands,
       $resourcesPath,
       $storageAccountUri,
       $sastoken
    )
  
    $powerShellFileNames = Get-Work -commands $powerShellCommands
    
    $WebClient = New-Object System.Net.WebClient

    foreach ($fileName in $powerShellFileNames.GetEnumerator()){

        $file =$resourcesPath + $fileName.key
     
        if (Test-Path $file ) {

            Remove-Item -Path $file -Recurse       

        }
 
        $WebClient.DownloadFile($storageAccountUri + $fileName.key + $sastoken, $resourcesPath + $fileName.key)

    }
}

function ExecutePSWithCredentials{
    param (
       $powerShellCommands,
       $resourcesPath,
       $serviceAccount,
       $serviceAccountPassword
    )

    $powerShellFileNames = Get-Work -commands $powerShellCommands
    $credential = Set-Credential -ServiceAccount $serviceAccount -ServiceAccountPassword $serviceAccountPassword

    foreach ($fileName in $powerShellFileNames.GetEnumerator()){
        $parameters =$fileName.value
        if($parameters){
            $parameters = $parameters.replace("""","'")
        }
        $command =$resourcesPath + $fileName.key + " " + $parameters

        function ExecutePowerShellFile($command){
            
            powershell $command

        }

        Invoke-Command -ComputerName localhost -ScriptBlock ${function:ExecutePowerShellFile} -ArgumentList $command -Credential $credential     

    }
}

function ExecutePS{
    param (
       $powerShellCommands,
       $resourcesPath
    )

    $powerShellFileNames = Get-Work -commands $powerShellCommands

    foreach ($fileName in $powerShellFileNames.GetEnumerator()){
        $parameters =$fileName.value
        if($parameters){
            $parameters = $parameters.replace("""","'")
        }
        $command =$resourcesPath + $fileName.key + " " + $parameters

        function ExecutePowerShellFile($command){

            powershell $command

        }

        Invoke-Command -ComputerName localhost -ScriptBlock ${function:ExecutePowerShellFile} -ArgumentList $command    

    }
}

function Main{
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "First Entry Commands $powerShellCommands"
    Set-LocalDirectory -resourcesPath $resourcesPath
    Get-PowerShellFiles -powerShellCommands $powerShellCommands -resourcesPath $resourcesPath -storageAccountUri $storageAccountUri -sastoken $sastoken

    if ($serviceAccount){

        ExecutePSWithCredentials -powerShellCommands $powerShellCommands -resourcesPath $resourcesPath -serviceAccount $serviceAccount -serviceAccountPassword $serviceAccountPassword

    }

    if (-Not($serviceAccount)){

        ExecutePS -powerShellCommands $powerShellCommands -resourcesPath $resourcesPath

    }
}

Main
