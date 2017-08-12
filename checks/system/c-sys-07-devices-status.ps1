<#
    DESCRIPTION: 
        Checks Device Manager to ensure there are no unknown devices, conflicts or errors.
        
    REQUIRED-INPUTS:
        IgnoreTheseDeviceNames - List of known devices that can be ignored

    DEFAULT-VALUES:
        IgnoreTheseDeviceNames = ('')

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            No disabled devices or device errors found
        WARNING:
            Disabled devices found
        FAIL:
            Device errors found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sys-07-devices-status
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-07-devices-status'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        # Excludes Working (0) and Disabled (22)
        [string]$query = 'SELECT Name, ConfigManagerErrorCode FROM Win32_PnPEntity WHERE NOT ConfigManagerErrorCode=0'
        $script:appSettings['IgnoreTheseDeviceNames'] | ForEach { $query += ' AND NOT Name = "{0}"' -f $_ }
        [array]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object Name, ConfigManagerErrorCode
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    [boolean]$onlyDisabled = $true
    $check | Sort-Object -Property Name | ForEach {
        If ($_.ConfigManagerErrorCode -ne 22) { $result.data += ('{0} (Error),#'    -f $_.Name); $onlyDisabled = $false }
        Else                                  { $result.data += ('{0} (Disabled),#' -f $_.Name)                         }
    }

    If ($check.Count -gt 0)
    {
        $result.message = 'Device errors found'
        If ($onlyDisabled -eq $true) { $result.result  = $script:lang['Warning'] } Else { $result.result  = $script:lang['Fail'] }
    }
    Else
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'No disabled devices or device errors found'
    }
    
    Return $result
}