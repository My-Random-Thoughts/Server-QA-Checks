<#
    DESCRIPTION: 
        Check the network adapter speed and duplex settings.  Should be set to "Full Duplex" and "Auto".

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            All network adapters configured correctly
        WARNING:
            One or more network adapters configured incorrectly
        FAIL:
            No network adapters found or enabled
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-net-05-network-speed-duplex
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-net-05-network-speed-duplex'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = "True"'
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
        $result.result  = $script:lang['Pass']
        $result.message = 'All network adapters configured correctly'

        ForEach ($connection In $check)
        {
            $data   = $connection.Caption -split ']'
            $suffix = $data[0].Substring(($data[0].length - 4), 4)

            Try
            {
                $reg     = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
                $regKey1 = $reg.OpenSubKey('SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\' + $suffix)
                If ($regKey1) { $keyVal = $regKey1.GetValue('*PhysicalMediaType') }
            }
            Catch
            {
                $result.result  = $script:lang['Error']
                $result.message = $script:lang['Script-Error']
                $result.data    = $_.Exception.Message
                Return $result
            }

            If ($keyVal -eq '14')    # Ethernet
            {
                $nic   = $connection.GetRelated('Win32_NetworkAdapter') | Select-Object Speed, NetConnectionID
                $keySD = $regKey1.GetValue('*SpeedDuplex')

                $regPath2 = 'SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}\' + $suffix + '\Ndi\Params\*SpeedDuplex\enum'
                $regKey2  = $reg.OpenSubKey($regPath2)
                If ($keySD -ne $null) { $duplex = $regKey2.GetValue($keySD) } Else { $duplex = 'unknown' }

                $nicSpeed = [math]::Round($nic.Speed/1000000)
                If (($nicSpeed -lt 1000) -or ($duplex -notlike '*auto*'))
                {
                    $result.result  = $script:lang['Warning']
                    $result.message = 'One or more network adapters configured incorrectly'
                }
                $result.data += '{0}: {1}mb ({2}),#' -f $nic.NetConnectionID, $nicSpeed, $duplex
                If ($keySD -ne $null) { $regKey2.Close() }
            }
        }
        $regKey1.Close()
        $reg.Close()
    }
    Else
    {
       $result.result  = $script:lang['Fail']
       $result.message = 'No network adapters found or enabled'
       $result.data    = ''
    }

    Return $result
}