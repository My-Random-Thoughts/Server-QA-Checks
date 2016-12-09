<#
    DESCRIPTION: 
        Check Application Event Log and ensure no errors or warnings are present in the last 14 days.  If found, will return the latest 15 entries



    PASS:    No errors found in application event log
    WARNING: Errors were found in the application event log
    FAIL:
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sys-06-application-event-log
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-06-application-event-log'

    #... CHECK STARTS HERE ...#

    Try
    {
        If ($PSVersionTable.PSVersion.Major -ge 4)
        {
            [double]$timeOffSet = ($script:appSettings['GetLatestEntriesAge'] -as [int]) * 60 * 60 * 24 * 1000    # Convert 'days' into 'miliseconds'
            [xml]   $xml        = '<QueryList><Query Id="0" Path="Application"><Select Path="Application">*[System[(Level=1 or Level=2) and TimeCreated[timediff(@SystemTime) &lt;= {0}]]]</Select></Query></QueryList>' -f $timeOffSet
            [object]$check      = Get-WinEvent -ComputerName $serverName -MaxEvents $script:appSettings['GetLatestEntriesCount'] -FilterXml $xml -ErrorAction SilentlyContinue | Select LevelDisplayName, TimeCreated, Id, ProviderName, Message
        }
        Else
        {
            $check = Get-EventLog -ComputerName $serverName -LogName Application -EntryType Error -Newest $script:appSettings['GetLatestEntriesCount'] -After (Get-Date).AddDays(-($script:appSettings['GetLatestEntriesAge'])) -ErrorAction SilentlyContinue
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check.Length -gt 0)
    {
        If ((Test-Path -Path ('{0}EventLogs' -f $resultPath)) -eq $false) { Try { New-Item -Path ('{0}EventLogs' -f $resultPath) -ItemType Directory -Force | Out-Null } Catch {} }
        [string]$outFile = '{0}EventLogs\{1}-Error-Events-Application.csv' -f $resultPath, $serverName.ToUpper()
        $check | Export-Csv $outFile -NoTypeInformation

        $result.result  = $script:lang['Warning']
        $result.message = 'Errors were found in the application event log'
        $result.data    = (Split-Path -Path $outFile -Leaf)
    }
    Else
    {
        $result.result  = $script:lang['Pass']        
        $result.message = 'No errors found in application event log'
    }
    
    Return $result
}