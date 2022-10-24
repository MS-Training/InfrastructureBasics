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
$Directorypath = $PSScriptRoot

#testing
#$Template = "C:\Users\edrush.REDMOND\OneDrive - Microsoft\R\repos\Invoice-Other-Stories\GovernmentClearance\Deploy-VirtualNetwork\vn-individual-deployments\deploy.bicep"
#$Parameters = "C:\Users\edrush.REDMOND\OneDrive - Microsoft\R\repos\Invoice-Other-Stories\GovernmentClearance\Deploy-VirtualNetwork\vn-individual-deployments\parameters.json"

#path to the default templates
$Template  = $Directorypath + "\deploy.bicep" 
$Parameters = $Directorypath + "\parameters.json" 

Write-Output $Template -Verbose
Write-Output $Parameters -Verbose


#Will get the Subscription based on the Name.
#$Subscription = Get-AzSubscription -SubscriptionName "Visual Studio Enterprise Subscription"

#use when you set the entire scope of execution to the subscription
$Subscription = Get-AzSubscription -SubscriptionId "f7798ac6-fe0d-4abd-8272-7ab2ea265db0"
Set-AzContext -SubscriptionObject $Subscription

$Location = "eastus2"
#will forcibly remove a resource group
#Remove-AzResourceGroup $ResourceGroup  -Force -Verbose

#https://docs.microsoft.com/en-us/powershell/module/az.resources/new-azresourcegroupdeployment?view=azps-8.0.0
#$rgDeployment = New-AzResourceGroupDeployment -Name $DeploymentName -ResourceGroupName $ResourceGroup -TemplateFile $ResourceGroupTemplate -TemplateParameterFile $ResourceGroupParameters

$DeploymentName = "VirtualNetworkDeployment$((Get-Date).Ticks.ToString())"
$rgDeployment = New-AzDeployment -Name $DeploymentName -Location $Location -TemplateFile $Template -TemplateParameterFile $Parameters

Write-Output $rgDeployment





#$ResourceGroupName = $rgDeployment.Outputs.resourceGroupName.Value

