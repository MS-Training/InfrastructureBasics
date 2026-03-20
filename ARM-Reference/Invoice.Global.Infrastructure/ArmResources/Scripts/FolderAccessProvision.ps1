<#
.SYNOPSIS
	Set local policy for the ProxyAccount.
.DESCRIPTION
    Set local policy for the ProxyAccount.
.ProxyAccountName
    Account to provide access to. 
.PARAMETER IsTest
    Possible Values: True , false
.OUTPUTS
    None
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string] $ProxyAccountName,    
    [bool] $IsTest = $false
  )

function ProvideAccessToAccount {
	Write-Verbose $("proxyAccount is: " + $ProxyAccountName) -Verbose	
    $drives = Get-PSDrive -PSProvider FileSystem

    Write-Verbose "--------------------------------------------------" -Verbose
    Write-Verbose "Granting permissions to Drvie -> $($path)" -Verbose
    Write-Verbose "--------------------------------------------------" -Verbose
 
    foreach($drive in $drives)
    {        
        $path = $drive.Root
        if ($path -eq 'A:\' -or $path -eq 'C:\' -or $path -eq 'D:\')
        {
            Continue
        }
        
        if(Test-Path -Path $path )        
        {
			$acl = Get-Acl $path
            $PermissionType = $ProxyAccountName , 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
            $AccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $PermissionType

            $acl.SetAccessRule($AccessRule)
            $acl | Set-Acl -Path $path
            Write-Verbose "Access to Path: $($path) for $($ProxyAccountName) provided successfully." -Verbose

            $inheritance = Get-Acl -path $path
            $inheritance.SetAccessRuleProtection($false,$true)
            set-acl -path $path -aclobject $inheritance                   
            Write-Verbose "On folder path '$($path)' 'Enable Inheritance' is now set." -Verbose
								

			foreach($_ in (Get-ChildItem $path -recurse -Filter '*standby*')){
			 
				Write-Verbose "------------------ " -Verbose
				Write-Verbose "file path : $($_.fullname) " -Verbose
								
				Write-Verbose "Before ACL Permissions granted:  " -Verbose
				Get-Acl $_.fullname | Select-Object accesstostring | Format-List
			 
				$inheritance = Get-Acl -path $_.fullname
				$inheritance.SetAccessRuleProtection($false,$true)
				set-acl -path $_.fullname -aclobject $inheritance                   
				Write-Verbose "File '$($_.fullname)' is now set 'Enable Inheritance'" -Verbose
			 
				## Grant full control to proxy account at file level as well.
				$fileAcl = Get-Acl -Path $_.fullname
				$fileSystemAccessRuleArgumentList = $ProxyAccountName, "FullControl", "Allow"
				$fileSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $fileSystemAccessRuleArgumentList
								
				# # Apply rule
				$fileAcl.SetAccessRule($fileSystemAccessRule)
				Set-Acl -Path $_.fullname -AclObject $fileAcl
								
				Write-Verbose "After ACL Permissions granted:  " -Verbose
				Get-Acl $_.fullname | Select-Object accesstostring | Format-List
			}
		}
        else{
            Write-Verbose "Path $($path) not found in Server: $($env:ComputerName)"
        }

		#Assign permissions on SMB shares
		$smbs = get-smbshare		
        $excludedListOfDrivesSMB = @('A:\','C:\','D:\')
        Write-Verbose "Exclusion list of drives for SMB shares: $($excludedListOfDrivesSMB)" -Verbose
		
		foreach($smb in $smbs)
		{			
			Write-Verbose $smb -Verbose
			if($smb -and $smb.Path -ne "" -and $smb.Path.Length -gt 2 -and $excludedListOfDrivesSMB -notcontains $smb.Path.Substring(0,3))
			{
                if((Test-Path $smb.Path) -and ($smb.Name -notmatch "\?") -and ($smb.Name -notmatch "\$"))
                {
				    Write-Verbose "SMB Name:$($smb.Name) , Path: $($smb.Path)" -Verbose
				    #Grant SMB Access
				    Grant-SmbShareAccess -Name $smb.Name -AccountName $ProxyAccountName -AccessRight Full -Force

				    #Grant Security access on the paths
				    $acl = (Get-Item $smb.Path).GetAccessControl('Access')
				    $PermissionType = $ProxyAccountName , 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
				    $AccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $PermissionType
				    $acl.SetAccessRule($AccessRule)
				    $acl | Set-Acl -Path $smb.Path
				    Write-Verbose "Access to Path: $($smb.Path) for $($ProxyAccountName) provided successfully." -Verbose
				    $inheritance = Get-Acl -path $smb.Path
				    $inheritance.SetAccessRuleProtection($false,$true)
				    set-acl -path $smb.Path -aclobject $inheritance
				    Write-Verbose "On folder path '$($smb.Path)' 'Enable Inheritance' is now set." -Verbose
                }
			}
		}        
    }
}

    Write-Verbose "Running script for machine: $($env:ComputerName). " -Verbose
    ProvideAccessToAccount
	Write-Verbose "Comleted - script for machine: $($env:ComputerName). " -Verbose				