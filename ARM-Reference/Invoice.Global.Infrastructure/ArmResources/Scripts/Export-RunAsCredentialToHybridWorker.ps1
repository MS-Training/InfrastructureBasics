<#
.SYNOPSIS
    Attaches a RunAs Credential to a hybrid worker group.
.DESCRIPTION
    This is a workaround for the lack of an ARM template approach.
    Intended to be called following hybrid worker deployment.
    Makes a REST API call.

    ASSUMES:
    - Values 'SubscriptionId' and 'RG' are already present in the automation
      account variables
#>

param (
    [string] $AutomationAccountName,
    [string] $CredentialName,
    [string] $HWGroupName
)

$ErrorActionPreference = 'Stop'
$SubscriptionID = Get-AutomationVariable -Name 'SubscriptionId'
$ResourceGroupName = Get-AutomationVariable -Name 'RG'

Write-Output "Starting Runbook Export-RunsAsCredentialToHybridWorker:" `
    "    -AutomationAccountName (from params): $AutomationAccountName" `
    "    -CredentialName (from params): $CredentialName" `
    "    -HWGroupName (from params): $HWGroupName" `
    "    -SubscriptionID (from automation variables): $SubscriptionID" `
    "    -ResourceGroupName (from automation variables): $ResourceGroupName"

$ConnectionName = "AzureRunAsConnection"
try {
    $servicePrincipalConnection = Get-AutomationConnection -Name $ConnectionName

    Write-Output "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

Write-Output "Setting context to subscription $SubscriptionID..."
$azContext = Set-AzureRmContext -SubscriptionId $SubscriptionID
Write-Output "`n-------------------------------------------------"
Write-Output "AZContext:`n"
Write-Output $azContext
Write-Output "-------------------------------------------------`n`n"

Write-Output "Invoking the REST API call:"
$azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
$token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
$authHeader = @{
    'Content-Type' = 'application/json'
    'Authorization' = 'Bearer ' + $token.AccessToken
}

$restURI = "https://management.azure.com/" `
    + "subscriptions/$SubscriptionID/" `
    + "resourceGroups/$ResourceGroupName/" `
    + "providers/Microsoft.Automation/automationAccounts/$AutomationAccountName/" `
    + "hybridRunbookWorkerGroups/$HWGroupName" `
    + "?api-version=2019-06-01"

Write-Output "REST API URI: $restURI"

$content = @{
    credential = @{
        name = $CredentialName
    }
}

$body = (ConvertTo-Json $content)

$response = Invoke-RestMethod `
    -Uri $restURI `
    -Method Patch `
    -Body $body `
    -ContentType 'application/json' `
    -Headers $authHeader

Write-Output "`n-------------------------------------------------"
Write-Output "RESPONSE: $restURI"
Write-Output $response
