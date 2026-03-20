<#
.SYNOPSIS
    This post scripts applies for enabling DBmail SQL VM's
.DESCRIPTION
    After the VMs are created, this script will setup DBMail
.PARAMETER AccountName
    This is used for creating account alias for DBMail
.PARAMETER EmailAddr
	This is used for creating email id for DBMail
.PARAMETER ReplyTo
    This is used for creating reply to for DBMail
.PARAMETER MailServerName
    SMTP server address
.PARAMETER PortNo
    Port number for DB mail
.PARAMETER Password
    Password for smtp server
.PARAMETER UserName
    UserName for smtp server
#>

param (
    $AccountName,
	$EmailAddr,
	$ReplyTo,
    $MailServerName,
    $PortNo,
    $Password,
    $ProfileName,
    $UserName
)

function Add-DbMail{
    param (
    $AccountName,
	$EmailAddr,
	$ReplyTo,
    $MailServerName,
    $PortNo,
    $Password,
    $ProfileName,
    $UserName,
    $SqlInstanceName
)

    $script = @"
    SET NOCOUNT ON
    IF NOT EXISTS (SELECT * FROM msdb.dbo.sysmail_account WHERE name = '$AccountName')
    BEGIN
        EXECUTE msdb.dbo.sysmail_add_account_sp
            @account_name = '$AccountName',
            @email_address = '$EmailAddr',
            @replyto_address = '$ReplyTo',
            @display_name = '$AccountName',
            @mailserver_name = '$MailServerName',
            @port = $PortNo,
            @enable_ssl = 1,
            @username = '$UserName',
            @password = '$Password';
    END
    -- Create a Database Mail Profile

    DECLARE @profile_id INT, @profile_description sysname;
    SELECT @profile_id = COALESCE(MAX(profile_id),1) FROM msdb.dbo.sysmail_profile
    SELECT @profile_description = 'Database Mail Profile for ' + @@servername 

    IF NOT EXISTS (SELECT * FROM msdb.dbo.sysmail_profile WHERE profile_id = @profile_id)
    BEGIN
        EXECUTE msdb.dbo.sysmail_add_profile_sp
            @profile_name = '$ProfileName',
            @description = 'Alerts for core tooling';
    END

    -- Add the account to the profile
    IF NOT EXISTS (SELECT * FROM msdb.dbo.sysmail_profileaccount WHERE profile_id = @profile_id)
    BEGIN
        EXECUTE msdb.dbo.sysmail_add_profileaccount_sp
            @profile_name = '$ProfileName',
            @account_name = '$AccountName',
            @sequence_number = @profile_id;
    END

    -- Grant access to the profile to the DBMailUsers role
    IF NOT EXISTS (SELECT * FROM msdb.dbo.sysmail_principalprofile WHERE profile_id = @profile_id)
    BEGIN
        EXECUTE msdb.dbo.sysmail_add_principalprofile_sp
            @profile_name = '$ProfileName',
            @principal_id = 0,
            @is_default = 1 ;
    END

    -- Enable Database Mail
    USE master;
    GO

    sp_CONFIGURE 'show advanced', 1
    GO
    RECONFIGURE
    GO
    sp_CONFIGURE 'Database Mail XPs', 1
    GO
    RECONFIGURE

    EXEC msdb.dbo.sp_set_sqlagent_properties @email_save_in_sent_folder = 0
    GO

    -- SQL Agent Properties Configuration

    EXEC msdb.dbo.sp_set_sqlagent_properties 
        @databasemail_profile = '$ProfileName'
        , @use_databasemail=1
    SET NOCOUNT OFF

"@
    Invoke-Sqlcmd -ServerInstance $SqlInstanceName -Query $script
}
function Get-SQLInstance {

    $InstanceName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -Name InstalledInstances | Select-Object -ExpandProperty InstalledInstances | Where-Object { $_ -eq 'MSSQLSERVER' }
    $InstanceFullName = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL' -Name $InstanceName | Select-Object -ExpandProperty $InstanceName;
    $ClusterName  = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$InstanceFullName\Cluster").ClusterName
    return $ClusterName
}

function Main{
    
		if ((Get-Service -Name 'ClusSvc' -ErrorAction SilentlyContinue)) {

			$ActiveNode = (Get-ClusterGroup | Where-Object { $_.Name -like "*SQL*" }).OwnerNode
			Write-Verbose "Active node name is $($ActiveNode)" -verbose
			$vmName = $env:ComputerName
	
			if ($Activenode -eq $vmName) {

				$SqlInstanceName = Get-SQLInstance
				Write-EventLog -LogName Application -Source AzureArmTemplates -EventId 1000 -EntryType Information -Message "Active Node :  $ActiveNode"
                Add-DbMail $AccountName $EmailAddr $ReplyTo $MailServerName $PortNo $Password $ProfileName $UserName $SqlInstanceName
            }
        }
        else {
		
			$vmName = $env:ComputerName
            Add-DbMail $AccountName $EmailAddr $ReplyTo $MailServerName $PortNo $Password $ProfileName $UserName $vmName
        }
}


if ($MyInvocation.InvocationName -ne '.') {
	Main
}