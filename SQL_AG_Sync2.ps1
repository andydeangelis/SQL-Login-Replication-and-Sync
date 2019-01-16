<#
	.SYNOPSIS
		This script creates a job to copy and sync all logins in a 2 node Availability Group environment
		(or really, any pair of SQL Servers). User accepts all risks. Always test in a test environment first.

		The script requires the use of the dbatool module (portable version included with this package).
		More information regarding DBA tools can be found at https://dbatools.io/.
	
	.DESCRIPTION
		A description of the file.
	
	.PARAMETER srcDBInstance
		REQUIRED: The source SQL instance name.
	
	.PARAMETER destDBInstance
		REQUIRED: The destination SQL instance
	
	.PARAMETER agName
		REQUIRED: The availability group name.
	
	.PARAMETER RunSilent
		OPTIONAL: Switch parameter to not prompt for credentials. Used when scheduling as a job.
	
	.PARAMETER DomainCredXMLFile
		OPTIONAL: If running as a scheduled job, and if you need to specify a separate credential, use the Get-Credential | Export-CliXML
		to save the encrypted XML file.
	
	.PARAMETER DomainCredentials
		OPTIONAL: If you don't want to save the credential into an XML (i.e. running the script once), use the Get-Credential cmdlet
		to pass a credential object to this parameter.
		
	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2018 v5.5.150
		Created on:   	01/14/2019 11:58 AM
		Created by:   	Andy DeAngelis
		Organization:
		Filename: SQL_AG_Sync2.ps1
		===========================================================================
#>
param
(
	[Parameter(Mandatory = $true)]
	[string]$srcDBInstance,
	[Parameter(Mandatory = $true)]
	[string]$destDBInstance,
	[Parameter(Mandatory = $true)]
	[string]$agName,
	[Parameter(Mandatory = $false,
			   ValueFromPipeline = $false)]
	[switch]$RunSilent = $false,
	[Parameter(Mandatory = $false,
			   ValueFromPipeline = $true)]
	[string]$DomainCredXMLFile,
	[Parameter(Mandatory = $false,
			   ValueFromPipeline = $true)]
	[System.Management.Automation.PSCredential]$DomainCredentials
)
. $PSScriptRoot\IncludeMe.ps1

# Add the required .NET assembly for Windows Forms.
Add-Type -AssemblyName System.Windows.Forms

# Check if domain credentials are being passed.

if (-not $RunSilent)
{
	if ((-not $DomainCredentials) -and (-not $DomainCredXMLFile))
	{
		# Show the MsgBox. This is going to ask if the user needs to specify a separate Domain logon.
		$result = [System.Windows.Forms.MessageBox]::Show('Do you need to specify a separate Domain logon account?', 'Warning', 'YesNo', 'Warning')
		
		if ($result -eq 'Yes')
		{
			$domainCred = Get-Credential -Message "Please specify your domain name and password that has the rights to query WMI on the target servers."
		}
		else
		{
			Write-Warning 'No domain credentials specifed. Using currently logged on account...'
			
		}
	}
	elseif ($DomainCredentials -and (-not $DomainCredXMLFile))
	{
		$domainCred = $DomainCredentials
	}
	elseif ((-not $DomainCredentials) -and $DomainCredXMLFile)
	{
		$domainCred = Import-Clixml -Path $DomainCredXMLFile		
	}
	elseif ($DomainCredentials -and $DomainCredXMLFiles)
	{
		$domainCred = $DomainCredentials
	}
}
else
{
	Write-Host "No Domain credential file found! We will attempt to use the logged on credentials!" -ForegroundColor Red			
}

# Define the SQL Query. The query returns any users on the primary replica that have had their password changed in the last 24 hours.
$getPasswordLastChanged = "                            
                            SELECT name, LOGINPROPERTY([name], 'PasswordLastSetTime') AS 'PasswordChanged'
                            FROM sys.sql_logins
                            WHERE LOGINPROPERTY([name], 'PasswordLastSetTime') > DATEADD(dd, -1, GETDATE());
                            "

$datetime = get-date -f MM-dd-yyyy_hh.mm.ss
$ReportPath = "$PSScriptRoot\logfiles"

if (-not (Test-Path -Path $ReportPath))
{
	New-Item -Path $PSScriptRoot -Name "logfiles" -ItemType Directory
}
else
{
	$targetPath = "$ReportPath\SQLServerInfo\$datetime"
}
$logFile = "$ReportPath\DebugLogFile-$datetime.txt"
$logFilelimit = (Get-Date).AddDays(-15)

