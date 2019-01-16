#######################################################################################################################################
#
#
#
#    Script: SQL Server Reporting Script Include file
#    Author: Andy DeAngelis
#    Descrfiption: 
#         When adding new functions or modules for the main SQL_AG_Sync.ps1 script to use, source/import them here.
#
#
#
#````Note: Powershellv3 or higher is needed.
#######################################################################################################################################

# Import the dbatools module, which can be downloaded from dbatools.io.

Import-Module -Name "$PSScriptRoot\dbatools\dbatools.psm1" -Scope Local -PassThru

# Source the Get-SQLInstances02 function. The included Get-SQLInstance cmdlet is lacking, and it requires the SQL Cloud adapter to run.
# The SQL Cloud Adapter is primarily for Azure instances, and does not exist in the feature pack for SQL 2016.

. "$PSScriptRoot\Functions\Get-SQLInstances02.ps1"

# Include the MS Clustering functions.

. "$PSScriptRoot\Functions\Get-IsClustered.ps1"
. "$PSScriptRoot\Functions\Get-ClusterNodes.ps1"
. "$PSScriptRoot\Functions\Get-ClusterConfig.ps1"