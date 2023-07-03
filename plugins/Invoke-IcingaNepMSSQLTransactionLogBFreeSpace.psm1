 <#
.SYNOPSIS
    Checks available space for tempDB files
.DESCRIPTION
    Checks available space for tempDB files
.FUNCTIONALITY
    Checks available space for tempDB files
.EXAMPLE
    PS> Invoke-IcingaNepMSSQLTempDBFreeSpace -IntegratedSecurity -AvailablePercentageWarning 10 -AvailablePercentageCritical 5
        WARNING] MSSQL TempDB Free Space [WARNING] Using Percentage Thresholds leads meaningless warnings and errors with files with no size limits: use fixed threshol instead (True)
        \_ [WARNING] Using Percentage Thresholds leads meaningless warnings and errors with files with no size limits: use fixed threshold instead: True is matching thrshold True
        | 'temp2'=99.9%;;;0;100 'temp3'=99.88%;;;0;100 'temp4'=99.89%;;;0;100 'tempdev'=99.63%;;;0;100
            
.PARAMETER SizeMBWarning
    Warning threshold in MB for files Size, in case of fixed file size (autogrowth not active) calculate suitable values
.PARAMETER SizeMBCritical
    Critical threshold in MB for files Size, in case of fixed file size (autogrowth not active) calculate suitable values
.PARAMETER AvailablePercentageWarning
    Warning threshold in percentage for files Size, do not use if files can grow indefintely: use SizeMBWarning
.PARAMETER AvailablePercentageCritical
    Critical threshold in percentage for files Size, do not use if files can grow indefintely: use SizeMBCritical

.PARAMETER SqlDatabase
    database name, default value is master
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

    - very uncommon to find more than one log file, but still possible
#>

