# SQL Login Replication and Sync

PURPOSE: This script is used to ensure logins stay replicated across SQL instances in an AlwaysOn Availability Group.

Dependent modules:

	- dbatools (portable version included with this package)
	
USE:
	
	.\SQL_AG_Sync2.ps1 -srcDBInstance SRCSERVER\SRCINSTANCE1 -destDBInstance DSTSERVER\DSTINSTANCE2 -agName AGNAME < -RunSilent -DomainCredXMLFile PATH_TO_CRED_XML -DomainCredentials (Get-Credential) >