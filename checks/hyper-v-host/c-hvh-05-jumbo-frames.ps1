<#
    DESCRIPTION: 
        Check the network adapter jumbo frame setting.  Should be set to 9000 or more.

    REQUIRED-INPUTS:
        IgnoreTheseAdapters - List of adapters to ignore this setting for

    DEFAULT-VALUES:
        IgnoreTheseAdapters = ('')

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            All network adapters configured correctly
        WARNING:
        FAIL:
            One or more network adapters are not using Jumbo Frames
            No network adapters found or enabled
        MANUAL:
        NA:

    APPLIES:
        Hyper-V Host Servers

    REQUIRED-FUNCTIONS:
        Check-NameSpace
#>

Function c-hvh-05-jumbo-frames
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-hvh-05-jumbo-frames'

    #... CHECK STARTS HERE ...#

    If ((Check-NameSpace -ServerName $serverName -NameSpace 'ROOT\Virtualization') -eq $true)
    {
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
                    If ($regKey1) { $keyVal = $regKey1.GetValue('*JumboPacket') }
                }
                Catch
                {
                    $result.result  = $script:lang['Error']
                    $result.message = $script:lang['Script-Error']
                    $result.data    = $_.Exception.Message
                    Return $result
                }

                If (($keyVal -gt '1') -and ($keyVal -lt '9000'))    # Jumbo frames > 9000
                {
                    [boolean]$ignore = $false
                    [string] $nic    = $connection.GetRelated('Win32_NetworkAdapter') | Select-Object -ExpandProperty NetConnectionID
                    $script:appSettings['IgnoreTheseAdapters'] | ForEach { If ($nic -like "*$_*") { $ignore = $true } }
                    If ($ignore -eq $false)
                    {
                        $result.result   = $script:lang['Fail']
                        $result.message  = 'One or more network adapters are not using Jumbo Frames'
                        $result.data    += "$nic - $keyVal,#"
                    }
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
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'Not a Hyper-V host server'
    }
    Return $result
}
