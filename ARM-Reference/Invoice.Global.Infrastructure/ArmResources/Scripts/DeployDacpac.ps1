param(
    [string]$dacpacConfigPath,
    [string]$keyVaultName,
    [string]$sqlPackageExePath,
    [string]$dacpacWorkingDirectory,
    [string]$deployemntTag
)

class DacpacObject {
    [string] $DeploymentAction
    [string] $DacPacFile
    [string] $SqlPackageParameters
    [string] $VariablesString
}


<#
    .SYNOPSIS
        Inner Function, intended to call within the Script..
    .DESCRIPTION
        Function masks the Variable Declaration to hide Secrets from the Geneated DACPAC Script file.
    .PARAMETER filePath
        Path of the DACPAC Script File.
    #>
function RemoveVariablesFromDacPacScript($filePath) {
    try {
            
        if (![System.IO.File]::Exists($filePath)) {
            throw "Failed to find the SQL Differential Script file at path ${filePath}."
        }
        else {
            # Verified the File Exists
            # We need to Read the Content and Mask the Input Arguments
            $regex = ':setvar.[A-Z].*'
            (Get-Content $filePath) -replace $regex, '' | Set-Content $filePath

            Write-Host -ForegroundColor Green -BackgroundColor Black `
                "Successfully removed the variable declaration(s) with secrets from ${filePath}."
        }
    }
    catch {
        Write-Verbose "Exception Occurred in RemoveVariablesFromDacPacScript !" -Verbose
        Write-Verbose $_.Exception -Verbose
        Write-Verbose $_.ScriptStackTrace -Verbose
        throw        
    }
}



<#.SYNOPSIS
        Inner Function, intended to call within the Script..
    .DESCRIPTION
        Parse DacpacParam json obhect from dacpac_settings.json file and build variable string to pass to dacpac
    .PARAMETER filePath
        DacpacParam Object
    #>
function prepareDacpacVarStringForDeployment($DacpacParam) {
    foreach ( $parameter in $DacpacParam.psobject.properties.Name ) {
        $variableName = ${parameter}
        $variableValue = $database.DacpacParam.$parameter
        $variableValues += " /Variables:${variableName}='${variableValue}'"
    }

    return  $variableValues
}

<#.SYNOPSIS
        Inner Function, intended to call within the Script..
    .DESCRIPTION
        Parse DacpacParam json obhect from dacpac_settings.json file and build variable string to pass to dacpac
    .PARAMETER Databases
        Database object from dacpac-settings.json file
    #>
function buildDacpacInfoMap($Databases) {

    $db_variableString = @{}

    foreach ($database in $Databases) {  
        $dbKey = $database.Name 

        if ($database.DacpacParam.Length -ne 0) {
            $dacpacVariable = prepareDacpacVarStringForDeployment $database.DacpacParam
        }
  

        $dacpacMapping = [DacpacObject] @{
            DeploymentAction     = $database.DeployParam.DeploymentAction
            DacPacFile           = $dacpacWorkingDirectory + "\" + $database.DeployParam.DacPacFile
            SqlPackageParameters = $database.DeployParam.SqlPackageParameters
            VariablesString      = $dacpacVariable
        }

        $db_variableString += @{ $dbKey = $dacpacMapping } 
      
    }

    return $db_variableString
}  

<#.SYNOPSIS
        Inner Function, intended to call within the Script..
    .DESCRIPTION
        Deploy dacpac to given TargetServerName
    #>
function deployDacpac ($DacpacPath , $TargetDatabaseName, $TargetServerName, $SqlPackagePath, $SqlPackageParameters, $DeploymentAction, $VariablesString) {
  
        try {
             
            $commandString = "$SqlPackageExePath"
            $commandString += " /Action:$DeploymentAction"
     
            $commandString += " /SourceFile:${DacpacPath}"
            $commandString += " /TargetServerName:${TargetServerName}"
            $commandString += " /TargetDatabaseName:${TargetDatabaseName}"
             
            $commandString += " " + ${SqlPackageParameters}
        
            $commandString += " " + $VariablesString 

            Write-Host -ForegroundColor Green -BackgroundColor Black `
                "Deploying database ${databaseName} Started On ${ServerName} with Action ${action}."

            Write-Host -ForegroundColor Green -BackgroundColor Black `
                "Command to execute $commandString" 
              
            $sqlInstances = gwmi win32_service -computerName localhost -ErrorAction SilentlyContinue | ? { $_.Name -match "mssql*" -and $_.PathName -match "sqlservr.exe" } 
   
                $output = (Invoke-Expression "& ${commandString}") 
           
        
            Write-Host -ForegroundColor Green -BackgroundColor Black `
                "Successfully deployed the ${databaseName} database on ${TargetServerName} Server with Action ${DeploymentAction}."

            Write-Host  "The Deployment output => ${output}" 
        } 
        catch {
                $agentuser = whoami     
                Write-Host "Exception Occurred in deployDacpac ! Running user as ${agentuser}" 

                Write-Host "Errors Deploying the ${TargetDatabaseName} on ${serverName} Server with ${output}." -Verbose

                Write-Host $_.Exception -Verbose
                Write-Host $_.ScriptStackTrace -Verbose

                throw
                               
        }  
}

 $agentuser = whoami     
 Write-Host "Running user as ${agentuser}" 
####################     Dacpac Deployemnt Script starts here       #########################################
$dacpacSettings = (Get-Content $dacpacConfigPath) -join "`n" | ConvertFrom-Json
###############################################################################


$Databases = $dacpacSettings.Databases
$Servers = $dacpacSettings.Servers


Write-Verbose "Deploying Dacpac for server $Databases" -Verbose

$dacpacMap = buildDacpacInfoMap($Databases)

$dacpacMap 

Write-Verbose "Deploying Dacpac for server $Servers"  -Verbose 
#Deploy dacpac for each server
foreach ($serverSet in $Servers) {
$configDeploymentTag = $serverSet.ServerType
    if($configDeploymentTag -eq $deployemntTag){
    
    Write-Verbose "Deploying Dacpac for server $serverSet" -Verbose   

    $serverNames = $serverSet.ServerName
    $databasesToDeploy = $serverSet.Database

    foreach ($targetServerName in $serverNames) {

        foreach ($db in $databasesToDeploy) {
            $dbDacpacDetails = $dacpacMap[$db]     

            $dacpacPath = $dbDacpacDetails.DacPacFile
            $SqlPackageParameters = $dbDacpacDetails.SqlPackageParameters
            $DeploymentAction = $dbDacpacDetails.DeploymentAction
            $VariablesString = $dbDacpacDetails.VariablesString

            deployDacpac -DacpacPath $dacpacPath `
                -TargetDatabaseName $db `
                -TargetServerName $targetServerName `
                -SqlPackagePath $SqlPackageExePath `
                -SqlPackageParameters $SqlPackageParameters `
                -DeploymentAction $DeploymentAction `
                -VariablesString $VariablesString
        }

}
    }
}
