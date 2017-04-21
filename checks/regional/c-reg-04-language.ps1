<#
    DESCRIPTION: 
        Ensure the Region and Language > keyboard and Languages is set correctly.  Default setting is "English (United Kingdom)".

    REQUIRED-INPUTS:
        DefaultLanguage - Numerical value of the correct keyboard to use

    DEFAULT-VALUES:
        DefaultLanguage = '00000809'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            Keyboard layout is set correctly
        WARNING:
        FAIL:
            Keyboard layout is not set correctly
            Registry setting not found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-reg-04-language
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-reg-04-language'

    #... CHECK STARTS HERE ...#

    Try
    {
        $reg     = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('Users', $serverName)
        $regKey1 = $reg.OpenSubKey('.DEFAULT\Keyboard Layout\Preload')
        If ($regKey1) { $keyVal1 = $regKey1.GetValue('1') }
        Try { $regKey1.Close() } Catch { }
        $reg.Close()

        If ([string]::IsNullOrEmpty($keyVal1) -eq $false)
        {
            $reg     = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
            $regKey2 = $reg.OpenSubKey("SYSTEM\CurrentControlSet\Control\Keyboard Layouts\$keyVal1")
            If ($regKey2) { $keyVal2 = $regKey2.GetValue('Layout Text') }
            Try { $regKey2.Close() } Catch { }
            $reg.Close()
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ([string]::IsNullOrEmpty($keyVal1) -eq $false)
    {
        If ($keyVal1 -eq $script:appSettings['DefaultLanguage'])
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Keyboard layout is set correctly'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Keyboard layout is not set correctly'
        }
        
        $result.data = $keyVal1
        If ([string]::IsNullOrEmpty($keyVal2) -eq $false) { $result.data += ",#$keyVal2" }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Registry setting not found'
        $result.data    = ''
    }
    
    Return $result
}
