<#
.SYNOPSIS
    Installs Visual C++ Runtime on VM
.DESCRIPTION
    Installs Visual C++ Runtime on VM
.OUTPUTS
    None.
#>
param (
    [Bool] $IsTest = $False,
    $InstallerURI = "",
    $SASToken = ''
)

# init log setting
$logLoc = "$env:SystemDrive\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\VisualCInstall"
if (! (Test-Path($logLoc))) {
    New-Item -path $logLoc -type directory -Force
}
$logPath = "$logLoc\tracelog.log"
"Start to excute InstallVisualC.ps1. `n" | Out-File $logPath

 
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
 

function Install-VisualCRuntime([string] $installerPath) {
    if ([string]::IsNullOrEmpty($installerPath)) {
        Throw-Error "Installer path is not specified"
    }

    if (!(Test-Path -Path $installerPath)) {
        Throw-Error "Invalid Install path: $installerPath"
    }

    Write-Host $installerPath
    #install silently
    Trace-Log "Start Installation: $installerPath"

    Run-Process $installerPath "/Q"        

    Start-Sleep -Seconds 120
    Trace-Log "Installation successful"

    # Remove the Visual C++ Runtime installer
    rm -Force -Recurse $installerPath
}


function Get-VisualCRuntime([string] $uri, [string] $installDir, [string] $installPath) {

    # Check if work directory exists if not create it
    If (!(Test-Path -Path $installDir -PathType Container)) { 
        New-Item -Path $installDir  -ItemType directory 
        Trace-Log "Created $installDir directory successfully"
    } 

    try {
        $ErrorActionPreference = "Stop";
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($uri, $installPath) 
        Trace-Log "Download Visual C++ Runtime successfully. Visual C++ Runtime loc: $installPath"
    }
    catch {
        Trace-Log "Fail to download Visual C++ Runtime exe"
        Trace-Log $_.Exception.ToString()
        throw
    }
}

function main {
    Trace-Log "Log file: $logLoc"
    $visualCInstallerName = "vcredist_x64.exe"
    $uri = $InstallerURI + $visualCInstallerName + $SASToken
    Trace-Log "Visual C++ Runtime Download Link: $uri"
    $visualCRuntimeDir = "$($PWD)\VisualCRuntime"
    $visualCRuntimePath = "$($visualCRuntimeDir)\vcredist_x64.exe" 
    Trace-Log "Visual C++ Runtime Download Location: $visualCRuntimePath"
    Get-VisualCRuntime $uri $visualCRuntimeDir $visualCRuntimePath
    Trace-Log "Visual C++ Runtime Downloaded Successfully: $visualCRuntimePath"
    Install-VisualCRuntime $visualCRuntimePath 

}

if ($IsTest -eq $False) {
    main
}