function Invoke-IcingaNepMSSQLTransactionLogBFreeSpace()
{
    param (
        [ValidateRange(0,[int]::MaxValue)]
        $SizeMBWarning = $null,
        [ValidateRange(0,[int]::MaxValue)]
        $SizeMBCritical = $null,
        [ValidateRange(0, 100)]
        $AvailablePercentageWarning = $null,
        [ValidateRange(0, 100)]
        $AvailablePercentageCritical = $null,
        [string]$SqlDatabase = "master",
        [string]$SqlUsername,
        [securestring]$SqlPassword,
        [string]$SqlHost            = "localhost",
        [int]$SqlPort               = 1433,
        [switch]$IntegratedSecurity = $FALSE,
        [switch]$NoPerfData,
        [ValidateSet(0, 1, 2, 3)]
        [int]$Verbosity             = 0
    );
    
    if(($SizeMBWarning -eq $null) -and ($SizeMBCritical -ne $null)) {
        $SizeMBWarning = $SizeMBCritical
    }
    if(($SizeMBCritical -eq $null) -and ($SizeMBWarning -ne $null)) {
        $SizeMBCritical = $SizeMBWarning
    }
    if ($null -ne $SizeMBWarning -and $SizeMBWarning -gt $SizeMBCritical) {
        throw "Warning & Critical thresholds not valid"
    }

    if(($AvailablePercentageWarning -eq $null) -and ($AvailablePercentageCritical -ne $null)) {
        $AvailablePercentageWarning = $AvailablePercentageCritical
    }
    if(($AvailablePercentageCritical -eq $null) -and ($AvailablePercentageWarning -ne $null)) {
        $AvailablePercentageCritical = $AvailablePercentageWarning
    }
    if ($null -ne $AvailablePercentageWarning -and $AvailablePercentageWarning -lt $AvailablePercentageCritical) {
        throw "Warning & Critical thresholds not valid"
    }
    
    if(($SizeMBCritical -ne $null) -and ($AvailablePercentageCritical -ne $null)) {
        throw "SizeMB and AvailablePercentage thresholds cannot be used together"
    }

    # Connect to MSSQL
    $SqlConnection     = Open-IcingaMSSQLConnection -Username $SqlUsername -Password $SqlPassword -Address $SqlHost -IntegratedSecurity:$IntegratedSecurity -Port $SqlPort -SqlDatabase $SqlDatabase;
    
    $DatabaseFiles             = Get-IcingaNepMSSQLTransactionLogBFreeSpace -SqlConnection $SqlConnection 

    Close-IcingaMSSQLConnection -SqlConnection $SqlConnection;

    $TotalSizeMB = ($DatabaseFiles|Foreach-Object Size|Measure-Object -Sum).Sum/128.
    $UnlimitedSizeCount = ($DatabaseFiles|Where-Object { $_.MaxSize -lt 0 }).Count
    $TotalMaxSizeMB = ($DatabaseFiles|Where-Object { $_.MaxSize -ge 0 }|Foreach-Object MaxSize|Measure-Object -Sum).Sum/128.
    $TotalSpaceUsedMB = ($DatabaseFiles|Foreach-Object SpaceUsed|Measure-Object -Sum).Sum/128.
    $ActiveGrowthCount = ($DatabaseFiles|Where-Object { $_.Growth -gt 0 }).Count
    
    #Creates root Icinga Check Package
    $RootCheckPackage = New-IcingaCheckPackage -Name "MSSQL $SqlDatabase Transaction Log Free Space"  -OperatorAnd -Verbose $Verbosity
    $DetailsCheckPackage = New-IcingaCheckPackage -Name 'File Free Space Details'  -OperatorNo -Verbose $Verbosity
    
    if($SizeMBCritical -eq $null) {
        $SingleFileSizeMBCritical = 0
    } else {
        $SingleFileSizeMBCritical = $SizeMBCritical / $DatabaseFiles.Length
    }

    $FileIndex = 1
    $DatabaseFiles|Foreach-Object {
        $AvailablePercentage = -1.

        if ($_.Growth -eq 0) {
            #fixed size files
            $AvailablePercentage = [math]::Round(100. * ($_.Size - $_.SpaceUsed) / $_.Size, 2);
        } else {
            if ($_.MaxSize -lt 0) {
                #files can growth with no limit
                if($SingleFileSizeMBCritical -eq 0) {
                    $AvailablePercentage = [math]::Round(100. * ($_.Size - $_.SpaceUsed) / $_.Size, 2);
                } else {
                    $AvailablePercentage = [math]::Round(100. * ($SingleFileSizeMBCritical - $_.SpaceUsed / 128.) / $SingleFileSizeMBCritical, 2);
                }
            }
            else {
                #files can growth up to a fixed size
                $AvailablePercentage = [math]::Round(100. * ($_.MaxSize - $_.SpaceUsed) / $_.MaxSize, 2);
            }
        }

        if ($AvailablePercentage -lt 0.) {
            $AvailablePercentage = 0.
        }
        $DetailsCheckPackage.AddCheck(
            (New-IcingaCheck -Name ([string]::Format('{0}', $_.Name)) -Unit '%' -Value $AvailablePercentage -MetricName ([string]::Format('{0}', $_.Name)))
        );

        $FileIndex++;
    }
    $RootCheckPackage.AddCheck($DetailsCheckPackage);
    
    if ($ActiveGrowthCount -eq 0) {
        #fixed size files

        #only for anomaly detection (should never happen)
        if ($TotalSizeMB -gt $TotalMaxSizeMB) {
            #set error 
            $RootCheckPackage.AddCheck(
                (
                    New-IcingaCheck -Name "TotalSizeMB ($TotalSizeMB) greater than TotalMaxSizeMB ($TotalMaxSizeMB) anomalous with fixed size files" -Value $true -NoPerfData
                ).CritIfMatch($true)
            );
        }

        if($SizeMBCritical -ne $null) {
            if($SizeMBCritical -gt $TotalSizeMB) {
                #set error (threshold not valid)
                $RootCheckPackage.AddCheck(
                    (
                        New-IcingaCheck -Name "Threshold SizeMBCritical ($SizeMBCritical) greater than TotalSizeMB ($TotalSizeMB) not valid with fixed size files" -Value $true -NoPerfData
                    ).CritIfMatch($true)
                );

                $AvailablePercentageWarning = $AvailablePercentageCritical = 100.;
            } else {
                
                $AvailablePercentageWarning = 100. * ($TotalSizeMB - $SizeMBWarning) / $TotalSizeMB;
                $AvailablePercentageCritical = 100. * ($TotalSizeMB - $SizeMBCritical) / $TotalSizeMB;
            }
        }

        $TotalAvailablePercentage = 100. * ($TotalSizeMB - $TotalSpaceUsedMB) / $TotalSizeMB;
        #TODO verificare che omettendo MetricName la metrica non ci sia
        $RootCheckPackage.AddCheck(
            (
                New-IcingaCheck -Name 'Available Percentage' -Unit '%' -Value $TotalAvailablePercentage -NoPerfData
            ).WarnIfLowerThan($AvailablePercentageWarning).CritIfLowerThan($AvailablePercentageCritical)
        );

    } else { 
        if ($UnlimitedSizeCount -gt 0) {
            #files can growth with no limit

            if($SizeMBCritical -ne $null) {
                $AvailablePercentageWarning = 100. * ($SizeMBCritical - $SizeMBWarning) / $SizeMBCritical;
                $AvailablePercentageCritical = 0.;
            } else {
                # add text explaining continuous warning
                #TODO capire come fare // al momento do warn sempre
                $RootCheckPackage.AddCheck(
                    (
                        New-IcingaCheck -Name "Using Percentage Thresholds leads meaningless warnings and errors with files with no size limits: use fixed threshold instead" -Value $true -NoPerfData
                    ).WarnIfMatch($true)
                );

                $SizeMBCritical = $TotalSizeMB
            }
            
            $TotalAvailablePercentage = 100. * ($SizeMBCritical - $TotalSpaceUsedMB) / $SizeMBCritical;
            $RootCheckPackage.AddCheck(
                (
                    New-IcingaCheck -Name 'Available Percentage' -Unit '%' -Value $TotalAvailablePercentage -NoPerfData
                ).WarnIfLowerThan($AvailablePercentageWarning).CritIfLowerThan($AvailablePercentageCritical)
            );

        } else {
            #files can growth up to a fixed size

            if($SizeMBCritical -ne $null) {
                if($SizeMBCritical -gt $TotalMaxSizeMB) {
                    #set error (threshold not valid)
                    $RootCheckPackage.AddCheck(
                        (
                            New-IcingaCheck -Name "Threshold SizeMBCritical ($SizeMBCritical) greater than max possible size ($TotalMaxSizeMB)" -Value $true -NoPerfData
                        ).CritIfMatch($true)
                    );
    
                    $AvailablePercentageWarning = $AvailablePercentageCritical = 100.;
                } else {
                    
                    $AvailablePercentageWarning = 100. * ($TotalMaxSizeMB - $SizeMBWarning) / $TotalMaxSizeMB;
                    $AvailablePercentageCritical = 100. * ($TotalMaxSizeMB - $SizeMBCritical) / $TotalMaxSizeMB;
                }
            }

            $TotalAvailablePercentage = 100. * ($TotalMaxSizeMB - $TotalSpaceUsedMB) / $TotalMaxSizeMB;
            $RootCheckPackage.AddCheck(
                (
                    New-IcingaCheck -Name 'Available Percentage' -Unit '%' -Value $TotalAvailablePercentage -NoPerfData
                ).WarnIfLowerThan($AvailablePercentageWarning).CritIfLowerThan($AvailablePercentageCritical)
            );
        }   
    }

    #Creates the Icinga output
    return (New-IcingaCheckResult -Check $RootCheckPackage -NoPerfData $NoPerfData -Compile)
}