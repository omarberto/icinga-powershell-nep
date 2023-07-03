 <#
.SYNOPSIS
    Checks if there are SQL Agent Jobs which duration is abobe specified duration in seconds, filtering by name if specified 
.DESCRIPTION
    Checks if there are SQL Agent Jobs which duration is abobe specified duration in seconds, filtering by name if specified 
.FUNCTIONALITY
    Gets a list of all running SQL Agent Jobs and duration in seconds, filtering by name if specified
.EXAMPLE
    PS> Invoke-IcingaNepMSSQLAgentRunningJobs -JobName 'SQLJObTest1' -SecondsDurationWarning 2400 -SecondsDurationCritical 3600
    [OK] MSSQL Agent Running Job SQLJObTest1 Status
    | 'duration'=17s;2400;3600
    
.PARAMETER JobName
    Use this value for filter a specific Job
.PARAMETER SecondsDurationWarning
    Warning threshold for job duration
.PARAMETER SecondsDurationCritical
    Critical threshold for job duration
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
.PARAMETER NoPerfData
    Disables the performance data output of this plugin
.PARAMETER Verbosity
    Changes the behavior of the plugin output which check states are printed:
    0 (default): Only service checks/packages with state not OK will be printed
    1: Only services with not OK will be printed including OK checks of affected check packages including Package config
    2: Everything will be printed regardless of the check state
    3: Identical to Verbose 2, but prints in addition the check package configuration e.g (All must be [OK])
.NOTES
    Wrote 07/03/2023 by Omar Bertò
#>

function Invoke-IcingaNepMSSQLAgentRunningJobs()
{
    param (
        [string]$JobName = $null,
        [ValidateRange(0,[int]::MaxValue)]
        $SecondsDurationWarning = $null,
        [ValidateRange(0,[int]::MaxValue)]
        $SecondsDurationCritical = $null,

        [string]$SqlUsername,
        [securestring]$SqlPassword,
        [string]$SqlHost            = "localhost",
        [int]$SqlPort               = 1433,
        [switch]$IntegratedSecurity = $FALSE,
        [switch]$NoPerfData,
        [ValidateSet(0, 1, 2, 3)]
        [int]$Verbosity             = 0
    );
    
    # Connect to MSSQL
    $SqlConnection     = Open-IcingaMSSQLConnection -Username $SqlUsername -Password $SqlPassword -Address $SqlHost -IntegratedSecurity:$IntegratedSecurity -Port $SqlPort -SqlDatabase "msdb";
    
    $RunningJobs       = Get-IcingaNepMSSQLAgentRunningJobs -SqlConnection $SqlConnection -JobName $JobName

    Close-IcingaMSSQLConnection -SqlConnection $SqlConnection;

    $RootCheckPackage

    if ([string]::IsNullOrEmpty($JobName)) {

        #Creates root Icinga Check Package
        $RootCheckPackage = New-IcingaCheckPackage -Name 'MSSQL Agent Running Jobs Status'  -OperatorAnd -Verbose $Verbosity

        if($RunningJobs.Lenght -gt 0) {
            $Seconds = ($RunningJobs|Foreach-Object Seconds|Measure-Object -Max).Maximum
        } else {
            $Seconds = 0
        }
        $RootCheckPackage.AddCheck(
            (
                New-IcingaCheck -Name "duration" -Value $Seconds -Unit 's'
            ).WarnIfGreaterEqualThan($SecondsDurationWarning).CritIfGreaterEqualThan($SecondsDurationCritical)
        );

    } else {

        #Creates root Icinga Check Package
        $RootCheckPackage = New-IcingaCheckPackage -Name ('MSSQL Agent Running Job ' + $JobName + ' Status')  -OperatorAnd -Verbose $Verbosity
        
        if($RunningJobs.Lenght -gt 0) {
            $Seconds = ($RunningJobs|Foreach-Object Seconds|Measure-Object -Max).Maximum
        } else {
            $Seconds = 0
        }

        $RootCheckPackage.AddCheck(
            (
                New-IcingaCheck -Name "duration" -Value $Seconds -Unit 's'
            ).WarnIfGreaterEqualThan($SecondsDurationWarning).CritIfGreaterEqualThan($SecondsDurationCritical)
        );
    }

    #Creates the Icinga output
    return (New-IcingaCheckResult -Check $RootCheckPackage -NoPerfData $NoPerfData -Compile)
}