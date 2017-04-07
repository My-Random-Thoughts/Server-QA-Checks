<#
    DESCRIPTION: 
        Ensure the system is set to reject attempts to enumerate accounts in the SAM by anonymous users.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            Reject annonymous account enumeration is enabled
        WARNING:
        FAIL:
            Reject annonymous account enumeration is disabled
            Registry setting not found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sec-06-reject-enumerate-accounts
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-06-reject-enumerate-accounts'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\Lsa')
        If ($regKey) { $keyVal = $regKey.GetValue('restrictanonymousSAM') }
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
            $result.message = 'Reject annonymous account enumeration is enabled'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Reject annonymous account enumeration is disabled'
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