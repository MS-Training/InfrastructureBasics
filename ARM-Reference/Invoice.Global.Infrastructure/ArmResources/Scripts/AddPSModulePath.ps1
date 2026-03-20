<#
.SYNOPSIS
    This scripts takes a list of paths separated by a comma.
.DESCRIPTION
    This scripts takes a list of modules separated by a comma and adds them to the PSModulePath Env. Variable .
.PARAMETER accountList
    This is a list of paths that contains psm1 files
.OUTPUTS
    None.
#>
param (
    $modulePaths
)

###########################################################################################################################################################
# Adds Module Path to the PSModulePath Environment Variable 
###########################################################################################################################################################
$modulePaths = ($modulePaths).split(",")

foreach ($modulePath in $modulePaths) {
        
    $currentValue = [Environment]::GetEnvironmentVariable("PSModulePath", "Machine")

    $currrentpPathList = $currentValue.Split(';')

    $addModulePath = $true

    foreach ($path in $currrentpPathList ) {

        if ($path -eq $modulePath ) {
            $addModulePath = $false
        }
    }
    if ($addModulePath) {
        [Environment]::SetEnvironmentVariable("PSModulePath", $currentValue + [System.IO.Path]::PathSeparator + $modulePath, "Machine")
    }    
}
