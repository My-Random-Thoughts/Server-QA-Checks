<#
    DESCRIPTION: 
        Ensure the system is set to request administrative credentials before granting an application elevated privileges. 
        Default setting is either "(1):Prompt for credentials on the secure desktop" or "(3):Prompt for credentials"
        Values and meanings can be seen here - https://msdn.microsoft.com/en-us/library/cc232761.aspx

    REQUIRED-INPUTS:
        ElevatePromptForAdminCredentials - "0,1,2,3,4,5" - List of settings to check for

    DEFAULT-VALUES:
        ElevatePromptForAdminCredentials = ('1', '3')

    DEFAULT-STATE:
        Enabled

    INPUT-DESCRIPTION:
        0: Elevate without prompting
        1: Prompt for credentials on the secure desktop
        2: Prompt for consent on the secure desktop
        3: Prompt for credentials
        4: Prompt for consent
        5: Prompt for consent for non-Windows binaries

    RESULTS:
        PASS:
            System is configured correctly
        WARNING:
        FAIL:
            System is not configured correctly
            Registry setting not found
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sec-09-request-admin-elevated
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-09-request-admin-elevated'

    #... CHECK STARTS HERE ...#

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System')
        If ($regKey) { $keyVal = $regKey.GetValue('ConsentPromptBehaviorAdmin') }
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
        If ($script:appSettings['ElevatePromptForAdminCredentials'] -contains $keyVal)
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'System is configured correctly'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'System is not configured correctly'
        }

        $result.data = 'Current setting: '
        Switch ($keyVal)
        {
            0 { $result.data += 'Elevate without prompting'                    }
            1 { $result.data += 'Prompt for credentials on the secure desktop' }    # Default Setting
            2 { $result.data += 'Prompt for consent on the secure desktop'     }
            3 { $result.data += 'Prompt for credentials'                       }    # Default Setting
            4 { $result.data += 'Prompt for consent'                           }
            5 { $result.data += 'Prompt for consent for non-Windows binaries'  }
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