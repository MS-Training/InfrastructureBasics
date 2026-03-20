<#
.SYNOPSIS
    This post script maps folders to network directories
.DESCRIPTION
    After the VMs are created, this script will configure the following vms settings.
    This post script maps folders to network directories
.OUTPUTS
    None.
.PARAMETER DirectoriesToMap
    The location of the shortcuts and where to map them. Must be in this format: fromLocation;mappedLocation,fromLocation2;mappedLocation2
    Example: C:\\path\to\folder;\\\\path\to\network\folder,C:\\another\folder;\\\\path\to\different\network\folder
#>
param (
    [Parameter(Mandatory = $true)]
    [string] $DirectoriesToMap
)
try {
    new-EventLog -LogName Application -source 'AzureArmTemplates' -ErrorAction SilentlyContinue
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Map Network Directories Event Log Source was Created"
    $directoryMap = ($DirectoriesToMap).split(",")
    foreach ($map in $directoryMap) {        
        $fromAndTo = $map.split(";")
        $from = $fromAndTo[0]
        $to = $fromAndTo[1]
        Write-Host "Attempting to create directory from $($from) to $($to)"
        Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Attempting to create directory from $($from) to $($to)"
        If ( (test-path -path "$($from).lnk") -ne $true) {
            $wsshell = New-Object -ComObject WScript.Shell
            $shortcut = $wsshell.CreateShortcut($from + ".lnk")
            $shortcut.TargetPath = $to
            $shortcut.IconLocation = "imageres.dll,3"
            $shortcut.save()

            Write-Host "Created directory from $($from) to $($to)"
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Created directory from $($from) to $($to)"
        }
        else {
            Write-Verbose "Not creating mapped folder - from directory ($($from)) already exists" -Verbose
            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -message "Not creating mapped folder - from directory ($($from)) already exists"
        }
    }
}
catch [System.Exception] {
    Write-Verbose "Error trying to create network directory map" -Verbose
    Write-Verbose $_.Exception -Verbose
    Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Error -message   "Error trying to create network directory map - $($_.Exception)"
    throw
} 