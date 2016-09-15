<#
    DESCRIPTION: 
        Check if Windows firewall is enabled or disabled



    PASS:    Windows firewall is set correctly
    WARNING: 
    FAIL:    Windows firewall is not set correctly
    MANUAL:
    NA:

    APPLIES: All

    REQUIRED-FUNCTIONS:
#>

Function c-sec-15-firewall-state
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = 'Check Firewall State'
    $result.check  = 'c-sec-15-firewall-state'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        Try { [string]$regDP = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\DomainProfile'  ).GetValue('EnableFirewall') } Catch { [string]$regDP = 'Unknown' }
        Try { [string]$regSP = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile').GetValue('EnableFirewall') } Catch { [string]$regSP = 'Unknown' }
        Try { [string]$regPP = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile'  ).GetValue('EnableFirewall') } Catch { [string]$regPP = 'Unknown' }
        $reg.Close()
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    $result.data = ''
    If ($regDP -ne $global:appSettings['DomainProfile']  ) { $result.data += (  'Domain profile is {0}, but should be {1},#' -f $regDP, $global:appSettings['DomainProfile']  ) }
    If ($regSP -ne $global:appSettings['StandardProfile']) { $result.data += ('Standard profile is {0}, but should be {1},#' -f $regSP, $global:appSettings['StandardProfile']) }
    If ($regPP -ne $global:appSettings['PublicProfile']  ) { $result.data += (  'Public profile is {0}, but should be {1},#' -f $regPP, $global:appSettings['PublicProfile']  ) }

    If ($result.data -eq '')
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'Windows firewall is set correctly'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Windows firewall is not set correctly'
        $result.data    = ($result.data).Replace('0', 'disabled').Replace('1', 'enabled')
    }

    Return $result
}