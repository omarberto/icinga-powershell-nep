 <#
.SYNOPSIS
    Gets a list of all running SQL Agent Jobs and duration in seconds, filtering by name if specified 
.DESCRIPTION
    Gets a list of all running SQL Agent Jobs and duration in seconds, filtering by name if specified
.FUNCTIONALITY
    Gets a list of all running SQL Agent Jobs and duration in seconds, filtering by name if specified
.EXAMPLE

.PARAMETER JobName
    Use this value for filter a specific Job
.PARAMETER SqlConnection
    Use an already existing and established SQL object for query handling. Otherwise leave it empty and use the
    authentication by username/password or integrate security
.PARAMETER SqlUsername
    The username for connecting to the MSSQL database
.PARAMETER SqlPassword
    The password for connecting to the MSSQL database as secure string
.PARAMETER SqlHost
    The IP address or FQDN to the MSSQL server to connect to
.PARAMETER SqlPort
    The port of the MSSQL server/instance to connect to with the provided credentials
.PARAMETER IntegratedSecurity
    Allows this plugin to use the credentials of the current PowerShell session inherited by
    the user the PowerShell is running with. If this is set and the user the PowerShell is
    running with can access to the MSSQL database you will not require to provide username
    and password
.INPUTS
    System.Array
.OUTPUTS
    System.Array
.LINK
    https://github.com/Fake/icinga-powershell-test
.NOTES
#>


function Get-IcingaNepMSSQLAgentRunningJobs
{
   param (
        [string]$JobName = $null,
        $SqlConnection              = $null,
        [string]$SqlUsername,
        [securestring]$SqlPassword,
        [string]$SqlHost            = "localhost",
        [int]$SqlPort               = 1433,
        [switch]$IntegratedSecurity = $FALSE
    );

    [bool]$NewSqlConnection = $FALSE;

    if ($null -eq $SqlConnection) {
        $SqlConnection     = Open-IcingaMSSQLConnection -Username $SqlUsername -Password $SqlPassword -Address $SqlHost -IntegratedSecurity:$IntegratedSecurity -Port $SqlPort -SqlDatabase "msdb";
        $NewSqlConnection = $TRUE;
    }

    $Query = "SELECT
                    sjs.name,
                    DATEDIFF(second, sja.start_execution_date,GETDATE()) AS seconds
                FROM sysjobactivity sja 
                JOIN sysjobs sjs 
                    ON sja.job_id = sjs.job_id
                WHERE sja.session_id = (SELECT MAX(session_id) FROM sysjobactivity)
                AND start_execution_date is not null
                AND stop_execution_date is null
                ";

    if (![string]::IsNullOrEmpty($JobName))
    {
        $Query += [string]::Format(" AND sjs.name = N'{0}'", $JobName) 
    }

    $SqlCommand              = New-IcingaMSSQLCommand -SqlConnection $SqlConnection -SqlQuery $Query;
    $Data                    = Send-IcingaMSSQLCommand -SqlCommand $SqlCommand;

    if ($NewSqlConnection -eq $TRUE) {
        Close-IcingaMSSQLConnection -SqlConnection $SqlConnection;
    }

    [array]$RunningJobs = @()

    foreach ($Entry in $Data) {
        [hashtable]$RunningJob = @{
            'Name'  = $Entry.name;
            'Seconds'       = $Entry.seconds;
        };

        $RunningJobs += $RunningJob;
    }

    return $RunningJobs;
}
