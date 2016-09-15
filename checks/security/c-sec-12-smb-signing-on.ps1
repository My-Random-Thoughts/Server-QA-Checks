<#
    DESCRIPTION: 
        Ensure SMB signing is turned on. 



    PASS:    SMB Signing configured correctly
    WARNING:
    FAIL:    SMB Signing not configured correctly / Registry setting not found
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sec-12-smb-signing-on
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'SMB Signing On'
    $result.check  = 'c-sec-12-smb-signing-on'

    #... CHECK STARTS HERE ...#

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters')
        If ($regKey) { $keyVal1 = $regKey.GetValue('RequireSecuritySignature') }
        Try { $regKey.Close() } Catch { }

        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters')
        If ($regKey) { $keyVal2 = $regKey.GetValue('RequireSecuritySignature') }
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

    If (([string]::IsNullOrEmpty($keyVal1) -eq $false) -or ([string]::IsNullOrEmpty($keyVal2) -eq $false))
    {
        $missing = ''
        If ($keyVal1 -eq $script:appSettings['RequireSMBSigning']) { $missing  = '' } Else { $missing  = 'LanmanServer,#'    }
        If ($keyVal2 -eq $script:appSettings['RequireSMBSigning']) { $missing += '' } Else { $missing += 'LanmanWorkstation' }

        If ($missing -eq '')
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'SMB Signing configured correctly'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'SMB Signing not configured correctly'
            $result.data    = 'The following sections are not configured correctly: {0}' -f $missing
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