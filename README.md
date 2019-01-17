Target Technologies:

Windows Server 2008R2, Windows Server 2012R2, Windows Server 2016, Windows Server 2019, Windows 10

Updates and such

    - 01/16/2019: Version 1.0 release

What does the tool do?

The tool uses the dbatools module and some creative SQL scripting to pull the logons from the primary and replicate based on last password change date, role or configuration changes. The script performs the following steps:

    - Pulls all the user accounts (SQL Users, Domain Users, domain groups) from the source and checks changes to properties along with the Password Last Changed Date property.
        - If the config of the user/group has changed (SQL roles, properties), the changes are synced to the user account on the destination.
        - If the password itself changes on the source, the user account is dropped completely from the destination and re-copied (including SID) from the source.
            - The script checks for only passwords that have changed within the last 24 hours. This can be changed in the script itself if need be.
        - If the user account does not exist on the destination, the user account is copied (including SID) from the source.
    - The job itself will generate an output log to script's logfile directory (this folder will be created in the same location as the script). By default, the script will only keep the last 15 days of log files.
    = This script, by default, only allows for one way replication between two node in an AOAG. To replicate to other secondary replicas, additional jobs with separate parameters would be needed. For example:
        - Job1: Replicate from Primary to Secondary
        - Job2: Replicate from Primary to DR

Requirements, Modules and Includes

The script requires the following pre-reqs:

    - PowerShell v4


How to use the tool

 
srcDBInstance - string REQUIRED: The source SQL instance name. (i.e. SRCSERVER\SRCINSTANCE)
destDBInstance - string REQUIRED: The destination SQL instance name (i.e. DESTSERVER\DESTINSTANCE)
DomainCredXMLFile - string Path to the encrypted XML file that stores credentials. This is needed if you are trying to schedule this to run as a job.
agName - string REQUIRED: The AlwaysOn Availability Group Listener name.
RunSilent - switch Prevents any dialog boxes from being prompted. Forces a run with the logged on session credentials.
DomainCredentials - credential The actual credential object returned from the Get-Credential cmdlet.

 

    Some notes:
        - The srcDNInstance, destDBInstance and agName parameters are mandatory.
        - If neither the DomainCredXMLFile nor the DomainCredentials parameter is specified, and if the RunSilent parameter is not passed, you will be prompted with a Get-Credential dialog box.
        - When creating the scheduled task, be sure to create it on each node of the AOAG. The script will automatically detect if it is running on a secondary node and exit without doing anything. - In the event of a failover, the script running on the secondary node will automatically start replicating changes once the secondary becomes the primary.
    
	- Example command line for running once. This script will specify the source instance, destination instance and AG name, prompting the end user for domain credentials before continuing. Note: If you select no in the pop up to specify a log on credential, the script will use the logged on session credentials.
        PS> .\SQL_AG_Synce2.ps1 -srcDBInstance SERVER1\INSTANCE1 -dstDBInstance DSTSERVER\Instance2 -agName AGList1
    
	- Saving credentials for future use. In order to run the script as a scheduled task, we need to save the credentials as an exported XML file. Do not save this to the credential file to the script’s root directory. Let’s start by creating our XML file:
        PS> Get-Credential | Export-Clixml -Path domainCred.xml
			- Ensure that the files have been created. You can open these XML files in your favorite editor to view the contents. Note that the password is stored as an encrypted string. This string is encrypted using Microsoft's DPAPI method.(You can read more about DPAPI here.)
				- Note that the credential files created are tied to the user account creating them. For example, if you create the credential files as Domain\UserA, you will not be able to run the script as Domain\UserB while passing the previously created credential files.
    
	- We can configure the task to run via Task Scheduler or as a SQL Agent job. Both steps are similar in setup. You can use the included SQLLoginReplication.bat file to make life easier. Be sure to change the srcDBInstance, destDBInstance and agName parameters. Additionally, if a credential XML is required, add the -DomainCredXMLFile <PATHTOFILE> parameter to the end of the line.
    
	- The following batch file has been included to make scheduling easier. You will need to modify the parameters in the batch file to match your environment.
        - Program/Script: "C:\Scripts\SQL AG Sync\SQLLoginReplication.bat"
			- Note: If you need to specify the DomainCredXMLFile paramater, you will need to specify this in the batch file by appending the path to the XML file to the list of arguments.
        
    
    - Verify your results in your target logfiles directory.

Troubleshooting

I've tried to include some debugging (it can and will be improved), but there should be enough there to get you started in the Debug log file. Some examples of accounts that will not be copied over:

    Local machine accounts
    NT AUTHORITY or Service accounts
    Domain accounts that are the SQL service's log on account.