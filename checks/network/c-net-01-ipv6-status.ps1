<#
    DESCRIPTION:
        Check the global IPv6 setting and of status of each NIC.

    REQUIRED-INPUTS:
        IPv6State - "Enabled|Disabled" - State of the IPv6 protocol for each network adapter

    DEFAULT-VALUES:
        IPv6State = 'Disabled'

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            D:IPv6 setting disabled globally
            E:IPv6 setting enabled globally, all NICs enabled
        WARNING:
            D:IPv6 setting enabled globally, all NICs disabled
        FAIL:
            D:IPv6 setting enabled globally, one or more NICs enabled
            E:IPv6 setting enabled globally, one or more NICs disabled
            E:IPv6 setting disabled globally
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-net-01-ipv6-status
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-01-ipv6-status'

    #... CHECK STARTS HERE ...#

    If ($script:appSettings['IPv6State'] -eq 'Disabled') { [string]$lookingFor = '-1'; [string]$stateGood = 'disabled'; [string]$stateBad = 'enabled'  }
    Else                                                 { [string]$lookingFor =  '0'; [string]$stateGood = 'enabled' ; [string]$stateBad = 'disabled' }

    Try
    {
        # First check if IPv6 is set globally
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
        $result.data    = '1: ' + $_.Exception.Message
        Return $result
    }

    # Check each enabled adapter to see their IPv6 status
    Try
    {
        # Get list of all adapters...
        [string]$query    = 'SELECT NetConnectionID, GUID FROM Win32_NetworkAdapter WHERE NetEnabled = "TRUE"'
        [object]$object   = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 -ErrorAction Stop | Select-Object NetConnectionID, GUID
        [object]$adapters = $object | Where-Object { [string]::IsNullOrEmpty($_.NetConnectionID) -eq $false } | Sort-Object NetConnectionID

        # ...and IPv6 enabled adapters...
        $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey2 = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Services\TCPIP6\Linkage')
        If ($regKey2) { $keyVal2 = $regKey2.GetValue('Bind') }
        Try { $regKey.Close() } Catch { }
        $reg.Close()
    }
    Catch
    {
        $result.result   = $script:lang['Error']
        $result.message += $script:lang['Script-Error']
        $result.data     = '2: ' + $_.Exception.Message
        Return $result
    }

    # Separate IPv6 enabled adapters
    [System.Collections.ArrayList]$ipv6d = @()                           # To hold list of IPv6 DISABLED adapters
    [System.Collections.ArrayList]$ipv6e = @()                           # To hold list of IPv6 ENABLED  adapters
    $adapters | ForEach { $ipv6d.Add($_.NetConnectionID) | Out-Null }    # 

    ForEach ($bind In $keyVal2)
    {
        [string]$deviceid = $bind.split('\')[2]
        [string]$found = ''
        $adapters | ForEach { If ($_.GUID -eq $deviceid) { $found = $_.NetConnectionID } }

        If ($found -ne '')
        {
            $ipv6e.Add(   $found) | Out-Null
            $ipv6d.Remove($found) | Out-Null
        }
    }

    # If setting is ENABLED, check all adapters
    $result.data = ''
    If ($script:appSettings['IPv6State'] -eq 'Disabled')
    {
        If ($keyval -ne $lookingFor)
        {
            If ($ipv6e.Count -gt 0)
            {
                # FAIL
                $result.result   = $script:lang['Fail']
                $result.message += "IPv6 setting $stateBad globally, one or more NICs $stateBad"
                $ipv6e | ForEach { $result.data += "$_,#" }
            }
            Else
            {
                # WARNING
                $result.result   = $script:lang['Warning']
                $result.message += "IPv6 setting $stateBad globally, all NICs $stateGood"
                $ipv6e | ForEach { $result.data += "$_,#" }
            }
        }
        Else
        {
            # PASS
            $result.result   = $script:lang['Pass']
            $result.message += "IPv6 setting $stateGood globally"
        }
    }
    Else
    {
        If ($keyval -ne $lookingFor)
        {
            # FAIL
            $result.result   = $script:lang['Fail']
            $result.message += "IPv6 setting $stateBad globally"
        }
        Else
        {
            If ($ipv6d.Count -gt 0)
            {
                # FAIL
                $result.result   = $script:lang['Fail']
                $result.message += "IPv6 setting $stateGood globally, one or more NICs $stateBad"
                $ipv6d | ForEach { $result.data += "$_,#" }
            }
            Else
            {
                # PASS
                $result.result   = $script:lang['Pass']
                $result.message += "IPv6 setting $stateGood globally, all NICs $stateGood"
                $ipv6d | ForEach { $result.data += "$_,#" }
            }
        }
    }
    Return $result
}
