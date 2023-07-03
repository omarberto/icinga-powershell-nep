 <#
.SYNOPSIS
    Gets a list of all tempDB rows files with size, used size and growth settings 
.DESCRIPTION
    Gets a list of all tempDB rows files with size, used size and growth settings
.FUNCTIONALITY
    Gets a list of all tempDB rows files with size, used size and growth settings
.EXAMPLE
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


function Get-IcingaNepMSSQLTempDBFreeSpace
{
   param (
        $SqlConnection              = $null,
        [string]$SqlUsername,
        [securestring]$SqlPassword,
        [string]$SqlHost            = "localhost",
        [int]$SqlPort               = 1433,
        [switch]$IntegratedSecurity = $FALSE
    );

    [bool]$NewSqlConnection = $FALSE;

    if ($null -eq $SqlConnection) {
        $SqlConnection     = Open-IcingaMSSQLConnection -Username $SqlUsername -Password $SqlPassword -Address $SqlHost -IntegratedSecurity:$IntegratedSecurity -Port $SqlPort -SqlDatabase "tempdb";
        $NewSqlConnection = $TRUE;
    }

    $Query = "SELECT 
                    name,
                    size,
                    max_size,
                    CAST(FILEPROPERTY(name, 'SPACEUSED') AS INT) AS space_used,
                    growth
                FROM sys.database_files 
                    WHERE type = 0";

    $SqlCommand              = New-IcingaMSSQLCommand -SqlConnection $SqlConnection -SqlQuery $Query;
    $Data                    = Send-IcingaMSSQLCommand -SqlCommand $SqlCommand;

    if ($NewSqlConnection -eq $TRUE) {
        Close-IcingaMSSQLConnection -SqlConnection $SqlConnection;
    }

    [array]$DatabaseFiles = @()

    foreach ($Entry in $Data) {
        #Write-Host "DATA" $Entry.name $Entry.size $Entry.max_size $Entry.space_used $Entry.growth

        [hashtable]$DatabaseFile = @{
            'Name'  = $Entry.name;
            'Size'       = $Entry.size;
            'MaxSize'        = $Entry.max_size;
            'SpaceUsed'        = $Entry.space_used;
            'Growth'             = $Entry.growth;
        };

        $DatabaseFiles += $DatabaseFile;
    }

    return $DatabaseFiles;
}
