<#
.SYNOPSIS
    Add a Windows fiewall rule to open port
.DESCRIPTION
    Add a Windows fiewall rule to open port if a rule with the same name name is not present
.PARAMETER FirewallRules
    Windows firewall Rules
#>
param (
    $FirewallRules
)

function ConfigureFireWall {
    param (
        $FirewallRules
    )
    

    $RulesMap = New-Object System.Collections.Generic.Dictionary"[String,String]"
    $FirewallRules = $FirewallRules.Replace('{','').Replace(']','').Replace('[','').Replace('}','').Trim()

    Write-Verbose "Firewall Rules :  $FirewallRules" -Verbose

    $RulesArray = $FirewallRules.Split(',')
    Write-Verbose "RulesArray : $RulesArray" -Verbose

    foreach($FirewallRule in $RulesArray){

        if($FirewallRule.Length -gt 0){
            $rule = $FirewallRule.Split(':')
            
            if(! $RulesMap.ContainsKey($rule[0])){
                $RulesMap[$rule[0]] = $rule[1]
            }
            else{

                    $displayName = $RulesMap["DisplayName"]
                    Write-Verbose "Display Name :  $displayName" -Verbose
                    Write-Verbose $RulesMap["DisplayName"] -Verbose
                    Write-Verbose $RulesMap["LocalPort"] -Verbose
                    Write-Verbose $RulesMap["Direction"] -Verbose
                    Write-Verbose $RulesMap["Protocol"] -Verbose
                    Write-Verbose $RulesMap["Action"] -Verbose
                    Write-Verbose $RulesMap["Profile"] -Verbose
                    Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Display Name :  $displayName"

                    # Checking whether for existing rule with Protocol, Local Port, Direction and Action
                    if(-not (CheckFireWallConfig -Protocol $RulesMap["Protocol"] -LocalPort $RulesMap["LocalPort"] -Direction $RulesMap["Direction"] -Action $RulesMap["Action"] -Profile $RulesMap["Profile"])){
                        
                        $existingRules = Get-NetFirewallRule
                        # Checking whether for existing display name existing
                        if (-not $existingRules.DisplayName.Contains($RulesMap["DisplayName"])){
                            $displayName = $RulesMap["DisplayName"]
                            Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Display Name for Firewall :  $displayName"
                            New-NetFirewallRule -DisplayName $RulesMap["DisplayName"] -Direction $RulesMap["Direction"] -LocalPort $RulesMap["LocalPort"] -Protocol $RulesMap["Protocol"] -Action $RulesMap["Action"] -Profile $RulesMap["Profile"]
                        }
                        else {
                            $random = Get-Random
                            $RulesMap["DisplayName"] =  $RulesMap["DisplayName"]+ " " +$random.ToString()
                            $displayName = $RulesMap["DisplayName"]
                            Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Display Name for Firewall :  $displayName"

                            New-NetFirewallRule -DisplayName $RulesMap["DisplayName"] -Direction $RulesMap["Direction"] -LocalPort $RulesMap["LocalPort"] -Protocol $RulesMap["Protocol"] -Action $RulesMap["Action"] -Profile $RulesMap["Profile"]
                        }
                    }
                    
                $RulesMap = New-Object System.Collections.Generic.Dictionary"[String,String]"
                $RulesMap[$rule[0]] = $rule[1]
            }
        }
    }

    $displayName = $RulesMap["DisplayName"]
    Write-Verbose "Display Name :  $displayName" -Verbose
    $existingRules = Get-NetFirewallRule

    if(-not (CheckFireWallConfig -Protocol $RulesMap["Protocol"] -LocalPort $RulesMap["LocalPort"] -Direction $RulesMap["Direction"] -Action $RulesMap["Action"] -Profile $RulesMap["Profile"] )){
        if (-not $existingRules.DisplayName.Contains($RulesMap["DisplayName"])){
            New-NetFirewallRule -DisplayName $RulesMap["DisplayName"] -Direction $RulesMap["Direction"] -LocalPort $RulesMap["LocalPort"] -Protocol $RulesMap["Protocol"] -Action $RulesMap["Action"] -Profile $RulesMap["Profile"]
        }
        else {
            $random = Get-Random
            $RulesMap["DisplayName"] =  $RulesMap["DisplayName"]+ " " +$random.ToString()
            New-NetFirewallRule -DisplayName $RulesMap["DisplayName"] -Direction $RulesMap["Direction"] -LocalPort $RulesMap["LocalPort"] -Protocol $RulesMap["Protocol"] -Action $RulesMap["Action"] -Profile $RulesMap["Profile"]
        }
    }
}

function CheckFireWallConfig {
    param (
        [string] $Protocol,
        [string] $LocalPort,
        [string] $Direction,
        [string] $Action,
        [string] $Profile
    )

    $rule = Get-NetFirewallPortFilter -Protocol $Protocol | Where { $_.localport -eq $LocalPort } | Get-NetFirewallRule  | Where { $_.Direction -eq $Direction -and $_.Enabled -eq 'True' -and $_.Action -eq $Action -and $_.Profile -eq $Profile }

    if($rule.DisplayName.Length -gt 0){
        return $true
    }
    else{
        return $false
    }
}

function Main{

	try {
        ConfigureFireWall $FirewallRules
    }
    catch {
		
		Write-Verbose "Error trying to create Firewall rules : " -verbose
		throw
	}
}

if ($MyInvocation.InvocationName -ne '.') {
	Main
}