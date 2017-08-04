<#
    DESCRIPTION: 
        Check System Event Log and ensure no errors are present in the last x days.  If found, will return the latest y entries

    REQUIRED-INPUTS:
        EventLogMaxSize       - Maximum size in MB of this event log (default is 16)
        EventLogRetentionType - "Overwrite|Archive|Manual" - When the maximum log size is reached
        GetLatestEntriesAge   - Return all entries for this number of days|Integer
        GetLatestEntriesCount - Return this number of entries|Integer

    DEFAULT-VALUES:
        EventLogMaxSize       = '16'
        EventLogRetentionType = 'Overwrite'
        GetLatestEntriesAge   = '14'
        GetLatestEntriesCount = '15'

    DEFAULT-STATE:
        Enabled

    INPUT-DESCRIPTION:
        Overwrite: Overwrite as needed (oldest first)
        Archive: Archive log when full
        Manual: Do not overwrite (clear manually)

    RESULTS:
        PASS:
            No errors found in system event log
        WARNING:
            Errors were found in the system event log
        FAIL:
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sys-05-system-event-log
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-05-system-event-log'

    #... CHECK STARTS HERE ...#

    Try
    {
        # Get size and retention
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Services\EventLog\System")
        If ($regKey)
        {
            [int64] $keyValMS = $regKey.GetValue('MaxSize')               # Size in bytes
            [string]$keyValR1 = $regKey.GetValue('Retention')             # Either '0' or '-1'
            [string]$keyValR2 = $regKey.GetValue('AutoBackupLogFiles')    # Either '0' or  '1'
            If ([string]::IsNullOrEmpty($keyValR1) -eq $True) { $keyValR1 = '0' }
            If ([string]::IsNullOrEmpty($keyValR2) -eq $True) { $keyValR2 = '0' }
        }
        Try { $regKey.Close() } Catch { }
        $reg.Close()

        # Get log entries
        If ($PSVersionTable.PSVersion.Major -ge 4)
        {
            [double]$timeOffSet = ($script:appSettings['GetLatestEntriesAge'] -as [int]) * 60 * 60 * 24 * 1000    # Convert 'days' into 'miliseconds'
            [xml]   $xml        = '<QueryList><Query Id="0" Path="System"     ><Select Path="System"     >*[System[(Level=1 or Level=2) and TimeCreated[timediff(@SystemTime) &lt;= {0}]]]</Select></Query></QueryList>' -f $timeOffSet
            [object]$check      = Get-WinEvent -ComputerName $serverName -MaxEvents $script:appSettings['GetLatestEntriesCount'] -FilterXml $xml -ErrorAction SilentlyContinue | Select LevelDisplayName, TimeCreated, Id, ProviderName, Message
        }
        Else
        {
            $check = Get-EventLog -ComputerName $serverName -LogName System      -EntryType Error -Newest $script:appSettings['GetLatestEntriesCount'] -After (Get-Date).AddDays(-($script:appSettings['GetLatestEntriesAge'])) -ErrorAction SilentlyContinue
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    $result.message = ''
    $result.data    = ''

    # Check max size
    $keyValMS = ($keyValMS / (1024*1024))    # Convert B to MB
    If ($keyValMS -ne $script:appSettings['EventLogMaxSize'])
    {
        $result.result   = $script:lang['Fail']
        $result.message += 'Event log max size is not set correctly,#'
        $result.data    += ('Current Max Size: {0},#' -f $keyValMS)
    }

    # Check retension type
    Switch ($script:appSettings['EventLogRetentionType'])
    {                 #       Retention                   AutoBackupLogFiles
        'Overwrite' { [string]$checkValR1 =  '0'; [string]$checkValR2 = '0'; Break }
        'Archive'   { [string]$checkValR1 = '-1'; [string]$checkValR2 = '1'; Break }
        'Manual'    { [string]$checkValR1 = '-1'; [string]$checkValR2 = '0'; Break }
        Default     { Break }
    }

    If (($keyValR1 -ne $checkValR1) -or ($keyValR2 -ne $checkValR2))
    {
        [string]$currRetention = 'Unknown'
        If ($keyValR1 -eq 0) { $currRetention = 'Overwrite' } Else { If ($keyValR2 -eq 0) { $currRetention = 'Manual' } Else { $currRetention = 'Archive' } }
        $result.result   = $script:lang['Fail']
        $result.message += 'Retention method is not set correctly,#'
        $result.data    += ('Current method: {0},#' -f $currRetention)
    }

    # Check event logs
    If ($check.Length -gt 0)
    {
        If ((Test-Path -Path ('{0}EventLogs' -f $resultPath)) -eq $false) { Try { New-Item -Path ('{0}EventLogs' -f $resultPath) -ItemType Directory -Force | Out-Null } Catch {} }
        [string]$outFile = '{0}EventLogs\{1}-Error-Events-System.csv' -f $resultPath, $serverName.ToUpper()
        $check | Export-Csv $outFile -NoTypeInformation

        $result.message += 'Errors were found in the system event log'
        $result.data    += (Split-Path -Path $outFile -Leaf)
    }

    # Pass or fail check
    If ($result.message -ne '')
    {
        $result.result   = $script:lang['Fail']
    }
    Else
    {
        $result.result   = $script:lang['Pass']
        $result.message += 'No errors found in system event log or its configuration'
    }
    
    Return $result
}
