<#
    DESCRIPTION: 
        Ensure the system is set to restrict anonymous access to named pipes

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            Restrict annonymous pipe/share access is enabled
        WARNING:
        FAIL:
            Restrict annonymous pipe/share access is disabled
            Registry setting not found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sec-10-anonymous-pipe-share-access
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-10-anonymous-pipe-share-access'

    #... CHECK STARTS HERE ...#

    Try
    {    
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanManServer\Parameters')
        If ($regKey) { $keyVal = $regKey.GetValue('restrictnullsessaccess') }
        Try { $regKey.Close() } Catch { }
        $reg.Close()
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ([string]::IsNullOrEmpty($keyVal) -eq $false)
    {
        If ($keyVal -eq '1')
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Restrict annonymous pipe/share access is enabled'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Restrict annonymous pipe/share access is disabled'
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Registry setting not found'
        $result.data    = ''
    }
    
    Return $result
}