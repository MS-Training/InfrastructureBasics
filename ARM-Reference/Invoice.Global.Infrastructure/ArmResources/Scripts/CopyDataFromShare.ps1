param(
    [String]$serviceAccountName,
    [String]$serviceAccountPassword,
    [String]$source,
    [String]$destination
)
 
try {
    $secureString = ConvertTo-SecureString $serviceAccountPassword -AsPlainText -Force
    [System.Management.Automation.PSCredential ]$cred1 = New-Object System.Management.Automation.PSCredential ($serviceAccountName, $secureString)
    
    Write-Verbose "Mapping J: drive to $source." -Verbose
    if(-not (Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'J:'")) {
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date)Mapping J: drive to $source."
        New-PSDrive -Name J -PSProvider FileSystem -Root $source -Credential $cred1
    }

    # Make sure the drive mapping suceeded.
    if (-not (Test-Path j:\ )) {  
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Share not available."
        throw
    }

    Get-PSDrive -Name J -PSProvider Filesystem | Select -first 1 | %{$source = $_.Root + $_.CurrentLocation} -InformationAction Ignore
    Write-Verbose "Begining copy operation from $source to $destination" -Verbose

    if($env:computername -match "pub"){
    Write-Verbose "Starting to Copy PUB Data from $source\$env:computername to $destination" -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Starting to Copy PUB Data from $source\$env:computername to $destination"
    robocopy $source\$env:computername $destination /MT:64
    }
    else{
    Write-Verbose "Starting to Copy All Data from $source to $destination" -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Starting to Copy All Data from $source to $destination"
    robocopy $source $destination /MT:128 /S /LEV:2
    }

    Write-Verbose "Completed copying data" -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "$(Get-Date) Completed copying data"

    Write-Verbose "Removing mapped drive: J." -Verbose
    Remove-PSDrive -Name J


    }
catch {
    $message = "Copy from Sync server to $destination failed."
    Write-Host -ForegroundColor Red -BackgroundColor Black $message
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message $message

    if((Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'J:'")) {
        Write-Verbose "Removing Mapped drive: J." -Verbose
        Remove-PSDrive -Name J
    }

    throw $_
}