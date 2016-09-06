<#
    DESCRIPTION: 
        Ensure the Region and Language > Location is set correctly.
        Default setting is "United Kingdom"


    PASS:    Regional location set correctly
    WARNING:
    FAIL:    Regional location incorrectly set to {0} / Registry setting not found
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-reg-03-location
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Region > Location'
    $result.check  = 'c-reg-03-location'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('Users', $serverName)
        $regKey = $reg.OpenSubKey('.DEFAULT\Control Panel\International')
        If ($regKey) { $keyVal = $regKey.GetValue('sCountry') }
        Try { $regKey.Close() } Catch { }
        $reg.Close()
    }
    Catch
    {
        $result.result  = 'Error'
        $result.message = 'SCRIPT ERROR'
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ([string]::IsNullOrEmpty($keyVal) -eq $false)
    {
        If ($keyVal -eq $script:appSettings['DefaultLocation'])
        {
            $result.result  = 'Pass'
            $result.message = 'Regional location set correctly'
        }
        Else
        {
            $result.result  = 'Fail'
            $result.message = 'Regional location incorrectly set to {0}' -f $keyVal
            $result.data    = $keyVal.toString()
        }
    }
    Else
    {
        $result.result  = 'Fail'
        $result.message = 'Registry setting not found'
        $result.data    = ''
    }
    
    Return $result
}