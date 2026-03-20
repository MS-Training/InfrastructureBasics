param(
    [Parameter(Mandatory = $true)]
    $DefaultWorkingDirectory,
    [Parameter(Mandatory = $true)]
    $ArtifactBasePath
)

Import-Module Az.Resources

$templatespecfolderPath = "$($DefaultWorkingDirectory)/$($ArtifactBasePath)/ArmResources/"
$ResourceGroupName = "RG-630-INV-GLOBAL-TEMPLATESPECS"
$location = "eastus"

if (Test-Path $templatespecfolderPath) {
 
    $files = Get-ChildItem -Path $templatespecfolderPath -Recurse -File -Include *.json
    Write-Verbose "Found $($files.Count) template files in folder" -Verbose

    # Create template spec resource group
    New-AzResourceGroup -Location $location -Name $ResourceGroupName -Force
    
    foreach ($file in $files) {
        $relativePath = $file.FullName -replace '.*ArmResources\\', '' -replace '.json', ''
        $directory = $relativePath -split '\\'

        $templatefileName = ''

        # Template Spec Name = "<Component Name>-<File Name>"
        # Component Name is the second child of /ArmResources, i.e., "Invoice", "Classic", "AutomationAccount",...

        if ($directory.Length -eq 1) {
            $templatefileName = $directory[0]
        } 
        elseif ($directory.Length -eq 2) {
            $templatefileName = $directory[1]
        } 
        elseif ($directory.Length -ge 3) {
            $templatefileName = $directory[1] + "-" + $directory[-1]
        }

        # Ensure template file name is less than 64 characters
        if ($templatefileName.Length -gt 64) {
            throw "Template file name too long: $templatefileName, length: $($templatefileName.Length)"
        }

        # Check if template spec exists
        Write-Verbose "Checking Name: $templatefileName" -Verbose
        $templatespec = get-AzTemplateSpec -Name $templatefileName -ResourceGroupName $ResourceGroupName -version v1 -ErrorAction SilentlyContinue
        
        # Remove existing template spec
        if ($templatespec) {
            Remove-AzTemplateSpec -Name $templatefileName -ResourceGroupName $ResourceGroupName -Force
            Write-Verbose "Removing template spec" -Verbose
        }
        else {
            Write-Verbose "Template spec does not exist" -Verbose
        }
        
        $templatefilePath = $file.FullName
        Write-Verbose "File Path: $templatefilePath" -Verbose
        Write-Verbose "Spec Name: $templatefileName" -Verbose
        New-AzTemplateSpec -ResourceGroupName  $ResourceGroupName -Name $templatefileName -Version 'v1' -Location $location -TemplateFile $templatefilePath
        Write-Verbose "Created template spec" -Verbose
    }
} 
else {
    throw "Directory not found: $templatespecfolderPath"
}