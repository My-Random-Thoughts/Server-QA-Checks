<#
    DESCRIPTION: 
        Check the WINS NetBIOS Settings for each enabled network adapter

    REQUIRED-INPUTS:
        RequriedSetting - "0|1|2" - Each adapter should be set to this value

    DEFAULT-VALUES:
        RequriedSetting = 2

    DEFAULT-STATE:
        Enabled

    INPUT-DESCRIPTION:
        0: Default (Use NetBIOS setting from DHCP server)
        1: Enabled NetBIOS over TCP/IP
        2: Disabled NetBIOS over TCP/IP

    RESULTS:
        PASS:
            All adapters are configured correctly
        WARNING:
            No network adapters configured
        FAIL:
            One or more adapters are not configured correctly
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-net-13-netbios-setting
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-13-netbios-setting'
    
    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled="TRUE"'
        [array] $check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ($check.Count -gt 0)
    {
        ForEach ($connection In $check)
        {
            If ($connection.TCPIPNetBIOSOptions -ne $script:appSettings['RequriedSetting'])
            {
                $nicName = $connection.GetRelated('Win32_NetworkAdapter') | Select-Object -ExpandProperty NetConnectionID

                Switch ($connection.TCPIPNetBIOSOptions)
                {
                    0 { $value = 'Default (0)'  }
                    1 { $value = 'Enabled (1)'  }
                    2 { $value = 'Disabled (2)' }
                }
                $result.data += ('Adapter: {0}: Setting: {1},#' -f $nicName, $value)
            }
        }

        If ($result.data -ne '')
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'One or more adapters are not configured correctly'
        }
        Else
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'All adapters are configured correctly'
        }
    }
    Else
    {
        $result.result  = $script:lang['Warning']
        $result.message = 'No network adapters configured'
    }

    Return $result
}
