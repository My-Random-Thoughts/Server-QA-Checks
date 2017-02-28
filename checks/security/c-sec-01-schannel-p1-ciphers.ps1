<#
    DESCRIPTION: 
        Ensure security ciphers are set correctly.  Settings taken from https://www.nartac.com/Products/IISCrypto/Default.aspx using "Best Practices/FIPS 140-2" settings.

    REQUIRED-INPUTS:
        EnabledCiphers  - List of Ciphers that should be enabled
        DisabledCiphers - List of Ciphers that should be disabled

    DEFAULT-VALUES:
        EnabledCiphers  = ('AES 128/128', 'AES 256/256', 'Triple DES 168/168')
        DisabledCiphers = ('DES 56/56', 'NULL', 'RC2 128/128', 'RC2 40/128', 'RC2 56/128', 'RC2 56/56', 'RC4 128/128', 'RC4 40/128', 'RC4 56/128', 'RC4 64/128')

    RESULTS:
        PASS:
            All ciphers set correctly
        WARNING:
        FAIL:
            One or more ciphers set incorrectly
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sec-01-schannel-p1-ciphers
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-01-schannel-p1-ciphers'

    #... CHECK STARTS HERE ...#

    Try
    {
        $disabled = $true
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)

        For ($i = 0; $i -lt 2; $i++)
        {
            If ($i -eq 0) { $regPathCheck = $script:appSettings['EnabledCiphers'];  $regValue = 0xFFFFFFFF; $regResult = 'Enabled'  }
            If ($i -eq 1) { $regPathCheck = $script:appSettings['DisabledCiphers']; $regValue = 0;          $regResult = 'Disabled' }

            ForEach ($key In $regPathCheck)
            {
                $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Ciphers\' + $key)
                If ([string]::IsNullOrEmpty($keyKey) -eq $false)
                {
                    $keyVal = $regKey.GetValue('Enabled')
                    If ($keyVal -ne $regValue)
                    {
                        $disabled     = $false
                        $result.data += '{0} (Should be {1}),#' -f $key, $regResult
                    }        
                }
                Else
                {
                    # Only show MISSING for ciphers that should be disabled
                    If ($i -eq 1)
                    {
                        $disabled     = $false
                        $result.data += '{0} (Missing, should be {1}),#' -f $key, $regResult
                    }
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
        $result.message = 'All ciphers set correctly'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'One or more ciphers set incorrectly'
    }

    Return $result
}