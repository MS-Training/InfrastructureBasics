#https://docs.microsoft.com/en-us/rest/api/containerapps/managed-environments/get
#https://app.pluralsight.com/course-player?clipId=a393eace-bf74-4e1a-ad5f-e02fe0af6fe0

<#
Bicep  Decompile , Update and Build Operations
bicep decompile .\QuickStart-Container-Apps-Arm\template.json

az bicep build --file ".\deploy.bicep"

az bicep upgrade

az bicep build --file .\deploy.bicep
#>

Clear-Host

Connect-AzAccount

#get the execution path of this current script
#$Directorypath = $PSScriptRoot

$Directorypath = (Get-Location).Path 

#testing
#$Template = "C:\Users\edrush.REDMOND\OneDrive - Microsoft\R\repos\Invoice-Other-Stories\GovernmentClearance\Deploy-VirtualNetwork\vn-individual-deployments\deploy.bicep"
#$Parameters = "C:\Users\edrush.REDMOND\OneDrive - Microsoft\R\repos\Invoice-Other-Stories\GovernmentClearance\Deploy-VirtualNetwork\vn-individual-deployments\parameters.json"

# Combine paths using Join-Path for cross-platform compatibility
#$Template = Join-Path $Directorypath "Resources\Components\Network\module-network-resourcegroup.bicep"
$Template   = Join-Path $Directorypath "Global-Infrastructure\Deployers\fc\ServiceRootGroup\Templates\deploy.bicep"
$Parameters = Join-Path $Directorypath "Global-Infrastructure\Deployers\fc\ServiceRootGroup\Parameters\azuredeploy-parameters.json"

Write-Output $Template -Verbose
Write-Output $Parameters -Verbose


#Will get the Subscription based on the Name.
#$Subscription = Get-AzSubscription -SubscriptionName "Visual Studio Enterprise Subscription"

#use when you set the entire scope of execution to the subscription
$Subscription = Get-AzSubscription -SubscriptionId "a897c71d-73a0-4b90-b084-9d2b39eee4eb"
Set-AzContext -SubscriptionObject $Subscription

$Location = "eastus"
#will forcibly remove a resource group
#Remove-AzResourceGroup $ResourceGroup  -Force -Verbose

#https://docs.microsoft.com/en-us/powershell/module/az.resources/new-azresourcegroupdeployment?view=azps-8.0.0
#$rgDeployment = New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroup -TemplateFile $ResourceGroupTemplate -TemplateParameterFile $ResourceGroupParameters

$DeploymentName = "MainDeployment$((Get-Date).Ticks.ToString())"
$rgDeployment = New-AzDeployment -Name $DeploymentName -Location $Location -TemplateFile $Template -TemplateParameterFile $Parameters

Write-Output $rgDeployment


az bicep build --file $Template




#$ResourceGroupName = $rgDeployment.Outputs.resourceGroupName.Value

