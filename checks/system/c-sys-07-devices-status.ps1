<#
    DESCRIPTION: 
        Checks Device Manager to ensure there are no unknown devices, conflicts or errors.
        


    PASS:    No device errors found
    WARNING:
    FAIL:    Device errors found
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sys-07-devices-status
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Device Errors'
    $result.check  = 'c-sys-07-devices-status'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        # Excludes Working (0) and Disabled (22)
        [string]$query = 'SELECT Name, ConfigManagerErrorCode FROM Win32_PnPEntity WHERE NOT ConfigManagerErrorCode = 0 AND NOT ConfigManagerErrorCode = 22'
        $script:appSettings['IgnoreTheseDeviceNames'] | ForEach { $query += ' AND NOT Name = "{0}"' -f $_ }
        [array]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Name
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check.Count -gt 0)
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Device errors found'
        $check | ForEach { $result.data += '{0},#' -f $_ }
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'No device errors found'
    }
    
    Return $result
}