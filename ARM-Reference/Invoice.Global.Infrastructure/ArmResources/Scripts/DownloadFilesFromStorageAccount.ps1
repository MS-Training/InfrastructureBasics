<#
.SYNOPSIS
    It will download a File Stored in an Azure Storage Account Blob locally to the VM and it is compressed it will explode the file
.DESCRIPTION
    The Following will happen.
    1. It will download a File Stored in an Azure Storage Account Blob locally to the VM
    2. The Local Directory where the Files will be copied to
    3. storageAccountUri it takes the URI of the store Account where the Files are initially stored. i.e https://mssalesarmtemplates.blob.core.windows.net/armtemplates/Scripts/ it is case sensitive
    4. sastoken a temporary read sas token to the storage account
.OUTPUTS
    None.
#>
param (
    $fileNameList = "FSAModules.zip",
    $destinationPath = "C:\AzureArmTemplates\",
    $storageAccountUri = "https://mssalesarmtemplates.blob.core.windows.net/armtemplates/Scripts/",
    $sastoken
)

function Set-NTFSPermissions {
    param (
        $path
    )

    Add-NTFSAccess -Path $path -Account "CREATOR OWNER" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    Add-NTFSAccess -Path $path -Account "BUILTIN\Users" -AccessRights "ReadAndExecute" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    Add-NTFSAccess -Path $path -Account "NT AUTHORITY\SYSTEM" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    Add-NTFSAccess -Path $path -Account "BUILTIN\Administrators" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow

    if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances | Select-Object -ExpandProperty InstalledInstances | Where-Object { $_ -eq 'MSSQLSERVER' }) {
        
        Add-NTFSAccess -Path $path -Account "NT SERVICE\MSSQLSERVER" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
        Add-NTFSAccess -Path $path -Account "NT SERVICE\SQLSERVERAGENT" -AccessRights "FullControl" -InheritanceFlags ContainerInherit, ObjectInherit -PropagationFlags None -AccessType Allow
    }
}

function Set-LocalDirectory {
    param (
        $downloadPath
    )

    if (-Not (Test-Path $downloadPath)) {

        New-Item -Path $downloadPath -ItemType directory
    }
    Set-NTFSPermissions -path $downloadPath
}

function CopyModulesToDestination {
    param (
        $modulesPath,
        $destinationPath
    )

    $modulesList = Get-ChildItem $modulesPath

    foreach ($module in $modulesList) {

        $moduleDestination = $destinationPath + $module.BaseName

        if (-Not (Test-Path $moduleDestination)) {

            New-Item -Path $moduleDestination -ItemType directory
        }

        Copy-Item -Path $module.FullName -Destination $moduleDestination -Force

    }
    
}

function Get-FilesFromStorageAccount {
    param (
        $destinationPath,
        $storageAccountUri,
        $sastoken
    )

    $downloadPath = "C:\AzureArmTemplates\"   
    $WebClient = New-Object System.Net.WebClient
    $fileNameList = $fileNameList.split(',')

    foreach ($fileName in $fileNameList) {

        $file = $downloadPath + $fileName
     
        if (Test-Path $file ) {

            Remove-Item -Path $file -Recurse       

        }
 
        $WebClient.DownloadFile($storageAccountUri + $fileName + $sastoken, $downloadPath + $fileName)

        if ((Get-Item -Path $file).Extension -eq ".zip") {

            $unzipDestination = $downloadPath + (Get-Item -Path $file).BaseName
            if ((Get-Item -Path $file).BaseName -match "Modules") {

                Expand-Archive -Path $file -DestinationPath $unzipDestination -Force
                CopyModulesToDestination -modulesPath $unzipDestination -destinationPath $destinationPath

            }
            else {

                Expand-Archive -Path $file -DestinationPath $destinationPath -Force

            }
        }
        else {
            if ($downloadPath -ne $destinationPath) {

                Copy-Item -Path $file -Destination $destinationPath
            }
        }
    }
}

function Main {

    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Starting to Download Files from Storage Account"
    $downloadPath = "C:\AzureArmTemplates\"
    Set-LocalDirectory -downloadPath $downloadPath
    Get-FilesFromStorageAccount -destinationPath $destinationPath -storageAccountUri $storageAccountUri -sastoken $sastoken
}
Main
