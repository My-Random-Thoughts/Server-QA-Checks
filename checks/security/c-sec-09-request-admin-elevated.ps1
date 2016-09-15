<#
    DESCRIPTION: 
        Ensure the system is set to request administrative credentials before granting an application elevated privileges. 
        Default setting is either "(1):Prompt for credentials on the secure desktop" or "(3):Prompt for credentials"


    PASS:    Prompt for credentials is enabled
    WARNING:
    FAIL:    System is not set to "Prompt for credentials" when launching an application with elevated privileges / Registry setting not found
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sec-09-request-admin-elevated
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Elevate Prompt For Admin Credentials'
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
            $result.message = 'Prompt for credentials is enabled'
            $result.data    = ''
        }
        Else
        {
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
        
            $result.result  = $script:lang['Fail']
            $result.message = 'System is not set to "Prompt for credentials" when launching an application with elevated privileges'
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