<#
    DESCRIPTION: 
        Ensure the Region and Language > keyboard and Languages is set correctly
        Default setting is "English (United Kingdom)"  


    PASS:    Keyboard layout is set correctly
    WARNING:
    FAIL:    Keyboard layout is not set correctly / Registry setting not found
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
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
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('Users', $serverName)
        $regKey = $reg.OpenSubKey('.DEFAULT\Keyboard Layout\Preload')
        If ($regKey) { $keyVal = $regKey.GetValue('1') }
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
        If ($keyVal -eq $script:appSettings['DefaultLanguage'])
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Keyboard layout is set correctly'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Keyboard layout is not set correctly'
            $result.data    =  $keyVal
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