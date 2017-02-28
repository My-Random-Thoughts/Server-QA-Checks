<#
    DESCRIPTION: 
        Ensure hashes are set correctly.  Settings taken from https://www.nartac.com/Products/IISCrypto/Default.aspx using "Best Practices/FIPS 140-2" settings.

    REQUIRED-INPUTS:
        EnabledHashes  - List of hashes that should be enabled
        DisabledHashes - List of hashes that should be disabled

    DEFAULT-VALUES:
        EnabledHashes  = ('SHA', 'SHA256', 'SHA384', 'SHA512')
        DisabledHashes = ('MD5')

    RESULTS:
        PASS:
            All hashes set correctly
        WARNING:
        FAIL:
            One or more hashes set incorrectly
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sec-02-schannel-p2-hashes
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-02-schannel-p2-hashes'

    #... CHECK STARTS HERE ...#

    Try
    {
        $disabled = $true
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)

        For ($i = 0; $i -lt 2; $i++)
        {
            If ($i -eq 0) { $regPathCheck = $script:appSettings['EnabledHashes'];  $regValue = 0xFFFFFFFF; $regResult = 'Enabled'  }
            If ($i -eq 1) { $regPathCheck = $script:appSettings['DisabledHashes']; $regValue = 0;          $regResult = 'Disabled' }

            ForEach ($key In $regPathCheck)
            {
                $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Hashes\' + $key)
                If ($regKey -ne $null)
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
                    # Only show MISSING for hashes that should be disabled
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
        $result.message = 'All hashes set correctly'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'One or more hashes set incorrectly'
    }

    Return $result
}