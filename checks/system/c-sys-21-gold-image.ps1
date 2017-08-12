<#
    DESCRIPTION: 
        Allows you to checks a specific list of registry keys and values to see if your in-house gold image was used.
        Up to three registry keys and values can be checked.  Note: All keys must be in HKEY_LOCAL_MACHINE only

    REQUIRED-INPUTS:
        Registry1Key   - "LARGE" - Full path and name of a registry value to check.  "HKEY_LOCAL_MACHINE\" is automatically added.
        Registry1Value - Minimum value or string required for the registry value.  Enter "Report Only" to just show the value.
        Registry2Key   - "LARGE" - Full path and name of a registry value to check.  "HKEY_LOCAL_MACHINE\" is automatically added.
        Registry2Value - Minimum value or string required for the registry value.  Enter "Report Only" to just show the value.
        Registry3Key   - "LARGE" - Full path and name of a registry value to check.  "HKEY_LOCAL_MACHINE\" is automatically added.
        Registry3Value - Minimum value or string required for the registry value.  Enter "Report Only" to just show the value.

    DEFAULT-VALUES:
        Registry1Key   = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion\InstallDate'
        Registry1Value = 'Report Only'
        Registry2Key   = ''
        Registry2Value = ''
        Registry3Key   = ''
        Registry3Value = ''

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            All gold build checks were found and correct
        WARNING:
        FAIL:
            One or more gold build checks were below specified value
        MANUAL:
            One or more gold build checks were "Report Only"
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sys-21-gold-image
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-21-gold-image'

    #... CHECK STARTS HERE ...#

    Try
    {
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)

        # Registry Key 1
        If ($script:appSettings['Registry1Key'].Length -gt 0)
        {
            [string]$regK1 = ($script:appSettings['Registry1Key'].Split('\')[-1])
            [string]$regP1 = ($script:appSettings['Registry1Key'].SubString(0, $script:appSettings['Registry1Key'].Length - ($regK1.Length + 1)))

            $regKey1 = $reg.OpenSubKey($regP1)
            If ($regKey1) { [string]$keyVal1 = $regKey1.GetValue($regK1) }
            Try { $regKey1.Close() } Catch { }

            # Check to see if it's a date we can convert
            If ($regK1.ToLower().Contains('date')) { If ($keyVal1 -eq ([System.Convert]::ToInt64($keyVal1)))
            { $keyVal1 = ((Get-Date -Date '01/01/1970').AddSeconds(([System.Convert]::ToInt64($keyVal1)))) } }
        }

        # Registry Key 2
        If ($script:appSettings['Registry2Key'].Length -gt 0)
        {
            [string]$regK2 = ($script:appSettings['Registry2Key'].Split('\')[-1])
            [string]$regP2 = ($script:appSettings['Registry2Key'].SubString(0, $script:appSettings['Registry2Key'].Length - ($regK2.Length + 1)))

            $regKey2 = $reg.OpenSubKey($regP2)
            If ($regKey2) { [string]$keyVal2 = $regKey2.GetValue($regK2) }
            Try { $regKey2.Close() } Catch { }

            # Check to see if it's a date we can convert
            If ($regK2.ToLower().Contains('date')) { If ($keyVal2 -eq ([System.Convert]::ToInt64($keyVal2)))
            { $keyVal2 = ((Get-Date -Date '01/01/1970').AddSeconds(([System.Convert]::ToInt64($keyVal2)))) } }
        }

        # Registry Key 3
        If ($script:appSettings['Registry3Key'].Length -gt 0)
        {
            [string]$regK3 = ($script:appSettings['Registry3Key'].Split('\')[-1])
            [string]$regP3 = ($script:appSettings['Registry3Key'].SubString(0, $script:appSettings['Registry3Key'].Length - ($regK3.Length + 1)))

            $regKey3 = $reg.OpenSubKey($regP3)
            If ($regKey3) { [string]$keyVal3 = $regKey3.GetValue($regK3) }
            Try { $regKey3.Close() } Catch { }

            # Check to see if it's a date we can convert
            If ($regK3.ToLower().Contains('date')) { If ($keyVal3 -eq ([System.Convert]::ToInt64($keyVal3)))
            { $keyVal3 = ((Get-Date -Date '01/01/1970').AddSeconds(([System.Convert]::ToInt64($keyVal3)))) } }
        }

        $reg.Close()
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    # Check the values
    $result.result  = $script:lang['Pass']
    $result.message = 'All gold build checks were found and correct'
    $result.data    = ''

    If ($script:appSettings['Registry1Key'] -ne '')
    {
        $result.data += ('1: ({0}) {1}: {2},#' -f 'XXXX', $regK1, $keyval1)
        If ($script:appSettings['Registry1Value'] -ne 'Report Only') {
            If ($keyVal1 -ge $script:appSettings['Registry1Value']) { $result.data = $result.data.Replace('XXXX', 'Pass') } Else { $result.data = $result.data.Replace('XXXX', 'Fail') }
        } Else { $result.data = $result.data.Replace('XXXX', 'Report') }
    }

    If ($script:appSettings['Registry2Key'] -ne '')
    {
        $result.data += ('2: ({0}) {1}: {2},#' -f 'XXXX', $regK2, $keyval2)
        If ($script:appSettings['Registry2Value'] -ne 'Report Only') {
            If ($keyVal2 -ge $script:appSettings['Registry2Value']) { $result.data = $result.data.Replace('XXXX', 'Pass') } Else { $result.data = $result.data.Replace('XXXX', 'Fail') }
        } Else { $result.data = $result.data.Replace('XXXX', 'Report') }
    }

    If ($script:appSettings['Registry3Key'] -ne '')
    {
        $result.data += ('3: ({0}) {1}: {2},#' -f 'XXXX', $regK3, $keyval3)
        If ($script:appSettings['Registry3Value'] -ne 'Report Only') {
            If ($keyVal3 -ge $script:appSettings['Registry3Value']) { $result.data = $result.data.Replace('XXXX', 'Pass') } Else { $result.data = $result.data.Replace('XXXX', 'Fail') }
        } Else { $result.data = $result.data.Replace('XXXX', 'Report') }
    }

    If ($result.data.Contains(': (Fail)'))   { $result.result = $script:lang['Fail']  ; $result.message = 'One or more gold build checks were below the specified value' }
    If ($result.data.Contains(': (Report)')) { $result.result = $script:lang['Manual']; $result.message = 'One or more gold build checks were "Report Only"'             }

    Return $result
}