Start-Transcript -Path $logFile

if (-not $domainCred)
{
	Write-Host "Testing logged on user connectivity..." -ForegroundColor Green
	$srcConnect = Test-DbaConnection -SqlInstance $srcDBInstance
	$destConnect = Test-DbaConnection -SqlInstance $destDBInstance
	
	if ($srcConnect -and $destConnect)
	{
		Write-Host "Connected successfully using logged on credentials." -ForegroundColor Green
		$AGPrimary = Get-DbaAgReplica -SqlInstance $agName | ?{ $_.Role -eq "Primary" } | select Name, Replica, Role, SqlInstance, InstanceName, ComputerName
		
		$changedUsers = @()
		$changedUsers = Invoke-DbaQuery -SqlInstance $srcDBInstance -Query $getPasswordLastChanged
		
		if ($AGPrimary.ComputerName -eq $env:COMPUTERNAME)
		{
			
			# Run through and copy any new logins
			Copy-dbaLogin -Source $srcDBInstance -Destination $destDBInstance -ExcludeSystemLogin -Verbose
			
			# Synchronize permissions between primary and secondary node.
			Sync-DbaLoginPermission -source $srcDBInstance -Destination $destDBInstance -Verbose
			
			foreach ($user in $changedUsers)
			{
				Copy-DbaLogin -Source $srcDBInstance -Destination $destDBInstance -Login $user.Name -KillActiveConnection -Force -Verbose
			}
			$changedUsers
		}
		Else
		{
			Write-Host "Not the primary server." -ForegroundColor Red
		}
	}
	else
	{
		if (-not $srcConnect)
		{
			Write-Host "Unable to log on to Primary Replica with logged on user..." -ForegroundColor Red
		}
		if (-not $destConnect)
		{
			Write-Host "Unable to log on to Secondary Replica with logged on user..." -ForegroundColor Red
		}
	}
}

else
{
	Write-Host "Testing specified domain account connectivity..." -ForegroundColor Green
	$srcConnect = Test-DbaConnection -SqlInstance $srcDBInstance -SqlCredential $domainCred
	$destConnect = Test-DbaConnection -SqlInstance $destDBInstance -SqlCredential $domainCred
	
	if ($srcConnect -and $destConnect)
	{
		Write-Host "Connected successfully using specified domain credentials." -ForegroundColor Green
		$AGPrimary = Get-DbaAgReplica -SqlInstance $agName -SqlCredential $domainCred | ?{ $_.Role -eq "Primary" } | select Name, Replica, Role, SqlInstance, InstanceName, ComputerName
		
		$changedUsers = @()
		$changedUsers = Invoke-DbaQuery -SqlInstance $srcDBInstance -Query $getPasswordLastChanged -SqlCredential $domainCred
		
		if ($AGPrimary.ComputerName -eq $env:COMPUTERNAME)
		{
			
			# Run through and copy any new logins
			Copy-dbaLogin -Source $srcDBInstance -Destination $destDBInstance -SourceSqlCredential $domainCred -DestinationSqlCredential $domainCred -ExcludeSystemLogin -Verbose
			
			# Synchronize permissions between primary and secondary node.
			Sync-DbaLoginPermission -source $srcDBInstance -Destination $destDBInstance -SourceSqlCredential $domainCred -DestinationSqlCredential $domainCred -Verbose
			
			foreach ($user in $changedUsers)
			{
				Copy-DbaLogin -Source $srcDBInstance -Destination $destDBInstance -SourceSqlCredential $domainCred -DestinationSqlCredential $domainCred -Login $user.Name -KillActiveConnection -Force -Verbose
			}
			$changedUsers
		}
		Else
		{
			Write-Host "Not the primary server." -ForegroundColor Red
		}
	}
	else
	{
		if (-not $srcConnect)
		{
			Write-Host "Unable to log on to Primary Replica with specified domain user..." -ForegroundColor Red
		}
		if (-not $destConnect)
		{
			Write-Host "Unable to log on to Secondary Replica with specified domain  user..." -ForegroundColor Red
		}
	}
}
Write-Host "Removing log files older than 15 days..."

Get-ChildItem -Path $ReportPath -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $logFilelimit } | Remove-Item -Force

Stop-Transcript