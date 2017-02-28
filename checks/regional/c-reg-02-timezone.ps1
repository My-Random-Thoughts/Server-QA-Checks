<#
    DESCRIPTION: 
        Check that the server timezone is correct.  Default setting is "(GMT) Greenwich Mean Time : Dublin, Edinburgh, Lisbon, London"
        For Windows 2003, check is "(UTC) Dublin, Edinburgh, Lisbon, London"

    REQUIRED-INPUTS:
        TimeZoneNames - List of time zone strings to check against.  Different OS versions use different strings.

    DEFAULT-VALUES:
        TimeZoneNames = ('(UTC) Dublin, Edinburgh, Lisbon, London', '(GMT) Greenwich Mean Time : Dublin, Edinburgh, Lisbon, London', '(UTC+00:00) Dublin, Edinburgh, Lisbon, London')

    RESULTS:
        PASS:
            Server timezone set correctly
        WARNING:
        FAIL:
            Server timezone is incorrect and should be set to {string}
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-reg-02-timezone
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-reg-02-timezone'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'Select Caption FROM Win32_TimeZone'
        [string]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Caption
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($script:appSettings['TimeZoneNames'] -contains $check )
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'Server timezone set correctly'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Server timezone is incorrect and should be set to {0}' -f $script:appSettings['TimeZoneNames']
        $result.data    = $check
    }

    Return $result
}