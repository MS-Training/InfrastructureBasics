<#
.SYNOPSIS
    Loops throgh post scripts, and executes each script with corresponding params
.DESCRIPTION
    Loops throgh post scripts, and executes each script with corresponding params
.PARAMETER ServicePrincipalKey
    Service Principal Password (Secured string).
.PARAMETER CommonUtilityPath
    Common Utility path
.PARAMETER ConfigFilePath
    Config File Path
.PARAMETER ReadParamValuesFromSettingsFile
    boolean flag to Read Param Values From SettingsFile (FromAutomationAccountName and FromAutomationAccountResourceGroup)
.PARAMETER ImportFromExistingAccount
    boolean flag to add variables from existing automation account or from settings file.
.PARAMETER FromAutomationAccountName
    Automation Account name from which varables should be copied.
.PARAMETER FromAutomationAccountResourceGroup
    Automation Account name's Resource Group from which varables should be copied
.PARAMETER IsTest
    bool flag for Test
#>

[CmdletBinding()]
param (    

    [bool] $ImportFromExistingAccount = $true,
    [bool] $ReadParamValuesFromSettingsFile = $false,
    [string] $FromAutomationAccountName,
    [string] $FromAutomationAccountResourceGroup,
    [string] $FromSubscriptionId,
    [string] $TargetAutomationAccountName,
    [string] $TargetResourceGroup,
    [bool] $DeleteAndAdd = $true,    
    [bool] $IsTest = $false,
    [string] $ToSubscriptionId
)

$ErrorActionPreference = "Stop"
<#
.SYNOPSIS
    Import all the variables from existing automation account
.DESCRIPTION
    Import all the variables from existing automation account
#>
function AddVariablesFromExistingAccount {
    try{    
        Write-Verbose "Creating Variables Please Wait!" -Verbose

        Set-AzContext -SubscriptionId $FromSubscriptionId

        $ToAutomationAccountName = $TargetAutomationAccountName
        $ToResourceGroup = $TargetResourceGroup

        Write-Verbose "ToAutomationAccountName : $ToAutomationAccountName " -Verbose
        Write-Verbose "ToResourceGroup : $ToResourceGroup " -Verbose

        Write-Verbose "FromAutomationAccountName : $FromAutomationAccountName " -Verbose
        Write-Verbose "FromAutomationAccountResourceGroup : $FromAutomationAccountResourceGroup" -Verbose

        $ListVariables= Get-AzAutomationVariable -AutomationAccountName $FromAutomationAccountName  -ResourceGroupName $FromAutomationAccountResourceGroup
        Write-Verbose "Found variables count: $($ListVariables.Count)" -Verbose

        Set-AzContext -SubscriptionId $ToSubscriptionId
        foreach($item in $ListVariables)
        {
         Write-Verbose "Current varaible $($item.name)" -Verbose
       
            # Verify if the variable is already exists
            $existingVariable = Get-AzAutomationVariable -AutomationAccountName $ToAutomationAccountName -Name $item.Name -ResourceGroupName $ToResourceGroup -ErrorAction SilentlyContinue

            if($existingVariable.Count -ne 0 -and $DeleteAndAdd -eq $true){        
                Write-Verbose "Removing the existing variable $($item.Name)" -Verbose
                # Remove variable if exists
                Remove-AzAutomationVariable -ResourceGroupName $ToResourceGroup -AutomationAccountName $ToAutomationAccountName -Name $item.Name -ErrorAction SilentlyContinue

                # set existingVariable to empty
                $existingVariable = @()
            }
            
            if($existingVariable.Count -eq 0){   
                
                $varName = $item.Name
                $varValue = ($item.Value).ToString()
                
                $varEnc = $item.Encrypted

                if($varName -eq "AutomationAccountName"){
                    $varValue = $TargetAutomationAccountName
                }

                if($varName -eq "SubscriptionID"){
                    $varValue = $ToSubscriptionId
                }

                New-AzAutomationVariable -Name $varName -Value $varValue -Encrypted $varEnc -ResourceGroupName $ToResourceGroup -AutomationAccountName $ToAutomationAccountName
            }
        }
    }
    catch{
        $Errormessage = $_.Exception.Message
        Write-Verbose "Creating Variables failed...$($_.Exception.ScriptStackTrace)" -Verbose
        Write-Verbose $Errormessage -Verbose        
    }
}

<#
.SYNOPSIS
    Create all the variables from settings fileCreate
.DESCRIPTION
    Create all the variables from settings fileCreate
#>
function CreateVariablesFromSettings {
    # Create variable from setting file
    Write-Verbose "Skipped creating variables, method is not implemented" -Verbose
}


<#
.SYNOPSIS
    Verify input params and call the respective method to add/create variables
.DESCRIPTION
    Verify input params and call the respective method to add/create variables
#>
function CreateVariables{

    if($ImportFromExistingAccount){

        # Override the input params from settings file if true
        if($ReadParamValuesFromSettingsFile){

            Write-Verbose "Reading params from settings file" -Verbose

            $FromAutomationAccountName = $SourceAutomationAccountName
            $FromAutomationAccountResourceGroup = $SourceResourceGroup
        }
        
        if($FromAutomationAccountName -eq "" -or  $FromAutomationAccountName -eq $null ){
            Write-Verbose "From Automation Account Name is missing..." -Verbose

            return
        }

        if($FromAutomationAccountResourceGroup -eq "" -or  $FromAutomationAccountResourceGroup -eq $null){
            Write-Verbose "From Automation Account ResourceGroup Name is missing..." -Verbose

            return
        }

        # If Import all the variables from existing automation account
        AddVariablesFromExistingAccount 
    }
    else{ 
        # Create variable from setting file
        CreateVariablesFromSettings
    }
    
}

<#
.SYNOPSIS
    Create Automation Account variables 
.DESCRIPTION
    Create Automation Account variables 
#>
function Main {

    # Create Variables
    CreateVariables
}

if ($IsTest -eq $false) {
    Main
}
