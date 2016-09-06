<#
    DESCRIPTION: 
        Check system is not caching domain credentials



    PASS:    Domain credential caching is disabled
    WARNING:
    FAIL:    Domain credential caching is enabled / Registry setting not found
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sec-08-domain-credential-caching
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Domain Credential Caching'
    $result.check  = 'c-sec-08-domain-credential-caching'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon')
        If ($regKey) { $keyVal = $regKey.GetValue('CachedLogonsCount') }
        Try { $regKey.Close() } Catch { }
        $reg.Close()
    }
    Catch
    {
        $result.result  = 'Error'
        $result.message = 'SCRIPT ERROR'
        $result.data    = $_.Exception.Message
        Return $result
    }
    
    If ([string]::IsNullOrEmpty($keyVal) -eq $false)
    {
        If ($keyVal -eq $script:appSettings['EnableDomainCredentialCaching'])
        {
            $result.result  = 'Pass'
            $result.message = 'Domain credential caching is disabled'
        }
        Else
        {
            $result.result  = 'Fail'
            $result.message = 'Domain credential caching is enabled'
        }
    }
    Else
    {
        $result.result  = 'Fail'
        $result.message = 'Registry setting not found'
        $result.data    = ''
    }
    
    Return $result
}