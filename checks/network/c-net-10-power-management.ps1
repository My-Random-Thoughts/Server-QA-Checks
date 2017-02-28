<#
    DESCRIPTION: 
        Check network interfaces have their power management switch disabled.
        
    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    RESULTS:
        PASS:
            All adapters have power saving disabled
        WARNING:
        FAIL:
            One or more adapters have power saving enabled
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-net-10-power-management
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-10-power-management'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query1 = 'SELECT DeviceID, NetConnectionID, NetConnectionStatus FROM Win32_NetworkAdapter WHERE NetConnectionStatus = "2"'
        [object]$check1 = Get-WmiObject -ComputerName $serverName -Query $query1 -Namespace ROOT\Cimv2
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    Try
    {
        $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
        $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}')

        ForEach ($adapter In $check1)
        {
            $regKey2 = $regKey.OpenSubKey($($adapter.DeviceID).Padleft(4, '0'))
            $keyVal = $regKey2.GetValue('PnPCapabilities')
            Try { $regKey2.Close() } Catch { }

            Switch ($keyVal)
            {
                 0 { $result.data += "$($adapter.NetConnectionID) (Unknown),#" }
                16 { $result.data += "$($adapter.NetConnectionID) (Enabled),#" }
                24 {  }    # Disabled value
            }
        }

        Try { $regKey.Close() } Catch { }
        $reg.Close()

        If (($result.data).Length -eq 0)
        {
            $result.result  = $script:lang['Pass']
            $result.message = 'All adapters have power saving disabled'
        }
        Else
        {
            $result.result  = $script:lang['Fail']
            $result.message = 'One or more adapters have power saving enabled'
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    Return $result
}