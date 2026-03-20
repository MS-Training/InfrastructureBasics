<#
.SYNOPSIS
    Makes the server as deployment Agent
.DESCRIPTION
    This script with makes the VM as agent for the passed deployment group
.PARAMETER DeploymentGroupName
    CICD deployment group name
.PARAMETER DeploymentGroupToken
    Access token for Deployment Group
.PARAMETER DeploymentGroupTag
    Tag for Deployment Group Agents
    For Agent Pools Agent Tag is NA
.PARAMETER IsDeploymentGroupAgent
    IsDeploymentGroupAgents = true for Deploy group agent.Default
    IsDeploymentGroupAgents = NO for Agent Pool agent.This value is by defualt configured through Agent Component
    #>

param(
    [String] $DeploymentGroupName,
    [String] $DeploymentGroupToken,
    [String] $DeploymentGroupTag = $env:COMPUTERNAME,
    [bool] $IsDeploymentGroupAgent = $True
)
try {

    if (-Not (Get-Service | Where-Object { $_.name -like 'vstsagent.microsoftit.OneITVSO*' })) {

        $ErrorActionPreference = "Stop";

        If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent() ).IsInRole( [Security.Principal.WindowsBuiltInRole] "Administrator")) { 
            throw "Run command in an administrator PowerShell prompt" 
        };

        If ($PSVersionTable.PSVersion -lt (New-Object System.Version("3.0"))) { 
            throw "The minimum version of Windows PowerShell that is required by the script (3.0) does not match the currently running version of Windows PowerShell." 
        }; 

        If (-NOT (Test-Path $env:SystemDrive\'azagent')) { 
            mkdir $env:SystemDrive\'azagent' 
        }; 

        cd $env:SystemDrive\'azagent'; 

        for ($i = 1; $i -lt 100; $i++) {
            $destFolder = "A" + $i.ToString(); 
            if (-NOT (Test-Path ($destFolder))) {
                mkdir $destFolder; cd $destFolder; break; 
            } 
        }; 

        $agentZip = "$PWD\agent.zip"; $DefaultProxy = [System.Net.WebRequest]::DefaultWebProxy; $securityProtocol = @(); $securityProtocol += [Net.ServicePointManager]::SecurityProtocol; 
        $securityProtocol += [Net.SecurityProtocolType]::Tls12; [Net.ServicePointManager]::SecurityProtocol = $securityProtocol; 
        $WebClient = New-Object Net.WebClient;
        $Uri = 'https://vstsagentpackage.azureedge.net/agent/2.174.1/vsts-agent-win-x64-2.174.1.zip'; 

        if ($DefaultProxy -and (-not $DefaultProxy.IsBypassed($Uri))) { 
            $WebClient.Proxy = New-Object Net.WebProxy($DefaultProxy.GetProxy($Uri).OriginalString, $True); 
        }; 


        $WebClient.DownloadFile($Uri, $agentZip);
        Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory( $agentZip, "$PWD"); 

        if ($IsDeploymentGroupAgent) {
            .\config.cmd --unattended --deploymentgroup --deploymentGroupName $DeploymentGroupName --agent $env:COMPUTERNAME --addDeploymentGroupTags --deploymentGroupTags $DeploymentGroupTag --runasservice --work '_work' --url 'https://microsoftit.visualstudio.com/' --projectname 'OneITVSO' --auth PAT --token $DeploymentGroupToken --replace;
        }
        else {
            .\config.cmd --unattended --pool $DeploymentGroupName --agent $env:COMPUTERNAME --runasservice --windowsLogonAccount "NT AUTHORITY\SYSTEM" --work '_work' --url 'https://microsoftit.visualstudio.com/' --projectname 'OneITVSO' --auth PAT --token $DeploymentGroupToken --replace;
        }
        Remove-Item $agentZip;
    }
}
catch {
    Write-Verbose "Erorr occured while deploying Agent on the server"
    throw
}