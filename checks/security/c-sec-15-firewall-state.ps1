<#
    DESCRIPTION: 
        Check if Windows firewall is enabled or disabled for each of the three profiles.  Set to "0" for off, and "1" for on

    REQUIRED-INPUTS:
        DomainProfile   - "0|1" - Domain firewall state (enabled / disabled)
        PublicProfile   - "0|1" - Public firewall state (enabled / disabled)
        StandardProfile - "0|1" - Standard (Home) firewall state (enabled / disabled)

    DEFAULT-VALUES:
        DomainProfile   = '0'
        PublicProfile   = '0'
        StandardProfile = '0'

    DEFAULT-STATE:
        Enabled

    INPUT-DESCRIPTION:
        0: Disabled
        1: Enabled

    RESULTS:
        PASS:
            Windows firewall is set correctly
        WARNING: 
        FAIL:
            Windows firewall is not set correctly
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sec-15-firewall-state
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
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
    If ($regDP -ne $script:appSettings['DomainProfile']  ) { $result.data += (  'Domain profile is {0}, but should be {1},#' -f $regDP, $script:appSettings['DomainProfile']  ) }
    If ($regSP -ne $script:appSettings['StandardProfile']) { $result.data += ('Standard profile is {0}, but should be {1},#' -f $regSP, $script:appSettings['StandardProfile']) }
    If ($regPP -ne $script:appSettings['PublicProfile']  ) { $result.data += (  'Public profile is {0}, but should be {1}'   -f $regPP, $script:appSettings['PublicProfile']  ) }

    If ($result.data -eq '')
    {
        $result.result  =   $script:lang['Pass']
        $result.message =   'Windows firewall is set correctly'
        $result.data    = (('Domain profile: {0},#Standard profile: {1},#Public profile: {2}' -f $regDP, $regSP, $regPP).Replace('0', 'Disabled').Replace('1', 'Enabled'))
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'Windows firewall is not set correctly'
        $result.data    = ($result.data).Replace('0', 'disabled').Replace('1', 'enabled')
    }

    Return $result
}
