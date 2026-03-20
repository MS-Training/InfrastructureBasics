<# This script will copy files from source to remote servers share in same directory as file
#>
param(
    [String]$serviceAccountName,
    [String]$serviceAccountPassword,
    [String]$source,
    [String]$destinationServers,
    [String]$moduleDirectory = "modules"
    )

try {

    Write-Verbose "Passed destination servers : $destinationServers" -Verbose    
    $destinationList = $destinationServers.split(',')

    $secureString = ConvertTo-SecureString $serviceAccountPassword -AsPlainText -Force
    [System.Management.Automation.PSCredential ]$cred1 = New-Object System.Management.Automation.PSCredential ($serviceAccountName, $secureString)

    $ModuleFiles = Get-ChildItem -Path $source -File

    foreach ($destinationServer in $destinationList){

        $destination = "\\"+$destinationServer+"\"+$moduleDirectory

    Write-Verbose "Mapping J: drive to $destination." -Verbose
    if(-not (Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'J:'")) {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date)Mapping J: drive to $destination."
        New-PSDrive -Name J -PSProvider FileSystem -Root $destination -Credential $cred1
        Write-Verbose "Creating J Drive" -Verbose 
    }

    # Make sure the drive mapping suceeded.
    if (-not (Test-Path j:\ )) {  
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Share not available."
        throw
    }

    Get-PSDrive -Name J -PSProvider Filesystem | Select -first 1 | %{$destination = $_.Root + $_.CurrentLocation} -InformationAction Ignore
  
            ForEach ($module in $ModuleFiles) {

                $moduleDir = $($destination + '\' + $module.Basename)
                New-Item $moduleDir -Type Directory -Force | Out-Null
                Write-Verbose "Created ModuleDirectory - $moduleDir" -Verbose
                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Created ModuleDirectory - $moduleDir"

                Write-Verbose "Starting to Copy All Data from $source to $destination" -Verbose
                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Starting to Copy All Data from $source to $destination"
                Copy-Item -Path $module.FullName -Destination $moduleDir -Force
                Write-Verbose "Copied Module - $($module.Name) to $moduleDir" -Verbose
                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Copied Module - $($module.Name) to $moduleDir"
    }
               Write-Verbose "Completed copying data" -Verbose
               Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Completed copying data"
    Write-Verbose "Removing mapped drive: J." -Verbose       
    Remove-PSDrive -Name J
        
    }
}
catch {
    Write-Error $_
    $message = "Copy from $source to $destination failed."

    Write-Error -ForegroundColor Red -BackgroundColor Black $message
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -message $message

    if((Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'J:'")) {
        Write-Verbose "Removing Mapped drive: J." -Verbose
        Remove-PSDrive -Name J
    }

    throw $_
}