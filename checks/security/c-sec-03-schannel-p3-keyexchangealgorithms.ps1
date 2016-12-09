<#
    DESCRIPTION:
        Ensure key exchange algorithms are set correctly.  Settings taken from https://www.nartac.com/Products/IISCrypto/Default.aspx using "Best Practices/FIPS 140-2" settings



    PASS:    All key exchange algorithms set correctly
    WARNING:
    FAIL:    One or more key exchange algorithms set incorrectly
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sec-03-schannel-p3-keyexchangealgorithms
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-03-schannel-p3-keyexchangealgorithms'

    #... CHECK STARTS HERE ...#

    Try
    {
        $disabled = $true
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        ForEach ($key In $script:appSettings['KeyExchangeAlgorithms'])
        {
            $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\KeyExchangeAlgorithms\' + $key)
            If ([string]::IsNullOrEmpty($regKey) -eq $false)
            {
                $keyVal = $regKey.GetValue('Enabled')
                If ($keyval -eq $null)
                {
                    $disabled     = $false
                    $result.data += '{0} (Value not explicitly set),#' -f $key
                }
                ElseIf ($keyVal -ne 0xFFFFFFFF)
                {
                    $disabled     = $false
                    $result.data += '{0} (Incorrect),#' -f $key
                }
            }
            Else
            {
                # $result.data += '{0} (Key not explicitly set),#' -f $key
            }
            Try { $regKey.Close() } Catch { }
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

    If ($disabled -eq $true)
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'All key exchange algorithms set correctly'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'One or more key exchange algorithms set incorrectly'
    }

    Return $result
}