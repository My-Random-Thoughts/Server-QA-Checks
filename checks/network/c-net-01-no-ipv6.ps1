<#
    DESCRIPTION: 
        Check IPv6 has been unbound on all active NICs, or globally.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            IPv6 disabled globally
            IPv6 enabled globally, but disabled on all NICs
        WARNING:
        FAIL:
            IPv6 enabled globally, and NIC(s) found with IPv6 enabled
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-net-01-no-ipv6
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-01-no-ipv6'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        # First check if IPv6 is disabled globally
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\TCPIP6\Parameters')
        If ($regKey) { [string]$keyVal = $regKey.GetValue('DisabledComponents') }
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

    If ($keyval -eq '-1')    # All Disabled
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'IPv6 disabled globally'
    }
    Else
    {
        $result.result  = $script:lang['Fail']
        $result.message = 'IPv6 enabled globally'

        # Second, check each adapter
        # Get binding GUIDs from reg key
        Try
        {
            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
            $regKey2 = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\TCPIP6\Linkage')
            If ($regKey2) { $keyVal2 = $regKey2.GetValue('Bind') }
            Try { $regKey.Close() } Catch { }
            $reg.Close()
        }
        Catch
        {
            $result.pass     = $script:lang['Error']
            $result.message += $script:lang['Script-Error']
            $result.data     = $_.Exception.Message
            Return $result
        }

        # Get names from WMI based on keyVal2 GUIDs
        [array]$ipv6Adapters = $null
    
        If ([string]::IsNullOrEmpty($keyVal2) -eq $false)
        {
            ForEach ($bind In $keyVal2)
            {
                Try
                {
                    $deviceid = $bind.split('\')[2]
                    [string]$query   = 'SELECT NetConnectionID FROM Win32_NetworkAdapter WHERE GUID="{0}"' -f $deviceid
                    [array] $adapter = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty NetConnectionID
                }
                Catch
                {
                    $result.result  = $script:lang['Error']
                    $result.message = $script:lang['Script-Error']
                    $result.data    = $_.Exception.Message
                    Return $result
                }

                If ([string]::IsNullOrEmpty($adapter) -eq $false)
                {
                    $ipv6Adapters +=            $adapter
                    $result.data  += '{0},#' -f $adapter
                }
            }

            If ($ipv6Adapters.Count -gt 0)
            {
                $result.result   = $script:lang['Fail']
                $result.message += ' and NIC(s) found with IPv6 enabled'
            }
            Else
            {
                $result.result   = $script:lang['Pass']
                $result.message += ', but disabled on all NICs'
                $result.data     = ''
            }
        }
        Else
        {
            $result.result   = $script:lang['Pass']
            $result.message += ', but disabled on all NICs'
            $result.data     = ''
        }
    }

    Return $result
}
