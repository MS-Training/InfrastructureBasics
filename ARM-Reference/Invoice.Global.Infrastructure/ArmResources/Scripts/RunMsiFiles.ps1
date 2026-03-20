<#
.SYNOPSIS
    This script will run a given list of .msi files
.DESCRIPTION
    This script will run a given list of .msi files
.PARAMETER fileNameList
    A string of a list of .msi files separated by "," i.e
.PARAMETER filesPath
    A path where all the .msi files are stored.
.OUTPUTS
    None.
#>
param (
    $fileNameList = "msodbcsql.msi",
    $filesPath = "C:\AzureArmTemplates\"
)

function ExecuteMsiInstaller {
    param (
        $command
    )

    Start-Process msiexec.exe -Wait -ArgumentList "$command"

}
function Main {

    $fileNameList = $fileNameList.split(',')

    foreach ($fileName in $fileNameList) {
    
        $file = $filesPath + $fileName

        if (Test-Path $file) { 

            $fileBaseName = ((Get-Item -Path $file).BaseName).ToUpper()
            $license = "IACCEPT$fileBaseName" + "LICENSETERMS=YES"
            $cmd = "/i $file /q $license /norestart"

            if (($fileBaseName = 'MSODBCSQL') -and (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft ODBC Driver 13 for SQL Server" -ErrorAction SilentlyContinue)) {

                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "SQL Server 2017 ODBC Driver $fileName is already Installed. Skipping..."
    
            }
            else {

                Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1000 -entrytype Information -message "Starting to execute msiexe with arg: $cmd" 
                ExecuteMsiInstaller -command $cmd   
            }

        }
        else {

            Write-EventLog -LogName Application -source AzureArmTemplates -eventID 1002 -entrytype Error -message "File does not exist: $fileBaseName" 
            Throw 
        }

    }

    shutdown /r /t 15
   
}

Main