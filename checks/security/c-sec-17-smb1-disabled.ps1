<#
    DESCRIPTION: 
        Ensure SMBv1 is disabled. 

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            SMBv1 is disabled
        WARNING:
        FAIL:
            SMBv1 is enabled
            Registry setting not found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sec-17-smb1-disabled
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-17-smb1-disabled'

    #... CHECK STARTS HERE ...#

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters')
        If ($regKey) { $keyVal = $regKey.GetValue('SMB1') }
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
        If ($keyVal -eq '0')
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'SMBv1 is disabled'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'SMBv1 is enabled'
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Registry setting not found'
        $result.data    = 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters,#DWORD: SMBv1, Value: 0'
    }

    Return $result
}