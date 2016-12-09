<#
    DESCRIPTION: 
        Ensure the security cipher order is set correctly.  Settings taken from https://www.nartac.com/Products/IISCrypto/Default.aspx using "Best Practices/FIPS 140-2" settings



    PASS:    Cipher suite order set correctly
    WARNING:
    FAIL:    Cipher suite order not set correctly / Cipher suite order set to the default value
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sec-05-schannel-p5-cipher-order
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sec-05-schannel-p5-cipher-order'

    #... CHECK STARTS HERE ...#

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002')
        If ($regKey) { $keyVal = $regKey.GetValue('Functions') }
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
        If ($keyVal -eq $script:appSettings['CipherSuiteOrder'])
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'Cipher suite order set correctly'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'Cipher suite order not set correctly'
        }
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Cipher suite order set to the default value'
    }

    Return $result
}