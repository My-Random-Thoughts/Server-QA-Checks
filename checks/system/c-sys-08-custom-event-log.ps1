<#
    DESCRIPTION:
        Check a custom event log and ensure no errors are present in the last x days.  If found, will return the latest y entries.
        To get the exact name of the log, view its properties and see the "Exact Name" entry.

    REQUIRED-INPUTS:
        EventLogName          - List of names of the event logs to search. Examples include: Directory Service, DNS Server, Windows PowerShell.
        GetLatestEntriesAge   - Return all entries for this number of days|Integer
        GetLatestEntriesCount - Return this number of entries|Integer

    DEFAULT-VALUES:
        EventLogName          = ('')
        GetLatestEntriesAge   = '14'
        GetLatestEntriesCount = '15'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            No errors found in the selected event logs
        WARNING:
            Errors were found in the following event logs
        FAIL:
            Errors were found in the following event logs
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sys-08-custom-event-log
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-08-custom-event-log'

    #... CHECK STARTS HERE ...#

    If ($script:appSettings['EventLogName'].Count -eq 0)
    {
        $result.result   = $script:lang['Not-Applicable']
        $result.message += 'No event log specified'
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'Errors were found in the following event logs,#'
        $result.data    = 'Event log error details:,#'

        [object]$eventLogs = @{}
        ForEach ($logName In $script:appSettings['EventLogName'])
        {
            If (($logName -ne 'Application') -and ($logName -ne 'System'))
            {
                Try
                {
                    If ($PSVersionTable.PSVersion.Major -ge 4)
                    {
                        [double]$timeOffSet    = ($script:appSettings['GetLatestEntriesAge'] -as [int]) * 60 * 60 * 24 * 1000    # Convert 'days' into 'miliseconds'
                        [xml]   $xml           = '<QueryList><Query Id="0" Path="{1}"><Select Path="{1}">*[System[(Level=1 or Level=2) and TimeCreated[timediff(@SystemTime) &lt;={0}]]]</Select></Query></QueryList>' -f $timeOffSet, $logName
                        $eventLogs["$logName"] = Get-WinEvent -ComputerName $serverName -MaxEvents $script:appSettings['GetLatestEntriesCount'] -FilterXml $xml -ErrorAction SilentlyContinue | Select LevelDisplayName, TimeCreated, Id, ProviderName, Message
                    }
                    Else
                    {
                        $eventLogs["$logName"] = Get-EventLog -ComputerName $serverName -LogName $logName -EntryType Error -Newest $script:appSettings['GetLatestEntriesCount'] -After (Get-Date).AddDays(-($script:appSettings['GetLatestEntriesAge'])) -ErrorAction SilentlyContinue
                    }
                }
                Catch
                {
                    # Event log name is incorrect
                    $result.result   = $script:lang['Warning']
                    $result.message += "$logName,#"
                    $result.data    += 'Invalid Log Name,#'
                }
            }

            # Check event log
            If ($eventLogs["$logName"].Length -gt 0)
            {
                If ((Test-Path -Path ('{0}EventLogs' -f $resultPath)) -eq $false) { Try { New-Item -Path ('{0}EventLogs' -f $resultPath) -ItemType Directory -Force | Out-Null } Catch {} }
                [string]$outFile = '{0}EventLogs\{1}-Error-Events-Custom-{2}.csv' -f $resultPath, $serverName.ToUpper(), $logName.Replace(' ', '')
                $eventLogs["$logName"] | Export-Csv $outFile -NoTypeInformation

                $result.result   = $script:lang['Fail']
                $result.message += "$logName,#"
                $result.data    += (Split-Path -Path $outFile -Leaf) + ',#'
            }
        }

        # Pass or fail check
        If ($result.result -eq $script:lang['Pass'])
        {
            $result.message = 'No errors found in the selected event logs'
            $result.data    = ''
        }
    }

    Return $result
}
