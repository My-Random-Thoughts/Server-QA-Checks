<#
    DESCRIPTION: 
        Ensure protocols are set correctly.  Settings taken from https://www.nartac.com/Products/IISCrypto/Default.aspx using "Best Practices/FIPS 140-2" settings.

    REQUIRED-INPUTS:
        DisabledProtocols - List of protocols that should be disabled

    DEFAULT-VALUES:
        DisabledProtocols = ('Multi-Protocol Unified Hello', 'PCT 1.0', 'SSL 2.0', 'SSL 3.0', 'TLS 1.0')

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            All protocols set correctly
        WARNING:
        FAIL:
            One or more protocols set incorrectly
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sec-04-schannel-p4-protocols
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-04-schannel-p4-protocols'

    #... CHECK STARTS HERE ...#

    Try
    {
        $disabled = $true
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        ForEach ($k In $script:appSettings['DisabledProtocols'])
        {
            For ($i = 0; $i -lt 2; $i++)
            {
                If ($i -eq 0) { $key = $k + '\Server' } Else { $key = $k + '\Client' }

                $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\' + $key)
                If ([string]::IsNullOrEmpty($regKey) -eq $false)
                {
                    If ($i -eq 0) { $keyVal = $regKey.GetValue('Enabled') } Else { $keyVal = $regKey.GetValue('DisabledByDefault') }
                    If ($keyval -eq $null)
                    {
                        $disabled     = $false
                        $result.data += '{0} (Value Missing),#' -f $key
                    }
                    ElseIf ($keyVal -ne $i)
                    {
                        $disabled     = $false
                        $result.data += '{0} (Incorrect),#' -f $key
                    }        
                }
                Else
                {
                    $disabled     = $false
                    $result.data += '{0} (Key Missing),#' -f $key
                }
                Try { $regKey.Close() } Catch { }
            }
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
        $result.message = 'All protocols set correctly'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'One or more protocols set incorrectly'
    }

    Return $result
}