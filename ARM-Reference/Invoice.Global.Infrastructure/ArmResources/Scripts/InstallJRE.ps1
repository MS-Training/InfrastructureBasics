<#
.SYNOPSIS
    Installs Java on ADF Gateway VMs and setup JAVA_HOME
.DESCRIPTION
    Installs Java on ADF Gateway VMs and setup JAVA_HOME
.PARAMETER JavaDownloadUrl
    Url to download java package
.OUTPUTS
    None.
#>
param (
    [Bool] $IsTest = $False,
    $JREInstallerName = "jre-11.0.10.msi",
    $InstallerURI = "",
    $SASToken = ''
)

# init log setting
$logLoc = "$env:SystemDrive\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\JREInstall"
if (! (Test-Path($logLoc))) {
    New-Item -path $logLoc -type directory -Force
}
$logPath = "$logLoc\tracelog.log"
"Start to excute InstallJRE.ps1. `n" | Out-File $logPath

 
function Now-Value() {
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}


function Throw-Error([string] $msg) {
    try {
        throw $msg
    } 
    catch {
        $stack = $_.ScriptStackTrace
        Trace-Log "DMDTTP is failed: $msg`nStack:`n$stack"
    }

    throw $msg
}

function Trace-Log([string] $msg) {
    $now = Now-Value
    try {
        "${now} $msg`n" | Out-File $logPath -Append
    }
    catch {
        #ignore any exception during trace
    }
}
 
function Run-Process([string] $process, [string] $arguments) {
    Write-Host "Run-Process: $process $arguments"
    
    $errorFile = "$env:tmp\tmp$pid.err"
    $outFile = "$env:tmp\tmp$pid.out"
    "" | Out-File $outFile
    "" | Out-File $errorFile    

    $errVariable = ""

    if ([string]::IsNullOrEmpty($arguments)) {
        $proc = Start-Process -FilePath $process -Wait -Passthru -NoNewWindow `
            -RedirectStandardError $errorFile -RedirectStandardOutput $outFile -ErrorVariable errVariable
    }
    else {
        $proc = Start-Process -FilePath $process -ArgumentList $arguments -Wait -Passthru -NoNewWindow `
            -RedirectStandardError $errorFile -RedirectStandardOutput $outFile -ErrorVariable errVariable
    }
    
    $errContent = [string] (Get-Content -Path $errorFile -Delimiter "!!!DoesNotExist!!!")
    $outContent = [string] (Get-Content -Path $outFile -Delimiter "!!!DoesNotExist!!!")

    Remove-Item $errorFile
    Remove-Item $outFile

    if ($proc.ExitCode -ne 0 -or $errVariable -ne "") {        
        Throw-Error "Failed to run process: exitCode=$($proc.ExitCode), errVariable=$errVariable, errContent=$errContent, outContent=$outContent."
    }

    Trace-Log "Run-Process: ExitCode=$($proc.ExitCode), output=$outContent"

    if ([string]::IsNullOrEmpty($outContent)) {
        return $outContent
    }

    return $outContent.Trim()
}
 

function Install-JRE([string] $jrePath) {
    if ([string]::IsNullOrEmpty($jrePath)) {
        Throw-Error "JRE path is not specified"
    }

    if (!(Test-Path -Path $jrePath)) {
        Throw-Error "Invalid JRE path: $jrePath"
    }

    Write-Host $jrePath
    #install silently
    Trace-Log "Start JRE installation"
    #INSTALLLEVEL=3 parameters creates/updates the Java_Home env variable
    Run-Process "msiexec.exe" "/i $jrePath /quiet /norestart INSTALLLEVEL=3"        

    Start-Sleep -Seconds 120
    Trace-Log "Installation of jre is successful"

    # Remove the java installer
    rm -Force -Recurse $jrePath
}


function Get-JRE([string] $uri, [string] $jreDir, [string] $jrePath) {

    # Check if work directory exists if not create it
    If (!(Test-Path -Path $jreDir -PathType Container)) { 
        New-Item -Path $jreDir  -ItemType directory 
        Trace-Log "Created $jreDir directory successfully"
    } 

    try {
        $ErrorActionPreference = "Stop";
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($uri, $jrePath) 
        Trace-Log "Download jre successfully. JRE loc: $jrePath"
    }
    catch {
        Trace-Log "Fail to download JRE exe"
        Trace-Log $_.Exception.ToString()
        throw
    }
}

function main {
    Trace-Log "Log file: $logLoc"
    $uri = $InstallerURI + $JREInstallerName + $SASToken
    Trace-Log "JRE download fw link: $uri"
    $jreDir = "$($PWD)\JavaSetup"
    $jrePath = "$($jreDir)\jre.msi" 
    Trace-Log "JRE directory download location: $jrePath"
    Get-JRE $uri $jreDir $jrePath
    Trace-Log "JRE Downloaded Successfully: $jrePath"
    Install-JRE $jrePath 

}
if ($IsTest -eq $false) {
    main
}